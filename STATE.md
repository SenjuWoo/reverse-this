# Reverse THIS! state

Version: 1.2.0

Owner: the existing reverse-this checkout; `sandbox/` contains machine-owned installed state and private work.

Audit baseline: 1.1.0, commit 94d27b7. The previous release and installed payloads are preserved. Review found native stdout embedded in four manifest rows, missing-shim success, destructive replacement, unbound body checksums and mutable source-archive provenance. These have regression coverage and corrections in this version.

Companions: Universal Modder owns game workflows; Ultimate AI Starter Bundle owns providers, skills, scoped MCP and its existing `um` installation. This kit adds analysis payloads and does not rewrite provider configuration or trust.

Validation: see VALIDATION.md. Local contracts/regressions pass in PowerShell 5.1 and 7. Eight new analysis capabilities have fresh-install/CLI checks, including owned sample roundtrips and a capa scan with matching rules/signatures. Capa uses the official Python route after host security blocked its packed binary. The optional OS Sandbox launcher has configuration tests; this host reports Home with no Sandbox executable, and an actual guest/game session remains unverified. Tools that need Java, .NET, Python or Node need those runtimes in the guest.

Resume ledger: the original checkout is migrated. All 57 catalog entries install/repair successfully; Doctor passes and all eight new-tool smoke checks pass there. The four malformed rows are normalized, immutable source archives replace legacy branch downloads, and old payload/state backups are retained. No game installation, provider settings or private target files were modified.

Release identity: v1.2.0. Publication evidence is the exact tag/check state at https://github.com/SenjuWoo/reverse-this/releases/tag/v1.2.0 and the local receipt `sandbox/work/release-validation.json`. The receipt records the pushed SHA, check conclusions, alert counts and downloaded asset hashes once the release gate completes; its absence is not success.

Release gate: run local tests, push, verify exact-SHA CI and repository alerts, package the installer, extract and smoke-test that exact artifact, publish, then download and compare size/SHA-256. Do not treat a static test or catalog entry as target compatibility proof.
