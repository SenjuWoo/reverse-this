# Reverse THIS! 1.6.0 — verified handoff (2026-10-27)

- Adds optional replica-skill (Jakeschincariol/replica-skill, MIT) as a github-archive catalog entry; catalog 59 tools. Release: https://github.com/SenjuWoo/reverse-this/releases/tag/v1.6.0 from a6029396ca591e310070144b10f99727aed0cb6f (PR #14). Exact-commit CI PASS; alerts 0/0/0.
- ZIP 64,634 bytes; SHA256 38cf2df03f9de2daaeb8d7b45b4d8a31f1499e703ee5d1c08d23bff59a444199; two builds identical; downloaded asset matches build and GitHub digest.
- Install proof: isolated -InstallRoot install and live install both ok=1; receipt records upstream commit 77c9436. Skills copied to ~/.claude/skills (11 replica-*, none pre-existing).
- Live owner: the registered kit Reverse-This-1.2.1 no longer existed (stale pointer); pointer backed up as kit.json.pre-1.6.0-stale and this checkout registered as owner with only replica-skill installed. Other catalog tools are not installed here; run install.cmd for them.
- Local env: tests/test_installer.ps1 and test_entrypoint.ps1 fail on this machine identically on main (cmd delayed-expansion/path); CI passes both shells.
- Last good: 1.5.0.

- Adds optional replica-skill (Jakeschincariol/replica-skill, MIT) as a github-archive catalog entry; catalog 59 tools. Real isolated install PASS (receipt records commit 77c9436). Last good: 1.5.0 (v1.5.0). Run: install.cmd; Install-Modkit.ps1 -Doctor. CI/release evidence below once complete.

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

# Reverse THIS! 1.4.1 verified release handoff

- Goal: independently installable analysis tools with one owner, shared runtimes and preserved private targets/settings.
- Published: https://github.com/SenjuWoo/reverse-this/releases/tag/v1.4.1 from b21a41427dd38cbb6f76cd00ddcca9df8808781e (PR #8). Exact-main CI/security PASS.
- Public ZIP: 108,340 bytes; SHA256 76b7ce541f313defbecb832a14dac4b8934a5fa8fde2ca1724639244306f0826. Both public assets match the deterministic local build, GitHub digests and checksum file. Extracted PowerShell 5.1/7 and catalog checks PASS.
- Fixed: PowerShell 5.1 stripped dictionary-key quotes from the shared Python probe. Quote-free construction retains all validation. A real native Python regression fails before the fix and passes afterward; production discovery handles multiple launchers.
- Validation: all offline installer tests in both shells, catalog 58 entries, exact-SHA CI/security, deterministic double build, CRC/extraction and downloaded bytes. One Windows runner timed out at batch startup; its failed job passed on retry without code/test changes.
- Source implementation/publication remaining: none. The approved live source is 1.4.1; its selected tool update completed 56 successful, zero failed, followed by the owner doctor. Official shared Python 3.14.10 is installed in place. Bundle STATE.md tracks cross-product/provider certification and the required AI-app reconnect.
- Last good rollback: 1.4.0 at 979fa17c7a9b7687a433e4f6a1e4689940d3b756; prior releases, payload/state backups and private work retained. No tag or asset was replaced.
- Companions: Starter Bundle owns general AI/build tools; Skyrim Forge owns Skyrim tooling/SDK guidance. Both are optional and mutually recommended.
- Run: install.cmd; read-only checks: Install-Modkit.ps1 -Doctor/-Offline. Update-ReverseThis.ps1 updates verified public source; Install-Modkit.ps1 refreshes the existing selection.
- Logs: <kit>/sandbox/log/modkit.log and source-update.log. Private tools, targets, state and backups remain outside Git/releases. Actual game/app GUI targets, paid APIs and guest sessions are not certified by source gates.
