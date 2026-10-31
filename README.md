# Reverse THIS!

One click installs a Windows reverse-engineering and modding workbench with stable commands in `sandbox/bin`. It covers native and .NET apps, Android/Java bytecode, PyInstaller packages, binary formats, and game engines from Unreal and Unity to Source, REDengine, FromSoftware, GameMaker and Total War.

`sandbox` is a workspace folder, not process isolation. Tools run with your account's permissions. Use a separate VM or Windows Sandbox when a target requires isolation. This kit does not guarantee recovery of original source, a working build, missing assets, symbols or keys; decompilation does not change ownership or licensing.

No capability limit in this repository is permanent: each is scoped to a tool, version and mechanism in [encyclopedia/CLAIMS.md](encyclopedia/CLAIMS.md). The catalog is a convenience, not a permission system: a tool you supply in `sandbox/manual/<name>/` is usable without being in the catalog.

## Modular composition

Reverse THIS! is the optional reverse-engineering layer. It installs and runs alone; it does not require the Starter Bundle, Skyrim Forge, or any other forge, and none of them require it. Install only the layers you need:

| Layer | Owns | Works alone |
|---|---|---|
| [Ultimate AI Starter Bundle](https://github.com/SenjuWoo/Ultimate-AI-Starter-Bundle) | providers, shared compilers/runtimes, general skills, GitHub and work-hygiene routing, presentation | yes |
| Reverse THIS! (this repo) | REA, the analysis payload catalog, `sandbox/bin` shims, the target workspace and the encyclopedia | yes |
| [Skyrim Forge](https://github.com/SenjuWoo/SkyrimForge) and other forges | game-specific authoring, records, Papyrus, assets and game MCPs | yes |

The boundaries are deliberate:

- **One owner per tool.** This catalog has no Skyrim tools; xEdit, LOOT, the Creation Kit, houseCARL and Skyrim records stay with Forge. Forge may reference this kit's `sandbox/bin/7z.cmd` and DirectXTex tools instead of installing a second copy.
- **One shared runtime.** When the bundle's `UABS_PYTHON` is set, this installer reuses it. Otherwise it resolves one compatible base interpreter for its own use and never creates a second one beside a working installation. `UABS_TOOL_ROOTS` is honored.
- **Overlap is synced, not duplicated.** The installer detects a shared tool or runtime first: a current version is skipped, an older owned copy is updated in place, and a newer or unknown copy is preserved and reported. `-Force` is the only explicit reinstall; `-NoUpdate` keeps valid installed bytes. Shared payloads such as 7-Zip and DirectXTex are owned here, and another forge references them instead of installing a second copy.
- **No provider writes.** This installer never edits AI-provider settings, trust, model choices, MCP profiles or another owner's ledger.
- **No version coupling.** Each repository releases independently. The bundle's optional `reverse` pack downloads this repo's latest verified release at or above its floor and calls this installer; a Reverse THIS! release never requires a bundle release.
- **No hard dependency.** `install.cmd` works on a clean Windows machine; `-InstallRoot` creates an isolated second kit. Use the bundle when you want the shared base, Forge when you want Skyrim authoring, and this kit when you want the RE bench — any subset.

## Encyclopedia and Context7

`context7.json` at the repository root points [Context7](https://context7.com) at `encyclopedia/`: engine fingerprint cards, coordinate and depth conventions, IPC/shader blueprints, Ghidra/Frida/AOB recipes, version-pinned game notes, and an error registry. The encyclopedia ships at the kit root in the release and is indexed by Context7; the installer does not copy it into `sandbox/`. The 6-tier route ladder and the downstream-sink rule live in `encyclopedia/ROUTING.md`; every limit is scoped to a tool, version and escape hatch in `encyclopedia/CLAIMS.md`; anti-cheat risk tiers are in `encyclopedia/anticheat-risk.md`.

This is the tool bench. It works alone and composes with:

- [universal-modder](https://github.com/rehan-remade/universal-modder), for game reconnaissance, engine routes, builds, runtime checks and field notes
- [Ultimate AI Starter Bundle](https://github.com/SenjuWoo/Ultimate-AI-Starter-Bundle), for provider setup, shared compilers/runtimes, skills, scoped MCPs and task routing
- [Skyrim Forge](https://github.com/SenjuWoo/SkyrimForge) and other game forges, for game-specific authoring and specialist toolchains

The current Starter Bundle already provides `um` and the shared `universal-modder` skill. Reuse that installation. Reverse THIS! supplies the analysis tools; it does not install another fal MCP, rewrite provider configuration or grant project trust. Paid fal generation is optional and separate from local analysis.

universal-modder uses "mod hub" for a future place to publish mods. This repository is not that. It is the kit those agents install from.

## Install

Windows x64, PowerShell 5.1+. The installer targets Windows 10/11; individual tools and optional OS features have their own requirements. Double-click `install.cmd`, or from this folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Modkit.ps1
```

Normal runs resolve current owned release, pip, npm and NuGet versions, preserving intentional pins and numerically newer valid installations. Capa's package, rules and signatures remain one matched transaction. `-NoUpdate` retains valid installed versions; `-Offline` and `-Doctor` inspect files without downloads or writes; `-Plan` prints the catalog. Another checkout reuses the registered owner kit. Use `-InstallRoot` only for an explicit isolated installation; it never moves the shared pointer. See [standalone installation and updates](docs/standalone.md).

This repository installs independently. It reuses a validated shared base Python (`UABS_PYTHON` Process/User, then supported discovery) and compatible shared Node/npm; missing prerequisites use the official Python manager/winget packages. Manager-owned Python receives patch updates on its existing feature line; known winget-owned Node LTS receives targeted updates. App runtimes and venvs stay app-owned. Frida, capa, LIEF, FLOSS and UnityPy use separate dependency venvs; capa requires Python 3.10+, LIEF 3.9+, FLOSS 3.10+ and UnityPy 3.8+. ASAR needs Node 22.12+; REA has the stricter range in the [standalone guide](docs/standalone.md). Java routes share JDK 25 and ilspycmd uses .NET 10, provisioned through their official winget packages when missing. Runtime setup can change the machine; the bundle is optional.

Check the installed records and required files without downloading:

```powershell
.\Install-Modkit.ps1 -Doctor
```

The doctor checks files and records. Downloads are digest-verified when installed, and the install receipt binds each tool's shimmed executables and key files by SHA-256. `-Doctor` re-hashes those files and external commands it reuses: a changed one is reported `CHANGED` (exit 1; reinstall with `-Only <id> -Force`), a tool with no receipt is reported `UNVERIFIED`, and the rest of a payload is checked for presence and structure. Run the selected tool on a lab sample to verify its runtime and target support. Installer version, paths, progress and failures are in `sandbox/log/modkit.log`. Add `-DebugLog` to an install or repair run for detailed package/archive output; it is quiet by default.

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

Native: Ghidra (GUI and `analyzeHeadless`), ImHex, Detect It Easy (`diec`), x64dbg, PE-bear, RenderDoc (`renderdoccmd` and `qrenderdoc`), Rizin (`rizin`, `rz-bin`, `rz-diff`, `rz-asm`), System Informer, Dependencies (CLI and GUI), UPX, YARA (`yara` and `yarac`), GoReSym, FLOSS, MinHook, SafetyHook sources, Frida.

Local helpers: `pe-recon` prints a JSON PE fingerprint (bitness, graphics APIs, anti-cheat markers, RTTI, proxy candidates); `aob-gen` turns an RVA or byte pattern into a wildcard AOB signature; `ghidra-mcp-up` probes the Ghidra plugin (8080) and MCP bridge (8081). They are `local-script` catalog tools copied from `kit/`, and they do not execute the target.

Apps and formats: JADX (`jadx`, `jadx-gui`) for Android/Java bytecode; Vineflower for a second JVM decompile; Apktool for APK resource/smali decode and rebuild; `uber-apk-signer` for signing rebuilt APKs; `asar` for Electron archives; capa for static executable capability triage; Kaitai Struct compiler (`kaitai-struct-compiler`) for binary parsers; `wasm-tools` for WebAssembly; and `pyinstxtractor-ng` for extracting PyInstaller packages. capa uses the official `flare-capa` Python package with released rules in `sandbox/tools/capa-rules` and library-identification signatures in `sandbox/tools/capa-source/sigs`. Both dependencies install automatically, including for `-Only capa`; its shim supplies both paths. LIEF is a Python library in `sandbox/tools/lief`; use its `Scripts/python.exe` to import `lief`. UnityPy is the same pattern for Unity assets under `sandbox/tools/unitypy`. Extraction and capability matches need further analysis; they are not reconstructed source or proof of behavior.

.NET and Unity: ilspycmd, ILSpy, dnSpyEx, AssetRipper, Il2CppDumper, UABEA, BepInEx 5, MelonLoader, and the matching UnityExplorer plugins.

Unreal: FModel, repak, retoc, UAssetGUI, and the UE4SS experimental release (the stable tag is older; it is not what gets installed).

Source: Crowbar for models, BSPSource (`bspsrc`) for BSP maps, and Source 2 Viewer in both GUI (`source2viewer`) and CLI (`source2viewer-cli`) form.

REDengine: WolvenKit (`wolvenkit`) and its CLI (`wolvenkit-cli`) for Cyberpunk 2077 and The Witcher 3.

FromSoftware: Mod Engine 2 (`modengine2`) to load mods, and Smithbox to edit params, maps and regulation files.

GameMaker: UndertaleModTool (`undertalemodtool`) and its CLI (`utmt-cli`) for `data.win` files.

Total War: RPFM (`rpfm`) for pack files.

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
python tests/test_encyclopedia.py
python tests/test_kit_tools.py
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Modkit.ps1 -SelfTest
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Modkit.ps1 -Plan
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\test_installer.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\test_isolation.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\test_entrypoint.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\test_dotnet_prerequisite.ps1
```

After installing the app/format tools, run `powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\test_tool_smoke.ps1` from a source checkout for generated-sample checks, including APK resource modification/rebuilding and a static capa scan. Results/logs stay under `sandbox/work/runtime-smoke`. APK signing/device installation, graphical tools and game compatibility still need a real target test.

## Companion projects

Who owns what across the three repositories is stated once, in the [bundle README](https://github.com/SenjuWoo/Ultimate-AI-Starter-Bundle#ownership); the bundle installs this kit's latest release. Use the [Starter Bundle](https://github.com/SenjuWoo/Ultimate-AI-Starter-Bundle) for shared compilers, AI providers, skills and MCP routing. Use [Skyrim Forge](https://github.com/SenjuWoo/SkyrimForge) for Skyrim-specific authoring and validation. All three can coexist; this kit never rewrites provider configuration.

REA is selectable with `-Only rea` and included in the full catalog run. Its owner pin uses npm integrity with lifecycle scripts disabled. A matching or newer compatible same-major global REA is reused as unowned; unknown/older unowned copies are preserved and reported for their owner's update instead of duplicated. `-Force` explicitly installs an isolated owned copy. No `rea setup` or `rea update` is run. See [analysis routing](docs/reverse-engineering.md), [companion and snapshot routes](docs/companions.md), and [standalone installation/updates](docs/standalone.md).

ZIP installations update their public source through `Update-ReverseThis.ps1`, which requires the official release asset digest and retains source backups without changing private tools/work/state. Git development checkouts use their reviewed Git workflow. The updater's `-Plan`, `-Offline` and `-NoUpdate` modes write and download nothing.

## Product delivery

The versioned product ZIP contains runnable installers, catalog, usage instructions and required licensing. Source ledgers, changelogs, tests, workflows and private target work stay outside it. Maintainers build from an exact tested commit with `python scripts/build_release.py <new-output.zip> --commit <SHA>`; GitHub source downloads remain separately labelled source exports. Source upgrades retire only unchanged obsolete owned files into rollback backups.
