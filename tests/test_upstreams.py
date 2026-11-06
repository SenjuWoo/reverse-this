# Offline tests for the read-only upstream currency report.
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import check_upstreams


class CurrencyTests(unittest.TestCase):
    def test_comparison_normalizes_tags_and_release_names(self):
        self.assertGreater(check_upstreams.compare("Ghidra_12.2_build", "12.1"), 0)
        self.assertEqual(check_upstreams.compare("6.8.0", "v6.8.0"), 0)
        self.assertIsNone(check_upstreams.compare("unknown", "1.0"))

    def test_statuses_distinguish_current_outdated_and_unverified(self):
        self.assertEqual(check_upstreams.status_for("ghidra", "12.2", "12.2"), "current")
        self.assertEqual(check_upstreams.status_for("ghidra", "12.1", "12.2"), "outdated")
        self.assertEqual(check_upstreams.status_for("rea", "6.8.0", "6.8.0"), "incompatible")
        self.assertEqual(check_upstreams.status_for("capstone", None, "5.0.9"), "unverified")

    def test_network_failure_is_reported_not_raised(self):
        def broken(*_args):
            raise OSError("offline")
        rows = check_upstreams.report(fetcher=broken)
        self.assertEqual(len(rows), len(check_upstreams.ENDPOINTS))
        self.assertTrue(all(row["status"] == "network-unavailable" for row in rows))
        self.assertTrue(all(row["error"] for row in rows))


if __name__ == "__main__":
    unittest.main()
