# Offline tests for the read-only upstream currency report.
import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import check_upstreams


class CurrencyTests(unittest.TestCase):
    def test_comparison_normalizes_tags_and_release_names(self):
        self.assertGreater(check_upstreams.compare("Ghidra_12.2_build", "12.1"), 0)
        self.assertEqual(check_upstreams.compare("6.8.0", "v6.8.0"), 0)
        self.assertIsNone(check_upstreams.compare("unknown", "1.0"))

    def test_update_never_invents_an_installed_version(self):
        self.assertEqual(check_upstreams.update_status("12.2", "12.2"), "current")
        self.assertEqual(check_upstreams.update_status("12.1", "12.2"), "outdated")
        self.assertEqual(check_upstreams.update_status(None, "5.0.9"), "unverified")
        self.assertEqual(check_upstreams.update_status("10", "10.0.14"), "outdated")

    def test_compatibility_is_independent_of_update_status(self):
        self.assertEqual(check_upstreams.compatibility_status(
            "rea", {"rea": "6.8.0", "ghidra": "Ghidra_12.2_build"}), "incompatible")
        self.assertEqual(check_upstreams.compatibility_status(
            "rea", {"rea": "6.9.0", "ghidra": "12.2"}), "not-evaluated")
        self.assertEqual(check_upstreams.compatibility_status("ghidra", {}), "not-evaluated")

    def test_missing_dotnet_is_not_reported_as_installed(self):
        with mock.patch.object(check_upstreams, "STATE", Path("missing-state.json")), \
             mock.patch.object(check_upstreams, "CATALOG", Path("missing-catalog.json")), \
             mock.patch.object(check_upstreams, "TEST_PIN", Path("missing-pin.txt")), \
             mock.patch.object(check_upstreams, "_observed_dotnet", return_value=None):
            self.assertNotIn("dotnet", check_upstreams.load_current())

    def test_network_failure_is_reported_not_raised(self):
        def broken(*_args):
            raise OSError("offline")
        rows = check_upstreams.report(fetcher=broken)
        self.assertEqual(len(rows), len(check_upstreams.ENDPOINTS))
        self.assertTrue(all(row["update"] == "network-unavailable" for row in rows))
        self.assertTrue(all(row["error"] for row in rows))

    def test_malformed_and_offline_modes_are_explicit(self):
        def malformed(*_args):
            raise ValueError("bad json")
        rows = check_upstreams.report(fetcher=malformed)
        self.assertTrue(all(row["update"] == "malformed-response" for row in rows))
        offline = check_upstreams.report(offline=True)
        self.assertTrue(all(row["update"] == "network-unavailable" for row in offline))


if __name__ == "__main__":
    unittest.main()
