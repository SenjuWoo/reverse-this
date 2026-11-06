#!/usr/bin/env python3
"""pe_recon.py — deterministic PE reconnaissance for the Reverse THIS! kit.

Outputs JSON: bitness, machine, subsystem, entry point, sections, imported DLLs,
graphics APIs, anti-cheat markers, RTTI strings and safe proxy DLL candidates.
Standard library only; no target execution.

Usage:
    python pe_recon.py <file.exe> [--json]
"""

from __future__ import annotations

import json
import struct
import sys
from pathlib import Path

GRAPHICS_DLLS = {
    "d3d9.dll": "Direct3D 9",
    "d3d10.dll": "Direct3D 10",
    "d3d11.dll": "Direct3D 11",
    "d3d12.dll": "Direct3D 12",
    "dxgi.dll": "DXGI",
    "opengl32.dll": "OpenGL",
    "vulkan-1.dll": "Vulkan",
    "ddraw.dll": "DirectDraw",
    "gdi32.dll": "GDI",
    "d2d1.dll": "Direct2D",
    "dwrite.dll": "DirectWrite",
}

ANTI_CHEAT_MARKERS = {
    "BattlEye": ["battleye", "beclient", "beservice"],
    "EasyAntiCheat": ["easyanticheat", "easyanti", "eac_launcher"],
    "Riot Vanguard": ["vgk.sys", "vgc.dll", "vanguard"],
    "Denuvo": ["denuvo"],
    "VMProtect": ["vmprotect"],
    "Themida": ["themida", "winlicense"],
    "Arxan": ["arxan"],
    "PunkBuster": ["punkbuster", "pnkbstr"],
    "Ricochet": ["ricochet"],
    "nProtect": ["nprotect", "gameguard"],
}

PROXY_CANDIDATES = [
    "dinput8.dll",
    "winmm.dll",
    "version.dll",
    "dxgi.dll",
    "d3d11.dll",
    "xinput1_4.dll",
    "xinput1_3.dll",
    "dwmapi.dll",
]


def u16(b: bytes, o: int) -> int:
    return struct.unpack_from("<H", b, o)[0]


def u32(b: bytes, o: int) -> int:
    return struct.unpack_from("<I", b, o)[0]


def u64(b: bytes, o: int) -> int:
    return struct.unpack_from("<Q", b, o)[0]


def cstr(b: bytes, o: int, limit: int = 512) -> str:
    end = b.find(b"\0", o, o + limit)
    if end < 0:
        end = min(o + limit, len(b))
    return b[o:end].decode("ascii", "replace")


