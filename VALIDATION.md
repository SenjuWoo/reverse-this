# Validation

Audit baseline: v1.1.0 at 94d27b7. New source version: 1.2.0.

- The existing kit had 47 tool directories and 32 resolved shim targets. Four manifest rows contained native command output instead of a single tool record. Four stored per-file hashes matched the installed bytes.
- Existing CLI checks passed for Detect It Easy, 7-Zip, repak, retoc, ILSpy CLI, DirectXTex, headless Godot and Frida. No game or injection target was launched.
- Catalog contract and asset fixture tests pass. Offline installer regression tests pass in PowerShell 5.1 and 7, including failed-update rollback, restored shim bytes, missing-shim repair, state recovery, atomic JSON replacement, exact asset digest selection and immutable source URLs.
- Windows Sandbox XML tests pass in both PowerShell versions: escaped paths, read-only inputs/tools, one writable output and no automatic target execution. The host currently has no WindowsSandbox.exe; an actual guest session is unverified. Java/.NET/Python/Node runtimes are not provisioned into the guest.
- Fresh installation of the eight added capabilities passes in an isolated test profile. ASAR pack/list/extract and Wasm roundtrips preserve bytes; JADX recovers our generated Java class; Kaitai compiles a generated schema; LIEF parses an official tool's PE; pyinstxtractor-ng reads its own bundle metadata; Apktool help/version succeeds. Capa scans its own Python launcher using matched released rules/signatures. Its packed standalone EXE was blocked by host security, so the kit uses the upstream-supported Python route.
- Original-kit migration completes all 57 entries without failures. Doctor passes and all eight new-tool smoke checks pass from that install. Native-output rows are normalized; source archives use recorded commits. Previous payloads and the original state snapshot are retained. No game files were modified.
- Release evidence is recorded in GitHub's exact-SHA checks/release and the local `sandbox/work/release-validation.json` receipt after publication. CI, alert checks and public byte verification must be confirmed there; the local tests above do not substitute for those gates.

Runtime limits: graphical tools, real app/game modifications, RenderDoc Vulkan layer registration and target rebuilds are unverified. The installer downloads upstream tools at run time; an installer archive does not contain every upstream binary or runtime.
