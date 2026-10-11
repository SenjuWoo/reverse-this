# Reverse THIS! state

Version: 1.2.1 candidate

Owner: the existing reverse-this checkout; `sandbox/` contains machine-owned installed state and private work.

Audit baseline: 1.1.0, commit 94d27b7. The previous release and installed payloads are preserved. Review found native stdout embedded in four manifest rows, missing-shim success, destructive replacement, unbound body checksums and mutable source-archive provenance. These have regression coverage and corrections in this version.

Companions: Universal Modder owns game workflows; Ultimate AI Starter Bundle owns providers, skills, scoped MCP and its existing `um` installation. This kit adds analysis payloads and does not rewrite provider configuration or trust.

Validation: see VALIDATION.md. Local contracts/regressions pass in PowerShell 5.1 and 7. Eight new analysis capabilities have fresh-install/CLI checks, including owned sample roundtrips and a capa scan with matching rules/signatures. Capa uses the official Python route after host security blocked its packed binary. The optional OS Sandbox launcher has configuration tests; this host reports Home with no Sandbox executable, and an actual guest/game session remains unverified. Tools that need Java, .NET, Python or Node need those runtimes in the guest.

Resume ledger: the original checkout is migrated. All 57 catalog entries install/repair successfully; Doctor passes and all eight new-tool smoke checks pass there. The four malformed rows are normalized, immutable source archives replace legacy branch downloads, and old payload/state backups are retained. No game installation, provider settings or private target files were modified.

Second audit: v1.2.0 is published and its bytes/checks are verified. A failing capa update could leave newer rules/signatures with an older restored package; v1.2.1 is correcting the whole matched group. The review also reproduced weak support-file checks, batch punctuation/exit-status errors and nested pointer truncation, and identified the .NET 10 prerequisite required by current ilspycmd beyond UABS's older defaults. Changes are under local verification; the owner install is still on v1.2.0. Generated APK build/decode/modify/rebuild and full static capa analysis pass. Keep the v1.2.0 source/package/state as the restorable baseline.

Release identity: v1.2.1 candidate. Publish only after local tests, owner migration, exact-SHA CI/alerts and fresh extracted-artifact checks pass. The current `sandbox/work/release-validation.json` receipt still describes published v1.2.0; retain it under a versioned name before writing the new receipt.

Release gate: run local tests, push, verify exact-SHA CI and repository alerts, package the installer, extract and smoke-test that exact artifact, publish, then download and compare size/SHA-256. Do not treat a static test or catalog entry as target compatibility proof.
