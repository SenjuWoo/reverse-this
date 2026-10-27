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

# Published 1.4.1 proof

Release commit b21a41427dd38cbb6f76cd00ddcca9df8808781e passed all attached main checks and security queries. Public ZIP 108,340 bytes, SHA256 76b7ce541f313defbecb832a14dac4b8934a5fa8fde2ca1724639244306f0826. Both assets match local reproducible bytes, GitHub digests and checksums. Extracted catalog and native Python/standalone checks pass in both shells. Live source 1.4.1 completed 56 selected tools with zero failures and its owner doctor; shared Python updated to 3.14.10 in place. The bundle tracks cross-provider certification and AI-app reconnect. This handoff does not change the release tag/assets.

# 1.4.1 native Python boundary (2026-10-26)

The added real-Python regression fails on unpatched Windows PowerShell 5.1; the existing canned stdout fixture passed. The fix removes embedded quotes from the Python expression without weakening validation. All six offline installer checks pass in PowerShell 5.1 and 7, including real Python 3.14.9; catalog 58 entries PASS. Exact-SHA CI/security and publication PASS; see proof above. The 1.4.0 evidence below covers the unchanged installer boundaries.

# Published 1.4.0 proof

Exact release commit 979fa17c7a9b7687a433e4f6a1e4689940d3b756 passed main CI/security. Both public assets were downloaded and matched the deterministic local build, GitHub digests and SHA256SUMS. ZIP SHA256 is 4087251269e6da95ffa563837ad4b6c684b4d60d52fe9873b3a6874351d5c24b (108,789 bytes). Extracted catalog/standalone checks passed. This post-publication handoff change is documentation-only and does not move the release tag or replace assets. Cross-product live proof is tracked in the Starter Bundle STATE.md.

## 1.4.0 standalone source verification (2026-10-26)

Source baseline: published 1.3.0 at f91aec703857d77cfa0d423ddbcbe77cb20c5cf2. No live kit, canonical pointer, game target or provider configuration was changed in this pass.

- Windows PowerShell 5.1 and PowerShell 7 each pass all seven offline checks (exit 0): `Install-Modkit.ps1 -SelfTest`, `Install-Modkit.ps1 -Plan`, `tests/test_installer.ps1`, `tests/test_isolation.ps1`, `tests/test_entrypoint.ps1`, `tests/test_dotnet_prerequisite.ps1` and `tests/test_standalone.ps1`.
- Every source `.ps1` passes AST parsing in both editions. `python -I tests/test_catalog.py` passes (exit 0): 58 tools, version 1.4.0. Retained receipts record PowerShell 5.1.26100.9711/7.6.5 and tested source hashes. The catalog uses the existing shared Python; no second base interpreter was installed.
- New boundaries cover canonical-owner reuse, invalid pointers, isolated roots, read-only Doctor/Offline with missing tools, unchanged shared-pointer bytes, explicit base-Python validation, manager patch-only requests, Node/npm compatibility/incomplete pairs, registry pin/latest selection, external owner hashes, newer owned releases and compatible unowned REA reuse. Older unowned REA fails without duplication.
- Runtime regressions retain Java/.NET bindings in NoUpdate, the JDK for normal reuse of a newer tool, and the selected compatible Node when a different Node leads the caller's PATH. Capa retains its matched version, repairs a missing signature file and uses external support paths. Existing archive, backup, atomic-JSON, transaction rollback, batch quoting/exit and .NET tests remain green.
- Actual local source archives exercise digest rejection, unchanged released-source promotion, retained last-good files, private-work preservation, edited-public-file refusal, new-path collision refusal, Git-root refusal, fresh empty/missing destination deployment and nonempty-unowned refusal. A deterministic hash-boundary fixture advances the prior valid release after the initial version read; the updater rechecks under its lock and preserves that newer release. Fixtures live outside Git ancestors so the same test works in CI checkouts.

CI resume: hidden AppData metadata probes now use forced read-only lookup, preserving reparse-point checks. The standalone fixture explicitly returns success after its expected failed child probes; both GitHub-style shell wrappers pass locally.

Source-only gate: SCOPE PASS; DIFF REVIEW PASS; BUILD/COMPILE N/A (scripts); TESTS/VALIDATORS PASS. PACKAGE INSPECTION/PUBLICATION pending in the parent release workflow. Real missing-prerequisite setup, online package/source release resolution, GUI/game targets and Sandbox guests were not retested. These offline results do not claim live deployment or public 1.4 byte verification.

