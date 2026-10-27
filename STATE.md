# Reverse THIS! 1.4.1 compatibility patch

- Live integration found that PowerShell 5.1 strips the embedded dictionary-key quotes from Python -c. The interpreter is healthy; the 1.4.0 fake-runtime fixture did not exercise native argument parsing.
- Fix: use quote-free dictionary keyword construction; keep all existing base-runtime, venv and version validation. Add a real Python boundary in both CI shells.
- Regression: new native test failed before the production fix on PowerShell 5.1. All offline installer regressions and the real Python probe pass in PowerShell 5.1 and 7; catalog 58 entries PASS. Publication remains pending.
- Previous verified release/rollback: 1.4.0 at 979fa17c7a9b7687a433e4f6a1e4689940d3b756. Existing live source is 1.4.0; tool payloads and personal settings were preserved when the probe failed.
- Next: dual-shell validation, exact-SHA CI/security, deterministic 1.4.1 source archive, downloaded-byte proof, then approved live update through the bundle.
- Run: install.cmd; read-only checks: Install-Modkit.ps1 -Doctor. Logs: <kit>/sandbox/log/modkit.log and source-update.log. Private tools, state, backups and targets remain outside Git/releases.
