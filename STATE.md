# Reverse THIS! state (2026-11-05)

- Goal: one Windows RE/modding workbench with stable `sandbox/bin` shims, one owner kit and preserved private targets.
- Version: 1.14.0, released at 4dc9e59eb7ab3f22cf5cfe569b6e626bdce8201b (8/8 exact-SHA checks green). ZIP 144,224 bytes, sha256 341f055b01a026d9427b34f1facf772fc2918ee2e182d8dd42dd1867ef79e1ac; all 54 manifest entries and the downloaded asset verified.
- Local kit: 1.14.0 source installed at the moved path; full update ok=90 failed=0, 92 catalog tools, NeoXtractor v3.3, Doctor clean.
- Maintenance: `maintain.cmd` reports; `-Apply` prunes only kit-owned temps/caches and old rollback copies (newest two retained), repairs a stale pointer after a move; `-UpdateTools` and `-Test` are explicit. Weekly CI check is read-only.
- Bundle sync: bundle 8.35.1 owns shared runtimes/providers and adopts this moved kit; `scripts/check_companions.py` passes. Bundle-Splits and `Ai tools` forges are separate owners and are documented, not duplicated.
- Addon boundary: Reverse THIS! supplies extraction, conversion, instrumentation and REA only. It does not install game Forges, Unity MCPs, Blender, image-stack presets or model assets.
- Next: none for 1.14.0; keep owner pointers and sibling links current.
- Known limits: REA 6.8.0 rejects Ghidra 12.2; upstream main accepts 12.x but is unreleased. Context7 submission was declined; agents read `encyclopedia/` from disk. Doctor checks files/receipts, not every GUI or target.
- Run: `install.cmd` or `powershell -NoProfile -ExecutionPolicy Bypass -File Install-Modkit.ps1`; check with `-Doctor`. Logs: `sandbox/log/modkit.log`.
- Build/release: bump VERSION + CHANGELOG on main; the release workflow publishes after green CI (two identical builds, attestation, byte re-check). Manual build: `python scripts/build_release.py <zip> --commit <sha>`.
- History: CHANGELOG.md and git log. This file holds the current state only.
