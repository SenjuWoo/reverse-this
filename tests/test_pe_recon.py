# Synthetic PE fixtures for the strict header parser and CLI error contract.
import json
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

KIT = Path(__file__).resolve().parent.parent / "kit"
sys.path.insert(0, str(KIT))


def make_pe(section_count=1, magic=0x20B, opt_size=240, raw_size=0x200, file_size=0x400, dir_count=16):
    data = bytearray(max(file_size, 0x200))
    data[:2] = b"MZ"
    struct.pack_into("<I", data, 0x3C, 0x40)
    data[0x40:0x44] = b"PE\0\0"
    coff = 0x44
    struct.pack_into("<H", data, coff, 0x8664 if magic == 0x20B else 0x14C)
    struct.pack_into("<H", data, coff + 2, section_count)
    struct.pack_into("<H", data, coff + 16, opt_size)
    opt = coff + 20
    struct.pack_into("<H", data, opt, magic)
    struct.pack_into("<I", data, opt + 16, 0x1000)
    if magic == 0x20B:
        struct.pack_into("<Q", data, opt + 24, 0x140000000)
        struct.pack_into("<I", data, opt + 108, dir_count)
    else:
        struct.pack_into("<I", data, opt + 28, 0x400000)
        struct.pack_into("<I", data, opt + 92, dir_count)
    struct.pack_into("<H", data, opt + 68, 3)
    sec = opt + opt_size
    data[sec:sec + 8] = b".text\0\0\0"
    struct.pack_into("<I", data, sec + 8, 0x100)
    struct.pack_into("<I", data, sec + 12, 0x1000)
    struct.pack_into("<I", data, sec + 16, raw_size)
    struct.pack_into("<I", data, sec + 20, 0x200)
    struct.pack_into("<I", data, sec + 36, 0x60000020)
    return bytes(data)


class PeReconTests(unittest.TestCase):
    def test_valid_pe32_and_pe32_plus(self):
        from pe_recon import PE
        self.assertTrue(PE(make_pe(magic=0x20B)).pe32_plus)
        self.assertFalse(PE(make_pe(magic=0x10B)).pe32_plus)

    def test_unsupported_optional_header_magic_is_rejected(self):
        from pe_recon import PE
        with self.assertRaisesRegex(ValueError, "optional-header magic"):
            PE(make_pe(magic=0x999))

    def test_truncated_section_and_directory_tables_are_rejected(self):
        from pe_recon import PE
        with self.assertRaisesRegex(ValueError, "section table"):
            PE(make_pe(section_count=40, file_size=0x200))
        with self.assertRaisesRegex(ValueError, "data-directory table"):
            PE(make_pe(opt_size=112, dir_count=16))

    def test_section_raw_range_is_bounded(self):
        from pe_recon import PE
        with self.assertRaisesRegex(ValueError, "section raw data"):
            PE(make_pe(raw_size=0x400, file_size=0x300))

    def test_cli_reports_malformed_pe_without_traceback(self):
        with tempfile.TemporaryDirectory() as tmp:
            bad = Path(tmp) / "bad.exe"
            bad.write_bytes(make_pe(magic=0x999))
            proc = subprocess.run([sys.executable, str(KIT / "pe_recon.py"), str(bad)],
                                  capture_output=True, text=True)
            self.assertEqual(proc.returncode, 2)
            payload = json.loads(proc.stdout)
            self.assertIn("error", payload)
            self.assertNotIn("Traceback", proc.stderr)


if __name__ == "__main__":
    unittest.main()
