# Reverse THIS! 1.9.0 encyclopedia + local helpers (2026-10-31)

- Goal: make the workbench's knowledge queryable by Context7 and give agents three deterministic local helpers, without weakening the catalog rules.
- Done: `context7.json` plus `encyclopedia/` (engine cards, 6-tier ladder, IPC seqlock, ReShade reprojection template, WARP/IPC harnesses, proxy bridge, Ghidra/Frida/AOB recipes, game notes, error registry). New `local-script` catalog method installs `pe-recon`, `aob-gen` and `ghidra-mcp-up` from `kit/`; `capstone` is the only new package dependency.
- Corrected the Gemini draft: BSA vs BA2, Ghidra MCP 8080/8081, ReShade effect depth is read-only as of the 6.x runtime (add-on/draw hook is the route), unsafe `CreateFileW` flag stripping, `pefile` not required. Details in `encyclopedia/VALIDATION.md`.
- Added `encyclopedia/CLAIMS.md`: every limit is scoped to tool, version and mechanism with an escape hatch and a re-test trigger; the encyclopedia test rejects permanent "impossible" wording.
- Added `encyclopedia/anticheat-risk.md`: anti-cheat is a risk tier, not a blanket ban, with dated Marvel Rivals and Monster Hunter Wilds policy evidence, cosmetic-only guidance and an explicit account-risk decision.
- Added modular composition docs: bundle base, Reverse THIS! optional RE layer, Forge specialist; ownership matrix, shared `UABS_PYTHON`/`UABS_TOOL_ROOTS` reuse, 7-Zip/DirectXTex reuse, no provider or ledger writes. Product ZIP now ships `context7.json` and `encyclopedia/` for the offline Context7 fallback.
- Validation: catalog 84; `test_encyclopedia` (including the claims policy) and `test_kit_tools` pass; `ipc_link_test.exe` and `fake_host_d3d11.exe` compile and pass; `pe-recon`, `aob-gen` and `ghidra-mcp-up` install into an isolated root and Doctor verifies their receipts.
- Next: run the full gate, then publish through the normal VERSION/CHANGELOG workflow if wanted. No live kit refresh or publication yet.
- Limits: the ReShade template was not compiled by ReShade here; it is syntax-reviewed and marked as post-process only. The game field notes are design records with hashes marked not recorded. Ghidra/Frida recipes are not exercised against a live target.

# Reverse THIS! 1.8.0 catalog expansion (2026-10-31)

- Goal: close the remaining generic app and game-modding gaps without weakening the one-asset, digest-verified install rules.
- Done: 21 new tools — native (UPX, YARA, GoReSym, Dependencies, Rizin, System Informer, FLOSS), JVM/Android (Vineflower, uber-apk-signer), Unity scripting (UnityPy), and engines (WolvenKit GUI/CLI, Mod Engine 2, Smithbox, Crowbar, BSPSource, Source 2 Viewer GUI/CLI, UndertaleModTool GUI/CLI, RPFM). Catalog is now 80 tools.
- Upstream audit: all 41 existing GitHub-release patterns still match exactly one asset; every new pattern was tested the same way. ILSpy v11.2 (build 11.2.0.10050, commit c86190ef) is the current release and the kit's self-contained zip remains the right asset.
- Validation: `python tests/test_catalog.py` (80 tools), `-SelfTest`, `-Plan`, and the installer, isolation, entrypoint, .NET prerequisite, standalone and product-delivery suites all pass. All 21 new tools were installed into an isolated `-InstallRoot` and `-Doctor` verified every receipt; the live kit was not refreshed.
- Released: v1.8.0 published by release.yml from 73ee31ff2f73b94246cbc309b02cf1cdc3754de9; Reverse-This-1.8.0.zip sha256 7865a43c20f5ad0eef5fa0f10cb405ac519c0d4a7f49d321ef3a0667cd905366 (71,142 bytes). Exact-SHA checks passed; SHA256SUMS, build attestation, downloaded bytes and RELEASE.json file hashes verified; alerts 0/0/0, code quality unavailable and left off.
- Next: refresh the live kit with `install.cmd` when wanted (59 tools installed; the 21 new ones are pending). No live kit refresh was performed by this change.
- Limits: all 21 new tools were installed and receipt-verified in an isolated root; their GUI applications were not launched and no game target was modified. REFramework, CodeWalker, Cutter, RetDec and de4dot stay manual/excluded as documented.

