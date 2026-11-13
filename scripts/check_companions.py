#!/usr/bin/env python3
"""Read-only compatibility check against the published companion contracts.

Checks the Starter Bundle's reverse-this catalog entry (minimum version, asset
template, owner) and the Skyrim Forge ownership link. It never writes to either
repository. Exit 0 = compatible, 1 = drift, 2 = the published contract could not
be fetched.
"""

from __future__ import annotations

import json
import re
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUNDLE_CATALOG = "https://raw.githubusercontent.com/SenjuWoo/Ultimate-AI-Starter-Bundle/main/BUNDLED-TOOLS/CATALOG.json"
BUNDLE_PACKS = "https://raw.githubusercontent.com/SenjuWoo/Ultimate-AI-Starter-Bundle/main/BUNDLED-TOOLS/PACKS.json"
BUNDLE_README ="https://raw.githubusercontent.com/SenjuWoo/Ultimate-AI-Starter-Bundle/main/README.md"
FORGE_README = "https://raw.githubusercontent.com/SenjuWoo/SkyrimForge/main/README.md"


def fetch(url: str) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": "reverse-this-companion-check"})
    with urllib.request.urlopen(request, timeout=20) as response:
        return response.read().decode("utf-8-sig")


def version_tuple(value: str) -> tuple[int, ...]:
    parts = [int(part) for part in value.strip().lstrip("v").split(".") if part.isdigit()]
    return tuple((parts + [0, 0, 0])[:3])


def selects_reverse_pack(command: str) -> bool:
    return bool(re.search(r"(?i)(?:^|[\s`\"'])-Packs\s+[^\n]*\breverse\b", command))


def pack_errors(packs: dict, version: str) -> list[str]:
    # PACKS.json is the bundle's machine-readable pack contract; README prose may be reworded freely.
    pack = packs.get("packs", {}).get("reverse")
    if not isinstance(pack, dict):
        return ["bundle PACKS.json has no reverse pack"]
    errors = []
    if not selects_reverse_pack(str(pack.get("enable", ""))):
        errors.append("bundle reverse pack no longer enables with -Packs reverse")
    if pack.get("owner") != "reverse-this" or str(pack.get("repository", "")).rstrip("/") != "https://github.com/SenjuWoo/reverse-this":
        errors.append("bundle reverse pack points at a different owner or repository")
    floor = str(pack.get("minimum_version", ""))
    if version_tuple(floor) > version_tuple(version):
        errors.append(f"bundle reverse pack floor {floor} is newer than this kit {version}")
    if "ReverseThis/kit.json" not in pack.get("detect", {}).get("local_state_files", []):
        errors.append("bundle reverse pack no longer detects the ReverseThis/kit.json owner pointer")
    return errors


def evaluate(catalog: dict, bundle_readme: str, forge_readme: str, version: str, packs: dict) -> list[str]:
    errors: list[str] = []
    entries = [row for row in catalog.get("components", []) if row.get("id") == "reverse-this"]
    if len(entries) != 1:
        errors.append("bundle catalog must declare exactly one reverse-this component")
    else:
        entry = entries[0]
        floor = str(entry.get("min_version", ""))
        if version_tuple(floor) > version_tuple(version):
            errors.append(f"bundle floor {floor} is newer than this kit {version}")
        if entry.get("asset_template") != "Reverse-This-{version}.zip":
            errors.append(f"bundle asset template changed: {entry.get('asset_template')}")
        github = entry.get("github", {})
        if (github.get("owner"), github.get("repo")) != ("SenjuWoo", "reverse-this"):
            errors.append("bundle catalog points at a different repository")

    if "Reverse THIS!" not in bundle_readme:
        errors.append("bundle README no longer names Reverse THIS!")
    errors.extend(pack_errors(packs, version))
    if "Reverse THIS!" not in forge_readme:
        errors.append("Forge README no longer names Reverse THIS!")
    if "bundle README" not in forge_readme:
        errors.append("Forge README no longer links the bundle ownership section")
    return errors


def main() -> int:
    version = (ROOT / "VERSION").read_text(encoding="utf-8-sig").strip()
    try:
        catalog = json.loads(fetch(BUNDLE_CATALOG))
        packs = json.loads(fetch(BUNDLE_PACKS))
        bundle_readme = fetch(BUNDLE_README)
        forge_readme = fetch(FORGE_README)
    except Exception as exc:  # noqa: BLE001 - a fetch failure is unknown, not drift
        print("UNKNOWN: companion contract could not be fetched: " + str(exc))
        return 2

    errors = evaluate(catalog, bundle_readme, forge_readme, version, packs)
    if errors:
        for error in errors:
            print("DRIFT: " + error)
        return 1
    print(f"companions ok: reverse-this {version}, bundle floor compatible, asset template and Forge ownership link present")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
