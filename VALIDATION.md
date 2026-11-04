# Validation gates

Run before every release; CI runs the same on both Windows PowerShell 5.1 and PowerShell 7.

| Gate | Command |
|---|---|
| Catalog, encyclopedia, delivery, kit helpers | `python tests/test_catalog.py`, `test_encyclopedia.py`, `test_delivery.py` (needs committed VERSION), `test_kit_tools.py` |
| Installer regressions (offline) | `tests/test_installer.ps1` |
| Isolation, entrypoint, .NET, standalone | `tests/test_isolation.ps1`, `test_entrypoint.ps1`, `test_dotnet_prerequisite.ps1`, `test_standalone.ps1` |
| Runtime smoke (installed kit) | `tests/test_tool_smoke.ps1` |
| Companion contract | `python scripts/check_companions.py` |
| Live kit | `Install-Modkit.ps1` then `-Doctor` |

## Latest local results (2026-11-03, 1.13.2 candidate, Windows PowerShell 5.1)

All six PowerShell suites and the four Python suites pass; companions check passes; live update ok=90 failed=0 and Doctor clean. PowerShell 7 is covered by CI only (no `pwsh` on this machine).
