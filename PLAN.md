# Current 1.9.2 overlap/sync rule — 2026-10-31

Goal: make overlap explicit and safe: one owner, detect before install, skip current, update older in place, preserve newer/unknown, never duplicate. README and `docs/standalone.md` state it; the second `pe-recon` install and the bundle shared-Python path were spot-verified. See STATE.md.

# Current 1.9.1 updater fix — 2026-10-31

Goal: deploy the encyclopedia/kit payload through the owner updater and the bundle's `reverse` pack. `Update-ReverseThis.ps1` now accepts `encyclopedia/` and `kit/`; the delivery test deploys the built product and checks it. See STATE.md for validation and limits.

# Current 1.9.0 encyclopedia — 2026-10-31

Goal: a Context7-indexed encyclopedia plus three deterministic local helpers, with the draft plan's technical errors corrected. Catalog 84 tools; `local-script` installs `pe-recon`, `aob-gen` and `ghidra-mcp-up`. See STATE.md for validation and limits.

# Current 1.8.0 catalog expansion — 2026-10-31

Goal: the catalog covers the remaining generic app and game-modding gaps with the same one-asset, digest-verified rules. Added 21 tools (80 total); re-verified all 41 existing GitHub-release patterns against current upstream releases. See STATE.md for validation and limits.

# Current 1.6.1 audit — 2026-10-28

Complete: corrected source-provenance documentation, verified both shell suites and the 59-tool live owner, converged release SHA CI/security, published the frozen double build and verified every public asset. Source-only handoff checks preserve the immutable release. See STATE.md.

# Reverse THIS! 1.5.0 — verified handoff (2026-10-27)

- Source/product complete. Frozen public tag v1.5.0: ab9b842d8a5f7bfce7c128f5f94c1421e3933723. Later handoff commits update documentation only.
- Exact-commit checks and dual-shell installer/catalog/archive gates PASS; security alerts 0/0/0, code quality unavailable and left off. Extracted SelfTest/Plan PASS without writing state. Runtime SelfTest inputs live in catalog, not developer tests.
- Product ZIP 64,217 bytes; SHA256 5734af455687f5c4345a497f8ea672e6fb0d2249f060e79ada36628b09b8a7ca. Two builds identical. Both public assets downloaded and match build bytes, GitHub digests and checksums.
- Approved existing live owner upgraded to 1.5.0, with source backups retained under sandbox/backups/source-1.5.0-62f9c745017b4caab100684cbb66b0b4. Existing selection refreshed with NoUpdate: 56 succeeded, 0 failed; read-only doctor PASS. Private target work and tool versions preserved.
- Last-good prior source: 1.4.1. Run: install.cmd; Install-Modkit.ps1 -Doctor; source tests: python tests/test_delivery.py and tests/test_standalone.ps1. Build: python scripts/build_release.py <new-output.zip> --commit <tested-SHA>. Logs: installed sandbox/log/modkit.log and source-update.log; detailed logs opt in with DebugLog.
- Evidence: Starter Bundle artifacts/final-assurance/reverse150-final/verified/final.local.json and reverse150-live-*.log. Bundle owns the global three-repository handoff and its pending Forge/bundle phases.
- Exact limits: doctor checks files/receipts, not every real target/GUI; no guest Sandbox or paid API/inference proof. No further Reverse implementation/release work remains.

# Final assurance 1.5.0 candidate (2026-10-27)

Ownership, frozen-commit product builder and transactional obsolete-file retirement implemented. Real archive regression and source-upgrade tests PASS. Full dual-shell gates, exact-SHA CI/security, release-byte proof and approved live refresh pending. Last good: 1.4.1; log/evidence: Starter Bundle artifacts/final-assurance. Run: install.cmd; tests/test_standalone.ps1; python scripts/build_release.py <new-output.zip> --commit <tested-SHA>. Historical evidence below.

# Standalone workbench 1.4.1

Keep Reverse THIS!, Skyrim Forge and the Starter Bundle independent. Reuse the registered workbench and shared runtimes; preserve private tools, state, user settings and newer compatible software.

1. Resolve the canonical owner receipt before installing; expose an isolated root override for tests.
2. Discover shared Python/Node and provision only missing compatible prerequisites through their official managers.
3. Resolve owned package updates while keeping pins, newer compatible versions and rollback behavior; add explicit no-update/offline modes.
4. Validate explicit external-tool receipts and keep their owner paths; add a digest-verified source-only release updater.
5. Document companion routing, snapshot provenance and exact limits; run the offline PowerShell 5.1/7 and catalog gates in an isolated copy.

Completion requires passing offline boundaries and a clean reviewed source diff. No live deployment, publication or target execution belongs to this change.
