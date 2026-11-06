#!/usr/bin/env python3
"""aob_gen.py — generate an ASLR-safe wildcard AOB signature.

Masks relocatable displacement/immediate bytes while preserving opcode and ModRM
shapes. Requires Capstone (the kit installs it as the `capstone` catalog tool).

Usage:
    python aob_gen.py <file.exe> --rva 0x1A2B30 [--instructions 24]
    python aob_gen.py <file.exe> --pattern "48 8B 05 ?? ?? ?? ??" [--instructions 24]
    python aob_gen.py <file.exe> --offset 0x1200

`--pattern` selects an executable-section match; `--offset` and `--rva` must
point into an executable section. `matches` counts overlapping starts.
Output JSON: pattern, rva, instructions, wildcards, unique, matches.
"""

from __future__ import annotations

import argparse
import json
import re
import struct
import sys
from pathlib import Path

try:
    from capstone import CS_ARCH_X86, CS_GRP_CALL, CS_GRP_JUMP, CS_MODE_32, CS_MODE_64, Cs
    from capstone.x86 import X86_OP_IMM, X86_OP_MEM, X86_REG_RIP
except ImportError:  # pragma: no cover - reported to the caller
    Cs = None  # type: ignore[assignment]


def u16(b: bytes, o: int) -> int:
    return struct.unpack_from("<H", b, o)[0]


def u32(b: bytes, o: int) -> int:
    return struct.unpack_from("<I", b, o)[0]


def u64(b: bytes, o: int) -> int:
    return struct.unpack_from("<Q", b, o)[0]


class PE:
    def __init__(self, data: bytes):
        self.data = data
        if data[:2] != b"MZ":
            raise ValueError("not a PE: missing MZ")
        self.e_lfanew = u32(data, 0x3C)
        if self.e_lfanew + 24 > len(data) or data[self.e_lfanew : self.e_lfanew + 4] != b"PE\0\0":
            raise ValueError("not a PE: missing PE signature")
        coff = self.e_lfanew + 4
        self.machine = u16(data, coff)
        self.section_count = u16(data, coff + 2)
        self.opt_size = u16(data, coff + 16)
        opt = coff + 20
        if opt + self.opt_size > len(data):
            raise ValueError("not a PE: optional header exceeds the file")
        self.magic = u16(data, opt)
        self.pe32_plus = self.magic == 0x20B
        if self.magic not in (0x10B, 0x20B):
            raise ValueError(f"not a PE: unsupported optional-header magic 0x{self.magic:04X}")
        self.image_base = u64(data, opt + 24) if self.pe32_plus else u32(data, opt + 28)
        self.sections = []
        sec = opt + self.opt_size
        if self.section_count <= 0 or sec + self.section_count * 40 > len(data):
            raise ValueError("not a PE: section table exceeds the file")
        for i in range(self.section_count):
            base = sec + i * 40
            section = {
                "name": data[base : base + 8].rstrip(b"\0").decode("ascii", "replace"),
                "virtual_size": u32(data, base + 8),
                "virtual_address": u32(data, base + 12),
                "raw_size": u32(data, base + 16),
                "raw_offset": u32(data, base + 20),
                "characteristics": u32(data, base + 36),
            }
            if section["raw_size"] and section["raw_offset"] + section["raw_size"] > len(data):
                raise ValueError(f"not a PE: section {section['name']} exceeds the file")
            self.sections.append(section)

    def executable_ranges(self) -> list[tuple[int, int]]:
        """Raw file ranges for sections the loader may execute."""
        ranges = []
        for s in self.sections:
            if s["characteristics"] & 0x20000000 and s["raw_size"]:
                ranges.append((s["raw_offset"], s["raw_offset"] + s["raw_size"]))
        return ranges

    def executable_range_at(self, offset: int) -> tuple[int, int] | None:
        for start, end in self.executable_ranges():
            if start <= offset < end:
                return start, end
        return None

    def rva_to_offset(self, rva: int) -> int | None:
        for s in self.sections:
            start = s["virtual_address"]
            size = max(s["virtual_size"], s["raw_size"])
            if start <= rva < start + size:
                delta = rva - start
                if delta < s["raw_size"]:
                    return s["raw_offset"] + delta
        return None

    def offset_to_rva(self, offset: int) -> int | None:
        for s in self.sections:
            start = s["raw_offset"]
            if s["raw_size"] and start <= offset < start + s["raw_size"]:
                return s["virtual_address"] + (offset - start)
        return None


def parse_pattern(text: str) -> tuple[re.Pattern[bytes], bytes]:
    tokens = text.replace(",", " ").split()
    if not tokens:
        raise ValueError("empty pattern")
    regex = bytearray()
    fixed = bytearray()
    for token in tokens:
        if token in ("??", "?", "**"):
            regex += b"."
            fixed += b"\x00"
        else:
            value = int(token, 16)
            if not 0 <= value <= 0xFF:
                raise ValueError(f"byte out of range: {token}")
            regex += re.escape(bytes([value]))
            fixed += bytes([value])
    return re.compile(bytes(regex), re.DOTALL), bytes(fixed)


