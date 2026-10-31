#!/usr/bin/env python3
"""ghidra_mcp_up.py — check or launch the local Ghidra MCP stack.

The stack has two layers:
  Ghidra plugin HTTP   127.0.0.1:8080  (GhidraMCP extension)
  MCP streamable HTTP  127.0.0.1:8081/mcp (bridge process)

Usage:
    python ghidra_mcp_up.py            # JSON status, exit 0 only if both answer
    python ghidra_mcp_up.py --text     # one line per layer
    python ghidra_mcp_up.py --launch   # run GHIDRA_MCP_CMD or the manual start.cmd
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

GHIDRA_URL = "http://127.0.0.1:8080/"
MCP_URL = "http://127.0.0.1:8081/mcp"
MANUAL_START = Path("sandbox/manual/ghidra-mcp/start.cmd")


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


def main(argv: list[str]) -> int:
    if "--launch" in argv:
        command = os.environ.get("GHIDRA_MCP_CMD")
        if command:
            subprocess.Popen(command, shell=True)
            print(json.dumps({"launched": command}))
            return 0
        if MANUAL_START.exists():
            subprocess.Popen([str(MANUAL_START)], shell=True)
            print(json.dumps({"launched": str(MANUAL_START)}))
            return 0
        print(
            json.dumps(
                {
                    "error": "no launcher configured",
                    "fix": "set GHIDRA_MCP_CMD or create sandbox/manual/ghidra-mcp/start.cmd",
                }
            )
        )
        return 2

    ghidra = probe(GHIDRA_URL)
    mcp = probe(MCP_URL)
    status = {"ghidra_plugin": ghidra, "mcp_bridge": mcp, "ready": ghidra["up"] and mcp["up"]}
    if "--text" in argv:
        for name, row in (("ghidra", ghidra), ("mcp", mcp)):
            state = "up" if row["up"] else "down"
            print(f"{name}: {state} {row['url']} status={row['status']}")
    else:
        print(json.dumps(status, indent=2))
    return 0 if status["ready"] else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
