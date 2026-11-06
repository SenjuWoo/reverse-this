# Task routes and supplied source snapshots

Use the three independent repositories together when their tasks overlap; who owns what is stated once, in the [bundle README](https://github.com/SenjuWoo/Ultimate-AI-Starter-Bundle#ownership). This kit owns app/game binary analysis, extractors, instrumentation and REA.

Reverse THIS! contributes 7-Zip and DirectXTex; another forge may reference `sandbox/bin/7z.cmd` and the DirectXTex tools instead of installing a second copy. This kit consumes `UABS_PYTHON` and `UABS_TOOL_ROOTS` and may reuse an existing `um` installation; it does not install Skyrim tools or provider skills. The bundle's optional `reverse` pack calls this installer; a Reverse THIS! release does not require a bundle release.

Each installs independently and consumes verified existing installations. The workbench's standalone prerequisites are described in [standalone.md](standalone.md). Companion recommendations do not install a second provider stack, grant trust, register all MCP schemas or run an upstream account setup command.

Run `python scripts/check_companions.py` (source checkout) or the scheduled `companions` workflow to read the published bundle floor, asset template and Forge ownership link. It only reads; it never writes to either repository.

The supplied `Tools` folder was re-inspected on 2026-11-05. These are observations of those local snapshots, not claims that their folder names identify an upstream revision:

| Snapshot | Verified manifest/license | Task and reuse decision |
|---|---|---|
| `Github/rea-main` | `package.json`: rea-agents 6.8.0; `LICENSE`: MIT | Unreleased upstream main after the `rea-agents-6.8.0` tag (no `.git`, so no exact commit). It already admits Ghidra 12.x >= 12.1, which the published 6.8.0 refuses. The kit keeps installing the integrity-pinned npm 6.8.0 release; bump `package_version`/`npm_integrity` when npm publishes the next release instead of building this snapshot. |
| `Github/CLI-Anything-main` | `LICENSE`: Apache-2.0 | [CLI-Anything](https://github.com/HKUDS/CLI-Anything) supplies task-specific application CLI harnesses (Blender, Godot, RenderDoc, LLDB and others). Use a harness when it fills the task; it is not another binary analysis toolkit. |
| `Github/context-mode-main` | `package.json`: context-mode 1.0.169, Node >=22.5.0; `LICENSE`: Elastic License 2.0 | [Context Mode](https://github.com/mksglu/context-mode) is an optional agent-context plugin. Its ELv2 terms differ from MIT; do not merge or relicense its source or replace existing hooks silently. |
| `Github/CLibDT (Windows)` | `ClibDT.exe` with GPL-3.0-only `LICENSE.txt` and third-party notices | A CommonLib/SKSE developer-tool manager. Skyrim development belongs to Skyrim Forge and the bundle, not this kit. Not catalogued. |
| `Github/zIDK` | nx 24.0.2, turbo 2.11.10 (binary), vite 8.3.5, webpack 5.112.2 source | JavaScript build tooling, not analysis tools. Use the target project's own lockfile versions when rebuilding a recovered web/Electron app. Not catalogued. |
| `Ai tools/Risk-Of-Rain-2-Forge` | MIT; WIP CLI/build/package workbench | The companion authoring owner for Risk of Rain 2 mods. Reverse THIS! supplies extraction and conversion tools; use the Forge for project scaffolding, Unity asset authoring, build/package checks and in-game validation. Do not duplicate its templates or mod-manager logic in this catalog. |
| `Ai tools/Minecraft-Forge`, `RimWorldForge`, `RobloxForge`, `Discord-Forge` | MIT workspaces | Game/platform-specific authoring workbenches. They own their loaders, templates and deployment rules; this kit does not install their toolchains or duplicate their skills. |
| `Github/Unity-MCP-1`, `Unity-MCP-2` | upstream MCP projects | Unity editor automation bridges, not standalone RE tools. Use one only when the task is Unity authoring or playtesting, and let the owning project manage MCP registration and trust. |
| `Github/blender` | Blender 5.2.3 Windows x64 | Manual DCC path for mesh/rig/glTF work after extraction. Large application payload; not catalogued or auto-installed. |
| `Bundle-Splits/img2threejs` | v1.5.1, 489-file tool tree | Separate 3D-generation owner with its own repository; not an RE component. Do not copy it back into this kit. |
| `Bundle-Splits/uabs-image-stack` (comfy-kit) | v0.4.0, image frontend/model tooling | Separate image-generation owner; outside this kit's scope. Do not add a second copy of its presets or model installer. |

No snapshot was vendored wholesale. MIT or Apache-2.0 files can be considered individually when a concrete missing feature warrants reuse, retaining their actual notices and exact revision provenance. The observations above do not grant rights over third-party dependencies, target games or extracted assets. Context Mode remains a separately licensed upstream component. Prefer owner installers and existing installed commands to copying redundant source trees.
