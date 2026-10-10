# Reverse THIS! agent contract

You are in a modkit. The tools are already unpacked, or one command unpacks them. Do not search the disk.

## Find the kit

1. If this file exists, the kit root is its directory.
2. Read `sandbox/installed.json`. Call the shims it names under `sandbox/bin`.
3. If that file is missing, run `powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-Modkit.ps1` and read `sandbox/installed.json` again.
4. If you were not started inside the kit, read `%LOCALAPPDATA%\ReverseThis\kit.json`. It has `kit_root`, `installed_json` and `bin`. Then follow those paths.
5. Stop if none of those exist. Ask for the kit root. Do not scan `Program Files`, Downloads, or a personal tools dump.

`Install-Modkit.ps1 -Plan` prints the catalog and downloads nothing. `-Force` updates an existing kit. A normal run skips tools that are already unpacked.

## Paths

| Path | Use |
|---|---|
| `sandbox/bin` | Every CLI. This is the stable path. |
| `sandbox/tools/<id>` | Unpacked files, including loaders you copy into a game |
| `sandbox/work/<game>` | Decomp, dumps, captures, notes |
| `sandbox/log/modkit.log` | Installer failures |
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
| DDS | `sandbox/bin/texconv.cmd` |

Ghidra's shims set `JAVA_HOME` to the JDK the installer recorded. Do not use a Java 8 that happens to be on `PATH`.

## Do not fetch these

The installer will not download them. Do not work around it. Reasons and the replacement, when there is one, are in `docs/currency.md`.

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

## Companions

- Mod loop, field notes, asset and capture CLIs: https://github.com/rehan-remade/universal-modder
- Agent skills and MCP stack: https://github.com/SenjuWoo/Ultimate-AI-Starter-Bundle

Use those for the workflow. Use this repo for the tools on disk.

## Safety

Single-player, offline, or a server the user runs. Do not attach a debugger, scanner, Frida, or injector to a game with anti-cheat. Do not publish game files or decompiled output.

## When a tool fails

Read `sandbox/log/modkit.log`. Fix the failed id, or re-run with `-Only <id>`. A missing shim means that tool's archive did not contain the expected executable; use `sandbox/installed.json` and the unpacked directory instead of guessing another install on the machine.
