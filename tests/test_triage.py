"""Target triage: format detection from bytes, tool routing, and the --run boundary.

Fixtures are built here. The fake kit has stub shims, so the launch path is real
(cmd.exe on Windows) while no analysis tool has to be installed. The folder names
carry a space, '!', parentheses and a non-ASCII letter.
"""
import json
import os
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KIT = ROOT / "kit"
sys.path.insert(0, str(KIT))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import triage  # noqa: E402
from test_pe_recon import make_pe  # noqa: E402

AWKWARD = "!targets (x) é"


def pe_bytes(clr=False, sections=(b".text",), tail=b""):
    """A PE32+ image that is just large enough to be classified."""
    data = bytearray(0x400)
    data[:2] = b"MZ"
    struct.pack_into("<I", data, 0x3C, 0x80)
    data[0x80:0x84] = b"PE\x00\x00"
    struct.pack_into("<HH", data, 0x84, 0x8664, len(sections))
    struct.pack_into("<H", data, 0x94, 240)           # optional header size
    struct.pack_into("<H", data, 0x96, 0x22)          # characteristics
    struct.pack_into("<H", data, 0x98, 0x20B)         # PE32+
    struct.pack_into("<I", data, 0x98 + 108, 16)      # number of data directories
    if clr:
        struct.pack_into("<II", data, 0x98 + 112 + 14 * 8, 0x2000, 72)
    table = 0x98 + 240
    for index, name in enumerate(sections):
        data[table + index * 40: table + index * 40 + len(name)] = name
    return bytes(data) + tail


class Fixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.dir = Path(self.temp.name).resolve() / AWKWARD
        self.dir.mkdir()

    def tearDown(self):
        self.temp.cleanup()

    def write(self, name, data):
        path = self.dir / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return path

    def kit(self, shims=()):
        """A kit root holding stub shims that print their arguments as JSON."""
        root = self.dir / "kit (stub)"
        (root / "sandbox" / "bin").mkdir(parents=True)
        (root / "sandbox" / "installed.json").write_text(json.dumps({"kit_version": "9.9.9"}), encoding="utf-8")
        stub = root / "stub.py"
        stub.write_text(
            "import json, os, sys\n"
            "name = os.environ.get('STUB_NAME', '')\n"
            "if name == 'diec': sys.stderr.write('boom'); sys.exit(4)\n"
            "print(json.dumps({'stub': name, 'args': sys.argv[1:], 'exists': os.path.isfile(sys.argv[-1])}))\n",
            encoding="utf-8")
        for name in shims:
            if os.name == "nt":
                # The stub is addressed through %~dp0, as the kit's own shims are, so no
                # path is written into the batch file in the console code page.
                (root / "sandbox" / "bin" / (name + ".cmd")).write_bytes(
                    ('@echo off\r\nsetlocal DisableDelayedExpansion\r\nset "STUB_NAME=%s"\r\n"%s" "%%~dp0..\\..\\stub.py" %%*\r\nexit /b %%errorlevel%%\r\n'
                     % (name, sys.executable)).encode("ascii"))
            else:
                path = root / "sandbox" / "bin" / name
                path.write_text('#!/bin/sh\nSTUB_NAME=%s exec "%s" "%s" "$@"\n' % (name, sys.executable, stub), encoding="utf-8")
                path.chmod(0o755)
        return root


