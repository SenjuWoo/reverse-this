# Offline tests for the read-only upstream currency report.
import hashlib
import json
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import check_upstreams


class CurrencyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.state = self.root / "sandbox" / "installed.json"
        self.catalog = self.root / "catalog" / "tools.json"
        self.pin = self.root / "requirements-test.txt"
        self.patches = [
            mock.patch.object(check_upstreams, "ROOT", self.root),
            mock.patch.object(check_upstreams, "STATE", self.state),
            mock.patch.object(check_upstreams, "CATALOG", self.catalog),
            mock.patch.object(check_upstreams, "TEST_PIN", self.pin),
            mock.patch.object(check_upstreams, "_observed_dotnet_sdks", return_value=[]),
            mock.patch.object(check_upstreams, "_observed_java", return_value=None),
        ]
        for patch in self.patches:
            patch.start()

    def tearDown(self):
        for patch in reversed(self.patches):
            patch.stop()
        self.tmp.cleanup()

    def write_state(self, tools, kit_root=None, schema=1):
        self.state.parent.mkdir(parents=True, exist_ok=True)
        self.state.write_text(json.dumps({
            "schema": schema,
            "kit_root": str(kit_root if kit_root is not None else self.root),
            "tools": tools,
        }), encoding="utf-8")

    def receipt_tool(self, relative="sandbox/tools/rea/bin/rea", version="6.8.0"):
        payload = self.root / relative
        payload.parent.mkdir(parents=True, exist_ok=True)
        payload.write_bytes(b"probe")
        digest = hashlib.sha256(payload.read_bytes()).hexdigest()
        return {
            "version": version,
            "dir": "sandbox/tools/rea",
            "files": {"bin/rea": digest},
        }

    def test_missing_state_does_not_claim_installed_tools(self):
        values, evidence = check_upstreams.probe_installed()
        self.assertNotIn("rea", values)
        self.assertEqual(evidence["rea"]["status"], "missing")

    def test_empty_or_malformed_state_is_not_installed(self):
        self.state.parent.mkdir(parents=True)
        self.state.write_text("{", encoding="utf-8")
        values, evidence = check_upstreams.probe_installed()
        self.assertNotIn("rea", values)
        self.assertEqual(evidence["rea"]["status"], "malformed")

    def test_valid_receipt_is_observed(self):
        self.write_state({"rea": self.receipt_tool()})
        values, evidence = check_upstreams.probe_installed()
        self.assertEqual(values["rea"], "6.8.0")
        self.assertEqual(evidence["rea"]["status"], "valid")


    def test_selected_java_prefers_a_valid_java_home_over_mismatched_path(self):
        with tempfile.TemporaryDirectory() as td:
            home = Path(td)
            java = home / "bin" / ("java.exe" if os.name == "nt" else "java")
            java.parent.mkdir()
            java.write_text("", encoding="utf-8")
            with mock.patch.dict(os.environ, {"JAVA_HOME": str(home)}),                  mock.patch.object(shutil, "which", return_value="C:/other/java.exe"),                  mock.patch.object(check_upstreams, "_java_version_at", side_effect=lambda p: "21" if str(p) == str(java) else "25"):
                self.assertEqual(check_upstreams._selected_java(), (str(java), "JAVA_HOME"))
                evidence = check_upstreams._java_evidence()
                self.assertEqual(evidence["path_version"], "25")
                self.assertEqual(evidence["home_version"], "21")
                self.assertEqual(evidence["selected_source"], "JAVA_HOME")

    def test_empty_malformed_and_escaping_digests_are_never_valid(self):
        for bad in ("", "abc", "0" * 63, "g" * 64):
            tool = self.receipt_tool()
            tool["files"]["bin/rea"] = bad
            self.write_state({"rea": tool})
            values, evidence = check_upstreams.probe_installed()
            self.assertNotIn("rea", values, bad)
            self.assertEqual(evidence["rea"]["status"], "malformed", bad)

        tool = self.receipt_tool()
        tool["files"] = {"../outside": "0" * 64}
        self.write_state({"rea": tool})
        values, evidence = check_upstreams.probe_installed()
        self.assertNotIn("rea", values)
        self.assertEqual(evidence["rea"]["status"], "malformed")

    def test_stale_executable_and_moved_root_are_not_installed(self):
        self.write_state({"rea": self.receipt_tool(relative="sandbox/tools/rea/bin/missing")})
        values, evidence = check_upstreams.probe_installed()
        self.assertNotIn("rea", values)
        self.assertEqual(evidence["rea"]["status"], "stale")

        self.write_state({"rea": self.receipt_tool()}, kit_root=self.root / "elsewhere")
        values, evidence = check_upstreams.probe_installed()
        self.assertNotIn("rea", values)
        self.assertEqual(evidence["rea"]["status"], "moved")

    def test_catalog_and_test_pins_are_not_installed(self):
        self.catalog.parent.mkdir(parents=True)
        self.catalog.write_text(
            json.dumps({"tools": [{"id": "rea", "package_version": "6.8.0"}]}),
            encoding="utf-8",
        )
        self.pin.write_text("capstone==5.0.9\n", encoding="utf-8")
        rows = check_upstreams.report(offline=True)
        rea = next(row for row in rows if row["component"] == "rea")
        capstone = next(row for row in rows if row["component"] == "capstone")
        self.assertIsNone(rea["installed"])
        self.assertEqual(rea["catalog_pin"], "6.8.0")
        self.assertIsNone(capstone["installed"])
        self.assertEqual(capstone["catalog_pin"], "5.0.9")

    def test_dotnet_parser_handles_all_sdk_lines_and_highest_wins(self):
        self.assertEqual(check_upstreams._parse_dotnet_sdks("8.0.100 [C:\\sdk]\n"), ["8.0.100"])
        self.assertEqual(check_upstreams._parse_dotnet_sdks("10.0.100 [C:\\sdk]\n"), ["10.0.100"])
        self.assertEqual(
            check_upstreams._parse_dotnet_sdks("8.0.100 [C:\\sdk]\n10.0.100 [C:\\sdk]\n"),
            ["10.0.100", "8.0.100"],
        )
        self.assertEqual(check_upstreams._parse_dotnet_sdks("malformed output"), [])

    def test_dotnet_probe_reports_highest_sdk_not_first_line(self):
        with mock.patch.object(check_upstreams, "_observed_dotnet_sdks", return_value=["10.0.100", "8.0.100"]):
            values, evidence = check_upstreams.probe_installed()
        self.assertEqual(values["dotnet"], "10.0.100")
        self.assertEqual(evidence["dotnet"]["sdk_versions"], ["10.0.100", "8.0.100"])

    def test_offline_has_its_own_state(self):
        rows = check_upstreams.report(offline=True)
        self.assertTrue(all(row["update"] == "offline" for row in rows))
        self.assertTrue(all(row["latest"] is None for row in rows))

    def test_network_failure_is_not_offline(self):
        def broken(*_args):
            raise OSError("offline")
        rows = check_upstreams.report(fetcher=broken)
        checked = [row for row in rows if check_upstreams.ENDPOINTS[row["component"]]]
        self.assertTrue(all(row["update"] == "network-unavailable" for row in checked))
        self.assertTrue(all(row["error"] for row in checked))

    def test_malformed_response_is_explicit(self):
        def malformed(*_args):
            raise ValueError("bad json")
        rows = check_upstreams.report(fetcher=malformed)
        checked = [row for row in rows if check_upstreams.ENDPOINTS[row["component"]]]
        self.assertTrue(all(row["update"] == "malformed-response" for row in checked))

    def test_compatibility_uses_published_stable_range(self):
        cases = [
            ({"rea": "6.8.0", "ghidra": "12.1.4"}, "compatible"),
            ({"rea": "6.8.0", "ghidra": "12.2"}, "incompatible"),
            ({"rea": "6.8.0", "ghidra": None}, "missing-ghidra"),
            ({"rea": "6.8.0", "ghidra": "11.4"}, "unknown-ghidra"),
            ({"rea": "6.9.0", "ghidra": "12.2"}, "unknown-version"),
            ({"rea": None, "ghidra": "12.1"}, "not-evaluated"),
        ]
        for observed, expected in cases:
            self.assertEqual(check_upstreams.compatibility_status("rea", observed), expected, observed)
        self.assertEqual(check_upstreams.java_compatibility(
            {"rea": "6.8.0", "java": "21"}, {"min": 21, "max": None}), "within-ghidra-bounds")
        self.assertEqual(check_upstreams.java_compatibility(
            {"rea": "6.8.0", "java": "25"}, {"min": 21, "max": None}), "within-ghidra-bounds")
        self.assertEqual(check_upstreams.java_compatibility(
            {"rea": "6.8.0", "java": "17"}, {"min": 21, "max": None}), "outside-ghidra-bounds")
        self.assertEqual(check_upstreams.java_compatibility(
            {"rea": "6.8.0", "java": "25"}, {"min": 21, "max": 25}), "within-ghidra-bounds")
        self.assertEqual(check_upstreams.java_compatibility(
            {"rea": "6.8.0", "java": "21"}), "unverified-bounds")
        self.assertEqual(check_upstreams.java_compatibility({"rea": "6.8.0"}), "missing-java")


if __name__ == "__main__":
    unittest.main()
