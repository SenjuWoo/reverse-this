# Audit 2026-11-03

Scope: whole repository, the installed kit and the supplied `Tools` snapshots. An outside Gemini report was read and checked against the repository; most of it described the Starter Bundle at an older state (50 tools, a `manifest.json`, a private repository) and did not apply.

| Area | Finding | Action |
|---|---|---|
| GitHub API | Without a logged-in `gh`, anonymous calls (60/hour) cannot cover a full catalog run. | Token fallback to `GH_TOKEN`/`GITHUB_TOKEN` plus a regression test. |
| REA | Shim never set `GHIDRA_INSTALL_DIR`; REA 6.8.0 also refuses Ghidra 12.2. Supplied source is unreleased main that accepts 12.x. | Shim wiring with caller override and a test; documented limit; pin bump waits for the npm release. |
| Context7 | Docs said the encyclopedia was Context7-indexed; `/senjuwoo/reverse-this` does not resolve. | Docs now say local-first; submission is an owner decision. |
| Ledgers | STATE/PLAN/VALIDATION held 20 stacked "current" sections back to 1.4.1. | Reduced to current state; history lives in CHANGELOG and git. |
| Installer code | 73 functions, none unused; no Invoke-Expression in product code; only retry backoff sleeps. | No change. |
| Catalog currency | Only `rea` is version-pinned and it equals npm latest; all others resolve latest per run. | No change. |
