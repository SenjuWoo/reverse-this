# Reverse THIS! state (2026-11-06)

- Goal: one Windows RE/modding workbench with stable `sandbox/bin` shims, one owner kit and preserved private targets.
- Version: 1.14.3, released at 0a5b166afae08fc76d050d564798943dcddad3e4 (CI 8/8 green). ZIP 149,533 bytes, sha256 65aa5728542cd414638e940fd13acfab7f1cf38fec60c10d6ae731302a65cc62; all 55 manifest entries and the packaged `Maintain.ps1 -Test`/`-Apply` checks verified.
- Local kit: source 1.14.3 at the moved path; last full tool update ok=90 failed=0, 92 catalog tools, NeoXtractor v3.3, Doctor clean after receipt hardening.
- Integrity: cached installs must match every file hash in their existing receipt; changed/missing receipts are rejected and recoverable. Doctor also reports those changes.
- Maintenance: `maintain.cmd` reports; `-Apply` removes only owned temps/caches/rollback copies, refuses reparse points, honors `.install.lock`, and repairs either owner record independently with backups. `-Test` works from the packaged ZIP; `Register-Maintenance.ps1` is explicit opt-in, honors `-WhatIf` for run/remove/register, and logs to `%LOCALAPPDATA%\ReverseThis\maintenance.log`.
- Scheduled task: it stores an absolute owner path. After moving the kit, re-register from the new root; the old task fails visibly instead of running stale source. Re-registration reports an obsolete owner before replacement.
- AOB/CI: `capstone==5.0.9` is a pinned test dependency in both CI jobs; the three encoding fixtures are mandatory, not skipped.
- Bundle sync: bundle 8.35.1 owns shared runtimes/providers and adopts this moved kit; `scripts/check_companions.py` passes. Bundle-Splits and `Ai tools` forges are separate owners and are documented, not duplicated.
- Addon boundary: Reverse THIS! supplies extraction, conversion, instrumentation and REA only. It does not install game Forges, Unity MCPs, Blender, image-stack presets or model assets.
- Next: none for 1.14.3; keep owner pointers and sibling links current.
- Known limits: REA 6.8.0 rejects Ghidra 12.2; upstream main accepts 12.x but is unreleased. Context7 submission was declined; agents read `encyclopedia/` from disk. Doctor checks files/receipts, not every GUI or target.
- Run: `install.cmd` or `powershell -NoProfile -ExecutionPolicy Bypass -File Install-Modkit.ps1`; check with `-Doctor`. Logs: `sandbox/log/modkit.log`.
- Build/release: bump VERSION + CHANGELOG on main; the release workflow publishes after green CI (two identical builds, attestation, byte re-check). Manual build: `python scripts/build_release.py <zip> --commit <sha>`.
- History: CHANGELOG.md and git log. This file holds the current state only.