class FileFormats(Fixture):
    def identify(self, name, data):
        return triage.identify_file(self.write(name, data))

    def test_native_dotnet_packed_and_bundled_pe(self):
        self.assertEqual(self.identify("a.exe", pe_bytes())["id"], "pe-native")
        dotnet = self.identify("b.dll", pe_bytes(clr=True))
        self.assertEqual(dotnet["id"], "pe-dotnet")
        self.assertIn("CLR runtime header is present", dotnet["evidence"])
        self.assertEqual(self.identify("c.exe", pe_bytes(sections=(b"UPX0", b"UPX1")))["id"], "pe-upx")
        self.assertEqual(self.identify("d.exe", pe_bytes(tail=b"x" * 64 + b"MEI\x0c\x0b\x0a\x0b\x0e" + b"y" * 32))["id"], "pe-pyinstaller")
        self.assertEqual(self.identify("e.exe", pe_bytes(tail=b""))["details"]["bits"], 64)

    def test_the_strict_parser_fixture_is_native(self):
        self.assertEqual(self.identify("strict.exe", bytes(make_pe()))["id"], "pe-native")

    def test_mz_without_pe_is_not_called_a_pe(self):
        result = self.identify("dos.exe", b"MZ" + b"\x00" * 0x3A + struct.pack("<I", 0x80) + b"\x00" * 0x100)
        self.assertEqual(result["id"], "unknown")
        self.assertIn("MZ stub", result["evidence"][0])

    def test_truncated_pe_does_not_raise(self):
        self.assertEqual(self.identify("cut.exe", pe_bytes()[:0x90])["id"], "unknown")

    def test_magic_table(self):
        cases = {
            "lib.so": (b"\x7fELF\x02\x01" + b"\x00" * 32, "elf"),
            "app": (b"\xcf\xfa\xed\xfe" + b"\x00" * 32, "macho"),
            "fat": (b"\xca\xfe\xba\xbe\x00\x00\x00\x02" + b"\x00" * 32, "macho"),
            "Main.class": (b"\xca\xfe\xba\xbe\x00\x00\x00\x41" + b"\x00" * 32, "java-class"),
            "m.wasm": (b"\x00asm\x01\x00\x00\x00", "wasm"),
            "classes.dex": (b"dex\n035\x00" + b"\x00" * 32, "dex"),
            "data.unity3d": (b"UnityFS\x00" + b"\x00" * 32, "unityfs"),
            "global-metadata.dat": (b"\xaf\x1b\xb1\xfa" + b"\x00" * 32, "il2cpp-metadata"),
            "game.pck": (b"GDPC" + b"\x00" * 32, "godot-pck"),
            "data.win": (b"FORM\x00\x00\x00\x00GEN8", "gamemaker"),
            "pak01_dir.vpk": (b"\x34\x12\xaa\x55" + b"\x00" * 32, "source-vpk"),
            "map.bsp": (b"VBSP" + b"\x00" * 32, "source-bsp"),
            "t.dds": (b"DDS " + b"\x00" * 32, "dds"),
            "x.7z": (b"7z\xbc\xaf\x27\x1c" + b"\x00" * 8, "7z"),
            "s.luac": (b"\x1bLua\x54" + b"\x00" * 8, "lua-bytecode"),
            "Skyrim.esm": (b"TES4" + b"\x00" * 32, "bethesda-plugin"),
            "pakchunk0.utoc": (b"-==--==--==--==-" + b"\x00" * 16, "unreal-iostore"),
        }
        for name, (data, expected) in cases.items():
            with self.subTest(name=name):
                self.assertEqual(self.identify(name, data)["id"], expected)

    def test_unreal_pak_confidence_follows_the_footer(self):
        real = self.identify("game.pak", b"\x00" * 256 + b"\xe1\x12\x6f\x5a" + b"\x00" * 40)
        self.assertEqual((real["id"], real["confidence"]), ("unreal-pak", "high"))
        named = self.identify("other.pak", b"\x01" * 256)
        self.assertEqual((named["id"], named["confidence"]), ("unreal-pak", "medium"))

    def test_zip_family_is_told_apart_by_content(self):
        def zipped(name, members):
            path = self.dir / name
            with zipfile.ZipFile(path, "w") as archive:
                for member in members:
                    archive.writestr(member, b"x")
            return triage.identify_file(path)["id"]

        self.assertEqual(zipped("a.apk", ["AndroidManifest.xml", "classes.dex"]), "apk")
        self.assertEqual(zipped("b.jar", ["META-INF/MANIFEST.MF", "a/B.class"]), "jar")
        self.assertEqual(zipped("renamed.bin", ["readme.txt"]), "zip")

    def test_unknown_bytes_say_so_with_the_first_bytes(self):
        result = self.identify("mystery.bin", b"\x01\x02\x03\x04ZZZZ" + b"\x00" * 64)
        self.assertEqual((result["id"], result["confidence"]), ("unknown", "none"))
        self.assertIn("0102030", result["evidence"][0])


