"""Contract tests for the optional reverse-api-engineer integration."""
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class WebApiTests(unittest.TestCase):
    def setUp(self):
        self.catalog = json.loads((ROOT / "catalog" / "tools.json").read_text(encoding="utf-8-sig"))
        self.tool = next(t for t in self.catalog["tools"] if t["id"] == "reverse-api-engineer")

    def test_catalog_pins_the_published_release_and_uses_a_private_venv(self):
        self.assertEqual(self.tool["method"], "pip-venv")
        self.assertEqual(self.tool["package"], "reverse-api-engineer")
        self.assertEqual(self.tool["package_version"], "0.14.0")
        self.assertEqual([s["name"] for s in self.tool["shims"]], ["reverse-api-engineer"])

    def test_shim_does_not_shadow_rea(self):
        names = [s["name"] for t in self.catalog["tools"] for s in t.get("shims", [])]
        self.assertEqual(names.count("reverse-api-engineer"), 1)
        self.assertNotIn("rae", names)
        self.assertEqual(names.count("rea"), 1)

    def test_routing_and_privacy_instructions_are_shipped(self):
        agents = (ROOT / "AGENTS.md").read_text(encoding="utf-8")
        guide = (ROOT / "docs" / "web-api.md").read_text(encoding="utf-8")
        self.assertIn("reverse-api-engineer.cmd", agents)
        self.assertIn("catalog/tools.json", guide)
        self.assertIn("sandbox", guide)
        self.assertIn("chrome-mcp", guide)
        self.assertIn("HAR", guide)
        self.assertIn("never paste", guide.lower())


if __name__ == "__main__":
    suite = unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    sys.exit(0 if result.wasSuccessful() else 1)
