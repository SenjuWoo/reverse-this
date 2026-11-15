"""Contract tests for the optional FModel MCP integration."""
import json
import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class UnrealMcpTests(unittest.TestCase):
    def setUp(self):
        catalog = json.loads((ROOT / "catalog" / "tools.json").read_text(encoding="utf-8-sig"))
        self.catalog = catalog
        self.tool = next(t for t in catalog["tools"] if t["id"] == "fmodel-mcp")
        self.guide = (ROOT / "docs" / "unreal-mcp.md").read_text(encoding="utf-8")

    def test_catalog_installs_the_self_contained_windows_release(self):
        self.assertEqual(self.tool["method"], "github-release")
        self.assertEqual(self.tool["repo"], "MayankS-Code/fmodel-mcp")
        pattern = re.compile(self.tool["asset_pattern"])
        self.assertTrue(pattern.search("fmodel-mcp-1.2.0-win-x64.zip"))
        for other in ("fmodel-mcp-1.2.0-source.zip", "fmodel-mcp-1.2.0-win-x64.zip.sha256"):
            self.assertIsNone(pattern.search(other))
        self.assertEqual(self.tool["shims"], [{"name": "fmodel-mcp", "exe_glob": "FModel.Mcp.exe"}])

    def test_shim_name_is_unique_and_separate_from_the_gui(self):
        names = [s["name"] for t in self.catalog["tools"] for s in t.get("shims", [])]
        self.assertEqual(names.count("fmodel-mcp"), 1)
        self.assertEqual(names.count("fmodel"), 1)

    def test_route_keeps_config_exports_and_keys_private(self):
        agents = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
        self.assertIn("fmodel-mcp.cmd --config", agents)
        self.assertIn("docs/unreal-mcp.md", agents)
        for needle in ("--config", "sandbox\\work\\fmodel-mcp", "inputRoots", "Install-Mcp.ps1", "not an operating-system sandbox"):
            self.assertIn(needle, self.guide)
        self.assertIn("never write aes keys", self.guide.lower())


if __name__ == "__main__":
    suite = unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
