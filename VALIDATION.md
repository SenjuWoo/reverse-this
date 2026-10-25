## 1.3.0 modular verification

Catalog: 58 tools. PowerShell 5.1/7 installer, isolation, entrypoint and .NET gates PASS. New pin mismatch, empty npm root-key, unowned REA reuse and self-shim exclusion fixtures PASS. Actual isolated REA 6.8.0 installation, owner Doctor, version/help and owned static-JavaScript fixture PASS. No Windows Sandbox guest or native target runtime was retested; existing unrelated-tool evidence remains in the prior release. Exact-SHA CI/security and public bytes pending.

# Validation

Source version: 1.2.1. Audit baselines: v1.1.0 at 94d27b7 and verified public v1.2.0 at 38f71b5. Previous source, release and installed-state rollback copies are retained.

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
