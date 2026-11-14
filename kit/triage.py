#!/usr/bin/env python3
"""First look at an unknown target: what it is, which installed tools read it, what to run.

    re-triage <file-or-folder> [--run] [--out DIR] [--kit ROOT] [--timeout SECONDS]

The target is identified from its bytes (a folder from the files in it). The answer
is one JSON document: the format with the evidence for it, every analyzer in this
kit that applies and whether it is installed, and the commands to run next.

`--run` also executes the quick, read-only static analyzers that are installed and
keeps their output under the kit's work folder. The target itself is never
executed, loaded or modified. A tool that is missing or fails is reported in the
result and does not stop the others.

Standard library only.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import struct
import subprocess
import sys
import time
import zipfile
from pathlib import Path

VERSION = "1"
READ_HEAD = 1 << 16
HASH_LIMIT = 8 << 30          # hashing more than this is announced, not skipped silently
POINTER = ("ReverseThis", "kit.json")

# shim, what it answers, argv after the shim ({target} is replaced), quick = safe for --run
ANALYZERS = {
    "pe-recon": ("PE fingerprint: bitness, graphics APIs, anti-cheat markers, RTTI, proxy DLL candidates", ["{target}"], True),
    "diec": ("compiler, linker, packer and protector detection", ["-j", "{target}"], True),
    "rz-bin": ("headers, sections, imports, exports, security flags", ["-I", "-j", "{target}"], True),
    "capa": ("capabilities from static rules (minutes on a large binary)", ["-j", "{target}"], False),
    "floss": ("decoded and stack strings (minutes on a large binary)", ["-j", "{target}"], False),
    "yara": ("match your own rules", ["<rules.yar>", "{target}"], False),
    "analyzeHeadless": ("Ghidra decompile without a GUI", ["<project-dir>", "<project-name>", "-import", "{target}"], False),
    "rea": ("agent-driven native analysis over Ghidra", ["analyze", "{target}"], False),
    "ilspycmd": (".NET decompile to C#", ["-p", "-o", "<out-dir>", "{target}"], False),
    "dnspy": (".NET debug and edit (GUI)", ["{target}"], False),
    "il2cppdumper": ("IL2CPP: recover type and method names from GameAssembly + global-metadata.dat", ["<GameAssembly.dll>", "<global-metadata.dat>", "<out-dir>"], False),
    "assetripper": ("Unity: extract assets and scenes", ["{target}"], False),
    "fmodel": ("Unreal: browse and export packaged assets (GUI)", [], False),
    "repak": ("Unreal .pak: list and unpack", ["list", "{target}"], False),
    "retoc": ("Unreal IoStore (.utoc/.ucas): list and convert", ["list", "{target}"], False),
    "uassetgui": ("Unreal: view and edit one .uasset (GUI)", ["{target}"], False),
    "gdre": ("Godot: recover a project from a .pck or executable", ["--headless", "--recover={target}"], False),
    "utmt-cli": ("GameMaker data.win: dump code, strings and assets", ["load", "{target}"], False),
    "source2viewer-cli": ("Source 2 VPK: list and export", ["-i", "{target}", "-l"], False),
    "bspsrc": ("Source BSP: decompile a map", ["{target}"], False),
    "crowbar": ("Source models: decompile and compile (GUI)", [], False),
    "jadx": ("Android/Java: decompile DEX, APK or JAR to Java", ["-d", "<out-dir>", "{target}"], False),
    "apktool": ("APK: decode resources and smali", ["d", "{target}", "-o", "<out-dir>"], False),
    "vineflower": ("Java bytecode decompile", ["{target}", "<out-dir>"], False),
    "pyinstxtractor-ng": ("PyInstaller: unpack the embedded archive", ["{target}"], False),
    "asar": ("Electron app.asar: list and extract", ["list", "{target}"], False),
    "wasm-tools": ("WebAssembly: print, validate, demangle", ["print", "{target}"], False),
    "7z": ("archives and installers: list without extracting", ["l", "{target}"], True),
    "upx": ("UPX: test or unpack a packed executable", ["-t", "{target}"], False),
    "quickbms": ("custom game archives through a BMS script", ["<script.bms>", "{target}", "<out-dir>"], False),
    "wolvenkit-cli": ("REDengine .archive: list and extract", ["unbundle", "-p", "{target}", "-o", "<out-dir>"], False),
    "rpfm": ("Total War .pack files (GUI)", [], False),
    "nstool": ("Nintendo Switch containers: NSO, NRO, NCA, XCI", ["{target}"], False),
    "vgmstream": ("game audio streams: decode to WAV", ["-m", "{target}"], False),
    "texdiag": ("DDS: format, size and mip information", ["info", "{target}"], True),
    "imhex": ("hex editor with pattern language (GUI)", ["{target}"], False),
    "kaitai-struct-compiler": ("write a parser for an unknown binary format", [], False),
    "gore-sym": ("Go binary: recover function and type names", ["-f", "{target}"], False),
    "frida": ("live instrumentation of a running process you own", [], False),
    "x64dbg": ("native debugger (GUI)", ["{target}"], False),
}

# format id -> (family, title, analyzers in the order to reach for them)
FORMATS = {
    "pe-native": ("executable", "Windows PE, native code", ["pe-recon", "diec", "rz-bin", "capa", "floss", "analyzeHeadless", "rea", "x64dbg", "yara"]),
    "pe-dotnet": ("executable", "Windows PE, .NET assembly", ["diec", "ilspycmd", "dnspy", "pe-recon", "rz-bin"]),
    "pe-go": ("executable", "Windows PE, Go", ["gore-sym", "pe-recon", "diec", "rz-bin", "analyzeHeadless"]),
    "pe-pyinstaller": ("executable", "Windows PE, PyInstaller bundle", ["pyinstxtractor-ng", "diec", "pe-recon"]),
    "pe-upx": ("executable", "Windows PE, UPX packed", ["upx", "diec", "pe-recon", "rz-bin"]),
    "elf": ("executable", "ELF", ["diec", "rz-bin", "capa", "floss", "analyzeHeadless", "rea"]),
    "macho": ("executable", "Mach-O", ["diec", "rz-bin", "analyzeHeadless", "rea"]),
    "wasm": ("executable", "WebAssembly module", ["wasm-tools", "rz-bin"]),
    "java-class": ("bytecode", "Java class file", ["vineflower", "jadx"]),
    "dex": ("bytecode", "Android DEX", ["jadx"]),
    "apk": ("package", "Android APK", ["jadx", "apktool", "7z"]),
    "jar": ("package", "Java archive", ["jadx", "vineflower", "7z"]),
    "asar": ("package", "Electron asar archive", ["asar"]),
    "zip": ("archive", "ZIP archive", ["7z"]),
    "7z": ("archive", "7-Zip archive", ["7z"]),
    "rar": ("archive", "RAR archive", ["7z"]),
    "gzip": ("archive", "gzip stream", ["7z"]),
    "cab": ("archive", "Microsoft cabinet", ["7z"]),
    "unityfs": ("game-data", "Unity asset bundle", ["assetripper"]),
    "unity-assets": ("game-data", "Unity serialized assets", ["assetripper"]),
    "il2cpp-metadata": ("game-data", "Unity IL2CPP global-metadata.dat", ["il2cppdumper"]),
    "unreal-pak": ("game-data", "Unreal .pak", ["repak", "fmodel"]),
    "unreal-iostore": ("game-data", "Unreal IoStore container", ["retoc", "fmodel"]),
    "unreal-asset": ("game-data", "Unreal package (.uasset/.umap)", ["uassetgui", "fmodel"]),
    "godot-pck": ("game-data", "Godot pack", ["gdre"]),
    "gamemaker": ("game-data", "GameMaker data file", ["utmt-cli"]),
    "source-vpk": ("game-data", "Valve VPK", ["source2viewer-cli"]),
    "source-bsp": ("game-data", "Source engine map", ["bspsrc"]),
    "red-archive": ("game-data", "REDengine archive", ["wolvenkit-cli"]),
    "dds": ("texture", "DirectDraw Surface texture", ["texdiag"]),
    "switch": ("executable", "Nintendo Switch container", ["nstool"]),
    "lua-bytecode": ("bytecode", "compiled Lua", ["imhex"]),
    "python-bytecode": ("bytecode", "compiled Python", ["imhex"]),
    "bethesda-plugin": ("game-data", "Bethesda plugin or archive", []),
    "unknown": ("unknown", "not recognised", ["diec", "7z", "imhex", "kaitai-struct-compiler", "quickbms"]),
}

ENGINES = {
    "unity-il2cpp": ("Unity, IL2CPP", ["il2cppdumper", "assetripper", "analyzeHeadless", "rea"]),
    "unity-mono": ("Unity, Mono", ["ilspycmd", "dnspy", "assetripper"]),
    "unreal": ("Unreal Engine", ["fmodel", "repak", "retoc", "uassetgui"]),
    "godot": ("Godot", ["gdre"]),
    "gamemaker": ("GameMaker", ["utmt-cli"]),
    "source": ("Source engine", ["source2viewer-cli", "bspsrc", "crowbar"]),
    "electron": ("Electron", ["asar"]),
    "renpy": ("Ren'Py", ["7z"]),
    "rpgmaker": ("RPG Maker MV/MZ", ["7z"]),
    "redengine": ("REDengine", ["wolvenkit-cli"]),
    "bethesda": ("Creation Engine", []),
    "java": ("Java application", ["jadx", "vineflower"]),
}


# ------------------------------------------------------------------ detection

def _pe_details(head: bytes, path: Path) -> tuple[str, list[str], dict]:
    """Classify a PE from its headers. Returns (format id, evidence, details)."""
    evidence, details = [], {}
    try:
        pe = struct.unpack_from("<I", head, 0x3C)[0]
        if head[pe:pe + 4] != b"PE\x00\x00":
            return "unknown", ["MZ stub without a PE header (DOS program or damaged file)"], details
        machine, sections = struct.unpack_from("<HH", head, pe + 4)
        opt_size = struct.unpack_from("<H", head, pe + 20)[0]
        characteristics = struct.unpack_from("<H", head, pe + 22)[0]
        magic = struct.unpack_from("<H", head, pe + 24)[0]
        plus = magic == 0x20B
        details.update(bits=64 if plus else 32, machine=hex(machine), dll=bool(characteristics & 0x2000))
        evidence.append("PE%s header, machine %s" % ("32+" if plus else "32", hex(machine)))
        directory = pe + 24 + (112 if plus else 96)
        count = struct.unpack_from("<I", head, directory - 4)[0]
        clr_rva = clr_size = 0
        if count > 14 and directory + 15 * 8 <= len(head):
            clr_rva, clr_size = struct.unpack_from("<II", head, directory + 14 * 8)
        names = []
        table = pe + 24 + opt_size
        for index in range(min(sections, 96)):
            entry = table + index * 40
            if entry + 40 > len(head):
                break
            names.append(head[entry:entry + 8].rstrip(b"\x00").decode("latin-1"))
        details["sections"] = names
    except struct.error:
        return "unknown", ["PE headers are truncated"], details
    if clr_rva and clr_size:
        return "pe-dotnet", evidence + ["CLR runtime header is present"], details
    if any(name.startswith("UPX") for name in names):
        return "pe-upx", evidence + ["section names " + ", ".join(n for n in names if n.startswith("UPX"))], details
    if _tail_contains(path, b"MEI\x0c\x0b\x0a\x0b\x0e"):
        return "pe-pyinstaller", evidence + ["PyInstaller archive cookie near the end of the file"], details
    if b"Go build ID:" in head or ".symtab" in names and b"runtime.main" in head:
        return "pe-go", evidence + ["Go build ID in the header region"], details
    return "pe-native", evidence, details


def _tail_contains(path: Path, needle: bytes, window: int = 1 << 16) -> bool:
    try:
        size = path.stat().st_size
        with open(path, "rb") as handle:
            handle.seek(max(0, size - window))
            return needle in handle.read(window)
    except OSError:
        return False


def _zip_kind(path: Path) -> tuple[str, list[str]]:
    try:
        with zipfile.ZipFile(path) as archive:
            names = set(archive.namelist()[:20000])
    except (zipfile.BadZipFile, OSError, ValueError):
        return "zip", ["ZIP signature; the central directory could not be read"]
    if "AndroidManifest.xml" in names and any(n.endswith(".dex") for n in names):
        return "apk", ["ZIP holding AndroidManifest.xml and a .dex"]
    if "META-INF/MANIFEST.MF" in names or any(n.endswith(".class") for n in names):
        return "jar", ["ZIP holding Java classes or a JAR manifest"]
    return "zip", ["ZIP signature, %d entries" % len(names)]


def identify_file(path: Path) -> dict:
    """Format of one file, from its bytes first and its name second."""
    try:
        with open(path, "rb") as handle:
            head = handle.read(READ_HEAD)
    except OSError as exc:
        return {"id": "unknown", "evidence": ["could not be read: %s" % exc], "details": {}, "confidence": "none"}
    suffix = path.suffix.lower()
    name = path.name.lower()
    details: dict = {}
    confidence = "high"

    def answer(fmt, evidence):
        family, title, _ = FORMATS[fmt]
        return {"id": fmt, "family": family, "title": title, "evidence": evidence,
                "details": details, "confidence": confidence}

    if head[:2] == b"MZ":
        fmt, evidence, details = _pe_details(head, path)
        return answer(fmt, evidence)
    if head[:4] == b"\x7fELF":
        details = {"bits": 64 if head[4:5] == b"\x02" else 32, "endian": "big" if head[5:6] == b"\x02" else "little"}
        return answer("elf", ["ELF magic"])
    if head[:4] in (b"\xcf\xfa\xed\xfe", b"\xce\xfa\xed\xfe", b"\xfe\xed\xfa\xcf", b"\xfe\xed\xfa\xce"):
        return answer("macho", ["Mach-O magic"])
    if head[:4] == b"\xca\xfe\xba\xbe" and len(head) >= 8:
        # A fat Mach-O and a Java class share this magic; the next field tells them apart.
        if struct.unpack_from(">I", head, 4)[0] < 40:
            return answer("macho", ["universal (fat) Mach-O header"])
        return answer("java-class", ["Java class magic"])
    if head[:4] == b"\x00asm":
        return answer("wasm", ["WebAssembly magic"])
    if head[:4] == b"dex\n":
        return answer("dex", ["DEX magic"])
    if head[:4] in (b"PK\x03\x04", b"PK\x05\x06"):
        fmt, evidence = _zip_kind(path)
        return answer(fmt, evidence)
    if head[:6] == b"7z\xbc\xaf\x27\x1c":
        return answer("7z", ["7-Zip magic"])
    if head[:4] == b"Rar!":
        return answer("rar", ["RAR magic"])
    if head[:2] == b"\x1f\x8b":
        return answer("gzip", ["gzip magic"])
    if head[:4] == b"MSCF":
        return answer("cab", ["cabinet magic"])
    if head[:7] in (b"UnityFS", b"UnityWe", b"UnityRa"):
        return answer("unityfs", ["Unity bundle signature %s" % head[:8].rstrip(b"\x00").decode("latin-1")])
    if head[:4] == b"\xaf\x1b\xb1\xfa":
        return answer("il2cpp-metadata", ["IL2CPP metadata magic"])
    if head[:4] == b"GDPC":
        return answer("godot-pck", ["Godot pack magic"])
    if head[:4] == b"FORM" and (name == "data.win" or head[8:12] == b"GEN8"):
        return answer("gamemaker", ["GameMaker FORM/GEN8 chunk"])
    if head[:4] == b"\x34\x12\xaa\x55":
        return answer("source-vpk", ["VPK directory magic"])
    if head[:4] == b"VBSP":
        return answer("source-bsp", ["Source BSP magic"])
    if head[:4] == b"RDAR":
        return answer("red-archive", ["REDengine archive magic"])
    if head[:4] == b"DDS ":
        return answer("dds", ["DDS magic"])
    if head[:4] in (b"NSO0", b"NRO0", b"HEAD") or head[0x10:0x14] == b"NRO0":
        return answer("switch", ["Nintendo Switch container magic"])
    if head[:4] == b"\x1bLua":
        details = {"lua_version": "%d.%d" % (head[4] >> 4, head[4] & 15)}
        return answer("lua-bytecode", ["Lua bytecode header"])
    if head[:4] in (b"TES4", b"BSA\x00", b"BTDX"):
        return answer("bethesda-plugin", ["Creation Engine %s header" % head[:4].rstrip(b"\x00").decode("latin-1")])
    if head[:4] == b"\xc1\x83\x2a\x9e":
        return answer("unreal-asset", ["Unreal package tag"])
    if head[:4] == b"-==-" or suffix == ".utoc" or suffix == ".ucas":
        return answer("unreal-iostore", ["IoStore container (%s)" % (suffix or "magic")])
    if suffix == ".pak":
        confidence = "high" if _tail_contains(path, b"\xe1\x12\x6f\x5a", 512) else "medium"
        return answer("unreal-pak", ["Unreal pak footer magic" if confidence == "high" else ".pak extension without the Unreal footer"])
    # an asar header is a pickle: uint32 4, uint32 header size, uint32, uint32 json length, then JSON
    if suffix == ".asar" or (len(head) > 20 and head[:4] == b"\x04\x00\x00\x00" and head[16:17] == b"{"):
        return answer("asar", ["asar pickle header"])
    if suffix == ".pyc":
        return answer("python-bytecode", [".pyc file"])
    if suffix in (".assets", ".unity3d") or name in ("globalgamemanagers", "maindata", "resources.assets"):
        confidence = "medium"
        return answer("unity-assets", ["Unity data file name"])
    confidence = "none"
    printable = sum(1 for byte in head[:4096] if 32 <= byte < 127 or byte in (9, 10, 13))
    details = {"first_bytes": head[:16].hex(), "text_like": bool(head) and printable / max(1, min(len(head), 4096)) > 0.9}
    return answer("unknown", ["no known signature; first bytes %s" % head[:8].hex()])


def identify_folder(root: Path) -> dict:
    """Engine of a game or application folder, from the files in its top two levels."""
    top = {}
    try:
        for item in root.iterdir():
            top[item.name.lower()] = item
    except OSError as exc:
        return {"id": "unknown", "family": "folder", "title": "folder could not be listed", "evidence": [str(exc)],
                "details": {}, "confidence": "none", "targets": []}
    evidence, targets = [], []

    def has(name):
        return name.lower() in top

    def glob(pattern, limit=12):
        return [str(p) for p in sorted(root.glob(pattern))[:limit]]

    engine = None
    data_dirs = [p for n, p in top.items() if n.endswith("_data") and p.is_dir()]
    if has("unityplayer.dll") or data_dirs:
        il2cpp = has("gameassembly.dll")
        engine = "unity-il2cpp" if il2cpp else "unity-mono"
        evidence.append("UnityPlayer.dll or a *_Data folder")
        if il2cpp:
            evidence.append("GameAssembly.dll (IL2CPP)")
            targets += [str(top["gameassembly.dll"])] + glob("*_Data/il2cpp_data/Metadata/global-metadata.dat")
        else:
            managed = glob("*_Data/Managed/Assembly-CSharp*.dll")
            if managed:
                evidence.append("Managed/Assembly-CSharp.dll (Mono)")
            targets += managed
    elif has("engine") and (root / "Engine" / "Binaries").is_dir() or glob("*/Content/Paks/*.pak", 1) or glob("*/Content/Paks/*.utoc", 1):
        engine = "unreal"
        evidence.append("Engine/Binaries or Content/Paks")
        targets += glob("*/Content/Paks/*.pak") + glob("*/Content/Paks/*.utoc") + glob("*/Binaries/Win64/*-Shipping.exe")
    elif glob("*.pck", 1):
        engine = "godot"
        evidence.append("a .pck beside the executable")
        targets += glob("*.pck")
    elif has("data.win"):
        engine = "gamemaker"
        evidence.append("data.win")
        targets.append(str(top["data.win"]))
    elif glob("*/gameinfo.txt", 1) or glob("*/gameinfo.gi", 1) or glob("*/*_dir.vpk", 1):
        engine = "source"
        evidence.append("gameinfo or *_dir.vpk")
        targets += glob("*/*_dir.vpk")
    elif (root / "resources" / "app.asar").is_file() or (root / "resources" / "app").is_dir():
        engine = "electron"
        evidence.append("resources/app.asar")
        targets += glob("resources/app.asar")
    elif has("renpy") and has("game"):
        engine = "renpy"
        evidence.append("renpy/ and game/ folders")
        targets += glob("game/*.rpa")
    elif (root / "www" / "js" / "rpg_core.js").is_file() or (root / "js" / "rmmz_core.js").is_file():
        engine = "rpgmaker"
        evidence.append("rpg_core.js or rmmz_core.js")
    elif glob("archive/pc/content/*.archive", 1):
        engine = "redengine"
        evidence.append("archive/pc/content/*.archive")
        targets += glob("archive/pc/content/*.archive", 6)
    elif glob("Data/*.esm", 1) or glob("Data/*.bsa", 1) or glob("Data/*.ba2", 1):
        engine = "bethesda"
        evidence.append("Data/*.esm, .bsa or .ba2")
    elif glob("*.jar", 1) and not glob("*.exe", 1):
        engine = "java"
        evidence.append("JAR files and no native executable")
        targets += glob("*.jar")
    executables = glob("*.exe", 8)
    if engine is None:
        return {"id": "unknown", "family": "folder", "title": "no engine recognised", "confidence": "none",
                "evidence": ["no engine marker in the top two folder levels"], "details": {},
                "targets": executables, "engine_tools": ["pe-recon", "diec"]}
    title, tools = ENGINES[engine]
    return {"id": engine, "family": "folder", "title": title, "confidence": "high", "evidence": evidence,
            "details": {}, "targets": targets + [e for e in executables if e not in targets], "engine_tools": tools}


# ----------------------------------------------------------------- kit lookup

def find_kit(explicit: str | None = None, here: Path | None = None) -> Path | None:
    """The kit root: an explicit one, the kit this script is in, then the owner pointer."""
    candidates = []
    if explicit:
        candidates.append(Path(explicit))
    # An installed copy (<kit>/sandbox/tools/triage/triage.py) or a source checkout with its own
    # sandbox serves its own kit; the shared pointer only covers a checkout that has no sandbox.
    here = (here or Path(__file__)).resolve()
    if len(here.parents) > 3 and here.parents[1].name.lower() == "tools" and here.parents[2].name.lower() == "sandbox":
        candidates.append(here.parents[3])
    candidates.append(here.parents[1])
    base = os.environ.get("LOCALAPPDATA")
    if base:
        pointer = Path(base, *POINTER)
        try:
            data = json.loads(pointer.read_text(encoding="utf-8-sig"))
            if isinstance(data, dict) and data.get("kit_root"):
                candidates.append(Path(data["kit_root"]))
        except (OSError, ValueError):
            pass
    for root in candidates:
        if (root / "sandbox" / "bin").is_dir():
            return root.resolve()
    return None


def shim_path(kit: Path | None, shim: str) -> Path | None:
    if kit is None:
        return None
    for suffix in (".cmd", ".bat", ".exe", ""):
        candidate = kit / "sandbox" / "bin" / (shim + suffix)
        if candidate.is_file():
            return candidate
    return None


def kit_version(kit: Path | None) -> str | None:
    if kit is None:
        return None
    try:
        return json.loads((kit / "sandbox" / "installed.json").read_text(encoding="utf-8-sig")).get("kit_version")
    except (OSError, ValueError, AttributeError):
        return None


# -------------------------------------------------------------------- running

def launch(shim: Path, arguments: list[str], timeout: float) -> dict:
    """Run one shim with a bounded wait. A .cmd goes through cmd.exe as one finished
    line, delayed expansion off, so a path with spaces, '!' or parentheses arrives whole."""
    started = time.monotonic()
    if os.name == "nt" and shim.suffix.lower() in (".cmd", ".bat"):
        line = subprocess.list2cmdline([str(shim)] + arguments)
        command = '%s /d /v:off /s /c "%s"' % (subprocess.list2cmdline([os.environ.get("COMSPEC", "cmd.exe")]), line)
    else:
        command = [str(shim)] + arguments
    try:
        done = subprocess.run(command, capture_output=True, timeout=timeout, stdin=subprocess.DEVNULL)
        return {"exit": done.returncode, "stdout": done.stdout, "stderr": done.stderr,
                "seconds": round(time.monotonic() - started, 2), "error": None}
    except subprocess.TimeoutExpired as exc:
        return {"exit": None, "stdout": exc.stdout or b"", "stderr": exc.stderr or b"",
                "seconds": round(time.monotonic() - started, 2), "error": "timed out after %gs" % timeout}
    except OSError as exc:
        return {"exit": None, "stdout": b"", "stderr": b"", "seconds": 0.0, "error": str(exc)}


def sha256_of(path: Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def workspace_for(kit: Path | None, target: Path, digest: str | None, explicit: str | None) -> Path | None:
    if explicit:
        return Path(explicit)
    if kit is None:
        return None
    safe = "".join(ch if ch.isalnum() or ch in "-_." else "_" for ch in target.stem)[:48] or "target"
    return kit / "sandbox" / "work" / ("%s-%s" % (safe, (digest or "folder")[:8])) / "triage"


# ---------------------------------------------------------------------- triage

def triage(target: Path, kit: Path | None, run: bool = False, out: str | None = None, timeout: float = 120) -> dict:
    target = target.expanduser().resolve()
    is_dir = target.is_dir()
    digest = None
    notes: list[str] = []
    if is_dir:
        fmt = identify_folder(target)
        names = list(fmt.get("engine_tools") or [])
        primary = Path(fmt["targets"][0]) if fmt.get("targets") else None
        if primary and primary.is_file():
            inner = identify_file(primary)
            fmt["primary_target"] = {"path": str(primary), "format": inner["id"], "title": inner["title"]}
            names += [n for n in FORMATS[inner["id"]][2] if n not in names]
        size = None
    else:
        fmt = identify_file(target)
        names = list(FORMATS[fmt["id"]][2])
        primary = target
        size = target.stat().st_size
        if size > HASH_LIMIT:
            notes.append("file is larger than %d GiB; hashing it takes a while" % (HASH_LIMIT >> 30))
        digest = sha256_of(target)
    if fmt["id"] in ("bethesda", "bethesda-plugin"):
        notes.append("Creation Engine plugins, archives and scripts belong to the game's own forge; this kit covers the native executable and DLLs")

    workspace = workspace_for(kit, target, digest, out)
    analyzers = []
    for name in names:
        purpose, template, quick = ANALYZERS[name]
        shim = shim_path(kit, name)
        subject = str(primary if primary else target)
        arguments = [part.replace("{target}", subject) for part in template]
        entry = {"shim": name, "purpose": purpose, "available": shim is not None,
                 "path": str(shim) if shim else None,
                 "command": ([str(shim)] if shim else [name]) + arguments,
                 "quick": quick, "ran": False}
        runnable = quick and shim is not None and template and not any(a.startswith("<") for a in arguments)
        if run and runnable and primary is not None and Path(subject).is_file():
            result = launch(shim, arguments, timeout)
            entry.update(ran=True, exit=result["exit"], seconds=result["seconds"], error=result["error"])
            if workspace is not None:
                workspace.mkdir(parents=True, exist_ok=True)
                text = result["stdout"].decode("utf-8", errors="replace")
                is_json = text.lstrip().startswith(("{", "["))
                artifact = workspace / ("%s.%s" % (name, "json" if is_json else "txt"))
                artifact.write_text(text, encoding="utf-8", newline="\n")
                entry["artifact"] = str(artifact)
                if result["stderr"].strip():
                    log = workspace / ("%s.stderr.txt" % name)
                    log.write_bytes(result["stderr"])
                    entry["stderr"] = str(log)
            if result["error"] or result["exit"] not in (0, None) and not result["stdout"].strip():
                entry["failed"] = result["error"] or "exit %s with no output" % result["exit"]
        analyzers.append(entry)

    available = [a for a in analyzers if a["available"]]
    next_steps = []
    for entry in analyzers:
        if entry["ran"] and not entry.get("failed"):
            continue
        if entry["available"] and entry["command"][1:]:
            next_steps.append({"why": entry["purpose"], "command": entry["command"]})
    if not available and analyzers:
        notes.append("none of the tools for this format are installed in the kit; "
                     "run Install-Modkit.ps1 -Only %s" % ",".join(a["shim"] for a in analyzers[:4]))
    if kit is None:
        notes.append("no kit was found; pass --kit <root> or install the workbench")
    if fmt["id"] == "unknown":
        notes.append("unrecognised format: start with the hex view and the detection tool, then describe the layout before choosing an extractor")

    report = {
        "schema": 1,
        "tool": "re-triage %s" % VERSION,
        "kit": {"root": str(kit) if kit else None, "version": kit_version(kit)},
        "target": {"path": str(target), "kind": "folder" if is_dir else "file", "bytes": size, "sha256": digest},
        "format": fmt,
        "analyzers": analyzers,
        "next": next_steps[:8],
        "workspace": str(workspace) if workspace else None,
        "notes": notes,
        "ran": [a["shim"] for a in analyzers if a["ran"]],
        "failed": [{"shim": a["shim"], "error": a["failed"]} for a in analyzers if a.get("failed")],
        "executed_target": False,
    }
    if run and workspace is not None:
        workspace.mkdir(parents=True, exist_ok=True)
        (workspace / "triage.json").write_text(json.dumps(report, indent=2), encoding="utf-8", newline="\n")
    return report


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="re-triage", description=__doc__.split("\n\n")[0])
    parser.add_argument("target", help="file or folder to identify")
    parser.add_argument("--run", action="store_true", help="also run the quick read-only analyzers and keep their output")
    parser.add_argument("--out", help="folder for --run output (default: <kit>/sandbox/work/<name>-<hash>/triage)")
    parser.add_argument("--kit", help="kit root (default: the kit this script is installed in, then the owner pointer)")
    parser.add_argument("--timeout", type=float, default=120, help="seconds allowed per analyzer")
    args = parser.parse_args(argv)
    target = Path(args.target)
    if not target.exists():
        print(json.dumps({"schema": 1, "error": "no such file or folder", "target": str(target)}, indent=2))
        return 3
    report = triage(target, find_kit(args.kit), run=args.run, out=args.out, timeout=args.timeout)
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
