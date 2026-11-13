# Task routes and supplied source snapshots

Use the three independent repositories together when their tasks overlap; who owns what is stated once, in the [bundle README](https://github.com/SenjuWoo/Ultimate-AI-Starter-Bundle#ownership). This kit owns app/game binary analysis, extractors, instrumentation and REA.

Reverse THIS! contributes 7-Zip and DirectXTex; another forge may reference `sandbox/bin/7z.cmd` and the DirectXTex tools instead of installing a second copy. This kit consumes `UABS_PYTHON` and `UABS_TOOL_ROOTS` and may reuse an existing `um` installation; it does not install Skyrim tools or provider skills. The bundle's optional `reverse` pack calls this installer; a Reverse THIS! release does not require a bundle release.

Each installs independently and consumes verified existing installations. The workbench's standalone prerequisites are described in [standalone.md](standalone.md). Companion recommendations do not install a second provider stack, grant trust, register all MCP schemas or run an upstream account setup command.

Run `python scripts/check_companions.py` (source checkout) or the scheduled `companions` workflow to read the published bundle catalog entry (floor, asset template), the bundle `PACKS.json` reverse pack (enable command, owner, floor, `ReverseThis/kit.json` detection) and the Forge ownership link. It only reads; it never writes to either repository.

Upstream snapshots supplied alongside this kit were reviewed on 2026-11-13. Local copies are refreshed outside this repository, so this table records ownership decisions, not local versions; check the upstream before relying on a copy.

| Snapshot | Upstream | Owner and decision |
|---|---|---|
| REA source | [morluto/rea](https://github.com/morluto/rea) | Catalogued here as `rea`, installed from the integrity-pinned npm release (6.9.0), never built from a source snapshot. |
| CLI-Anything | [HKUDS/CLI-Anything](https://github.com/HKUDS/CLI-Anything) | Starter Bundle. Per-application CLI harnesses (RenderDoc, LLDB, Blender, Godot and others); use one when it fills the task. |
| Context Mode | [mksglu/context-mode](https://github.com/mksglu/context-mode) | Starter Bundle (agent context plugin). Elastic License 2.0: do not merge or relicense its source. |
| OBS MCP | [Tom-R-Main/OBS-MCP](https://github.com/Tom-R-Main/OBS-MCP) | Starter Bundle. Scene and recording control, handy for recording runtime proof; not an analysis tool. |
| MCP for Unity | [CoplayDev/unity-mcp](https://github.com/CoplayDev/unity-mcp) | Starter Bundle. Drives a Unity Editor project, not a shipped game; game-side Unity work here uses BepInEx, MelonLoader and UnityExplorer. |
| Unity-MCP | [IvanMurzak/Unity-MCP](https://github.com/IvanMurzak/Unity-MCP) | Starter Bundle, same scope; pick one Unity MCP per project. |
| awesome-gamedev-agent-skills | [gamedev-skills/awesome-gamedev-agent-skills](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) | Starter Bundle skills for game development. |
| Blender, blender-skills, img2threejs, teardown | [blender.org](https://www.blender.org/download/), [EL4CTEO/blender-skills](https://github.com/EL4CTEO/blender-skills), [img2threejs/img2threejs](https://github.com/img2threejs/img2threejs), [elvarofficial/teardown](https://github.com/elvarofficial/teardown) | Starter Bundle creative and 3D tooling. This kit installs none of them. |
| awesome-opus5-5-videos | [yihui-dev/awesome-opus5-5-videos](https://github.com/yihui-dev/awesome-opus5-5-videos) | Prompt gallery; reference only. |
| CLibDT | CommonLib/SKSE developer tool, GPL-3.0-only | Skyrim Forge / bundle. Not catalogued. |
| nx, turbo, vite, webpack | upstream release pages | JavaScript build tooling. When rebuilding a recovered web or Electron app, use the versions in that project's lockfile. |

No snapshot was vendored wholesale. MIT or Apache-2.0 files can be considered individually when a concrete missing feature warrants reuse, retaining their actual notices and exact revision provenance. The observations above do not grant rights over third-party dependencies, target games or extracted assets. Context Mode remains a separately licensed upstream component. Prefer owner installers and existing installed commands to copying redundant source trees.
