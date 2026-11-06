"""Deterministic AOB masking fixtures; requires the kit's Capstone environment."""
import importlib.util
import unittest
from pathlib import Path

try:
    from capstone import CS_ARCH_X86, CS_MODE_64, Cs
except ImportError:  # pragma: no cover - CI without the optional kit venv
    Cs = None

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("aob_gen", ROOT / "kit/aob_gen.py")
aob_gen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(aob_gen)


@unittest.skipIf(Cs is None, "capstone is not installed")
class AobFixtures(unittest.TestCase):
    def decode(self, hexbytes):
        md = Cs(CS_ARCH_X86, CS_MODE_64)
        md.detail = True
        return list(md.disasm(bytes.fromhex(hexbytes), 0x1000))

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


if __name__ == "__main__":
    unittest.main()
