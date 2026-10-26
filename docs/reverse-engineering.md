# Reverse-engineering routes, on demand

Pick the operation, not every tool with an RE label. All five providers use
these same CLIs; no RE MCP is registered globally by this recipe.

| Need | First choice |
| --- | --- |
| Identify an unfamiliar game, engine, loader and modding route | Installed `um scan "<verified game folder>" --format json`; Universal Modder guide |
| Disassembly/decompilation, APK/resources, assets, debugging | Existing Reverse THIS! tool shims, selected for the actual format |
| Evidence-linked static JavaScript/Electron or managed-assembly analysis | REA CLI; use its subcommand help, then retain/filter JSON locally |
| Skyrim records, Papyrus or framework syntax | Skyrim specialist skills/Forge; REA is not a replacement |

## Reuse Reverse THIS!

Resolve `%LOCALAPPDATA%\ReverseThis\kit.json`, parse its `kit_root`, and verify
that root, `sandbox/installed.json` and the selected `sandbox/bin` shim exist.
An explicit verified conversation path is a fallback. Do not search entire
drives or reinstall another Ghidra/Java/.NET/tool suite. Run the selected shim's
help or the kit's `Install-Modkit.ps1 -Doctor` before relying on it.
The folder named sandbox is **not** process isolation.

## REA CLI

The optional `rea` catalog component pins `rea-agents@6.8.0` and npm integrity;
Node ^22.23.4, ^24.22.1 or >=26.12.1 is required. If needed for the current authorized task,
install it through this standalone workbench; reuse an existing compatible shared Node runtime:

```powershell
powershell -NoProfile -File Install-Modkit.ps1 -Only rea
rea --help
rea analyze-javascript-application "<owned extracted app or ASAR>" --format json
```

Resolve the installed CLI from PATH. Other operations start with
`rea <subcommand> --help`; don't guess their arguments. Use an owned lab copy,
retain evidence/digests on disk and send only the fields the question needs to
the model. Static observations are not runtime behavior or recovered source.
Runtime capture, instrumentation and annotation are separate actions with side
effects; never run them merely to list capabilities.

Do not run `rea setup`, `rea update`, or an upstream skill installer over
bundle-managed provider trees. No extra REA skill collection is needed.
Windows native Ghidra support is experimental with specific Ghidra/JDK/format
requirements; discover the existing kit and check REA's provider doctor before
using that route. Static JavaScript analysis of an owned fixture was exercised with REA 6.8.0.

CLI-first avoids attaching a large MCP inventory to ordinary chats. A needed MCP
must be scoped and filtered using the current host's supported features. Measure
the installed version's actual schemas; old inventory sizes are not current
tool counts or billing measurements.

The official [REA 6.8.0 npm record](https://registry.npmjs.org/rea-agents/6.8.0)
was verified against the catalog integrity. Its metadata supplied no gitHead;
the upstream v6.8.0 Git ref was absent, so no invented exact-version Git link is used.

Sources: [REA upstream](https://github.com/morluto/rea),
[published 6.8.0 package](https://www.npmjs.com/package/rea-agents/v/6.8.0),
[Reverse THIS!](https://github.com/SenjuWoo/reverse-this).
