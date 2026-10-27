# Reverse THIS! agent contract

You are in a reverse-engineering and modding workbench. Check the installed manifest; catalog entries alone do not prove tools are installed. Do not search the disk.

The `sandbox` directory is not process isolation. Tools and targets inherit the launching account's permissions. Inspect unknown targets in a separate VM or Windows Sandbox when isolation is needed; do not claim this folder provides it.

## Find the kit

1. Read `%LOCALAPPDATA%\ReverseThis\kit.json` when present. Its validated `kit_root`, `installed_json` and `bin` identify the canonical owner; a different source checkout reuses it.
2. Read that owner's `sandbox/installed.json`. Call the shims it names under `sandbox/bin`.
3. If no owner pointer exists, this source directory is the initial kit root. Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Modkit.ps1` when installation is needed.
4. Tests use an explicit `-InstallRoot` and isolated state. That override never rewrites the shared pointer. An invalid owner receipt is a repair issue, not permission to create a duplicate kit.
5. Stop if none of those exist. Ask for the kit root. Do not scan `Program Files`, Downloads, or a personal tools dump.

`Install-Modkit.ps1 -Plan` prints the catalog without network or writes. Normal runs update old owned release/pip/npm/NuGet tools while preserving pins, newer valid versions and rollback backups. `-NoUpdate` retains installed versions; missing selections can install. `-Doctor`/`-Offline` check receipts/files without network, setup or writes, not runtime behavior. Add `-DebugLog` for detailed diagnostics. The workbench provisions its own missing shared prerequisites; the bundle is optional. Read `docs/standalone.md` before changing ownership or using external tool receipts, and `docs/companions.md` for task routing and snapshot provenance.

## Paths

| Path | Use |
|---|---|
| `sandbox/bin` | Every CLI. This is the stable path. |
| `sandbox/tools/<id>` | Unpacked files, including loaders you copy into a game |
| `sandbox/work/<target>` | Decomp, dumps, captures, notes |
| `sandbox/log/modkit.log` | Installer failures |
| `sandbox/backups/<id>-<unique-id>` | Replaced payloads retained for rollback |
| `%LOCALAPPDATA%\ReverseThis\kit.json` | Absolute kit root on this machine |

Put the game's decomp and extracts in `sandbox/work`. Do not commit that directory, game files, or `sandbox/tools`.

## Which tool

| Job | Command or folder |
|---|---|
| Native decompile | `sandbox/bin/analyzeHeadless.cmd` or `sandbox/bin/ghidra.cmd` |
| .NET decompile | `sandbox/bin/ilspycmd.cmd` |
| .NET debug or edit | `sandbox/bin/dnspy.cmd` |
| IL2CPP metadata | `sandbox/bin/il2cppdumper.cmd` |
| Unity extract | `sandbox/bin/assetripper.cmd` and `sandbox/tools/uabea` |
| Unity Mono loader | `sandbox/tools/bepinex5` |
| Unity IL2CPP loader | `sandbox/tools/melonloader` |
| Unity live inspector | the matching folder under `sandbox/tools/unityexplorer-*` |
| Unreal browse | `sandbox/bin/fmodel.cmd` |
| Unreal pak | `sandbox/bin/repak.cmd` |
| Unreal IoStore | `sandbox/bin/retoc.cmd` |
| Unreal assets | `sandbox/bin/uassetgui.cmd` |
| Unreal Lua / dumper | `sandbox/tools/ue4ss` |
| File type | `sandbox/bin/diec.cmd` |
| Hex | `sandbox/bin/imhex.cmd` |
| Debugger | `sandbox/bin/x64dbg.cmd` |
| PE | `sandbox/bin/pe-bear.cmd` |
| Frame capture | `sandbox/bin/renderdoccmd.cmd` |
| Hook, new C++ | `sandbox/tools/safetyhook` |
| Hook, C | `sandbox/tools/minhook` |
| Dynamic trace | `sandbox/bin/frida.cmd` |
| Android / Java decompile | `sandbox/bin/jadx.cmd` or `sandbox/bin/jadx-gui.cmd` |
| Executable capability triage | `sandbox/bin/capa.cmd` (Python package, rules in `sandbox/tools/capa-rules`, signatures in `sandbox/tools/capa-source/sigs`) |
| Binary format parser generation | `sandbox/bin/kaitai-struct-compiler.cmd` |
| PyInstaller extraction | `sandbox/bin/pyinstxtractor-ng.cmd` |
| APK resource/smali decode and rebuild | `sandbox/bin/apktool.cmd` |
| Electron ASAR archives | `sandbox/bin/asar.cmd` |
| WebAssembly modules and components | `sandbox/bin/wasm-tools.cmd` |
| Programmatic binary parsing/patching | `sandbox/tools/lief/Scripts/python.exe` with `import lief` |
| DDS | `sandbox/bin/texconv.cmd` |
| Frostbite edit | `sandbox/bin/frosty-editor.cmd` |
| Frostbite apply | `sandbox/bin/frosty-modmanager.cmd` |
| Godot editor | `sandbox/bin/godot.cmd` |
| Godot PCK recover | `sandbox/bin/gdre.cmd` |
| Fighting-game engine | `sandbox/bin/ikemen-go.cmd` and `sandbox/bin/openbor.cmd` |
| Sprite and move toolset | `sandbox/bin/fighter-factory.cmd` (x64 `ffs.exe`) |
| Pixel art | `sandbox/bin/pixelorama.cmd` |
| Level editor | `sandbox/bin/ldtk.cmd` |
| Archives | `sandbox/bin/7z.cmd` |
| Helldivers 2 runtime | `sandbox/tools/hd2-runtime`, `hd2-runtime-sdk`, `hd2-runtime-examples`, `hd2-runtime-template` |
| Helldivers 2 builder | `sandbox/bin/hd2-modbuilder.cmd` |
| Helldivers 2 community SDK | `sandbox/tools/hd2-sdk-community` |
| Helldivers 2 loader | `sandbox/tools/bingus-shared-loader` |
| Risk of Rain 2 API | `sandbox/tools/r2api` |
| Sleeping Dogs engine source | `sandbox/tools/theoryengine` |
| Sleeping Dogs SDK | `sandbox/tools/sleeping-dogs-sdk` and `sandbox/tools/sleeping-dogs-sdk-playground` |
| Clean-room app recon / rebuild / parity diff (web and mobile app behavior, not binaries) | `sandbox/tools/replica-skill/replica-*` skills; load with `Copy-Item -Recurse sandbox	oolseplica-skilleplica-* $HOME\.claude\skills\`. Behavior only: do not copy the target's code, assets or copy. |

Ghidra, JADX, Apktool and Kaitai shims set `JAVA_HOME` to the JDK the installer recorded. Use their shims. ASAR needs Node 22.12+ and npm; capa needs Python 3.10+, LIEF 3.9+. capa uses `flare-capa` in a venv, with released `capa-rules` and the signature-bearing `capa-source` archive installed automatically even for `-Only capa`; its shim supplies the rules and signature directories. The source archive excludes the separate malware testfiles submodule. JADX does not guarantee complete decompilation; PyInstaller extraction produces files and bytecode, not automatically readable source. Confirm capa matches against actual code or observed behavior.

Consult `docs/coverage.md` for optional tools and missing domains. `Start-IsolatedLab.ps1 -Plan` previews Windows Sandbox settings without writing files. Actual launch requires that Windows feature on a supported Pro/Enterprise/Education edition; Windows Home needs a separate VM. The launcher maps tools/input read-only, disables networking and other host integration, and only shares `sandbox/work/isolated` writable. It never starts a target. Host JDK/.NET/Python/Node prerequisites are not copied, so verify each guest tool before claiming it works there.

ilspycmd uses a stable .NET 10 SDK/runtime, provisioned through winget when missing. Its shim binds the selected runtime without changing the caller's environment. Installing any of `capa`, `capa-rules` or `capa-source` updates the matched group together; Plan and Doctor still show individual entries.

## Retired automatic routes

The installer does not download these ids. Use the replacement or target-specific manual route documented in `docs/currency.md`; do not silently substitute an old artifact.

- `assetstudio`
- `dnspy` (the archived original; `dnspyex` is the one installed)
- `uabe` (original; `uabea` is installed)
- `umodel-ue4`
- `cpp2il-2022-binary`
- `ue4ss-stable`
- `bepinex6-pre2`
- `cheat-engine-download`
- `reclass-rar`
- `3dmigoto-tag`
- `sinai-unityexplorer`
- `frosty-rewrite` (no published binary; `frosty-editor` and `frosty-modmanager` are installed)
- `ldtk-installer`
- `openbor-rar`
- `fighter-factory-installer`

## Companions

- Mod loop, field notes, asset and capture CLIs: https://github.com/rehan-remade/universal-modder
- Agent skills and MCP stack: https://github.com/SenjuWoo/Ultimate-AI-Starter-Bundle
- IKEMEN Go project workflow (Claude plugin, not a binary in this kit): https://github.com/nategarelik/ikemen-forge

Use those for the workflow. Use this repo for the tools on disk. The current Starter Bundle already supplies `um` and the shared Universal Modder skill; reuse them. This installer does not register upstream fal MCP/hooks, edit provider configuration or change project trust. Keep credentials out of target work folders and output.

## Safety

Do not commit or publish game files or decompiled output. The kit does not contain game executables. TheoryEngine and the Sleeping Dogs SDK are source. HD2 and R2API are the public mod tools. Whether a mod can be published is the user's call.

Distinguish recovery from reimplementation: native decompilers output approximations, extracted bytecode may not decompile, and absent source/assets/build systems cannot be invented. Reverse engineering does not grant permission to relicense third-party code as open source. Record provenance and license separately from technical findings, and keep target files and private analysis out of releases.

## When a tool fails

Read `sandbox/log/modkit.log`. Fix the failed id, or re-run with `-Only <id> -DebugLog`. A missing shim means that tool's archive did not contain the expected executable; use `sandbox/installed.json` and the unpacked directory instead of guessing another install on the machine. Replaced payloads are retained under `sandbox/backups`; the pre-update manifest is `sandbox/installed.json.pre-<kit-version>.json`. Keep those until the new target workflow works, and do not publish them.

## Target project ownership and publication

Before substantive target edits, establish one source project with `WORKSPACE_OWNERSHIP.md`; preserve existing records, source layout and repository. The kit owner and target project are different owners. When available, use workspace-organization/ensure_ownership.py; otherwise create the same explicit record before writing. Do not publish extracted third-party code or assets by assumption.

New work stays local/private until publication is requested. "Put it on GitHub" means public and MIT for original work by default, subject to third-party rights and platform terms; preserve existing licences and explicit choices. Generic publication uses the appropriate destination (normally Nexus Mods for Skyrim). A mod needing no compilation does not get a duplicate GitHub repository by default; add source hosting when requested or needed for development.

Target releases contain runtime product/mod files and required licences; keep changelogs, ownership/progress files, decompilation notes, tests and backups outside deployment ZIPs. Kit AGENTS/CLAUDE and docs are usage instructions, not target payloads.