def mask_flags(insn, length: int) -> bytearray:
    """Return a flag per byte: 1 = wildcard, 0 = keep.

    Capstone's encoding offsets distinguish displacement bytes from immediate
    bytes. Only relocatable fields are masked; small constants stay visible.
    """
    encoding = getattr(insn, "encoding", None)
    if encoding is None:
        raise ValueError("the decoder did not expose instruction encoding offsets")
    flags = bytearray(length)

    def mask(offset: int, size: int) -> None:
        if size and 0 <= offset < length:
            for i in range(offset, min(length, offset + size)):
                flags[i] = 1

    disp_offset = getattr(encoding, "disp_offset", 0)
    disp_size = getattr(encoding, "disp_size", 0)
    imm_offset = getattr(encoding, "imm_offset", 0)
    imm_size = getattr(encoding, "imm_size", 0)
    branch = insn.group(CS_GRP_JUMP) or insn.group(CS_GRP_CALL)

    for op in insn.operands:
        if op.type == X86_OP_MEM:
            if op.mem.base == X86_REG_RIP:
                mask(disp_offset, disp_size)
            elif op.mem.base == 0 and op.mem.index == 0 and disp_size >= 4 and abs(op.mem.disp) >= 0x10000:
                # Absolute addressing describes an image address, not a constant.
                mask(disp_offset, disp_size)
        elif op.type == X86_OP_IMM:
            if branch:
                mask(imm_offset, imm_size or op.size)
            elif op.size >= 4 and abs(op.imm) >= 0x10000:
                mask(imm_offset, imm_size or op.size)
    return flags


def emit(original: bytes | bytearray, masked: bytearray) -> str:
    parts = []
    for i, byte in enumerate(original):
        parts.append("??" if masked[i] else f"{byte:02X}")
    return " ".join(parts)


def count_overlapping(pattern: bytes | re.Pattern[bytes], data: bytes) -> int:
    """Count every start offset, including overlaps; short signatures need this."""
    compiled = pattern if isinstance(pattern, re.Pattern) else re.compile(pattern, re.DOTALL)
    if compiled.pattern == b"":
        return 0
    count = 0
    position = 0
    length = len(data)
    while position <= length:
        match = compiled.search(data, position)
        if match is None:
            return count
        count += 1
        position = match.start() + 1
    return count


def positive_instructions(value: str) -> int:
    number = int(value)
    if not 1 <= number <= 1000:
        raise argparse.ArgumentTypeError("instructions must be between 1 and 1000")
    return number


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file")
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--rva", type=lambda s: int(s, 0))
    source.add_argument("--offset", type=lambda s: int(s, 0))
    source.add_argument("--pattern")
    parser.add_argument("--instructions", type=positive_instructions, default=24)
    args = parser.parse_args(argv[1:])

    if Cs is None:
        print(json.dumps({"error": "capstone is not installed; run install.cmd -Only aob-gen"}))
        return 3

    path = Path(args.file)
    try:
        data = path.read_bytes()
        pe = PE(data)
    except Exception as exc:  # noqa: BLE001 - report the parse failure as JSON
        print(json.dumps({"file": str(path), "error": str(exc)}))
        return 2

    if args.pattern:
        try:
            regex, _ = parse_pattern(args.pattern)
        except (ValueError, TypeError) as exc:
            print(json.dumps({"file": str(path), "error": f"invalid pattern: {exc}"}))
            return 2
        match = next((m for start, end in pe.executable_ranges() for m in [regex.search(data, start, end)] if m), None)
        if not match:
            print(json.dumps({"file": str(path), "error": "pattern not found in an executable section"}))
            return 1
        offset = match.start()
    elif args.rva is not None:
        offset = pe.rva_to_offset(args.rva)
        if offset is None:
            print(json.dumps({"file": str(path), "error": "RVA is not in a raw section"}))
            return 1
    else:
        offset = args.offset
        if not (0 <= offset < len(data)):
            print(json.dumps({"file": str(path), "error": "offset out of range"}))
            return 1

    if pe.machine not in (0x14C, 0x8664):
        print(json.dumps({"file": str(path), "error": f"unsupported PE machine: 0x{pe.machine:04X}"}))
        return 2
    if not pe.executable_ranges():
        print(json.dumps({"file": str(path), "error": "PE has no executable section"}))
        return 2
    exec_range = pe.executable_range_at(offset)
    if exec_range is None:
        print(json.dumps({"file": str(path), "error": "offset is not in an executable section"}))
        return 1
    rva = pe.offset_to_rva(offset)
    if rva is None:
        print(json.dumps({"file": str(path), "error": "offset is not in a mapped section"}))
        return 1

    mode = CS_MODE_64 if pe.pe32_plus else CS_MODE_32
    md = Cs(CS_ARCH_X86, mode)
    md.detail = True
    va = pe.image_base + rva
    window = data[offset : min(exec_range[1], offset + 4096)]
    original = bytearray()
    wildcard_flags = bytearray()
    count = 0
    for insn in md.disasm(window, va):
        if count >= args.instructions:
            break
        raw = bytearray(insn.bytes)
        try:
            flags = mask_flags(insn, len(raw))
        except ValueError as exc:
            print(json.dumps({"file": str(path), "error": str(exc)}))
            return 2
        original += raw
        wildcard_flags += flags
        count += 1
        if len(original) >= len(window):
            break

    if count == 0:
        print(json.dumps({"file": str(path), "error": "no instructions decoded"}))
        return 1

    text = emit(original, wildcard_flags)
    tokens = text.split()
    regex = re.compile(b"".join(b"." if t == "??" else re.escape(bytes([int(t, 16)])) for t in tokens), re.DOTALL)
    matches = 0
    for start, end in pe.executable_ranges():
        matches += count_overlapping(regex, data[start:end])
    result = {
        "file": str(path),
        "pattern": text,
        "rva": hex(rva),
        "offset": hex(offset),
        "instructions": count,
        "wildcards": sum(1 for t in tokens if t == "??"),
        "bytes": len(tokens),
        "unique": matches == 1,
        "matches": matches,
    }
    print(json.dumps(result, indent=2))
    return 0 if matches == 1 else 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
