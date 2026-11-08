<p align="center">
  <img src="assets/mark.svg" width="76" height="76" alt="Reverse THIS!">
</p>

<h1 align="center">Reverse THIS!</h1>

<p align="center">
  <a href="https://github.com/SenjuWoo/reverse-this/actions/workflows/ci.yml"><img src="https://github.com/SenjuWoo/reverse-this/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://github.com/SenjuWoo/reverse-this/releases/latest"><img src="https://img.shields.io/github/v/release/SenjuWoo/reverse-this?label=release&color=33566E&labelColor=0d1117" alt="latest release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-33566E?labelColor=0d1117" alt="MIT"></a>
</p>

<p align="center"><strong>A one-click Windows reverse-engineering and modding workbench for you and your AI agents.</strong></p>

Reverse THIS! installs the useful parts of a reverse-engineering bench in one place: Ghidra, x64dbg, Frida, decompilers, Unity/Unreal extractors, archive tools, game-specific converters and stable command shims in `sandbox/bin`. Your agent reads the catalog, picks the right tool and follows a documented route instead of guessing.

It is the **reverse-engineering add-on** for the [Ultimate AI Starter Bundle](https://github.com/SenjuWoo/Ultimate-AI-Starter-Bundle). The Bundle is the recommended foundation for shared runtimes, providers and skills; Reverse THIS! also installs and runs alone when you already have your own harness.

## Quick start

```text
git clone https://github.com/SenjuWoo/reverse-this.git
cd reverse-this
install.cmd
```

Or from PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Modkit.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Modkit.ps1 -Doctor
```

The first run installs the catalog into `sandbox/tools` and writes stable shims to `sandbox/bin`. It reuses a configured shared Python (including `UABS_PYTHON`), Node, Java and .NET runtime instead of creating parallel copies. `-Only <id>` installs one tool; `-Plan` shows the catalog; `-Offline` and `-Doctor` inspect without downloading; `-InstallRoot <dir>` creates an isolated test kit.

## What it covers

| Task | Examples |
|---|---|
| Native and .NET analysis | Ghidra, x64dbg, PE-bear, DIE, ImHex, ILSpy, dnSpy, Rizin |
| Instrumentation and tracing | Frida, RenderDoc, capa, FLOSS, YARA, MinHook, SafetyHook |
| Unity and Unreal | AssetRipper, UABEA, UnityPy, FModel, repak, retoc, UE4SS |
| Web APIs | Reverse API Engineer (`reverse-api-engineer`, optional) |
| Archives and formats | 7-Zip, QuickBMS, Kaitai, wasm-tools, NeoXtractor, `nstool`, RPFM |
| Game routes | League WADs/LTK, Naruto CPK/XFBIN, NeoX NPK, Risk of Rain 2 source-to-Unity, Pokémon Switch extraction |
| Java, Android and Python | JADX, Apktool, Vineflower, uber-apk-signer, PyInstaller extractors |

The full catalog is [catalog/tools.json](catalog/tools.json), with scope and limits in [docs/coverage.md](docs/coverage.md) and dated version boundaries in [docs/compatibility.md](docs/compatibility.md). Game-specific routes are in [docs/](docs/); engine fingerprints and reusable patterns are in [encyclopedia/](encyclopedia/).

## A kit, not a silo

Reverse THIS! is deliberately narrow: extraction, inspection, instrumentation and conversion. It does not install game-authoring suites, AI providers, Unity MCPs, image-generation stacks or DCC applications.

| Owner | Owns |
|---|---|
| [Ultimate AI Starter Bundle](https://github.com/SenjuWoo/Ultimate-AI-Starter-Bundle) | Shared runtimes, AI provider wiring, general skills, work hygiene |
| **Reverse THIS!** | REA, analysis/conversion tools, `sandbox/bin`, target workspace, encyclopedia |
| [Skyrim Forge](https://github.com/SenjuWoo/SkyrimForge) and other forges | Game-specific authoring, loaders, records, packaging and deployment |

All three install independently. The bundle’s optional `reverse` pack calls this installer and reuses its `kit.json`; no Reverse THIS! release requires a bundle release. Forge projects may reference this kit’s `7z` and DirectXTex shims instead of installing duplicates.

Reverse THIS! installs **no Skyrim tools** and no game-authoring stack; Skyrim Forge remains the owner. For general mod-loop field notes, see [universal-modder](https://github.com/rehan-remade/universal-modder).

## Self-maintaining by default

```text
maintain.cmd              # report stale kit-owned files
maintain.cmd -Apply       # remove old temp, cache and rollback leftovers
maintain.cmd -UpdateTools # refresh the catalog + run Doctor
maintain.cmd -Test        # packaged catalog/version checks; source catalog/encyclopedia only
maintain.cmd -All         # cleanup + update + tests
```

`Maintain.ps1` keeps the newest recovery copies, removes generated junk only under explicitly owned paths (`sandbox/tmp`, `sandbox/backups`, one smoke-run subtree, source `__pycache__`), validates the owner pointer and `installed.json` independently and repairs either record after a move, and never touches target work, tools outside the kit, or system temp. `-Test` in a released ZIP verifies the packaged catalog/version contract; in a source checkout it runs only the catalog and encyclopedia checks. It does not run the installer, isolation, scheduled-task, AOB or Windows delivery suites; use `tests/` for those. A weekly `maintenance` workflow checks the catalog, encyclopedia and bundle contract without writing to any owner. `Register-Maintenance.ps1` optionally registers a user-scoped weekly task; it is not enabled automatically. It refuses unrecognized tasks, honors `-WhatIf` for run/remove/register, and escapes the scheduled command. Its output is appended to `%LOCALAPPDATA%\ReverseThis\maintenance.log`; remove the task with `Register-Maintenance.ps1 -Remove`. The task records an absolute owner path: after moving the kit, re-register from the new root. The old task then fails visibly if its path is gone; it does not run stale source.

## Working with an agent

1. Read `sandbox/installed.json` or `%LOCALAPPDATA%\ReverseThis\kit.json` for the active kit.
2. Pick a tool from the catalog or run `sandbox/bin/<tool>.cmd -h`.
3. Use the matching route in `docs/` or `encyclopedia/`; do not skip the verification step.
4. Write findings to the target workspace, not into the kit.

`AGENTS.md` contains the short operating contract. `docs/reverse-engineering.md` explains the analysis workflow; `docs/standalone.md` covers ownership, updates and isolation.

## Isolated target work

`sandbox` is a workspace folder, not process isolation. When a target needs a separate boundary, use the optional Windows Sandbox launcher on supported Pro, Enterprise or Education editions:

```powershell
.\Start-IsolatedLab.ps1 -Plan
.\Start-IsolatedLab.ps1 -InputFolder 'C:\Lab\Input'
```

The first command prints the configuration without launching or writing files. Tools and optional input are mapped read-only; no target runs automatically. Windows Home users need a separate VM. The launcher does not enable Windows features or reboot the host.

## Safety and scope

Tools run with your account’s permissions. This kit does not grant rights to game assets, keys or third-party code, and does not guarantee source recovery, a working build or a bypass of a live service. Use it on software you own or are authorized to test. A catalog entry or successful install is not proof that a particular app can be modified or rebuilt.

## Development and releases

- Source lives in this Git checkout; installed payloads live under `sandbox/` and are ignored.
- Version and changelog are updated together; CI runs catalog, encyclopedia, installer, isolation, entrypoint, runtime, standalone, maintenance and delivery checks.
- The release workflow builds twice from the exact green commit, requires identical bytes, attests the artifact, publishes it, and re-downloads it to compare.
- Manual maintenance and recovery commands are in [docs/standalone.md](docs/standalone.md); release history is in [CHANGELOG.md](CHANGELOG.md).

MIT for the kit. Every downloaded tool keeps its own licence and notices.
