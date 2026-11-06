#!/usr/bin/env python3
"""Read-only currency report for the critical compatibility boundary.

It queries official release endpoints, reports only observed installation
evidence in ``installed``, and keeps catalog/test pins, update status and
compatibility status in separate fields. It exits 0 even when upstream has
moved; this is intelligence, not a release gate.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
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

BASELINES = {"dotnet": "10", "capstone": "5.0.9", "rea": "6.8.0", "java": "21"}
ENDPOINTS = {
    "ghidra": "https://api.github.com/repos/NationalSecurityAgency/ghidra/releases/latest",
    "ghidra-mcp": "https://api.github.com/repos/LaurieWired/GhidraMCP/releases/latest",
    "rea": "https://registry.npmjs.org/rea-agents/latest",
    "ilspy": "https://api.github.com/repos/icsharpcode/ILSpy/releases/latest",
    "ilspycmd": "https://api.nuget.org/v3-flatcontainer/ilspycmd/index.json",
    "dotnet": "https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/10.0/releases.json",
    "capstone": "https://pypi.org/pypi/capstone/json",
    "java": None,
}
# Stable REA 6.8.0 documents Ghidra 12.1.x with JDK 21. Development main may
# accept more, but an unreleased branch is not a published compatibility claim.
REA_STABLE = (6, 8, 0)
REA_GHIDRA_LINE = (12, 1)
REA_JAVA_MAJOR = 21


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
        rea = version_tuple(observed.get("rea"))
        ghidra = version_tuple(observed.get("ghidra"))
        if not rea:
            return "not-evaluated"
        if rea != REA_STABLE:
            # A newer published REA needs its own release notes and a real
            # bridge check; do not promote it because a number moved.
            return "unknown-version"
        if not ghidra:
            return "missing-ghidra"
        if ghidra[:2] == REA_GHIDRA_LINE:
            return "compatible"
        if ghidra[0] == 12:
            return "incompatible"
        return "unknown-ghidra"
    baseline = BASELINES.get(component)
    current = observed.get(component)
    comparison = compare(current, baseline)
    if comparison is not None and comparison < 0:
        return "below-baseline"
    return "not-evaluated"


def java_compatibility(observed: dict[str, str | None]) -> str:
    rea = version_tuple(observed.get("rea"))
    java = version_tuple(observed.get("java"))
    if not rea or rea != REA_STABLE:
        return "not-evaluated"
    if not java:
        return "missing-java"
    return "compatible" if java[0] == REA_JAVA_MAJOR else "unsupported-major"


def _parse_dotnet_sdks(text: str) -> list[str]:
    versions = []
    for line in text.splitlines():
        match = re.match(r"^\s*(\d+\.\d+\.\d+)\s*\[", line)
        if match:
            versions.append(match.group(1))
    return sorted(set(versions), key=lambda value: version_tuple(value) or (), reverse=True)


def _observed_dotnet_sdks() -> list[str]:
    if not shutil.which("dotnet"):
        return []
    try:
        result = subprocess.run(["dotnet", "--list-sdks"], capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        return []
    if result.returncode != 0:
        return []
    return _parse_dotnet_sdks(result.stdout)


def _observed_dotnet() -> str | None:
    sdks = _observed_dotnet_sdks()
    return sdks[0] if sdks else None


def _parse_java_major(text: str) -> str | None:
    match = re.search(r'version\s+"([^"]+)"', text, re.I)
    if not match:
        return None
    value = match.group(1)
    if value.startswith("1."):
        value = value[2:]
    parsed = version_tuple(value)
    return str(parsed[0]) if parsed else None


def _observed_java() -> str | None:
    java = shutil.which("java")
    if not java:
        home = os.environ.get("JAVA_HOME")
        candidate = Path(home) / "bin" / ("java.exe" if os.name == "nt" else "java") if home else None
        if candidate and candidate.is_file():
            java = str(candidate)
    if not java:
        return None
    try:
        result = subprocess.run([java, "-version"], capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        return None
    if not result.stdout and not result.stderr:
        return None
    return _parse_java_major((result.stdout or "") + "\n" + (result.stderr or ""))


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _tool_evidence(root: Path, row: dict, state_root: str | None) -> dict[str, str]:
    """Validate one installed-tool receipt, not just its JSON version string."""
    version = str(row.get("version") or "").strip()
    if not version:
        return {"status": "malformed", "reason": "tool row has no version"}
    if state_root is not None and os.path.normcase(os.path.normpath(state_root)) != os.path.normcase(os.path.normpath(str(root))):
        return {"status": "moved", "reason": "installed.json kit_root does not match this checkout"}
    directory = row.get("dir")
    if not isinstance(directory, str) or not directory:
        return {"status": "malformed", "reason": "tool row has no dir"}
    tool_dir = (root / directory).resolve()
    try:
        tool_dir.relative_to(root.resolve())
    except ValueError:
        return {"status": "malformed", "reason": "tool dir escapes the kit root"}
    if not tool_dir.is_dir():
        return {"status": "stale", "reason": "tool dir is missing"}
    files = row.get("files")
    if not isinstance(files, dict) or not files:
        return {"status": "unverified", "reason": "tool row has no file receipt"}
    for relative, expected in files.items():
        if not isinstance(relative, str) or not isinstance(expected, str):
            return {"status": "malformed", "reason": "file receipt is malformed"}
        candidate = (tool_dir / relative.replace("\\", "/")).resolve()
        try:
            candidate.relative_to(tool_dir)
        except ValueError:
            return {"status": "malformed", "reason": "file receipt escapes the tool dir"}
        if not candidate.is_file():
            return {"status": "stale", "reason": f"receipt file is missing: {relative}"}
        if expected and _sha256(candidate) != expected.lower():
            return {"status": "changed", "reason": f"receipt hash differs: {relative}"}
    return {"status": "valid", "version": version, "dir": str(tool_dir)}


def probe_installed():
    """Return observed versions plus per-component evidence.

    Values are populated only from a valid installed-state receipt or a live
    runtime probe. Catalog versions and test pins are never installation proof.
    """
    values: dict[str, str | None] = {}
    evidence: dict[str, dict] = {}
    state_root = None
    state_tools: dict = {}
    if STATE.is_file():
        try:
            state = json.loads(STATE.read_text(encoding="utf-8-sig"))
            if state.get("schema") == 1 and isinstance(state.get("tools"), dict):
                state_tools = state["tools"]
                state_root = str(state.get("kit_root") or "")
            else:
                for component in ("ghidra", "rea", "ilspy", "ilspycmd", "capstone"):
                    evidence[component] = {"status": "malformed", "reason": "installed.json schema is not 1"}
        except (OSError, ValueError) as exc:
            for component in ("ghidra", "rea", "ilspy", "ilspycmd", "capstone"):
                evidence[component] = {"status": "malformed", "reason": str(exc)}
    else:
        for component in ("ghidra", "rea", "ilspy", "ilspycmd", "capstone"):
            evidence[component] = {"status": "missing", "reason": "sandbox/installed.json is absent"}
    for component in ("ghidra", "rea", "ilspy", "ilspycmd", "capstone"):
        row = state_tools.get(component)
        if row is None:
            evidence.setdefault(component, {"status": "missing", "reason": "no installed tool row"})
            continue
        if not isinstance(row, dict):
            evidence[component] = {"status": "malformed", "reason": "tool row is not an object"}
            continue
        result = _tool_evidence(ROOT, row, state_root)
        evidence[component] = result
        if result["status"] == "valid":
            values[component] = result["version"]

    sdks = _observed_dotnet_sdks()
    if sdks:
        values["dotnet"] = sdks[0]
        evidence["dotnet"] = {"status": "probed", "sdk_versions": sdks}
    else:
        evidence["dotnet"] = {"status": "missing", "reason": "dotnet --list-sdks unavailable"}
    java = _observed_java()
    if java:
        values["java"] = java
        evidence["java"] = {"status": "probed"}
    else:
        evidence["java"] = {"status": "missing", "reason": "java -version unavailable"}
    return values, evidence


def load_current():
    return probe_installed()[0]


def _catalog_pins() -> dict[str, str]:
    pins: dict[str, str] = {}
    if CATALOG.is_file():
        try:
            catalog = json.loads(CATALOG.read_text(encoding="utf-8-sig"))
            for row in catalog.get("tools", []):
                if row.get("id") == "rea" and row.get("package_version"):
                    pins["rea"] = str(row["package_version"])
        except (OSError, ValueError):
            pass
    if TEST_PIN.is_file():
        match = re.search(r"^capstone==([^\s]+)", TEST_PIN.read_text(encoding="utf-8-sig"), re.M)
        if match:
            pins["capstone"] = match.group(1)
    return pins


def fetch_latest(component: str, timeout: float = 8.0) -> str | None:
    endpoint = ENDPOINTS.get(component)
    if not endpoint:
        return None
    request = urllib.request.Request(endpoint, headers={"User-Agent": "reverse-this-currency"})
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
    current, evidence = probe_installed()
    pins = _catalog_pins()
    rows = []
    for component in ENDPOINTS:
        error = None
        malformed = False
        if ENDPOINTS[component] is None:
            latest = None
        elif offline:
            latest, error = None, "offline mode"
        else:
            try:
                latest = fetcher(component, timeout)
            except (ValueError, KeyError, TypeError) as exc:
                latest, error, malformed = None, str(exc), True
            except Exception as exc:  # noqa: BLE001 - network failure is a reported state
                latest, error = None, str(exc)
        if offline:
            update = "offline"
        elif malformed:
            update = "malformed-response"
        elif error:
            update = "network-unavailable"
        elif ENDPOINTS[component] is None:
            update = "not-checked"
        else:
            update = update_status(current.get(component), latest)
        rows.append({
            "component": component,
            "installed": current.get(component),
            "baseline": BASELINES.get(component),
            "catalog_pin": pins.get(component),
            "latest": latest,
            "update": update,
            "compatibility": compatibility_status(component, current),
            "install_evidence": evidence.get(component),
            "java_compatibility": java_compatibility(current) if component == "rea" else None,
            "dotnet_sdks": evidence.get("dotnet", {}).get("sdk_versions"),
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
