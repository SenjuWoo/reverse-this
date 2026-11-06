# Reverse THIS! state (2026-11-05)

- Goal: one Windows RE/modding workbench with stable `sandbox/bin` shims, one owner kit and preserved private targets.
- Version: 1.14.2, released at f9e8c300364bd1e1b432da59c73e6d6e22f4cd59 (CI 8/8 green). ZIP 148,932 bytes, sha256 851df4ce11dcc529ed7aa43ace14871c6c2beee14783034d9fb0f8899f243c31; all 55 manifest entries and the packaged `Maintain.ps1 -Test` check verified. 1.14.1 contains the correctness fixes; 1.14.2 only logs the optional scheduled task.
- Local kit: 1.14.1 source installed at the moved path; full update ok=90 failed=0, 92 catalog tools, NeoXtractor v3.3, Doctor clean after receipt hardening.
- Integrity: cached installs must match every file hash in their existing receipt; changed/missing receipts are rejected and recoverable. Doctor also reports those changes.
- Maintenance: `maintain.cmd` reports; `-Apply` removes only owned temps/caches/rollback copies, refuses reparse points, honors `.install.lock`, and repairs `kit.json` plus `installed.json` together with backups. `-Test` works from the packaged ZIP; `Register-Maintenance.ps1` is explicit opt-in and logs to `%LOCALAPPDATA%\ReverseThis\maintenance.log`.
- Bundle sync: bundle 8.35.1 owns shared runtimes/providers and adopts this moved kit; `scripts/check_companions.py` passes. Bundle-Splits and `Ai tools` forges are separate owners and are documented, not duplicated.
- Addon boundary: Reverse THIS! supplies extraction, conversion, instrumentation and REA only. It does not install game Forges, Unity MCPs, Blender, image-stack presets or model assets.
- Next: none for 1.14.2; keep owner pointers and sibling links current.
- Known limits: REA 6.8.0 rejects Ghidra 12.2; upstream main accepts 12.x but is unreleased. Context7 submission was declined; agents read `encyclopedia/` from disk. Doctor checks files/receipts, not every GUI or target.
- Run: `install.cmd` or `powershell -NoProfile -ExecutionPolicy Bypass -File Install-Modkit.ps1`; check with `-Doctor`. Logs: `sandbox/log/modkit.log`.
- Build/release: bump VERSION + CHANGELOG on main; the release workflow publishes after green CI (two identical builds, attestation, byte re-check). Manual build: `python scripts/build_release.py <zip> --commit <sha>`.
- History: CHANGELOG.md and git log. This file holds the current state only.
