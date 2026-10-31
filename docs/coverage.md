# Coverage and remaining routes

Reverse THIS! supplies local analysis tools. [Universal Modder](https://github.com/rehan-remade/universal-modder) supplies the game workflow and field notes. [Ultimate AI Starter Bundle](https://github.com/SenjuWoo/Ultimate-AI-Starter-Bundle) supplies provider setup, skills and scoped MCPs, and already includes `um` and the shared Universal Modder skill. Reuse those instead of registering duplicate plugins or fal servers. This installer does not edit provider configuration or trust.

The catalog is an install plan; `sandbox/installed.json` records what a run installed. A successful install proves neither target compatibility nor a working modification. Verify the chosen command and then one small target change.

## Included routes

| Target or job | Included tools | Limit to verify |
|---|---|---|
| Native PE, ELF and other supported executable formats | Ghidra, Detect It Easy, ImHex, PE-bear, capa | Decompiled C is an approximation; symbols, types and build details may be absent. Confirm capability-rule matches. |
| Windows debugging and instrumentation | x64dbg, Frida, MinHook, SafetyHook | Architecture and target version matter; hooks require target-specific evidence. |
| .NET and Unity Mono | ILSpy, ilspycmd, dnSpyEx, BepInEx 5 | Current [ilspycmd](https://www.nuget.org/packages/ilspycmd) targets .NET 10; the installer provisions its SDK when absent, including on UABS setups with only older .NET versions. Obfuscation, runtime changes and missing dependencies can prevent a rebuild. |
| Unity IL2CPP and assets | Il2CppDumper, AssetRipper, UABEA, MelonLoader, UnityExplorer variants | Metadata does not recover native method bodies. Choose plugins for the actual loader/runtime. |
| Android DEX/APK, Java bytecode | JADX CLI and GUI; Apktool | Source reconstruction is incomplete in some cases. Apktool decodes/rebuilds resources and smali; signing and device tooling are separate. |
| PyInstaller-packaged Python | pyinstxtractor-ng | Extracts files and bytecode. It does not guarantee Python source decompilation or support arbitrary Nuitka/native extensions. |
| Electron archives | Electron ASAR (`asar`) | Lists, extracts and repacks archives. Minification, absent source maps, native modules and app integrity/signatures need separate work. |
| WebAssembly | wasm-tools | Inspect, validate, assemble and disassemble modules/components; this does not recreate original source or build tooling. |
| Programmable PE/ELF/Mach-O parsing and patching | LIEF Python library | Use the isolated `sandbox/tools/lief/Scripts/python.exe`; this library has no CLI shim. Verify modified files before running them. |
| Undocumented binary formats | ImHex, Kaitai Struct compiler | Write and validate a format specification; generated parsers need a language runtime. Kaitai is not an automatic format detector. |
| Generic archives | 7-Zip | Proprietary packing and custom compression can require a format-specific tool. |
| Unreal, Godot, Frostbite | FModel, repak, retoc, UAssetGUI, UE4SS; GDRE and Godot; Frosty tools | Check engine/game versions. A source archive or loader is not a supported executable for every game. |
| Graphics and textures | RenderDoc, DirectXTex | API/driver support and capture compatibility vary; this is not every vendor's profiling suite. |
| Binary comparison | Ghidra Version Tracking, ImHex, `rz-diff` | Compare the same architecture and record target hashes; generated names are not stable identifiers. |
| Packed executables | UPX | Only UPX-packed files unpack cleanly; other packers need their own unpacker. |
| Stripped Go binaries | GoReSym | Symbol and build-info recovery depends on the Go version and build flags. |
| Rule-based scanning | YARA (`yara`, `yarac`) | Rules are yours to write; a match is a lead, not proof of behavior. |
| Import and dependency view | Dependencies (CLI and GUI) | Resolution can differ from what the loader does at runtime. |
| Live process, handle and module inspection | System Informer | Needs the same privilege as the target; kernel protections can block it. |
| Obfuscated or runtime strings | FLOSS | Recovered strings can be decoys; emulation may not reach every code path. |
| Scripted native analysis | Rizin (`rizin`, `rz-bin`, `rz-diff`, `rz-asm`) | Command syntax differs from radare2; check the installed version's help. |
| JVM decompilation, second opinion | Vineflower | Compare with JADX output; neither restores the original source. |
| APK signing | uber-apk-signer | You supply the key; a debug key is not a release identity. |
| Scripted Unity asset work | UnityPy | Type trees are Unity-version specific; this is a library, not a GUI. |
| Source models and maps | Crowbar, BSPSource | Format and game support vary; materials and mounts are separate. |
| Source 2 assets | Source 2 Viewer (GUI and CLI) | Supports current VPK/resource versions; not every resource type exports. |
| REDengine archives and assets | WolvenKit (GUI and CLI) | Game-version support and archive format changes matter. |
| FromSoftware mods | Mod Engine 2, Smithbox | Per-game offsets and regulation versions; online/anti-cheat use is out of scope. |
| GameMaker games | UndertaleModTool (GUI and CLI) | `data.win` version support varies; not every runner build is covered. |
| Total War packs | RPFM | Schemas are per game; verify the pack version before writing. |
| App behavior recon and clean-room rebuild | replica-skill (`replica-recon`, `-diff`, `-test`, others) | MIT Claude skills with stdlib Python helpers. They work from public pages, screenshots and your own account; they do not analyze binaries. The installer resolves the current default branch to a full immutable commit, records that archive identity and its SHA-256, and reuses the recorded version with `-NoUpdate`; review the selected source before use. Rebuilding features is not a licence to copy code, assets or branding. |

The game-specific SDKs, fighting-game tools and art editors remain in the catalog. They do not extend generic app decompilation. Bethesda and Skyrim tooling is owned by [Skyrim Forge](https://github.com/SenjuWoo/SkyrimForge); this kit does not duplicate xEdit, LOOT or the Creation Kit.

## Added tool sources and runtimes

| Tool | Primary upstream | Runtime and license |
|---|---|---|
| JADX | [skylot/jadx](https://github.com/skylot/jadx) | Apache-2.0; Java 11+ upstream, JDK 25 shared by this kit. |
| capa | [mandiant/capa](https://github.com/mandiant/capa), [installation guide](https://github.com/mandiant/capa/blob/master/doc/installation.md), [released rules](https://github.com/mandiant/capa-rules) | Apache-2.0 code and rules; `flare-capa` in a venv requires Python 3.10+. Released rules install as `capa-rules` and the signature-bearing release source archive as `capa-source`, including with `-Only capa`. The shim supplies both paths; the separate malware testfiles submodule is not downloaded. |
| Kaitai compiler | [kaitai-io/kaitai_struct_compiler](https://github.com/kaitai-io/kaitai_struct_compiler), [runtime licenses](https://kaitai.io/#licensing) | GPL-3.0-or-later compiler; Java 8+ upstream, JDK 25 shared here. Generated parsers need the selected language runtime under its own license. |
| pyinstxtractor-ng | [pyinstxtractor/pyinstxtractor-ng](https://github.com/pyinstxtractor/pyinstxtractor-ng) | GPL-3.0; standalone executable, no matching target Python version needed for extraction. |
| wasm-tools | [bytecodealliance/wasm-tools](https://github.com/bytecodealliance/wasm-tools) | Triple licensed under Apache-2.0, Apache-2.0 with LLVM exception, and MIT; standalone Windows x64 zip. |
| Apktool | [iBotPeaches/Apktool](https://github.com/iBotPeaches/Apktool), [installation guide](https://apktool.org/docs/install/), [decode/build options](https://apktool.org/docs/cli-parameters/) | Apache-2.0; Java 8+ confirmed for v3.0.3, JDK 25 shared here. Supply Android framework files if the target needs them. Case-distinct APK paths need a case-sensitive work directory; the installer does not change that Windows setting. |
| Electron ASAR | [electron/asar](https://github.com/electron/asar) | MIT; `@electron/asar` requires Node 22.12+ and npm. Local prefix with package lifecycle scripts disabled. |
| LIEF | [lief-project/LIEF](https://github.com/lief-project/LIEF), [Python package metadata](https://pypi.org/project/lief/) | Apache-2.0; Python 3.9+ in a separate venv. Use the installed version's API. |
| UPX | [upx/upx](https://github.com/upx/upx) | GPL-2.0-or-later with the UPX special exception; standalone Windows x64 zip. |
| YARA | [VirusTotal/yara](https://github.com/VirusTotal/yara) | BSD-3-Clause; standalone Windows x64 zip with `yara64` and `yarac64`. |
| GoReSym | [mandiant/GoReSym](https://github.com/mandiant/GoReSym) | MIT; standalone Windows executable. |
| Dependencies | [lucasg/Dependencies](https://github.com/lucasg/Dependencies) | MIT; x64 release zip with CLI and GUI. |
| Rizin | [rizinorg/rizin](https://github.com/rizinorg/rizin) | LGPL-3.0; static Windows x64 zip. |
| System Informer | [winsiderss/systeminformer](https://github.com/winsiderss/systeminformer) | MIT; portable bin zip, amd64 tree. |
| FLOSS | [mandiant/flare-floss](https://github.com/mandiant/flare-floss) | Apache-2.0; `flare-floss` in a venv, Python 3.10+. |
| UnityPy | [K0lb3/UnityPy](https://github.com/K0lb3/UnityPy) | MIT; `UnityPy` in a venv, Python 3.8+. |
| Vineflower | [Vineflower/vineflower](https://github.com/Vineflower/vineflower) | Apache-2.0; JAR, Java 17+, JDK 25 shared here. |
| uber-apk-signer | [patrickfav/uber-apk-signer](https://github.com/patrickfav/uber-apk-signer) | Apache-2.0; JAR, Java 8+, JDK 25 shared here. |
| WolvenKit | [WolvenKit/WolvenKit](https://github.com/WolvenKit/WolvenKit) | GPL-3.0; self-contained Windows zip for GUI and CLI. |
| Mod Engine 2 | [soulsmods/ModEngine2](https://github.com/soulsmods/ModEngine2) | MIT; Windows x64 zip. |
| Smithbox | [vawser/Smithbox](https://github.com/vawser/Smithbox) | MIT; self-contained Windows zip. |
| Crowbar | [ZeqMacaw/Crowbar](https://github.com/ZeqMacaw/Crowbar) | CC BY-SA 3.0; 7-Zip archive containing `Crowbar.exe`. |
| BSPSource | [ata4/bspsrc](https://github.com/ata4/bspsrc) | Public domain; JAR-only zip, Java 24+, JDK 25 shared here. |
| Source 2 Viewer | [ValveResourceFormat/ValveResourceFormat](https://github.com/ValveResourceFormat/ValveResourceFormat) | MIT; single-file GUI exe and Windows x64 CLI zip. |
| UndertaleModTool | [UnderminersTeam/UndertaleModTool](https://github.com/UnderminersTeam/UndertaleModTool) | GPL-3.0; self-contained Windows GUI and CLI zips. |
| RPFM | [Frodo45127/rpfm](https://github.com/Frodo45127/rpfm) | MIT; Windows x64 zip with `rpfm_ui.exe`. |

Selecting `capa`, `capa-rules` or `capa-source` for installation updates the entire matched capa group in one transaction. Plan and Doctor still list/check the individual catalog entries.

`Install-Modkit.ps1 -Doctor` checks records and required files. It does not import every library or prove target compatibility. For LIEF, run `.\sandbox\tools\lief\Scripts\python.exe -c "import lief; print(lief.__version__)"` and then a small parse on a copied target. Java, Python, .NET and Node prerequisites on the host do not automatically become available in a Windows Sandbox guest.

Installer diagnostics are in `sandbox/log/modkit.log`; `-DebugLog` enables detailed package/archive output. Updates retain previous payloads in `sandbox/backups` and save a pre-update manifest. Keep the rollback copy until the new tool works on your target.

## Optional routes, not installed by this kit

These are primary upstream entry points checked on 2026-10-11. Resolve current versions and prerequisites before use. Put portable files under `sandbox/manual/<name>` or use a project-local environment. Do not assume a shim exists.

| Gap | Upstream route | Setup and scope |
|---|---|---|
| Android signing and device debugging | [Android SDK Build Tools](https://developer.android.com/tools/releases/build-tools), [SDK Platform Tools](https://developer.android.com/tools/releases/platform-tools) | `uber-apk-signer` covers signing and zipalignment. The separate SDK is still needed for `adb`, device work and Google's own `apksigner`; licenses apply. |
| Newer Unity IL2CPP metadata or a second analysis route | [Cpp2IL preview 2022.1.0-pre-release.21](https://github.com/SamboyCoding/Cpp2IL/releases/tag/2022.1.0-pre-release.21) | MIT; preview binaries published 2026-02-22 include a Windows EXE and .NET Framework 4.7.2 ZIP. Choose the correct architecture/runtime and verify target metadata support. No preview is automatically installed. |
| Source 2 tools not covered by the viewer | [Source 2 SDK / ValveResourceFormat source](https://github.com/ValveResourceFormat/ValveResourceFormat) | Build from source when a resource type or game version is newer than the released binaries. |
| RE Engine mods | [REFramework](https://github.com/praydog/REFramework) | MIT; releases are one ZIP per game (RE2, RE3, RE4, RE7, RE8, DD2, MH Wilds, SF6 and others). Pick the game's asset; a single pattern cannot select all of them. |
| GTA V modding | [CodeWalker](https://github.com/dexyfex/CodeWalker) | The repository publishes no GitHub release. Use the author's published build; verify its provenance. |
| Rizin GUI | [Cutter](https://github.com/rizinorg/cutter) | GPL-3.0; the `Cutter-v*-Windows-x86_64.zip` GUI over the installed `rizin` CLI. Optional when Ghidra already covers GUI analysis. |
| Second native decompiler | [RetDec](https://github.com/avast/retdec) | MIT; last release v5.0 (2023) ships a Windows 7z. Ghidra and Rizin are the maintained defaults; use RetDec only for a target where its output helps. |
| JVM bytecode editing | [Recaf](https://github.com/Col-E/Recaf/releases/tag/4.0.0-alpha) | MIT; 4.x is explicitly a preview despite GitHub marking its tag as a normal release. Windows artifact `recaf-4x-alpha-win-86-x64.jar`, Java 22+. Do not relabel it stable. |
| File, registry and process activity | [Microsoft Process Monitor](https://learn.microsoft.com/en-us/sysinternals/downloads/procmon) | Separate Sysinternals license and first-run acceptance; monitoring can require elevation and a driver. Current 4.11 requires Windows 11; it is not part of this kit's Windows 10 baseline. |
| Windows dumps and system debugging | [WinDbg](https://learn.microsoft.com/en-us/windows-hardware/drivers/debugger/) | Microsoft-managed installation and symbol setup; not a portable payload here. Preserve private dumps and symbol caches outside source. |
| HTTP(S)/WebSocket behavior | [mitmproxy](https://github.com/mitmproxy/mitmproxy), [Wireshark](https://www.wireshark.org/download.html) | Separate installation/runtime requirements. HTTPS interception needs an explicit target-specific certificate setup; packet capture may need Npcap. Do not silently install certificates, drivers or modify system proxy settings. |
| Game-specific archives not handled by 7-Zip | [QuickBMS](https://aluigi.altervista.org/quickbms.htm) and the game's format documentation | Not automatically downloaded; check the downloaded archive's terms. Scripts are executable instructions and format/version specific; inspect them and test with copies. |
| Older Unreal and target-specific UE4 resource extraction | [UE Viewer / UModel](https://www.gildor.org/en/projects/umodel) | Supports older Unreal engines and many UE4 games; check its compatibility table for the target. The official page says its license is not determined, so it is a manual route rather than a redistributed kit payload. |
| Actual isolation | [Windows Sandbox](https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/), a separate VM | `Start-IsolatedLab.ps1 -Plan` previews this kit's configuration. Launch requires the Windows feature on a supported Pro/Enterprise/Education edition; Windows Home needs a separate VM. Tools and optional input are read-only, only `sandbox/work/isolated` is shared writable, and networking/clipboard are disabled. No target starts at logon. Host runtimes are not copied; use a prepared VM when the route needs them. |

UABS's existing browser, source-navigation and editor routes remain useful after source is available. They are not additional decompilers. Generic development runtimes, compilers, Android SDKs and vendor GPU suites are not all bundled here.

## Recovery, reimplementation and publication

Record target hashes, architecture, runtime and dependency versions before analysis. Keep originals and a rollback copy. Work on copies under `sandbox/work/<target>`; inspect one change before applying it more broadly. Logs, dumps and captures can contain private data.

Recovered source can be incomplete or inaccurate. Missing server code, assets, symbols, keys and build systems do not become available because a binary was decompiled. For a replacement implementation, document observed inputs/outputs and verify behavior against the original target.

Technical access does not change copyright or licensing. The kit's MIT license covers its own code, not third-party tools or analyzed targets. Keep tool licenses, target provenance and permission to publish separate. Do not call a target open source merely because extracted or reconstructed code is readable, and keep proprietary target files and private analysis out of releases.

No finite catalog can guarantee every app, engine, obfuscator or future format. Add a tool when a verified target needs it and its artifact, runtime, license and rollback path are known.
