# Validation gates

Run before every release; CI runs the same on both Windows PowerShell 5.1 and PowerShell 7.

| Gate | Command |
|---|---|
| Catalog, encyclopedia, delivery, kit helpers | `python tests/test_catalog.py`, `test_encyclopedia.py`, `test_delivery.py` (needs committed VERSION), `test_kit_tools.py` |
| Ghidra health/MCP probes | `python tests/test_ghidra_mcp_up.py` |
| AOB masking, PE bounds, overlap and section fixtures | `python tests/test_aob_gen.py` (Capstone test dependency) |
| PE parser malformed/valid fixtures | `python tests/test_pe_recon.py` |
| Companion parser fixtures (live checker is scheduled/manual) | `python tests/test_companions.py` |
| Upstream currency report fixtures | `python tests/test_upstreams.py` |
| Installer regressions (offline) | `tests/test_installer.ps1` |
| Isolation, entrypoint, .NET, standalone | `tests/test_isolation.ps1`, `test_entrypoint.ps1`, `test_dotnet_prerequisite.ps1`, `test_standalone.ps1` |
| Maintenance ownership, retention and scheduled previews | `tests/test_maintain.ps1`, `tests/test_register_maintenance.ps1` |
| Windows release delivery | `python tests/test_delivery.py` with `PSHOST` set to `powershell.exe` or `pwsh` |
| Runtime smoke (installed kit) | `tests/test_tool_smoke.ps1` |
| Companion live contract | `python scripts/check_companions.py` (scheduled/manual) |
| Critical upstream currency | `python scripts/check_upstreams.py` (read-only report) |
| Live kit | `Install-Modkit.ps1` then `-Doctor` |

## Comparing a local build with a release

`build_release.py` pins `core.autocrlf=false` and `core.eol=lf`, so a Windows build has the same file contents (and `RELEASE.json`) as the CI build. Zip bytes can still differ across hosts because Python builds ship different deflate libraries; compare extracted contents or `RELEASE.json`, not the zip hash. CI compares two builds on the same runner byte for byte.

## Latest local results (2026-11-06, 1.14.7 candidate, Windows PowerShell 5.1)

58 Python checks passed: catalog/encyclopedia/delivery scripts, 15 Ghidra MCP
fixtures, 12 AOB fixtures, 6 PE parser fixtures, 5 kit-tool checks, 4 companion
fixtures and 11 upstream-report fixtures. All seven PowerShell suites passed,
including owner-failure propagation, ambiguous-owner refusal, strict task
templates, wrong-root removal refusal, missing-pointer parent creation, linked
cleanup refusal and zero-mutation `-WhatIf` previews. Live companion contract
passed. The extracted product runs `pe_recon.py`, starts `aob_gen.py` and runs
the packaged upstream checker in offline mode without the source module path.
Doctor exits 0; existing legacy rows without shim digests emit explicit
regeneration warnings until the shim receipt is refreshed. PowerShell 7 and the
Windows delivery path under `PSHOST=pwsh` are covered by CI only; no `pwsh` is
installed locally.
