#!/usr/bin/env python3
"""Read-only currency report for the critical compatibility boundary.

It queries official release endpoints, compares observed installed versions with
catalog/report baselines, and keeps update status separate from compatibility.
It exits 0 even when upstream has moved; this is intelligence, not a gate.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STATE = ROOT / "sandbox" / "installed.json"
CATALOG = ROOT / "catalog" / "tools.json"
TEST_PIN = ROOT / "requirements-test.txt"

BASELINES = {"dotnet": "10", "capstone": "5.0.9", "rea": "6.8.0"}
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


def update_status(current: str | None, latest: str | None) -> str:
    if not current or not latest:
        return "unverified"
    comparison = compare(current, latest)
    if comparison is None:
        return "unverified" if current != latest else "current"
    return "outdated" if comparison < 0 else "current"


def compatibility_status(component: str, observed: dict[str, str | None]) -> str:
    if component == "rea":
        rea = observed.get("rea")
        ghidra = version_tuple(observed.get("ghidra"))
        if version_tuple(rea) == (6, 8, 0) and ghidra and ghidra[:2] == (12, 2):
            return "incompatible"
        return "not-evaluated"
    baseline = BASELINES.get(component)
    current = observed.get(component)
    comparison = compare(current, baseline)
    if comparison is not None and comparison < 0:
        return "below-baseline"
    return "not-evaluated"


def _observed_dotnet() -> str | None:
    if not shutil.which("dotnet"):
        return None
    try:
        result = subprocess.run(["dotnet", "--list-sdks"], capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        return None
    if result.returncode != 0:
        return None
    for line in result.stdout.splitlines():
        match = re.search(r"^\s*(\d+\.\d+\.\d+)", line)
        if match:
            return match.group(1)
    return None


def load_current():
    values: dict[str, str | None] = {}
    if STATE.is_file():
        try:
            state = json.loads(STATE.read_text(encoding="utf-8-sig"))
            for component in ("ghidra", "rea", "ilspy", "ilspycmd", "capstone"):
                row = (state.get("tools") or {}).get(component)
                if isinstance(row, dict) and row.get("version"):
                    values[component] = str(row["version"])
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
    observed_dotnet = _observed_dotnet()
    if observed_dotnet:
        values["dotnet"] = observed_dotnet
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


def report(timeout: float = 8.0, fetcher=fetch_latest, offline: bool = False):
    current = load_current()
    rows = []
    for component in ENDPOINTS:
        error = None
        malformed = False
        if offline:
            latest, error = None, "offline mode"
        else:
            try:
                latest = fetcher(component, timeout)
            except (ValueError, KeyError, TypeError) as exc:
                latest, error, malformed = None, str(exc), True
            except Exception as exc:  # noqa: BLE001 - network failure is a reported state
                latest, error = None, str(exc)
        rows.append({
            "component": component,
            "installed": current.get(component),
            "baseline": BASELINES.get(component),
            "latest": latest,
            "update": "malformed-response" if malformed else ("network-unavailable" if error else update_status(current.get(component), latest)),
            "compatibility": compatibility_status(component, current),
            "evidence": "official release endpoint" if latest else "unavailable",
            "checked_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "error": error,
        })
    return rows


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--offline", action="store_true")
    parser.add_argument("--timeout", type=float, default=8.0)
    args = parser.parse_args(argv)
    rows = report(args.timeout, offline=args.offline)
    if args.json:
        print(json.dumps(rows, indent=2))
    else:
        print(f"{'component':12} {'installed':12} {'baseline':10} {'latest':12} {'update':14} compatibility")
        for row in rows:
            print(f"{row['component']:12} {str(row['installed'] or '-'):12} {str(row['baseline'] or '-'):10} "
                  f"{str(row['latest'] or '-'):12} {row['update']:14} {row['compatibility']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
