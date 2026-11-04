# Reverse THIS! state (2026-11-03)

- Goal: one Windows RE/modding workbench with stable `sandbox/bin` shims, one owner kit and preserved private targets.
- Version: 1.13.2 (candidate). Last known good: v1.13.1 at 2d2ccfd5ab493f7ecaae5c62581e84cad9871a34.
- Owner kit: this checkout (`%LOCALAPPDATA%\ReverseThis\kit.json`). 92 catalog tools installed; live update 2026-11-03 ok=90 failed=0 across the 92 catalog entries; Doctor clean.
- Done in 1.13.2: GH_TOKEN/GITHUB_TOKEN fallback for the GitHub API; `rea` shim wires `GHIDRA_INSTALL_DIR`; Context7 claims corrected (not indexed); REA agent row; companion snapshot table refreshed; ledgers trimmed to current state.
- Known limits: REA 6.8.0 rejects Ghidra 12.2 (`unsupported_version`); fixed upstream on main, not yet released. Bump `rea` `package_version`/`npm_integrity` when npm publishes it. Context7 indexing needs a submission at context7.com by the owner. Doctor checks files and receipts, not every GUI or target.
- Next: when a new rea-agents release lands, bump the pin and confirm `rea doctor` shows ghidra-version healthy.
- Run: `install.cmd` or `powershell -NoProfile -ExecutionPolicy Bypass -File Install-Modkit.ps1`; check with `-Doctor`. Logs: `sandbox/log/modkit.log`.
- Build/release: bump VERSION + CHANGELOG on main; the `release` workflow publishes after green CI (two identical builds, attestation, byte re-check). Manual build: `python scripts/build_release.py <zip> --commit <sha>`.
- History: CHANGELOG.md and git log. This file holds the current state only.
