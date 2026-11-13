"""Offline companion-contract fixtures; the live URL check stays scheduled/manual."""

import copy
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
PACKS = {
    "packs": {
        "reverse": {
            "enable": "START-HERE.bat -Packs reverse",
            "disable": "START-HERE.bat -ExcludePacks reverse",
            "owner": "reverse-this",
            "repository": "https://github.com/SenjuWoo/reverse-this",
            "minimum_version": "1.4.0",
            "detect": {"local_state_files": ["ReverseThis/kit.json"]},
        }
    }
}
README = "# Bundle\nReverse THIS! is discovered automatically when its kit is found.\n"
FORGE = "# Forge\nReverse THIS! is owned elsewhere; see the bundle README.\n"


def packs_with(**changes):
    packs = copy.deepcopy(PACKS)
    packs["packs"]["reverse"].update(changes)
    return packs


class CompanionFixtures(unittest.TestCase):
    def test_current_contract_is_compatible(self):
        self.assertEqual(check_companions.evaluate(CATALOG, README, FORGE, "1.16.1", PACKS), [])

    def test_combined_pack_command_is_valid(self):
        packs = packs_with(enable="START-HERE.bat -Packs skyrim,reverse")
        self.assertEqual(check_companions.evaluate(CATALOG, README, FORGE, "1.16.1", packs), [])

    def test_readme_rewording_is_not_drift(self):
        # The bundle dropped the `-Packs reverse` prose in 8.41; PACKS.json still carries the selection.
        self.assertEqual(check_companions.evaluate(CATALOG, "# Bundle\nReverse THIS!\n", FORGE, "1.16.1", PACKS), [])

    def test_exclude_only_is_not_a_reverse_pack_selection(self):
        errors = check_companions.evaluate(CATALOG, README, FORGE, "1.16.1", packs_with(enable="START-HERE.bat -ExcludePacks reverse"))
        self.assertIn("bundle reverse pack no longer enables with -Packs reverse", errors)

    def test_missing_pack_floor_owner_and_detection_are_drift(self):
        self.assertIn("bundle PACKS.json has no reverse pack",
                      check_companions.evaluate(CATALOG, README, FORGE, "1.16.1", {"packs": {}}))
        self.assertIn("bundle reverse pack floor 9.0.0 is newer than this kit 1.16.1",
                      check_companions.evaluate(CATALOG, README, FORGE, "1.16.1", packs_with(minimum_version="9.0.0")))
        self.assertIn("bundle reverse pack points at a different owner or repository",
                      check_companions.evaluate(CATALOG, README, FORGE, "1.16.1", packs_with(repository="https://github.com/other/reverse-this")))
        self.assertIn("bundle reverse pack no longer detects the ReverseThis/kit.json owner pointer",
                      check_companions.evaluate(CATALOG, README, FORGE, "1.16.1", packs_with(detect={"local_state_files": []})))

    def test_missing_name_or_owner_is_incompatible(self):
        errors = check_companions.evaluate(CATALOG, "# Bundle\n", FORGE, "1.16.1", PACKS)
        self.assertIn("bundle README no longer names Reverse THIS!", errors)

        catalog = {"components": [{**CATALOG["components"][0], "github": {"owner": "other", "repo": "reverse-this"}}]}
        errors = check_companions.evaluate(catalog, README, FORGE, "1.16.1", PACKS)
        self.assertIn("bundle catalog points at a different repository", errors)


if __name__ == "__main__":
    unittest.main()