class Folders(Fixture):
    def game(self, files):
        root = self.dir / "Game (GOTY)!"
        for name in files:
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(pe_bytes() if name.lower().endswith((".exe", ".dll")) else b"\x00" * 8)
        return triage.identify_folder(root)

    def test_unity_il2cpp_points_at_the_two_files_the_dumper_needs(self):
        result = self.game(["Game.exe", "UnityPlayer.dll", "GameAssembly.dll",
                            "Game_Data/il2cpp_data/Metadata/global-metadata.dat"])
        self.assertEqual(result["id"], "unity-il2cpp")
        names = [Path(t).name for t in result["targets"]]
        self.assertEqual(names[:2], ["GameAssembly.dll", "global-metadata.dat"])
        self.assertIn("il2cppdumper", result["engine_tools"])

    def test_unity_mono_points_at_the_managed_assembly(self):
        result = self.game(["Game.exe", "UnityPlayer.dll", "Game_Data/Managed/Assembly-CSharp.dll"])
        self.assertEqual(result["id"], "unity-mono")
        self.assertEqual(Path(result["targets"][0]).name, "Assembly-CSharp.dll")

    def test_other_engines(self):
        cases = {
            "unreal": ["Game/Content/Paks/pakchunk0.pak", "Game/Binaries/Win64/Game-Win64-Shipping.exe"],
            "godot": ["game.exe", "game.pck"],
            "gamemaker": ["runner.exe", "data.win"],
            "source": ["hl2.exe", "mod/gameinfo.txt", "mod/pak01_dir.vpk"],
            "electron": ["app.exe", "resources/app.asar"],
            "redengine": ["bin/x64/Game.exe", "archive/pc/content/basegame.archive"],
            "bethesda": ["SkyrimSE.exe", "Data/Skyrim.esm"],
        }
        for engine, files in cases.items():
            with self.subTest(engine=engine):
                self.tearDown()
                self.setUp()
                self.assertEqual(self.game(files)["id"], engine)

    def test_a_plain_folder_is_unknown_and_lists_its_executables(self):
        result = self.game(["tool.exe", "readme.txt"])
        self.assertEqual(result["id"], "unknown")
        self.assertEqual(Path(result["targets"][0]).name, "tool.exe")


