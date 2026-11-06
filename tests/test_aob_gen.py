"""Deterministic AOB masking fixtures; requires the kit's Capstone environment."""
import importlib.util
import json
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from capstone import CS_ARCH_X86, CS_MODE_64, Cs

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("aob_gen", ROOT / "kit/aob_gen.py")
aob_gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(aob_gen)


def make_pe(text: bytes, extra_text: bytes | None = None) -> bytes:
    """Build a minimal PE32+ with one or two executable sections."""
    e_lfanew = 0x80
    opt_size = 0xF0
    table = e_lfanew + 4 + 20 + opt_size
    data = bytearray(max(0x600 + len(text), 0x800 + len(extra_text or b"")))
    data[0:2] = b"MZ"
    struct.pack_into("<I", data, 0x3C, e_lfanew)
    data[e_lfanew : e_lfanew + 4] = b"PE\0\0"
    struct.pack_into("<H", data, e_lfanew + 4, 0x8664)
    struct.pack_into("<H", data, e_lfanew + 6, 2 if extra_text is not None else 1)
    struct.pack_into("<H", data, e_lfanew + 20, opt_size)
    struct.pack_into("<H", data, e_lfanew + 24, 0x20B)
    struct.pack_into("<Q", data, e_lfanew + 48, 0x140000000)
    struct.pack_into("<I", data, table + 8, len(text))
    struct.pack_into("<I", data, table + 12, 0x1000)
    struct.pack_into("<I", data, table + 16, len(text))
    struct.pack_into("<I", data, table + 20, 0x200)
    struct.pack_into("<I", data, table + 36, 0x60000020)
    data[0x200 : 0x200 + len(text)] = text
    if extra_text is not None:
        struct.pack_into("<I", data, table + 40 + 8, len(extra_text))
        struct.pack_into("<I", data, table + 40 + 12, 0x2000)
        struct.pack_into("<I", data, table + 40 + 16, len(extra_text))
        struct.pack_into("<I", data, table + 40 + 20, 0x400)
        struct.pack_into("<I", data, table + 40 + 36, 0x60000020)
        data[0x400 : 0x400 + len(extra_text)] = extra_text
    return bytes(data)


class AobFixtures(unittest.TestCase):
    def run_aob(self, data: bytes, *args: str) -> tuple[int, dict]:
        with tempfile.TemporaryDirectory(prefix="rt-aob-") as td:
            path = Path(td) / "fixture.exe"
            path.write_bytes(data)
            result = subprocess.run([sys.executable, str(ROOT / "kit/aob_gen.py"), str(path), *args],
                                    capture_output=True, text=True, timeout=30)
        return result.returncode, json.loads(result.stdout)

    def test_rip_displacement_and_immediate_are_distinct(self):
        insn = self.decode("C7 05 01 02 03 04 2A 00 00 00")[0]
        flags = aob_gen.mask_flags(insn, insn.size)
        self.assertEqual(list(flags[2:6]), [1, 1, 1, 1])
        self.assertEqual(list(flags[6:10]), [0, 0, 0, 0])

    def test_short_and_near_branch_bytes_are_masked(self):
        short = self.decode("74 05")[0]
        self.assertEqual(list(aob_gen.mask_flags(short, short.size)), [0, 1])
        near = self.decode("E8 01 02 03 04")[0]
        self.assertEqual(list(aob_gen.mask_flags(near, near.size)), [0, 1, 1, 1, 1])

    def test_indirect_call_has_no_immediate_to_mask(self):
        insn = self.decode("FF D0")[0]
        self.assertEqual(list(aob_gen.mask_flags(insn, insn.size)), [0, 0])

    def decode(self, hexbytes):
        md = Cs(CS_ARCH_X86, CS_MODE_64)
        md.detail = True
        return list(md.disasm(bytes.fromhex(hexbytes), 0x1000))

    def test_overlapping_matches_are_not_reported_unique(self):
        code, result = self.run_aob(make_pe(b"\x90\x90\x90"), "--offset", "0x200", "--instructions", "2")
        self.assertEqual(code, 1, result)
        self.assertEqual(result["pattern"], "90 90")
        self.assertEqual(result["matches"], 2)
        self.assertFalse(result["unique"])

    def test_pattern_skips_header_duplicate_and_uses_executable_section(self):
        data = bytearray(make_pe(b"\x90\x90\x90"))
        data[0x40:0x42] = b"\x90\x90"
        code, result = self.run_aob(bytes(data), "--pattern", "90 90", "--instructions", "2")
        self.assertEqual(code, 1, result)
        self.assertEqual(result["offset"], "0x200")
        self.assertEqual(result["matches"], 2)

    def test_pattern_finds_the_second_executable_section(self):
        code, result = self.run_aob(make_pe(b"\xCC", b"\x90\x90"), "--pattern", "90 90")
        self.assertIn(code, (0, 1), result)
        self.assertEqual(result["offset"], "0x400")

    def test_non_executable_and_invalid_ranges_are_refused(self):
        code, result = self.run_aob(make_pe(b"\x90"), "--offset", "0x100")
        self.assertEqual(code, 1)
        self.assertIn("executable", result["error"])
        with tempfile.TemporaryDirectory(prefix="rt-aob-") as td:
            path = Path(td) / "fixture.exe"
            path.write_bytes(make_pe(b"\x90"))
            result = subprocess.run([sys.executable, str(ROOT / "kit/aob_gen.py"), str(path),
                                     "--offset", "0x200", "--instructions", "0"],
                                    capture_output=True, text=True, timeout=30)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("instructions", result.stderr + result.stdout)

    def test_signature_near_section_end_and_section_bounds(self):
        code, result = self.run_aob(make_pe(b"\xCC" * 15 + b"\x90"), "--offset", "0x20f", "--instructions", "1")
        self.assertEqual(code, 0, result)
        self.assertEqual(result["rva"], "0x100f")

    def test_unsupported_machine_and_truncated_section_fail_closed(self):
        data = bytearray(make_pe(b"\x90"))
        struct.pack_into("<H", data, 0x84, 0x1C0)
        code, result = self.run_aob(bytes(data), "--offset", "0x200")
        self.assertEqual(code, 2)
        self.assertIn("unsupported", result["error"])
        data = bytearray(make_pe(b"\x90"))
        struct.pack_into("<I", data, 0x188 + 16, 0x100000)
        code, result = self.run_aob(bytes(data), "--offset", "0x200")
        self.assertEqual(code, 2)
        self.assertIn("exceeds", result["error"])


if __name__ == "__main__":
    unittest.main()