## Historical 1.3.0 modular verification

Catalog: 58 tools. PowerShell 5.1/7 installer, isolation, entrypoint and .NET gates PASS. New pin mismatch, empty npm root-key, unowned REA reuse and self-shim exclusion fixtures PASS. Actual isolated REA 6.8.0 installation, owner Doctor, version/help and owned static-JavaScript fixture PASS. No Windows Sandbox guest or native target runtime was retested; existing unrelated-tool evidence remains in the prior release. Exact-SHA CI/security and public bytes pending.

# Validation

Historical source version: 1.2.1. Audit baselines: v1.1.0 at 94d27b7 and verified public v1.2.0 at 38f71b5. Previous source, release and installed-state rollback copies are retained.

- All six offline PowerShell checks pass in Windows PowerShell 5.1 and PowerShell 7: SelfTest, Plan, installer regressions, isolation configuration, real batch entrypoint and .NET prerequisites. Together with Python catalog validation, the local matrix passes 13/13 checks.
- Added regressions exercise unsafe ZIP rejection; failed package backups; matched capa rollback after parent/dependency failures; full catalog order and support-only group routing; nested pointer preservation; literal batch punctuation, environment and exit status; and native Windows sharing-lock recovery/exhaustion. Atomic replacement retries are bounded and preserve old/new files; permanent and partially renamed-file errors are surfaced. The process behind the earlier sporadic Win32 1175 error is unidentified.
- Current ilspycmd installs and launches through production functions/shims from a directory pinned to SDK 8.0.418, using the selected .NET 10 host and explicit net10.0 framework. Fake-command regressions cover missing/preview SDKs, runtime discovery, winget failure/rediscovery and environment restoration. This host already has .NET 10, so a real missing-runtime winget installation was not exercised here.
- Owner repair to 1.2.1 completed 55/55 transactions covering 57 records and 40 shims. Doctor passes all 57 entries; pointer extensions are preserved. Previous installed state/payloads and the versioned v1.2.0 release receipt remain available.
- Runtime checks now build/decode/modify/rebuild/decode an owned APK with package/resource/asset assertions, and perform full static capa analysis of its own Python launcher with sample hash/version assertions. Unsigned APKs are not installed and scanned PE samples are not executed. The other six generated-input checks below remain covered.

Prior audit foundation (v1.2.0, retained in 1.2.1):

- The existing kit had 47 tool directories and 32 resolved shim targets. Four manifest rows contained native command output instead of a single tool record. Four stored per-file hashes matched the installed bytes.
- Existing CLI checks passed for Detect It Easy, 7-Zip, repak, retoc, ILSpy CLI, DirectXTex, headless Godot and Frida. No game or injection target was launched.
- Catalog contract and asset fixture tests pass. Offline installer regression tests pass in PowerShell 5.1 and 7, including failed-update rollback, restored shim bytes, missing-shim repair, state recovery, atomic JSON replacement, exact asset digest selection and immutable source URLs.
- Windows Sandbox XML tests pass in both PowerShell versions: escaped paths, read-only inputs/tools, one writable output and no automatic target execution. The host currently has no WindowsSandbox.exe; an actual guest session is unverified. Java/.NET/Python/Node runtimes are not provisioned into the guest.
- Fresh installation of the eight added capabilities passes in an isolated test profile. ASAR pack/list/extract and Wasm roundtrips preserve bytes; JADX recovers our generated Java class; Kaitai compiles a generated schema; LIEF parses an official tool's PE; pyinstxtractor-ng reads its own bundle metadata; Apktool help/version succeeds. Capa scans its own Python launcher using matched released rules/signatures. Its packed standalone EXE was blocked by host security, so the kit uses the upstream-supported Python route.
- Original-kit migration completes all 57 entries without failures. Doctor passes and all eight new-tool smoke checks pass from that install. Native-output rows are normalized; source archives use recorded commits. Previous payloads and the original state snapshot are retained. No game files were modified.
- Release evidence is recorded in GitHub's exact-SHA checks/release and the local `sandbox/work/release-validation.json` receipt after publication. CI, alert checks and public byte verification must be confirmed there; the local tests above do not substitute for those gates.

Runtime limits: graphical tools, real app/game modifications, RenderDoc Vulkan layer registration and target rebuilds are unverified. The installer downloads upstream tools at run time; an installer archive does not contain every upstream binary or runtime.