class Routing(Fixture):
    def test_report_names_tools_and_marks_what_is_installed(self):
        target = self.write("a (1).exe", pe_bytes())
        kit = self.kit(["pe-recon", "rz-bin"])
        report = triage.triage(target, kit)
        by_name = {a["shim"]: a for a in report["analyzers"]}
        self.assertTrue(by_name["pe-recon"]["available"])
        self.assertFalse(by_name["capa"]["available"])
        self.assertEqual(by_name["pe-recon"]["command"][-1], str(target))
        self.assertEqual(report["kit"]["version"], "9.9.9")
        self.assertEqual(len(report["target"]["sha256"]), 64)
        self.assertFalse(report["executed_target"])
        self.assertFalse(report["ran"], "nothing runs without --run")
        self.assertFalse((kit / "sandbox" / "work").exists(), "nothing is written without --run")

    def test_run_keeps_output_and_survives_a_failing_tool(self):
        target = self.write("a (1).exe", pe_bytes())
        kit = self.kit(["pe-recon", "diec", "rz-bin", "capa"])
        report = triage.triage(target, kit, run=True, timeout=60)
        self.assertEqual(report["ran"], ["pe-recon", "diec", "rz-bin"], "only quick analyzers run; capa is offered, not run")
        self.assertEqual([f["shim"] for f in report["failed"]], ["diec"])
        workspace = Path(report["workspace"])
        self.assertTrue(str(workspace).startswith(str(kit / "sandbox" / "work")))
        recon = json.loads((workspace / "pe-recon.json").read_text(encoding="utf-8"))
        self.assertTrue(recon["exists"], "the target path reached the tool intact: %s" % recon["args"])
        self.assertEqual(recon["args"][-1], str(target))
        self.assertEqual((workspace / "diec.stderr.txt").read_text(encoding="utf-8"), "boom")
        saved = json.loads((workspace / "triage.json").read_text(encoding="utf-8"))
        self.assertEqual(saved["target"]["sha256"], report["target"]["sha256"])
        self.assertTrue(any(step["command"][0].endswith(("capa.cmd", "capa")) for step in report["next"]))

    def test_no_kit_still_identifies_and_says_what_is_missing(self):
        report = triage.triage(self.write("lib.so", b"\x7fELF\x02\x01" + b"\x00" * 64), None)
        self.assertEqual(report["format"]["id"], "elf")
        self.assertTrue(all(not a["available"] for a in report["analyzers"]))
        self.assertTrue(any("no kit was found" in note for note in report["notes"]))

    def test_folder_report_adds_the_tools_for_its_primary_file(self):
        root = self.dir / "Game"
        (root / "Game_Data" / "Managed").mkdir(parents=True)
        (root / "UnityPlayer.dll").write_bytes(pe_bytes())
        (root / "Game_Data" / "Managed" / "Assembly-CSharp.dll").write_bytes(pe_bytes(clr=True))
        report = triage.triage(root, self.kit(["ilspycmd"]))
        self.assertEqual(report["format"]["id"], "unity-mono")
        self.assertEqual(report["format"]["primary_target"]["format"], "pe-dotnet")
        self.assertEqual(report["analyzers"][0]["shim"], "ilspycmd")
        self.assertEqual(report["target"]["kind"], "folder")

    def test_every_format_routes_to_known_analyzers(self):
        for fmt, (_family, _title, names) in triage.FORMATS.items():
            for name in names:
                self.assertIn(name, triage.ANALYZERS, "%s names an analyzer with no entry: %s" % (fmt, name))
        for engine, (_title, names) in triage.ENGINES.items():
            for name in names:
                self.assertIn(name, triage.ANALYZERS, "%s names an analyzer with no entry: %s" % (engine, name))

    def test_every_analyzer_is_a_shim_the_catalog_ships(self):
        catalog = json.loads((ROOT / "catalog" / "tools.json").read_text(encoding="utf-8"))
        shims = {shim["name"] for tool in catalog["tools"] for shim in tool.get("shims", [])}
        missing = sorted(set(triage.ANALYZERS) - shims)
        self.assertEqual(missing, [], "triage routes to shims the catalog does not install")


class CommandLine(Fixture):
    def run_cli(self, *args):
        return subprocess.run([sys.executable, str(KIT / "triage.py"), *args], capture_output=True, text=True,
                              encoding="utf-8", errors="replace", timeout=120)

    def test_json_on_stdout_and_exit_codes(self):
        target = self.write("a.exe", pe_bytes())
        done = self.run_cli(str(target), "--kit", str(self.kit(["pe-recon"])))
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertEqual(json.loads(done.stdout)["format"]["id"], "pe-native")
        missing = self.run_cli(str(self.dir / "absent.exe"))
        self.assertEqual(missing.returncode, 3)
        self.assertEqual(json.loads(missing.stdout)["error"], "no such file or folder")

    @unittest.skipUnless(os.name == "nt", "system binary")
    def test_real_system_binary(self):
        notepad = Path(os.environ.get("WINDIR", r"C:\Windows")) / "System32" / "notepad.exe"
        if not notepad.is_file():
            self.skipTest("notepad.exe not available")
        report = json.loads(self.run_cli(str(notepad), "--kit", str(self.kit())).stdout)
        self.assertEqual(report["format"]["id"], "pe-native")
        self.assertEqual(report["format"]["details"]["bits"], 64)


if __name__ == "__main__":
    unittest.main(verbosity=2)
