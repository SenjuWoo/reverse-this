# 1.3.0 modular ownership (2026-10-25)

- Baseline 2f3ccca; branch codex/modular-tool-ownership.
- REA 6.8.0 pin matches the npm registry integrity. Isolated npm installation
  disables lifecycle scripts and verifies the lock before activation; matching
  global REA is unowned and preserved. Both PowerShell editions handle npm's
  empty root package-lock key. No provider setup/update command is run.
- 58-entry catalog gate and all existing offline installer, isolation,
  entrypoint and .NET prerequisite gates PASS on PowerShell 5.1 and 7.
- REA version/help, owner Doctor, and static JavaScript analysis of a tiny
  owned fixture PASS. The JSON evidence is retained privately; no target was run.
- The original live kit pointer and its existing payloads are preserved. The
  source test install uses an isolated LOCALAPPDATA pointer. Private sandbox,
  logs, npm modules and target work are excluded from Git/publication.
- Next: exact-SHA CI/security checks and release 1.3.0; deploy only public
  source files into the existing kit, keeping installed tools/state/backups.
- Last good public version: 1.2.1. Logs: sandbox/log/modkit.log.
- Run: powershell -NoProfile -ExecutionPolicy Bypass -File Install-Modkit.ps1.


# Reverse THIS! state

Version: 1.2.1

Owner: the existing reverse-this checkout; `sandbox/` contains machine-owned installed state and private work.

Audit baseline: 1.1.0, commit 94d27b7. The previous release and installed payloads are preserved. Review found native stdout embedded in four manifest rows, missing-shim success, destructive replacement, unbound body checksums and mutable source-archive provenance. These have regression coverage and corrections in this version.

Companions: Universal Modder owns game workflows; Ultimate AI Starter Bundle owns providers, skills, scoped MCP and its existing `um` installation. This kit adds analysis payloads and does not rewrite provider configuration or trust.

Validation: see VALIDATION.md. Local contracts/regressions pass in PowerShell 5.1 and 7. Eight new analysis capabilities have fresh-install/CLI checks, including owned sample roundtrips and a capa scan with matching rules/signatures. Capa uses the official Python route after host security blocked its packed binary. The optional OS Sandbox launcher has configuration tests; this host reports Home with no Sandbox executable, and an actual guest/game session remains unverified. Tools that need Java, .NET, Python or Node need those runtimes in the guest.

Resume ledger: the original checkout is migrated. All 57 catalog entries install/repair successfully; Doctor passes and all eight new-tool smoke checks pass there. The four malformed rows are normalized, immutable source archives replace legacy branch downloads, and old payload/state backups are retained. No game installation, provider settings or private target files were modified.

Second audit: v1.2.0 is published and its bytes/checks are verified. The owner repair to 1.2.1 completed 55/55 transactions covering all 57 records, Doctor passes and 40 shims exist. Matched capa package/rules/signatures now update and roll back together, including full-catalog and support-only selections. Support checks reject missing signatures/rules. The installer preserves failed-backup originals, nested pointer extensions and batch punctuation/exit status; bounded retries handle safe transient Windows JSON replacement failures without deleting good state. Current ilspycmd uses a selected .NET 10 host, provisioned when absent, and explicit framework selection works when the caller pins SDK 8. All 13 offline checks pass across PowerShell 5.1/7 and Python; generated APK build/decode/modify/rebuild and full static capa analysis pass. Keep the v1.2.0 source/package/state as the restorable baseline.

Release tracking: GitHub's v1.2.1 release/tag identifies the published source. The ignored `sandbox/work/release-validation.json` receipt records the final SHA, CI/alert results, extracted-artifact checks and redownloaded asset hashes after publication. The retained `release-validation-1.2.0.json` describes the previous release. Never infer publication from this source file alone.

Release gate: run local tests, push, verify exact-SHA CI and repository alerts, package the installer, extract and smoke-test that exact artifact, publish, then download and compare size/SHA-256. Do not treat a static test or catalog entry as target compatibility proof.