# Reverse THIS! 1.7.0 independent releases (2026-10-29)

- Goal: a changed tool binary is detected, and releases need no human step.
- Done: digest-verifying doctor (CHANGED/UNVERIFIED states, regression test); self-publishing `release.yml` with build attestation; Dependabot auto-merge; ownership linked to the bundle README.
- Supersedes the uncommitted 1.6.2 plan left in the live kit: its integrity item shipped here as real verification; a VERSION.txt mirror stays rejected (the bundle reads `VERSION`); the source provenance item is covered by the release attestation and RELEASE.json.
- Released: v1.7.0 published by release.yml from acee844903b04dffb70e3a444907c104c60cbd85 (Reverse-This-1.7.0.zip sha256 32da083f29b03a8921a419de415354fe48013ee7a554adb2cd337c3a9968a747; SHA256SUMS and build attestation verified). Live kit updated by git to 1.7.0; doctor verifies all 59 tools by digest.
- After 1.7.0: `release.yml` decides inside the job (no job-level `if`), so a CI run cancelled by a newer push ends as a no-op release run instead of a skipped one that GitHub files under main's newest commit and that reads as a failed exact-SHA verdict; `tests/test_delivery.py` pins it. CI-only, no release.
- Next: nothing pending. Push to main after the local tests; a VERSION bump with its CHANGELOG section publishes itself.

# Reverse THIS! 1.6.1 — verified handoff (2026-10-28)

- Complete: truthful standalone companion patch; shared tools reuse their recorded owner, and Skyrim Forge remains optional. Installer/catalog/tool versions are unchanged by this documentation patch.
- Published: https://github.com/SenjuWoo/reverse-this/releases/tag/v1.6.1 ; immutable tag 2d30d7352230e5d69371f29833c19b01e2ad964b (PR 16). Exact main and tag checks passed; alerts 0/0/0, code quality unavailable and left off.
- Product ZIP: 64,697 bytes; SHA256 c71b497ac846cb7d51458fa6e00480a94ad4fc6424bbe3b48cd06d23fabcfc7b. Two frozen builds byte-identical; both public assets downloaded and matched local bytes, GitHub digests and SHA256SUMS.
- Corrected replica-skill provenance: default-branch discovery resolves a full immutable commit and records the archive digest; NoUpdate retains that recorded version.
- Validation: catalog 59; product tests 2/2; installer, real batch entrypoint, isolation, .NET prerequisite and standalone suites PASS in Windows PowerShell 5.1 and 7. Extracted SelfTest/Plan PASS in both shells. Previously recorded local batch failures no longer reproduce.
- Live: registered canonical checkout owner refreshed with NoUpdate, 59 success/0 failures, doctor PASS. All 59 tool records and owner pointer remained unchanged; only kit_version advanced. Older claim that only replica-skill was installed is superseded.
- Recovery/evidence: sandbox/backups/live-1.6.1-ef5eaa85faf74add9e501682d2d29332; sandbox/log/audit-*.log; sandbox/tmp/release-1.6.1/verified.local.json. Prior releases/tags intact; last good 1.6.0.
- Branch audit: all ten pre-existing remote topic refs are ancestry-merged into main; no unmerged work. PR 16 squash tree exactly equals its task tree; remote/local task ref removed after verification. Historic merged refs are reported, not force-deleted.
- Build/run: python scripts/build_release.py <new-output.zip> --commit <tested-SHA>; install.cmd; Install-Modkit.ps1 -Doctor. Next: no product or deployment work remains; use install.cmd for a later requested update. Source-only handoff checks do not move the release tag.
- Limits: file/receipt doctor is not proof for every real target or GUI. Actual game targets, guest Sandbox and paid inference/API runtime were not exercised; source/archive tests cover the documented command and ownership boundaries.

## Historical handoffs (superseded where noted)

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
