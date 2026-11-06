# Reverse THIS! state (2026-11-05)

- Goal: one Windows RE/modding workbench with stable `sandbox/bin` shims, one owner kit and preserved private targets.
- Version: 1.13.3 (documentation/sync release). Owner checkout moved to `Tools/Github/reverse-this`; the bundle adopted the moved receipt rather than creating a second kit.
- Local kit: 1.13.2 installed at the moved path, 92 catalog tools, NeoXtractor v3.3, Doctor clean. 1.13.3 changes docs only; the local installer state will be refreshed after release.
- Bundle sync: bundle 8.35.1 owns shared runtimes/providers and adopted this moved kit; `scripts/check_companions.py` passes. Bundle-Splits (`img2threejs`, `uabs-image-stack`/comfy-kit) and `Ai tools` forges are separate owners and are documented, not duplicated.
- Addon boundary: Reverse THIS! supplies extraction, conversion, instrumentation and REA only. It does not install game Forges, Unity MCPs, Blender, image-stack presets or model assets.
- Next: publish 1.13.3 after exact-SHA CI; then refresh the local kit and verify Doctor.
- Known limits: REA 6.8.0 rejects Ghidra 12.2; upstream main accepts 12.x but is unreleased. Context7 submission was declined; agents read `encyclopedia/` from disk. Doctor checks files/receipts, not every GUI or target.
- Run: `install.cmd` or `powershell -NoProfile -ExecutionPolicy Bypass -File Install-Modkit.ps1`; check with `-Doctor`. Logs: `sandbox/log/modkit.log`.
- Build/release: bump VERSION + CHANGELOG on main; the release workflow publishes after green CI (two identical builds, attestation, byte re-check). Manual build: `python scripts/build_release.py <zip> --commit <sha>`.
- History: CHANGELOG.md and git log. This file holds the current state only.
