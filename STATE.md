# Reverse THIS! state (2026-11-05)

- Goal: one Windows RE/modding workbench with stable `sandbox/bin` shims, one owner kit and preserved private targets.
- Version: 1.14.1, released at b4368825f58ccdbd8fd318a39724bf2e0a052638 (8/8 exact-SHA checks green). ZIP 148,774 bytes, sha256 732a3bf4f6b4440962fd8d87a6b52d8d26eec76736dd5645443bacd0b9c746a5; all 55 manifest entries and the packaged `Maintain.ps1 -Test`/`-Apply` checks verified.
- Local kit: 1.14.1 source installed at the moved path; full update ok=90 failed=0, 92 catalog tools, NeoXtractor v3.3, Doctor clean after receipt hardening.
- Integrity: cached installs must match every file hash in their existing receipt; changed/missing receipts are rejected and recoverable. Doctor also reports those changes.
- Maintenance: `maintain.cmd` reports; `-Apply` removes only owned temps/caches/rollback copies, refuses reparse points, honors `.install.lock`, and repairs `kit.json` plus `installed.json` together with backups. `-Test` works from the packaged ZIP; `Register-Maintenance.ps1` is explicit opt-in.
- Bundle sync: bundle 8.35.1 owns shared runtimes/providers and adopts this moved kit; `scripts/check_companions.py` passes. Bundle-Splits and `Ai tools` forges are separate owners and are documented, not duplicated.
- Addon boundary: Reverse THIS! supplies extraction, conversion, instrumentation and REA only. It does not install game Forges, Unity MCPs, Blender, image-stack presets or model assets.
- Next: none for 1.14.1; keep owner pointers and sibling links current.
- Known limits: REA 6.8.0 rejects Ghidra 12.2; upstream main accepts 12.x but is unreleased. Context7 submission was declined; agents read `encyclopedia/` from disk. Doctor checks files/receipts, not every GUI or target.
- Run: `install.cmd` or `powershell -NoProfile -ExecutionPolicy Bypass -File Install-Modkit.ps1`; check with `-Doctor`. Logs: `sandbox/log/modkit.log`.
- Build/release: bump VERSION + CHANGELOG on main; the release workflow publishes after green CI (two identical builds, attestation, byte re-check). Manual build: `python scripts/build_release.py <zip> --commit <sha>`.
- History: CHANGELOG.md and git log. This file holds the current state only.
