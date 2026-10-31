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

GHIDRA_URL = "http://127.0.0.1:8080/"
MCP_URL = "http://127.0.0.1:8081/mcp"


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


def probe(url: str, timeout: float = 1.5) -> dict:
    request = urllib.request.Request(url, method="GET")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return {"url": url, "up": True, "status": response.status}
    except urllib.error.HTTPError as exc:
        # Any HTTP answer means the listener is alive (405/400 are common here).
        return {"url": url, "up": True, "status": exc.code}
    except Exception as exc:  # noqa: BLE001 - connection errors are the normal miss
        return {"url": url, "up": False, "status": None, "error": str(exc)}


def snapshot() -> dict:
    ghidra = probe(GHIDRA_URL)
    mcp = probe(MCP_URL)
    return {
        "ghidra_plugin": ghidra,
        "mcp_bridge": mcp,
        "ready": ghidra["up"] and mcp["up"],
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
            print(f"{name}: {state} {row['url']} status={row['status']}")
    else:
        print(json.dumps(status, indent=2))
    return 0 if status["ready"] else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
