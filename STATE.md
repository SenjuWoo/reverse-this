# Reverse THIS! state (2026-11-05)

- Goal: one Windows RE/modding workbench with stable `sandbox/bin` shims, one owner kit and preserved private targets.
- Version: 1.13.3, released at 3c9c189f9d059e339cbb45cb75098402ce27b875 (8/8 exact-SHA checks green). ZIP 146,264 bytes, sha256 ad25896e73418f10db0c4670454917bf263b61188e25a0789b5634f1f9f74ba0; all 52 manifest entries and the downloaded asset verified. The bundle's `Install-ReverseThis.ps1 -ResolveOnly` resolves this moved checkout.
- Local kit: 1.13.3 installed at the moved path, 92 catalog tools, NeoXtractor v3.3, Doctor clean. The 1.13.3 diff is documentation-only; no tool payload changed.
- Bundle sync: bundle 8.35.1 owns shared runtimes/providers and adopted this moved kit; `scripts/check_companions.py` passes. Bundle-Splits (`img2threejs`, `uabs-image-stack`/comfy-kit) and `Ai tools` forges are separate owners and are documented, not duplicated.
- Addon boundary: Reverse THIS! supplies extraction, conversion, instrumentation and REA only. It does not install game Forges, Unity MCPs, Blender, image-stack presets or model assets.
- Next: none for 1.13.3; keep sibling owners as documented links.
- Known limits: REA 6.8.0 rejects Ghidra 12.2; upstream main accepts 12.x but is unreleased. Context7 submission was declined; agents read `encyclopedia/` from disk. Doctor checks files/receipts, not every GUI or target.
- Run: `install.cmd` or `powershell -NoProfile -ExecutionPolicy Bypass -File Install-Modkit.ps1`; check with `-Doctor`. Logs: `sandbox/log/modkit.log`.
- Build/release: bump VERSION + CHANGELOG on main; the release workflow publishes after green CI (two identical builds, attestation, byte re-check). Manual build: `python scripts/build_release.py <zip> --commit <sha>`.
- History: CHANGELOG.md and git log. This file holds the current state only.
