"""Encyclopedia contract. Stdlib only. Run: python tests/test_encyclopedia.py"""

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    "context7.json",
    "encyclopedia/README.md",
    "encyclopedia/ROUTING.md",
    "encyclopedia/CLAIMS.md",
    "encyclopedia/anticheat-risk.md",
    "encyclopedia/VALIDATION.md",
    "encyclopedia/engines/creation-engine.md",
    "encyclopedia/engines/unreal-3-4-5.md",
    "encyclopedia/engines/unity-mono-il2cpp.md",
    "encyclopedia/engines/rage-gta5.md",
    "encyclopedia/blueprints/ipc_seqlock.h",
    "encyclopedia/blueprints/ipc_seqlock.py",
    "encyclopedia/blueprints/passthrough_reproject.fxh",
    "encyclopedia/blueprints/fake_host_d3d11.cpp",
    "encyclopedia/blueprints/ipc_link_test.cpp",
    "encyclopedia/blueprints/proxy_entity_bridge.md",
    "encyclopedia/re-recipes/ghidra-mcp-streamable-http.md",
    "encyclopedia/re-recipes/frida-downstream-sink.md",
    "encyclopedia/re-recipes/aob-wildcard-signatures.md",
    "encyclopedia/games/TEMPLATE.md",
    "encyclopedia/games/arkham-knight-x-spiderman.md",
    "encyclopedia/games/gtav-x-minecraft-passthrough.md",
    "encyclopedia/ERROR-REGISTRY.json",
    "kit/README.md",
    "kit/pe_recon.py",
    "kit/aob_gen.py",
    "kit/ghidra_mcp_up.py",
]


def main():
    errors = []
    for rel in REQUIRED:
        path = ROOT / rel
        if not path.is_file() or path.stat().st_size == 0:
            errors.append("missing or empty: " + rel)

    try:
        manifest = json.loads((ROOT / "context7.json").read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001 - report as a contract error
        errors.append("context7.json does not parse: " + str(exc))
        manifest = {}
    if manifest.get("$schema") != "https://context7.com/schema/context7.json":
        errors.append("context7.json has no Context7 $schema")
    if manifest.get("folders") != ["encyclopedia"]:
        errors.append("context7.json folders must be ['encyclopedia']")
    if not manifest.get("projectTitle") or not manifest.get("description"):
        errors.append("context7.json is missing projectTitle or description")
    if not isinstance(manifest.get("rules"), list) or not manifest["rules"]:
        errors.append("context7.json has no rules")
    if not any("scoped" in rule and "version" in rule for rule in manifest.get("rules", [])):
        errors.append("context7.json needs a rule that scopes limits to a tool and version")

    claims = (ROOT / "encyclopedia/CLAIMS.md").read_text(encoding="utf-8").lower()
    for needle in ("escape hatch", "re-test", "version"):
        if needle not in claims:
            errors.append("CLAIMS.md is missing " + needle)
    anti = (ROOT / "encyclopedia/anticheat-risk.md").read_text(encoding="utf-8").lower()
    for needle in ("risk tier", "policy", "cosmetic", "marvelrivals.com", "monsterhunter.com"):
        if needle not in anti:
            errors.append("anticheat-risk.md is missing " + needle)
    banned = ("permanently impossible", "never be possible", "no way to", "impossible to", "can never")
    for path in [ROOT / "README.md", ROOT / "AGENTS.md"] + list((ROOT / "encyclopedia").rglob("*.md")):
        text = path.read_text(encoding="utf-8").lower()
        for phrase in banned:
            if phrase in text:
                errors.append("{0} uses a permanent capability block: {1}".format(path.relative_to(ROOT), phrase))
    for folder in manifest.get("folders", []):
        if not (ROOT / folder).is_dir():
            errors.append("context7 folder does not exist: " + folder)

    try:
        registry = json.loads((ROOT / "encyclopedia/ERROR-REGISTRY.json").read_text(encoding="utf-8"))
    except Exception as exc:  # noqa: BLE001
        errors.append("ERROR-REGISTRY.json does not parse: " + str(exc))
        registry = {}
    for row in registry.get("errors", []):
        for field in ("id", "signature", "cause", "fix"):
            if not row.get(field):
                errors.append("ERROR-REGISTRY row {0} is missing {1}".format(row.get("id", "?"), field))

    for card in ("creation-engine.md", "unreal-3-4-5.md", "unity-mono-il2cpp.md", "rage-gta5.md"):
        text = (ROOT / "encyclopedia/engines" / card).read_text(encoding="utf-8")
        for heading in ("## Coordinates", "## Depth", "## Verification"):
            if heading not in text:
                errors.append("{0} is missing {1}".format(card, heading))

    template = (ROOT / "encyclopedia/games/TEMPLATE.md").read_text(encoding="utf-8").lower()
    for needle in ("build id", "exe sha256", "loader version", "coordinate conversion", "known engine traps"):
        if needle not in template:
            errors.append("games/TEMPLATE.md is missing " + needle)

    link = re.compile(r"\[[^\]]+\]\(([^)]+)\)")
    for path in [ROOT / rel for rel in REQUIRED if rel.endswith(".md")]:
        text = path.read_text(encoding="utf-8")
        for target in link.findall(text):
            target = target.split("#", 1)[0].strip()
            if not target or target.startswith(("http://", "https://", "mailto:", "MEDIA:")):
                continue
            resolved = (path.parent / target).resolve()
            if not resolved.exists():
                errors.append("{0} has a broken link: {1}".format(path.relative_to(ROOT), target))

    if errors:
        print("\n".join(errors))
        return 1
    print("encyclopedia ok: {0} files, {1} registry rows".format(len(REQUIRED), len(registry.get("errors", []))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
