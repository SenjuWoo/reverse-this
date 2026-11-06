"""Offline companion-contract fixtures; the live URL check stays scheduled/manual."""

import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("check_companions", ROOT / "scripts/check_companions.py")
check_companions = importlib.util.module_from_spec(spec)
spec.loader.exec_module(check_companions)

CATALOG = {
    "components": [{
        "id": "reverse-this",
        "min_version": "1.0.0",
        "asset_template": "Reverse-This-{version}.zip",
        "github": {"owner": "SenjuWoo", "repo": "reverse-this"},
    }]
}
FORGE = "# Forge\nReverse THIS! is owned elsewhere; see the bundle README.\n"


class CompanionFixtures(unittest.TestCase):
    def test_separate_reverse_pack_selection_is_valid(self):
        readme = "# Bundle\nReverse THIS!\nForce it with `-Packs reverse`.\n"
        self.assertEqual(check_companions.evaluate(CATALOG, readme, FORGE, "1.14.3"), [])

    def test_combined_pack_example_is_valid(self):
        readme = "# Bundle\nReverse THIS!\nUse `-Packs skyrim,reverse` for both.\n"
        self.assertEqual(check_companions.evaluate(CATALOG, readme, FORGE, "1.14.3"), [])

    def test_exclude_only_is_not_a_reverse_pack_selection(self):
        readme = "# Bundle\nReverse THIS!\nSkip it with `-ExcludePacks reverse`.\n"
        errors = check_companions.evaluate(CATALOG, readme, FORGE, "1.14.3")
        self.assertIn("bundle README no longer documents the reverse pack selection", errors)

    def test_missing_name_or_owner_is_incompatible(self):
        readme = "# Bundle\nUse `-Packs reverse`.\n"
        errors = check_companions.evaluate(CATALOG, readme, FORGE, "1.14.3")
        self.assertIn("bundle README no longer names Reverse THIS!", errors)

        catalog = {"components": [{**CATALOG["components"][0], "github": {"owner": "other", "repo": "reverse-this"}}]}
        errors = check_companions.evaluate(catalog, "# Bundle\nReverse THIS!\n`-Packs reverse`\n", FORGE, "1.14.3")
        self.assertIn("bundle catalog points at a different repository", errors)


if __name__ == "__main__":
    unittest.main()
