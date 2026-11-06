#!/usr/bin/env python3
"""Read-only currency report for the critical compatibility boundary.

It queries official release endpoints, compares them with the installed kit and
the catalog/report assumptions, and exits 0 even when upstream has moved. This is
an intelligence report, never a release gate or an automatic version pin.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STATE = ROOT / "sandbox" / "installed.json"
CATALOG = ROOT / "catalog" / "tools.json"
TEST_PIN = ROOT / "requirements-test.txt"

ENDPOINTS = {
    "ghidra": "https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest",
    "ghidra-mcp": "https://api.github.com/repos/LaurieWired/GhidraMCP/releases/latest",
    "rea": "https://registry.npmjs.org/rea-agents/latest",
    "ilspy": "https://api.github.com/repos/icsharpcode/ILSpy/releases/latest",
    "ilspycmd": "https://api.nuget.org/v3-flatcontainer/ilspycmd/index.json",
    "dotnet": "https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/10.0/releases.json",
    "capstone": "https://pypi.org/pypi/capstone/json",
}


def version_tuple(value: str | None):
    if not value:
        return None
    match = re.search(r"(\d+(?:\.\d+){0,3})", str(value))
    if not match:
        return None
    return tuple(int(part) for part in match.group(1).split("."))


def compare(left: str | None, right: str | None) -> int | None:
    a, b = version_tuple(left), version_tuple(right)
    if a is None or b is None:
        return None
    width = max(len(a), len(b))
    a += (0,) * (width - len(a))
    b += (0,) * (width - len(b))
    return (a > b) - (a < b)


def status_for(component: str, current: str | None, latest: str | None) -> str:
    if not latest:
        return "unverified"
    if not current:
        return "unverified"
    comparison = compare(current, latest)
    if comparison is None:
        return "unverified" if current != latest else "current"
    if comparison == 0:
        # The published REA 6.8.x line still rejects the installed Ghidra 12.2.
        return "incompatible" if component == "rea" and version_tuple(current) == (6, 8, 0) else "current"
    return "outdated" if comparison < 0 else "current"


def load_current():
    values = {}
    if STATE.is_file():
        try:
            state = json.loads(STATE.read_text(encoding="utf-8-sig"))
            for component in ("ghidra", "rea", "ilspy", "ilspycmd", "capstone"):
                row = (state.get("tools") or {}).get(component)
                if isinstance(row, dict):
                    values[component] = str(row.get("version") or "")
        except (OSError, ValueError):
            pass
    if CATALOG.is_file():
        try:
            catalog = json.loads(CATALOG.read_text(encoding="utf-8-sig"))
            for row in catalog.get("tools", []):
                if row.get("id") == "rea" and row.get("package_version"):
                    values.setdefault("rea", str(row["package_version"]))
        except (OSError, ValueError):
            pass
    if TEST_PIN.is_file():
        match = re.search(r"^capstone==([^\s]+)", TEST_PIN.read_text(encoding="utf-8-sig"), re.M)
        if match:
            values.setdefault("capstone", match.group(1))
    values.setdefault("dotnet", "10")
    return values


def fetch_latest(component: str, timeout: float = 8.0) -> str | None:
    request = urllib.request.Request(ENDPOINTS[component], headers={"User-Agent": "reverse-this-currency"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        payload = json.loads(response.read().decode("utf-8"))
    if component in {"ghidra", "ghidra-mcp", "ilspy"}:
        return str(payload.get("tag_name") or "")
    if component == "rea":
        return str(payload.get("version") or "")
    if component == "ilspycmd":
        versions = payload.get("versions") or []
        return str(versions[-1]) if versions else ""
    if component == "dotnet":
        releases = payload.get("releases") or []
        return str(releases[0].get("release-version") or "") if releases else ""
    if component == "capstone":
        return str((payload.get("info") or {}).get("version") or "")
    return None


def report(timeout: float = 8.0, fetcher=fetch_latest):
    current = load_current()
    rows = []
    for component in ENDPOINTS:
        try:
            latest = fetcher(component, timeout)
            error = None
        except Exception as exc:  # noqa: BLE001 - network failure is a reported state
            latest, error = None, str(exc)
        rows.append({
            "component": component,
            "installed": current.get(component),
            "latest": latest,
            "status": "network-unavailable" if error else status_for(component, current.get(component), latest),
            "error": error,
        })
    return rows


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--timeout", type=float, default=8.0)
    args = parser.parse_args(argv)
    rows = report(args.timeout)
    if args.json:
        print(json.dumps(rows, indent=2))
    else:
        print(f"{'component':12} {'installed':12} {'latest':12} status")
        for row in rows:
            print(f"{row['component']:12} {str(row['installed'] or '-'):12} {str(row['latest'] or '-'):12} {row['status']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
