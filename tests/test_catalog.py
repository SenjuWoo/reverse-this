"""Catalog contract. Stdlib only. Run: python tests/test_catalog.py"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
METHODS = {
    "github-release",
    "github-files",
    "renderdoc-stable-zip",
    "dotnet-tool",
    "pip-venv",
}


def load(name):
    return json.loads((ROOT / name).read_text(encoding="utf-8"))


def one_match(names, pattern):
    hits = [name for name in names if re.search(pattern, name)]
    return hits


def renderdoc_zip_url(tag):
    if not re.fullmatch(r"v\d+\.\d+", tag):
        raise ValueError(tag)
    version = tag[1:]
    return "https://renderdoc.org/stable/{0}/RenderDoc_{0}_64.zip".format(version)


def release_api(repo, release):
    if release:
        return "https://api.github.com/repos/{0}/releases/tags/{1}".format(repo, release)
    return "https://api.github.com/repos/{0}/releases/latest".format(repo)


def main():
    errors = []
    catalog = load("catalog/tools.json")
    fixture = load("tests/fixtures/assets.json")
    version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    agents = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
    currency = (ROOT / "docs/currency.md").read_text(encoding="utf-8")

    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        errors.append("VERSION is not semver")
    if "## {0}".format(version) not in changelog:
        errors.append("CHANGELOG.md is missing heading {0}".format(version))

    for needle in (
        "https://github.com/rehan-remade/universal-modder",
        "https://github.com/SenjuWoo/Ultimate-AI-Starter-Bundle",
        "Install-Modkit.ps1",
        "sandbox/bin",
        "sandbox/installed.json",
        "%LOCALAPPDATA%\\ReverseThis\\kit.json",
    ):
        if needle not in readme or needle not in agents:
            errors.append("missing contract text in README or AGENTS: {0}".format(needle))

    ids = []
    for tool in catalog["tools"]:
        tid = tool["id"]
        ids.append(tid)
        if tid != tid.lower() or not re.fullmatch(r"[a-z0-9-]+", tid):
            errors.append("bad id {0}".format(tid))
        if tool["method"] not in METHODS:
            errors.append("{0} has unknown method".format(tid))
        if tool["method"] == "github-release":
            if tid not in fixture:
                errors.append("{0} has no asset fixture".format(tid))
            else:
                hits = one_match(fixture[tid]["assets"], tool["asset_pattern"])
                if hits != [fixture[tid]["expect"]]:
                    errors.append("{0} pattern matched {1}".format(tid, hits))
        if tool["method"] == "github-files":
            missing = [name for name in tool["files"] if name not in fixture[tid]["assets"]]
            if missing:
                errors.append("{0} files missing from fixture {1}".format(tid, missing))
            if any(name.endswith("_arm64.exe") for name in tool["files"]):
                errors.append("{0} selected an arm64 exe".format(tid))
        if tool["method"] in ("dotnet-tool", "pip-venv") and not tool.get("package"):
            errors.append("{0} needs a package".format(tid))
        if "repo" in tool and tool["repo"].count("/") != 1:
            errors.append("{0} repo is not owner/name".format(tid))

    if len(ids) != len(set(ids)):
        errors.append("duplicate tool ids")

    installable = set(ids)
    for row in catalog["retired"]:
        if row["id"] in installable:
            errors.append("retired id is also installed: {0}".format(row["id"]))
        if row["id"] not in currency:
            errors.append("currency.md does not mention {0}".format(row["id"]))
        instead = row.get("instead")
        if instead is not None and instead not in installable:
            errors.append("retired {0} points at unknown {1}".format(row["id"], instead))

    if renderdoc_zip_url("v1.46") != "https://renderdoc.org/stable/1.46/RenderDoc_1.46_64.zip":
        errors.append("renderdoc url builder drifted")
    try:
        renderdoc_zip_url("nightly")
        errors.append("renderdoc url builder accepted a bad tag")
    except ValueError:
        pass

    ue = next(tool for tool in catalog["tools"] if tool["id"] == "ue4ss")
    if release_api(ue["repo"], ue["release"]).endswith("/releases/latest"):
        errors.append("ue4ss must not track the stable latest release")

    if errors:
        print("\n".join(errors))
        return 1
    print("catalog ok: {0} tools, version {1}".format(len(ids), version))
    return 0


if __name__ == "__main__":
    sys.exit(main())
