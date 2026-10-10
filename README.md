# Reverse THIS!

One click. The current reverse-engineering and game-modding tools land in `sandbox/bin`. A fresh agent reads that folder and does not go searching the disk.

This is the tool bench. It is meant to be used with:

- [universal-modder](https://github.com/rehan-remade/universal-modder), the loop that recon, builds, tests and writes field notes for a PC game you own
- [Ultimate AI Starter Bundle](https://github.com/SenjuWoo/Ultimate-AI-Starter-Bundle), the agent stack (skills, MCP, providers)

universal-modder uses "mod hub" for a future place to publish mods. This repository is not that. It is the kit those agents install from.

## Install

Windows 10 or 11. Double-click `install.cmd`, or from this folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Modkit.ps1
```

The click is safe to repeat. It skips tools it already unpacked. `Install-Modkit.ps1 -Force` fetches current releases again. `Install-Modkit.ps1 -Plan` prints the catalog and downloads nothing.

Ghidra needs JDK 25. If the machine only has an older Java, the installer uses winget package `Microsoft.OpenJDK.25` and points the Ghidra shims at that home. .NET decompilation uses the installed `dotnet` SDK. Frida uses `py -3`.

## Where an agent looks

| Path | What it is |
|---|---|
| `sandbox/bin` | The only commands to call |
| `sandbox/tools/<id>` | The unpacked tool |
| `sandbox/installed.json` | Version, file, hash, shim for each tool |
| `sandbox/work` | Decomp, dumps and captures. Not part of the git repo |
| `sandbox/log/modkit.log` | Installer log: version, each download, each failure |
| `%LOCALAPPDATA%\ReverseThis\kit.json` | Machine pointer, for a chat that was not opened inside the clone |

Open the agent in this folder. It reads `AGENTS.md`. If the chat is somewhere else, the pointer file has the absolute kit root. Do not search `Program Files`, Downloads, or an old tools dump.

## What the click installs

Native: Ghidra (GUI and `analyzeHeadless`), ImHex, Detect It Easy (`diec`), x64dbg, PE-bear, RenderDoc (`renderdoccmd` and `qrenderdoc`), MinHook, SafetyHook sources, Frida.

.NET and Unity: ilspycmd, ILSpy, dnSpyEx, AssetRipper, Il2CppDumper, UABEA, BepInEx 5, MelonLoader, and the matching UnityExplorer plugins.

Unreal: FModel, repak, retoc, UAssetGUI, and the UE4SS experimental release (the stable tag is older; it is not what gets installed).

Textures: `texconv`, `texassemble`, `texdiag`.

Drop-in loaders stay in `sandbox/tools/<id>`. Copy them into a game folder when a mod needs them. Do not point them at a game with anti-cheat.

## What it refuses

Archived or replaced tools, stale binaries, website installers that bundle offers, rars, paid shader packs, leaked game SDKs, and vendor GPU suites that install themselves into their own directories. The reasons are in [docs/currency.md](docs/currency.md). A portable tool you still want on the path, and that this kit will not download, goes in `sandbox/manual/<name>/`. The installer does not scan the rest of the disk.

## Rules

Single-player, offline, or a server you run. Do not attach a debugger, scanner or injector to a game with anti-cheat. Do not commit game files, decompiled output, or the unpacked tools. Those stay under `sandbox/`.

Each upstream tool keeps its own license. This repository is MIT.

## Development

```powershell
python tests/test_catalog.py
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Modkit.ps1 -SelfTest
powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Modkit.ps1 -Plan
```