class PE:
    def __init__(self, data: bytes):
        self.data = data
        if len(data) < 64 or data[:2] != b"MZ":
            raise ValueError("not a PE: missing or truncated MZ header")
        self.e_lfanew = u32(data, 0x3C)
        if self.e_lfanew < 64 or self.e_lfanew + 24 > len(data):
            raise ValueError("not a PE: e_lfanew is outside the file")
        if data[self.e_lfanew : self.e_lfanew + 4] != b"PE\0\0":
            raise ValueError("not a PE: missing PE signature")
        coff = self.e_lfanew + 4
        self.machine = u16(data, coff)
        self.section_count = u16(data, coff + 2)
        if self.section_count > 96:
            raise ValueError("unsupported PE: too many sections")
        self.timestamp = u32(data, coff + 4)
        self.opt_size = u16(data, coff + 16)
        self.characteristics = u16(data, coff + 18)
        opt = coff + 20
        self.opt = opt
        if opt + self.opt_size > len(data) or self.opt_size < 2:
            raise ValueError("not a PE: optional header is truncated")
        self.magic = u16(data, opt)
        if self.magic not in (0x10B, 0x20B):
            raise ValueError(f"unsupported PE optional-header magic: 0x{self.magic:X}")
        self.pe32_plus = self.magic == 0x20B
        minimum_opt = 112 if self.pe32_plus else 96
        if self.opt_size < minimum_opt:
            raise ValueError("not a PE: optional header is smaller than its fixed fields")
        self.entry_rva = u32(data, opt + 16)
        self.image_base = u64(data, opt + 24) if self.pe32_plus else u32(data, opt + 28)
        self.subsystem = u16(data, opt + 68)
        self.dll_characteristics = u16(data, opt + 70)
        self.dir_count = min(u32(data, opt + (108 if self.pe32_plus else 92)), 16)
        self.dirs_at = opt + (112 if self.pe32_plus else 96)
        if self.dirs_at + self.dir_count * 8 > opt + self.opt_size:
            raise ValueError("not a PE: data-directory table exceeds the optional header")
        sec = opt + self.opt_size
        if sec + self.section_count * 40 > len(data):
            raise ValueError("not a PE: section table is truncated")
        self.sections = []
        for i in range(self.section_count):
            base = sec + i * 40
            raw_size = u32(data, base + 16)
            raw_offset = u32(data, base + 20)
            if raw_size and raw_offset + raw_size > len(data):
                raise ValueError("not a PE: section raw data exceeds the file")
            name = data[base : base + 8].rstrip(b"\0").decode("ascii", "replace")
            self.sections.append(
                {
                    "name": name,
                    "virtual_size": u32(data, base + 8),
                    "virtual_address": u32(data, base + 12),
                    "raw_size": raw_size,
                    "raw_offset": raw_offset,
                    "characteristics": u32(data, base + 36),
                }
            )

    def dir(self, index: int) -> tuple[int, int]:
        if index >= self.dir_count:
            return (0, 0)
        return (u32(self.data, self.dirs_at + index * 8), u32(self.data, self.dirs_at + index * 8 + 4))

    def rva_to_offset(self, rva: int) -> int | None:
        for s in self.sections:
            start = s["virtual_address"]
            size = max(s["virtual_size"], s["raw_size"])
            if start <= rva < start + size:
                delta = rva - start
                if delta < s["raw_size"] and s["raw_offset"] + delta < len(self.data):
                    return s["raw_offset"] + delta
        return None

    def imports(self) -> list[str]:
        rva, size = self.dir(1)
        if not rva:
            return []
        off = self.rva_to_offset(rva)
        if off is None:
            return []
        names = []
        limit = min(4096 * 20, max(0, size))
        for i in range(0, limit, 20):
            base = off + i
            if base + 20 > len(self.data):
                break
            name_rva = u32(self.data, base + 12)
            if name_rva == 0:
                break
            name_off = self.rva_to_offset(name_rva)
            if name_off is not None:
                names.append(cstr(self.data, name_off))
            if len(names) >= 4096:
                break
        return sorted(set(n.lower() for n in names))

    def rtti_strings(self) -> list[str]:
        out: list[str] = []
        for s in self.sections:
            if s["name"] not in (".rdata", ".data"):
                continue
            blob = self.data[s["raw_offset"] : s["raw_offset"] + s["raw_size"]]
            for marker in (b".?AV", b".?AU"):
                start = 0
                while True:
                    idx = blob.find(marker, start)
                    if idx < 0:
                        break
                    text = cstr(blob, idx, 256)
                    if 4 <= len(text) <= 200 and text not in out:
                        out.append(text)
                    start = idx + 4
                    if len(out) >= 60:
                        return out
        return out


def main(argv: list[str]) -> int:
    if len(argv) < 2 or argv[1] in ("-h", "--help"):
        print((__doc__ or "").strip())
        return 2
    path = Path(argv[1])
    try:
        data = path.read_bytes()
        pe = PE(data)
    except Exception as exc:  # noqa: BLE001 - report the parse failure as JSON
        print(json.dumps({"file": str(path), "error": str(exc)}, indent=2))
        return 2

    imports = pe.imports()
    graphics = [
        {"dll": dll, "api": GRAPHICS_DLLS[dll]}
        for dll in imports
        if dll in GRAPHICS_DLLS
    ]
    lowered = data.lower()
    anti_cheat = [
        name
        for name, needles in ANTI_CHEAT_MARKERS.items()
        if any(n.encode("ascii") in lowered for n in needles)
    ]
    proxy = [
        {"name": name, "already_imported": name in imports}
        for name in PROXY_CANDIDATES
    ]
    result = {
        "file": str(path),
        "size": len(data),
        "sha256_note": "hash the file separately; this tool does not hash large targets",
        "bitness": 64 if pe.pe32_plus else 32,
        "machine": hex(pe.machine),
        "subsystem": pe.subsystem,
        "entry_rva": hex(pe.entry_rva),
        "image_base": hex(pe.image_base),
        "dll": bool(pe.characteristics & 0x2000),
        "sections": pe.sections,
        "imports": imports,
        "graphics_apis": graphics,
        "anti_cheat_markers": anti_cheat,
        "anti_cheat_note": "string indicators, not definitive detection",
        "rtti_strings": pe.rtti_strings(),
        "proxy_candidates": proxy,
        "proxy_note": "candidates only; loading a proxy DLL is never guaranteed safe",
    }
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
