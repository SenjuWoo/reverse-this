# Reverse THIS!

One click installs a Windows reverse-engineering and modding workbench with stable commands in `sandbox/bin`. It covers native and .NET apps, Android/Java bytecode, PyInstaller packages, binary formats, and several game engines.

`sandbox` is a workspace folder, not process isolation. Tools run with your account's permissions. Use a separate VM or Windows Sandbox when a target requires isolation. This kit does not promise to recover original source, a working build, missing assets, symbols or keys; decompilation does not change ownership or licensing.

This is the tool bench. It is meant to be used with:

- [universal-modder](https://github.com/rehan-remade/universal-modder), for game reconnaissance, engine routes, builds, runtime checks and field notes
- [Ultimate AI Starter Bundle](https://github.com/SenjuWoo/Ultimate-AI-Starter-Bundle), for provider setup, skills, scoped MCPs and task routing

The current Starter Bundle already provides `um` and the shared `universal-modder` skill. Reuse that installation. Reverse THIS! supplies the analysis tools; it does not install another fal MCP, rewrite provider configuration or grant project trust. Paid fal generation is optional and separate from local analysis.

universal-modder uses "mod hub" for a future place to publish mods. This repository is not that. It is the kit those agents install from.

## Install

Windows x64, PowerShell 5.1+. The installer targets Windows 10/11; individual tools and optional OS features have their own requirements. Double-click `install.cmd`, or from this folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Modkit.ps1
```

Normal runs resolve current owned release, pip, npm and NuGet versions, preserving intentional pins and numerically newer valid installations. Capa's package, rules and signatures remain one matched transaction. `-NoUpdate` retains valid installed versions; `-Offline` and `-Doctor` inspect files without downloads or writes; `-Plan` prints the catalog. Another checkout reuses the registered owner kit. Use `-InstallRoot` only for an explicit isolated installation; it never moves the shared pointer. See [standalone installation and updates](docs/standalone.md).

This repository installs independently. It reuses a validated shared base Python (`UABS_PYTHON` Process/User, then supported discovery) and compatible shared Node/npm; missing prerequisites use the official Python manager/winget packages. Manager-owned Python receives patch updates on its existing feature line; known winget-owned Node LTS receives targeted updates. App runtimes and venvs stay app-owned. Frida, capa and LIEF use separate dependency venvs; capa requires Python 3.10+, LIEF 3.9+. ASAR needs Node 22.12+; REA has the stricter range in the [standalone guide](docs/standalone.md). Java routes share JDK 25 and ilspycmd uses .NET 10, provisioned through their official winget packages when missing. Runtime setup can change the machine; the bundle is optional.

Check the installed records and required files without downloading:

```powershell
.\Install-Modkit.ps1 -Doctor
```

The doctor checks files and records. Downloads are digest-verified when installed; afterwards `-Doctor` re-hashes external commands it reuses, but for kit-owned payloads it checks presence and structure only, so a binary changed after install is not detected. Reinstall the tool if in doubt. Run the selected tool on a lab sample to verify its runtime and target support. Installer version, paths, progress and failures are in `sandbox/log/modkit.log`. Add `-DebugLog` to an install or repair run for detailed package/archive output; it is quiet by default.

Updates retain replaced tool payloads under `sandbox/backups/<id>-<unique-id>`. The previous installed manifest is saved as `sandbox/installed.json.pre-<kit-version>.json`. Failed updates restore the saved payload when one exists. Keep these backups until the replacement works on your target; they are local state, not release files.

## Isolated target work

The optional launcher uses Windows Sandbox when that feature is available on a supported Pro, Enterprise or Education edition. Windows Home users need a separate VM for isolation:

```powershell
.\Start-IsolatedLab.ps1 -Plan
.\Start-IsolatedLab.ps1 -InputFolder 'C:\Lab\Input'
```

The first command prints the configuration without launching or writing files. For the second, replace the example input path with an existing folder, or omit `-InputFolder`. It opens the guest with networking, clipboard, audio/video input, printer redirection and vGPU disabled. Tools and optional input are mapped read-only; the shared host output folder is `sandbox/work/isolated`. No target runs automatically. Host runtimes are not copied: Java, .NET, Python and Node routes can need a prepared VM or guest setup. Read-only tool folders can also prevent tools from saving settings beside their executables. The launcher does not enable Windows features or reboot the host.

## Where an agent looks

| Path | What it is |
|---|---|
| `sandbox/bin` | The only commands to call |
| `sandbox/tools/<id>` | The unpacked tool |
| `sandbox/installed.json` | Version, file, hash, shim for each tool |
| `sandbox/work` | Decomp, dumps and captures. Not part of the git repo |
| `sandbox/log/modkit.log` | Installer log: version, each download, each failure |
| `sandbox/backups` | Replaced tool payloads kept for rollback |
| `%LOCALAPPDATA%\ReverseThis\kit.json` | Machine pointer, for a chat that was not opened inside the clone |

Open the agent in this folder. It reads `AGENTS.md`. If the chat is somewhere else, the pointer file has the absolute kit root. Do not search `Program Files`, Downloads, or an old tools dump.

## What the click installs

Native: Ghidra (GUI and `analyzeHeadless`), ImHex, Detect It Easy (`diec`), x64dbg, PE-bear, RenderDoc (`renderdoccmd` and `qrenderdoc`), MinHook, SafetyHook sources, Frida.

Apps and formats: JADX (`jadx`, `jadx-gui`) for Android/Java bytecode; Apktool for APK resource/smali decode and rebuild; `asar` for Electron archives; capa for static executable capability triage; Kaitai Struct compiler (`kaitai-struct-compiler`) for binary parsers; `wasm-tools` for WebAssembly; and `pyinstxtractor-ng` for extracting PyInstaller packages. capa uses the official `flare-capa` Python package with released rules in `sandbox/tools/capa-rules` and library-identification signatures in `sandbox/tools/capa-source/sigs`. Both dependencies install automatically, including for `-Only capa`; its shim supplies both paths. LIEF is a Python library in `sandbox/tools/lief`; use its `Scripts/python.exe` to import `lief`. Extraction and capability matches need further analysis; they are not reconstructed source or proof of behavior.

.NET and Unity: ilspycmd, ILSpy, dnSpyEx, AssetRipper, Il2CppDumper, UABEA, BepInEx 5, MelonLoader, and the matching UnityExplorer plugins.

Unreal: FModel, repak, retoc, UAssetGUI, and the UE4SS experimental release (the stable tag is older; it is not what gets installed).

Frostbite: Frosty Editor and Frosty Mod Manager.

Godot: the current stable mono editor (`godot`, console build) and GDRE Tools for packed games.

Fighting games and pixel art: IKEMEN Go, Pixelorama, OpenBOR, and Fighter Factory (official Windows portable, x64). LDtk is unpacked from its Windows installer with 7-Zip. The installer is not run. `7z` is on `sandbox/bin`.

Helldivers 2: HD2Runtime SDK, runtime, example projects, and mod template; HD2Runtime ModBuilder; the community SDK; and Bingus Shared Loader.

Risk of Rain 2: R2API source from the current release tag.

Sleeping Dogs: TheoryEngine source, the SDK source, and the SDK example playground. The game executable and its PDB are not part of the kit.

Textures: `texconv`, `texassemble`, `texdiag`.

Drop-in loaders and SDKs stay in `sandbox/tools/<id>`. Copy a loader into a game folder when a mod needs it.

See [coverage and optional routes](docs/coverage.md) for Java editing, process monitoring, network inspection, SDKs and other gaps. Optional routes are not silently installed. A catalog entry or a successful installer is not proof that a particular app can be modified or rebuilt.

## What it refuses

Archived or replaced tools, stale binaries, website installers that bundle offers, paid shader packs, leaked private SDKs, game executables, and vendor GPU suites that install themselves into their own directories. An official rar or installer that 7-Zip can unpack into `sandbox/tools` is installed. The reasons are in [docs/currency.md](docs/currency.md). A portable tool you still want on the path, and that this kit will not download, goes in `sandbox/manual/<name>/`. The installer does not scan the rest of the disk.

## Rules

Do not commit game files, decompiled output, or the unpacked tools. Those stay under `sandbox/`. The kit does not download game executables or private symbol files. Whether a mod can be published is your call.

Each upstream tool keeps its own license. This repository is MIT.

## Development

Run these checks from a source checkout:

```powershell
python tests/test_catalog.py
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Modkit.ps1 -SelfTest
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Modkit.ps1 -Plan
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\test_installer.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\test_isolation.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\test_entrypoint.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\test_dotnet_prerequisite.ps1
```

After installing the app/format tools, run `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\test_tool_smoke.ps1` from a source checkout for generated-sample checks, including APK resource modification/rebuilding and a static capa scan. Results/logs stay under `sandbox/work/runtime-smoke`. APK signing/device installation, graphical tools and game compatibility still need a real target test.

## Companion projects

Use the [Starter Bundle](https://github.com/SenjuWoo/Ultimate-AI-Starter-Bundle) for shared compilers, AI providers, skills and MCP routing. Use [Skyrim Forge](https://github.com/SenjuWoo/SkyrimForge) for Skyrim-specific authoring and validation. All three can coexist; this kit never rewrites provider configuration.

REA is selectable with `-Only rea` and included in the full catalog run. Its owner pin uses npm integrity with lifecycle scripts disabled. A matching or newer compatible same-major global REA is reused as unowned; unknown/older unowned copies are preserved and reported for their owner's update instead of duplicated. `-Force` explicitly installs an isolated owned copy. No `rea setup` or `rea update` is run. See [analysis routing](docs/reverse-engineering.md), [companion and snapshot routes](docs/companions.md), and [standalone installation/updates](docs/standalone.md).

ZIP installations update their public source through `Update-ReverseThis.ps1`, which requires the official release asset digest and retains source backups without changing private tools/work/state. Git development checkouts use their reviewed Git workflow. The updater's `-Plan`, `-Offline` and `-NoUpdate` modes write and download nothing.

## Product delivery

The versioned product ZIP contains runnable installers, catalog, usage instructions and required licensing. Source ledgers, changelogs, tests, workflows and private target work stay outside it. Maintainers build from an exact tested commit with `python scripts/build_release.py <new-output.zip> --commit <SHA>`; GitHub source downloads remain separately labelled source exports. Source upgrades retire only unchanged obsolete owned files into rollback backups.
