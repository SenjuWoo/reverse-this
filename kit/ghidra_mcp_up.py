#!/usr/bin/env python3
"""ghidra_mcp_up.py — check or launch the optional local Ghidra MCP stack.

The stack has two layers:
  Ghidra plugin HTTP   127.0.0.1:8080  (GhidraMCP extension)
  MCP streamable HTTP  127.0.0.1:8081/mcp (bridge process)

Usage:
    python ghidra_mcp_up.py            # JSON status, exit 0 only if both answer
    python ghidra_mcp_up.py --text     # one line per layer
    python ghidra_mcp_up.py --launch   # start GHIDRA_MCP_CMD or an optional start.cmd,
                                       # wait for both layers, then print status

Unattended Ghidra work does not need this stack: use analyzeHeadless. MCP is an
optional interactive bridge; the agent starts it only when a launcher exists.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

GHIDRA_URL = "http://127.0.0.1:8080/health"
MCP_URL = "http://127.0.0.1:8081/mcp"
MAX_BODY = 64 * 1024


def kit_root() -> Path:
    """Resolve the kit from env, then from this file, then from the cwd."""
    explicit = os.environ.get("REVERSE_THIS_KIT_ROOT")
    if explicit:
        return Path(explicit)
    here = Path(__file__).resolve()
    for parent in [here.parent, *here.parents]:
        if (parent / "sandbox").is_dir() and (parent / "catalog").is_dir():
            return parent
    return Path.cwd()


MANUAL_START = kit_root() / "sandbox/manual/ghidra-mcp/start.cmd"


def _read_bytes(response, limit: int = MAX_BODY) -> tuple[bytes, str | None]:
    try:
        data = response.read(limit + 1)
    except Exception as exc:  # noqa: BLE001 - a body is optional for diagnostics
        return b"", str(exc)
    if len(data) > limit:
        return data[:limit], f"response exceeded {limit} bytes"
    return data, None


def _text(data: bytes) -> str:
    return data.decode("utf-8", "replace")


def _ghidra_result(message, status: int, url: str) -> dict:
    data = message.get("data") if isinstance(message, dict) else None
    if not isinstance(data, dict):
        return {"url": url, "up": True, "status": status, "identity": "unknown",
                "healthy": False, "program_loaded": False, "error": "health response has no data object"}
    strong_marker = any(key in data for key in ("ghidra_version", "mode", "capabilities", "program"))
    if not strong_marker:
        return {"url": url, "up": True, "status": status, "identity": "unknown",
                "healthy": False, "program_loaded": False, "error": "health response is not GhidraMCP"}
    healthy = message.get("success") is True and data.get("status") == "ok"
    program = data.get("program")
    return {
        "url": url,
        "up": True,
        "status": status,
        "identity": "ghidra",
        "healthy": bool(healthy),
        "program_loaded": bool(program),
        "version": data.get("version"),
        "ghidra_version": data.get("ghidra_version"),
        "mode": data.get("mode"),
        "error": None if healthy else "GhidraMCP backend is not healthy",
    }


def probe_ghidra(url: str, timeout: float = 1.5) -> dict:
    """Recognize the official GhidraMCP JSON health envelope, not a bare HTTP answer."""
    request = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            body, read_error = _read_bytes(response)
            status = response.status
    except urllib.error.HTTPError as exc:
        body, read_error = _read_bytes(exc)
        return {"url": url, "up": True, "status": exc.code, "identity": "unknown",
                "healthy": False, "program_loaded": False,
                "error": f"HTTP {exc.code}" + (f": {read_error}" if read_error else "")}
    except Exception as exc:  # noqa: BLE001 - connection errors are the normal miss
        return {"url": url, "up": False, "status": None, "identity": "unknown",
                "healthy": False, "program_loaded": False, "error": str(exc)}
    if read_error:
        return {"url": url, "up": True, "status": status, "identity": "unknown",
                "healthy": False, "program_loaded": False, "error": read_error}
    try:
        message = json.loads(_text(body))
    except (ValueError, TypeError) as exc:
        return {"url": url, "up": True, "status": status, "identity": "unknown",
                "healthy": False, "program_loaded": False,
                "error": f"malformed health JSON: {exc}"}
    return _ghidra_result(message, status, url)


def _sse_message(event: bytes):
    """Return one SSE JSON data payload, or None for comments/keepalives."""
    lines = event.replace(b"\r\n", b"\n").split(b"\n")
    data = []
    for line in lines:
        if line.startswith(b"data:"):
            data.append(line[5:].lstrip(b" "))
    if not data:
        return None
    try:
        return json.loads(_text(b"\n".join(data)))
    except (ValueError, TypeError):
        return None


def _read_sse_response(response, expected_id: int, timeout: float) -> tuple[dict | None, str | None]:
    """Read bounded SSE until the initialize response, ignoring keepalives."""
    deadline = time.monotonic() + timeout
    buf = b""
    total = 0
    events = 0
    while total < MAX_BODY and time.monotonic() < deadline:
        try:
            chunk = response.read1(4096)
        except Exception as exc:  # noqa: BLE001 - a timed-out stream is a failed probe
            return None, str(exc)
        if not chunk:
            break
        total += len(chunk)
        if total > MAX_BODY:
            return None, f"response exceeded {MAX_BODY} bytes"
        buf += chunk.replace(b"\r\n", b"\n")
        while b"\n\n" in buf:
            raw, buf = buf.split(b"\n\n", 1)
            events += 1
            if events > 64:
                return None, "too many SSE events before initialize response"
            message = _sse_message(raw)
            if isinstance(message, dict) and str(message.get("id")) == str(expected_id):
                return message, None
    if buf.strip():
        message = _sse_message(buf)
        if isinstance(message, dict) and str(message.get("id")) == str(expected_id):
            return message, None
    return None, "no matching SSE initialize response"


def _mcp_result(message, expected_id: int, url: str, status: int, session: str | None) -> dict:
    base = {"url": url, "up": True, "status": status, "identity": "unknown",
            "healthy": False, "session": bool(session)}
    if not isinstance(message, dict):
        return {**base, "error": "MCP response is not a JSON object"}
    if message.get("jsonrpc") != "2.0":
        return {**base, "error": "MCP response is not JSON-RPC 2.0"}
    if str(message.get("id")) != str(expected_id):
        return {**base, "error": f"unexpected MCP response id: {message.get('id')!r}"}
    if "error" in message:
        return {**base, "error": f"MCP error: {message.get('error')}"}
    result = message.get("result")
    if not isinstance(result, dict):
        return {**base, "error": "MCP initialize result is missing"}
    server = result.get("serverInfo")
    name = str((server or {}).get("name", "")) if isinstance(server, dict) else ""
    protocol = result.get("protocolVersion")
    if not isinstance(protocol, str) or not protocol:
        return {**base, "error": "MCP initialize result has no protocolVersion"}
    if not name:
        return {**base, "error": "MCP initialize result has no serverInfo.name"}
    normalized = name.lower().replace("_", "-")
    is_ghidra = "ghidra" in normalized and "mcp" in normalized
    return {
        **base,
        "identity": "mcp" if is_ghidra else "unknown",
        "healthy": is_ghidra,
        "server_name": name,
        "protocol": protocol,
        "error": None if is_ghidra else f"unrelated MCP server: {name}",
    }


def _cleanup_session(url: str, session: str | None, timeout: float) -> None:
    if not session:
        return
    try:
        request = urllib.request.Request(url, method="DELETE", headers={"Mcp-Session-Id": session})
        with urllib.request.urlopen(request, timeout=min(timeout, 1.0)):
            pass
    except Exception:  # noqa: BLE001 - cleanup is best effort
        pass


def probe_mcp(url: str, timeout: float = 2.5) -> dict:
    """Perform an MCP initialize over JSON or Streamable HTTP SSE."""
    expected_id = 1
    payload = json.dumps({
        "jsonrpc": "2.0",
        "id": expected_id,
        "method": "initialize",
        "params": {
            "protocolVersion": "2025-03-26",
            "capabilities": {},
            "clientInfo": {"name": "reverse-this", "version": "1"},
        },
    }).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=payload,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
        },
    )
    status = None
    session = None
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            status = response.status
            session = response.headers.get("Mcp-Session-Id")
            content_type = response.headers.get("Content-Type", "").lower()
            if "text/event-stream" in content_type:
                message, error = _read_sse_response(response, expected_id, timeout)
                if error:
                    return {"url": url, "up": True, "status": status, "identity": "unknown",
                            "healthy": False, "session": bool(session), "error": error}
                return _mcp_result(message, expected_id, url, status, session)
            body, read_error = _read_bytes(response)
            if read_error:
                return {"url": url, "up": True, "status": status, "identity": "unknown",
                        "healthy": False, "session": bool(session), "error": read_error}
    except urllib.error.HTTPError as exc:
        return {"url": url, "up": True, "status": exc.code, "identity": "unknown",
                "healthy": False, "error": f"HTTP {exc.code}"}
    except Exception as exc:  # noqa: BLE001 - connection errors are the normal miss
        return {"url": url, "up": False, "status": None, "identity": "unknown",
                "healthy": False, "error": str(exc)}
    finally:
        _cleanup_session(url, session, timeout)
    try:
        message = json.loads(_text(body))
    except (ValueError, TypeError) as exc:
        return {"url": url, "up": True, "status": status, "identity": "unknown",
                "healthy": False, "session": bool(session), "error": f"malformed MCP JSON: {exc}"}
    return _mcp_result(message, expected_id, url, status, session)


def snapshot() -> dict:
    ghidra = probe_ghidra(GHIDRA_URL)
    mcp = probe_mcp(MCP_URL)
    return {
        "ghidra_plugin": ghidra,
        "mcp_bridge": mcp,
        "ready": ghidra.get("identity") == "ghidra"
        and ghidra.get("healthy") is True
        and mcp.get("identity") == "mcp"
        and mcp.get("healthy") is True,
    }


def launch() -> int:
    status = snapshot()
    if status["ready"]:
        print(json.dumps(status, indent=2))
        return 0

    command = os.environ.get("GHIDRA_MCP_CMD")
    if not command and MANUAL_START.is_file():
        command = str(MANUAL_START)
    if not command:
        print(
            json.dumps(
                {
                    "error": "no Ghidra MCP launcher configured",
                    "optional": True,
                    "fix": "Use analyzeHeadless for unattended Ghidra analysis. "
                    "Set GHIDRA_MCP_CMD only if a Ghidra MCP bridge is installed.",
                }
            )
        )
        return 2

    subprocess.Popen(command, shell=True)
    wait = int(os.environ.get("GHIDRA_MCP_WAIT", "60"))
    deadline = time.monotonic() + max(0, wait)
    while True:
        status = snapshot()
        if status["ready"]:
            print(json.dumps({"launched": command, **status}, indent=2))
            return 0
        if time.monotonic() >= deadline:
            print(json.dumps({"launched": command, **status}, indent=2))
            return 1
        time.sleep(2)


def main(argv: list[str]) -> int:
    if "--launch" in argv:
        return launch()

    status = snapshot()
    if "--text" in argv:
        for name, row in (("ghidra", status["ghidra_plugin"]), ("mcp", status["mcp_bridge"])):
            state = "up" if row["up"] else "down"
            extra = f" identity={row['identity']} healthy={row.get('healthy', False)}"
            if row.get("error"):
                extra += f" error={row['error']}"
            print(f"{name}: {state} {row['url']} status={row['status']}{extra}")
    else:
        print(json.dumps(status, indent=2))
    return 0 if status["ready"] else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
