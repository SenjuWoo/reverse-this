# Task routes and supplied source snapshots

Use these three independent repositories together when their tasks overlap:

| Work | Owner |
|---|---|
| Shared compilers, agent setup, provider skills and scoped MCPs | [Ultimate AI Starter Bundle](https://github.com/SenjuWoo/Ultimate-AI-Starter-Bundle) |
| Skyrim plugin/script/assets authoring and validation, houseCARL | [Skyrim Forge](https://github.com/SenjuWoo/SkyrimForge) |
| App/game binary analysis, extractors, instrumentation and REA | [Reverse THIS!](https://github.com/SenjuWoo/reverse-this) |

Each installs independently and consumes verified existing installations. The workbench's standalone prerequisites are described in [standalone.md](standalone.md). Companion recommendations do not install a second provider stack, grant trust, register all MCP schemas or run an upstream account setup command.

The supplied `Tools` folder was inspected on 2026-10-26. These are observations of those local snapshots, not claims that their folder names identify the latest upstream revision:

| Snapshot | Verified manifest/license | Task and reuse decision |
|---|---|---|
| `rea-main` | `package.json`: rea-agents 6.7.0; `LICENSE`: MIT, 2026 morluto | Reference source for REA. The owner kit uses integrity-pinned 6.8.0; do not replace it with this older snapshot. The official [6.8.0 npm record](https://registry.npmjs.org/rea-agents/6.8.0) identifies the package/integrity. No v6.8.0 Git tag or gitHead was present in the checked upstream metadata. |
| `universal-modder-main` | `pyproject.toml`: universal-modder 0.2.0, Python >=3.10; `LICENSE`: MIT | [Universal Modder](https://github.com/rehan-remade/universal-modder) supplies game reconnaissance, field notes and asset/capture workflows. Reuse an installed `um`; the bundle already ships this version. Follow its upstream isolated installation when the bundle is absent. Paid generation is optional. |
| `CLI-Anything-main` | `LICENSE`: Apache-2.0 | [CLI-Anything](https://github.com/HKUDS/CLI-Anything) supplies task-specific application CLI harnesses. Select the relevant Blender, Godot, graphics, browser or other harness when it fills the actual task; consult its hub and harness prerequisites. This source collection is not another binary analysis toolkit. |
| `context-mode-main` | `package.json`: context-mode 1.0.169, Node >=22.5.0, Elastic-2.0; `LICENSE`: Elastic License 2.0 | [Context Mode](https://github.com/mksglu/context-mode) is an optional agent-context/plugin workflow. Evaluate it against the host's existing context tools and provider configuration. Its ELv2 terms are distinct from MIT; do not merge/relicense its source into the workbench or replace existing hooks silently. |

No snapshot was vendored wholesale. MIT or Apache-2.0 files can be considered individually when a concrete missing feature warrants reuse, retaining their actual notices and exact revision provenance. The observations above do not grant rights over third-party dependencies, target games or extracted assets. Context Mode remains a separately licensed upstream component. Prefer owner installers and existing installed commands to copying redundant source trees.
