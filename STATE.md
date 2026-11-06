# Reverse THIS! state (2026-11-06)

- Goal: one Windows RE/modding workbench with stable `sandbox/bin` shims, one owner kit and preserved private targets.
- Version: 1.14.4, released at c81c207e2690b05b5680822a4962ae4026c354e9 (CI, CodeQL and release checks green). ZIP 153,672 bytes, sha256 0393ef1b7e380ee1cf2b633ec9a2ce2a4d6e699bebac205cc92436786e32f906; 56 manifest entries and packaged `Maintain.ps1 -Test`/`-Apply` verified.
- Local kit: source 1.14.4 at the moved path; last full tool update ok=90 failed=0, 92 catalog tools, NeoXtractor v3.3, Doctor clean after receipt hardening.
- Integrity: cached installs must match every file hash in their existing receipt; changed/missing receipts are rejected and recoverable. Doctor also reports those changes.
- Maintenance: `maintain.cmd` reports; `-Apply` removes only owned temps/caches/rollback copies, refuses reparse points, honors `.install.lock`, and repairs either owner record independently with backups. `-Test` works from the packaged ZIP; `Register-Maintenance.ps1` is explicit opt-in, honors `-WhatIf` for run/remove/register, and logs to `%LOCALAPPDATA%\ReverseThis\maintenance.log`.
- Scheduled task: it stores an absolute owner path and refuses a task without a Reverse THIS! owner marker. After moving the kit, re-register from the new root; the old task fails visibly instead of running stale source. Registration uses an encoded command and validates a real HH:mm time.
- AOB/CI: `capstone==5.0.9` is a pinned test dependency; 9 AOB fixtures cover overlapping matches, executable-section selection, PE bounds and masks. GhidraMCP health/MCP probes have 10 offline fixtures; no real bridge handshake was available on this machine.
- Windows delivery: `test_delivery.py` runs in both PowerShell 5.1 and 7 CI jobs through `PSHOST`; the live companion check stays scheduled/manual.
- Bundle sync: bundle 8.35.1 owns shared runtimes/providers and adopts this moved kit; `scripts/check_companions.py` passes. Bundle-Splits and `Ai tools` forges are separate owners and are documented, not duplicated.
- Addon boundary: Reverse THIS! supplies extraction, conversion, instrumentation and REA only. It does not install game Forges, Unity MCPs, Blender, image-stack presets or model assets.
- Next: none for 1.14.4; keep owner pointers and sibling links current.
- Known limits: REA 6.8.0 rejects Ghidra 12.2; upstream main accepts 12.x but is unreleased. Context7 submission was declined; agents read `encyclopedia/` from disk. Doctor checks files/receipts, not every GUI or target.
- Run: `install.cmd` or `powershell -NoProfile -ExecutionPolicy Bypass -File Install-Modkit.ps1`; check with `-Doctor`. Logs: `sandbox/log/modkit.log`.
- Build/release: bump VERSION + CHANGELOG on main; the release workflow publishes after green CI (two identical builds, attestation, byte re-check). Manual build: `python scripts/build_release.py <zip> --commit <sha>`.
- History: CHANGELOG.md and git log. This file holds the current state only.
