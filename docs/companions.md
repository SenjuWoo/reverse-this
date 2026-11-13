# Task routes and supplied source snapshots

Use the three independent repositories together when their tasks overlap; who owns what is stated once, in the [bundle README](https://github.com/SenjuWoo/Ultimate-AI-Starter-Bundle#ownership). This kit owns app/game binary analysis, extractors, instrumentation and REA.

Reverse THIS! contributes 7-Zip and DirectXTex; another forge may reference `sandbox/bin/7z.cmd` and the DirectXTex tools instead of installing a second copy. This kit consumes `UABS_PYTHON` and `UABS_TOOL_ROOTS` and may reuse an existing `um` installation; it does not install Skyrim tools or provider skills. The bundle's optional `reverse` pack calls this installer; a Reverse THIS! release does not require a bundle release.

Each installs independently and consumes verified existing installations. The workbench's standalone prerequisites are described in [standalone.md](standalone.md). Companion recommendations do not install a second provider stack, grant trust, register all MCP schemas or run an upstream account setup command.

Run `python scripts/check_companions.py` (source checkout) or the scheduled `companions` workflow to read the published bundle catalog entry (floor, asset template), the bundle `PACKS.json` reverse pack (enable command, owner, floor, `ReverseThis/kit.json` detection) and the Forge ownership link. It only reads; it never writes to either repository.

The supplied upstream snapshots were re-inspected on 2026-11-13 and each snapshot compared with its upstream. These are observations of local copies, not a promise about future upstream revisions. None is vendored; owner decisions are below.

| Snapshot | Local / upstream (2026-11-13) | Owner and decision |
|---|---|---|
| `rea-main` | rea-agents 6.9.0 source; npm and tag `rea-agents-6.9.0` | Catalogued here as `rea`, installed from the integrity-pinned npm 6.9.0 release, not built from this source. Verified with Ghidra 12.1.4 and 12.2. |
| `CLI-Anything-main` | source collection, Apache-2.0; upstream release v0.4.0, main active | Starter Bundle. Per-application CLI harnesses (RenderDoc, LLDB, Blender, Godot and others); use a harness when it fills the task. Not an analysis payload. |
| `context-mode-main` | 1.0.169, Elastic-2.0; upstream 2.1.10 | Starter Bundle (agent context plugin). The local copy is a major version behind; take upstream 2.x if it is adopted. ELv2: do not merge or relicense its source. |
| `OBS-MCP-main` | obs-mcp 1.1.1, MIT; upstream 1.1.1 | Starter Bundle (OBS Studio scene/recording MCP). Useful for recording runtime proof, but not an analysis tool. Not catalogued. |
| `Unity-MCP-1` | CoplayDev MCP for Unity 10.3.0, MIT; upstream 10.3.0 | Starter Bundle (Unity Editor automation). Works on a Unity project, not on a shipped game binary; game-side Unity work uses BepInEx/MelonLoader/UnityExplorer here. |
| `Unity-MCP-2` | IvanMurzak Unity-MCP server 9.3.2, Apache-2.0; upstream 9.3.2 | Starter Bundle, same scope as above. Pick one Unity MCP per project. |
| `awesome-gamedev-agent-skills-main` | Apache-2.0 skill collection, 2026-11-07 copy; upstream pushed 2026-11-12 | Starter Bundle skills. Game development, not reverse engineering. |
| `awesome-opus5-5-videos-main` | MIT prompt gallery | Reference only; no tool. |
| `blender/blender-5.2.3-windows-x64` | 5.2.3; upstream and the shared PATH install are 5.3.0 | Shared application owned by the bundle; this kit does not install Blender. The 5.2.3 copy is superseded. |
| `CLibDT (Windows)` | `ClibDT.exe`, GPL-3.0-only | Skyrim Forge / bundle (CommonLib/SKSE developer tools). Not catalogued. |
| `zIDK` | nx 24.0.2 (upstream 24.0.6), turbo 2.11.10 (2.11.11), vite 8.3.5 (8.3.8), webpack 5.112.2 (current) | JavaScript build tooling. When rebuilding a recovered web/Electron app, use the versions in that project's lockfile, not these copies. |

No snapshot was vendored wholesale. MIT or Apache-2.0 files can be considered individually when a concrete missing feature warrants reuse, retaining their actual notices and exact revision provenance. The observations above do not grant rights over third-party dependencies, target games or extracted assets. Context Mode remains a separately licensed upstream component. Prefer owner installers and existing installed commands to copying redundant source trees.
