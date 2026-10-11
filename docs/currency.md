# What is in the kit, and what was left out

The installer resolves the current official release at install time. This page is the cut list. It names projects, not pins, except where the pin itself is the thing being rejected.

## Installed on purpose

- Ghidra's current public release, with JDK 25. Headless is `analyzeHeadless`.
- ImHex's Windows portable x64 zip. Not the NoGPU build, not the arm64 build, not the MSI.
- Detect It Easy's win64 portable zip from `horsicq/DIE-engine`. `diec` is the CLI. `detectiteasy.com` is not an official download.
- x64dbg's current snapshot zip, the x64 debugger. Not the symbols zip.
- PE-bear's Qt 6 x64 Windows zip.
- dnSpyEx's `dnSpy-net-win64` zip. Not the .NET Framework build.
- ILSpy's self-contained Windows x64 zip, plus the [`ilspycmd` dotnet tool](https://www.nuget.org/packages/ilspycmd). Current ilspycmd 11.1 targets .NET 10; its installer checks for the SDK/runtime and uses the official `Microsoft.DotNet.SDK.10` winget package when absent. Older UABS .NET prerequisites alone do not satisfy this tool.
- AssetRipper's Windows x64 zip.
- Il2CppDumper's Windows zip (`Il2CppDumper-win-`), not the net6 or net7 framework-dependent zips.
- FModel's current zip.
- repak and retoc Windows x64 CLI zips. repak is `.pak`. retoc is IoStore. Neither replaces the other.
- UAssetGUI's published exe, and the current DirectXTex `texconv`, `texassemble` and `texdiag` exes. Not the arm64 exes.
- UABEA's Windows zip. That is the Unity asset editor that still publishes a binary.
- BepInEx 5's current Windows x64 release, for Mono games.
- MelonLoader's current x64 zip, for Mono and IL2CPP.
- UnityExplorer builds from the yukieiji fork: BepInEx 5 Mono, BepInEx 6 Mono, and MelonLoader IL2CPP. Those are plugins, not loaders.
- UE4SS from the `experimental-latest` release, asset `UE4SS_*.zip` only. Not `zDEV`, not `zCustomGameConfigs`, not `zMapGenBP`.
- RenderDoc's stable portable x64 zip from `renderdoc.org`, using the version of the current GitHub release tag. Not the nightly. Not the MSI.
- MinHook's bin zip, for C. SafetyHook's amalgamated Zydis sources, for new C++.
- Frida tools in a venv under `sandbox/tools/frida`.
- [JADX](https://github.com/skylot/jadx)'s cross-platform `jadx-<version>.zip`, containing both CLI and GUI batch launchers. The separate Windows GUI zip would omit the CLI. Upstream requires Java 11+; this kit shares its JDK 25. Apache-2.0.
- [capa](https://github.com/mandiant/capa)'s official `flare-capa` Python package in its own venv, Python 3.10+. [Released capability rules](https://github.com/mandiant/capa-rules) install as `capa-rules`; capa's release source archive installs as `capa-source` to supply `sigs/`. Both dependencies install even with `-Only capa`; the shim supplies `-r` and `-s` with those directories. The source archive does not include the separate malware testfiles submodule. This follows the [upstream package installation route](https://github.com/mandiant/capa/blob/master/doc/installation.md), rather than using the packed standalone executable. capa and its rules are Apache-2.0. Matches are leads to confirm, not proof that code executes a behavior.
- [Kaitai Struct compiler](https://github.com/kaitai-io/kaitai_struct_compiler)'s universal `kaitai-struct-compiler-<version>.zip`, including the Windows batch launcher. Upstream requires Java 8+; this kit shares its JDK 25. GPL-3.0-or-later compiler; generated parsers need the target language's separate runtime with its own license.
- [pyinstxtractor-ng](https://github.com/pyinstxtractor/pyinstxtractor-ng)'s standalone Windows `pyinstxtractor-ng.exe`. No local Python installation or matching target Python version is required for extraction. Decompiling extracted bytecode is a separate, version-dependent task. GPL-3.0.
- [wasm-tools](https://github.com/bytecodealliance/wasm-tools)'s `wasm-tools-<version>-x86_64-windows.zip`. One self-contained CLI for inspection, validation, text/binary conversion and component work. Triple licensed under Apache-2.0, Apache-2.0 with LLVM exception, and MIT.
- [Apktool](https://github.com/iBotPeaches/Apktool)'s `apktool_<version>.jar`, stored without extraction and launched with `java -jar`. Java 8+ is confirmed by the [v3.0.3 build configuration](https://github.com/iBotPeaches/Apktool/blob/v3.0.3/build.gradle.kts) and the released JAR's Java 8 class version; this kit shares its JDK 25. Apache-2.0. See the current [decode/build CLI options](https://apktool.org/docs/cli-parameters/); Android signing and device tools are separate.
- [Electron ASAR](https://github.com/electron/asar)'s `@electron/asar` npm package under `sandbox/tools/asar`, without lifecycle scripts or a global installation. Node 22.12+ and npm are required. MIT.
- [LIEF](https://github.com/lief-project/LIEF)'s `lief` Python package in its own venv under `sandbox/tools/lief`. Python 3.9+ is required. Use that environment's Python to import the library; there is no LIEF CLI shim. Apache-2.0.
- Frosty Editor and Frosty Mod Manager from the current stable release (`FrostyEditor.zip` and `FrostyModManager.zip`). Not the bundled prereq installers. Those stay inside the unpacked zip and are not shims.
- Godot's current stable mono win64 zip. The shim is the console executable. Not the win32 zip, not the arm64 zip, not the non-mono `.exe.zip`.
- GDRE Tools' Windows zip, for packed Godot games.
- IKEMEN Go's Windows zip. Not the Android, Linux, or macOS zips.
- Pixelorama's Windows 64-bit zip. Not the 32-bit zip and not the setup exe.
- 7-Zip's current x64 MSI. `msiexec /a` extracts it into `sandbox/tools/7zip`. It is not installed for the machine. Not the arm64 build, not the 32-bit package, not the exe installer. `7z.exe` plus `7z.dll` is what unpacks the two tools below.
- LDtk's current Windows installer. 7-Zip extracts the 64-bit `app-64.7z` payload only. The installer is not executed. Not the 32-bit payload, not the macOS or Ubuntu zips.
- OpenBOR's current Windows rar. Not the Android apk and not the Linux AppImages.
- Fighter Factory's current official Windows portable zip. The download page is read at install time and the first Windows portable topic is the one that is downloaded. The shim is x64 `ffs.exe`. Not `ffs.qt4.exe`, not the 32-bit build, and not the installer topic.
- HD2Runtime's current SDK, runtime, example projects, and mod template zips, as four separate tools. HD2Runtime ModBuilder's current Windows x64 zip. The shim is `HD2RuntimeModBuilder.exe`, not the `HD2RuntimeGUI.exe` compatibility copy. The community SDK zip. Bingus Shared Loader's loader zip, not its source zip.
- R2API source for the current release tag. That repository publishes source, not a bench executable.
- Sleeping Dogs TheoryEngine source, SDK source (the repository's default branch), and the SDK playground examples. These trees contain no game executable.

## Left out

- `assetstudio`: the AssetStudio repository is archived. Use `assetripper`.
- `dnspy`: the original dnSpy repository is archived. Use `dnspyex`.
- `uabe`: original UABE is unsupported. Use `uabea`. UABEANext is the active source tree and publishes no release binary, so it is not unpacked.
- `umodel-ue4`: [UE Viewer / UModel](https://www.gildor.org/en/projects/umodel) supports older Unreal engines and many UE4 games. It remains a manual, target-specific route; `fmodel`, `repak` and `retoc` are this kit's modern defaults. The official page says its license is not determined, so the kit does not redistribute it or label it unsupported across UE4.
- `cpp2il-2022-binary`: Cpp2IL's latest stable binary is 2022.0.7, but [2022.1.0-pre-release.21](https://github.com/SamboyCoding/Cpp2IL/releases/tag/2022.1.0-pre-release.21) published Windows binaries on 2026-02-22. Its version prefix is not its publication year. Keep `il2cppdumper` as the automatic default; the current Cpp2IL preview is a manual alternative for targets needing its newer metadata support.
- `ue4ss-stable`: the stable UE4SS tag lags the experimental release. The kit installs `ue4ss` from `experimental-latest`.
- `bepinex6-pre2`: BepInEx 6.0.0-pre.2 is an old prerelease. Mono games get current BepInEx 5. IL2CPP gets current MelonLoader. The UnityExplorer BepInEx 6 plugin is included for a game that already has that loader.
- `cheat-engine-download`: the Cheat Engine GitHub release ships no Windows binary. The website installer bundles offers. The kit does not download it. A portable copy can be placed in `sandbox/manual/cheat-engine/` by hand.
- `reclass-rar`: ReClass.NET's only published binary is the 2019 v1.2 rar. The source kept changing through 2024 and published no newer binary. The kit can unpack a current rar. This one is stale. A portable copy can be placed in `sandbox/manual/reclass/` by hand.
- `3dmigoto-tag`: the tagged 3Dmigoto release is from 2018, the repository has continued, and that one release attaches every historical zip. A pattern cannot select a single current file. It is not part of the one-click set.
- `sinai-unityexplorer`: `sinai-dev/UnityExplorer` is archived. The kit uses the yukieiji builds.
- `frosty-rewrite`: `FrostyToolsuite/FrostyToolsuite` publishes no release. Use `frosty-editor` and `frosty-modmanager`.
- `ldtk-installer`: the old id for LDtk's installer. The installed tool is `ldtk`.
- `openbor-rar`: the old id for OpenBOR's rar. The installed tool is `openbor`.
- `fighter-factory-installer`: the old id for the dump's installer. The installed tool is `fighter-factory`.

Also not unpacked, because they install into their own directories or are not redistributable here: ReShade, NVIDIA Nsight, PIX, RTX Remix, and paid shader packs.

The Sleeping Dogs game executable and its PDB are not downloaded. TheoryEngine's README points at a file host for "Game Executable" and "Debug Symbols (PDB)". Those are the game, not a tool. The public GitHub source trees are what the kit installs.

The dump's other new folders are not a second kit. `GoDot/LimboAi` is another Godot editor build, not the LimboAI addon. IKEMEN Forge is a Claude Code plugin (`nategarelik/ikemen-forge`), not a bench executable. `UE-Modding-Tools` is a link list: the commonly used packers are already `repak`, `retoc`, FModel and UAssetGUI. ZenTools is deprecated upstream in favor of retoc. kismet-analyzer publishes no release binary. QuickBMS and the old UnrealPak rar are not unpacked.

Helldivers 2's public runtime, SDKs, ModBuilder, and loader are installed. Sleeping Dogs TheoryEngine, its SDK, and the SDK playground are installed from their public source archives. R2API is installed from the current release tag's source archive. None of those downloads include a game executable.

Duplicate trees of the same UE4SS build (`zDEV` next to the release) are not installed. One copy is enough.

## Coverage audit, 2026-10-11

The eight app/format additions above fill gaps in the existing game-oriented catalog; capa also adds rules and signature-source dependencies. Their official latest releases/packages were checked: JADX v1.5.6 (2026-07-10), flare-capa 9.4.0 with capa/capa-rules v9.4.0 (2026-04-01), Kaitai 0.11 (2025-09-07), pyinstxtractor-ng 2026.07.03, wasm-tools v1.261.0 (2026-10-02), Apktool v3.0.3 (2026-07-20), Electron ASAR 4.3.1 on npm, and LIEF 1.0.0 on PyPI. The asset fixture records the five GitHub tools' exact binary/JAR filenames; capa rules and signatures use release source archives. These are dated observations, not permanent version pins or runtime certification.

The [coverage map](coverage.md) separates installed tools from optional/manual routes. Universal Modder provides workflows and the Starter Bundle provides agent tooling; neither makes every reverse-engineering binary present. The current Starter Bundle already includes `um`, so no second Universal Modder install is needed through this kit.
