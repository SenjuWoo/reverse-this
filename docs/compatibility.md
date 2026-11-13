# Compatibility inventory

Last checked: 2026-11-13. This is a dated report, not a promise that a newer
upstream release works. The catalog remains dynamic; only the compatibility
boundaries below are reviewed.

| Component | Installed / baseline | Catalog policy | Upstream stable | Status | Evidence |
|---|---|---|---|---|---|
| Ghidra | 12.2 + JDK 25; isolated 12.1.4 for REA | current official GitHub release | 12.2 | 12.2 remains the kit default; 12.1.4 + JDK 25 passed REA doctor and a read-only `notepad.exe` analysis | `-Doctor`, REA doctor, MCP `binary_overview` |
| REA (`rea-agents`) | 6.9.0 | exact npm pin + integrity | 6.9.0 | verified build Ghidra 12.1.4; 6.9.0 admits 12.x >= 12.1 and its doctor, a read-only `notepad.exe` analysis (853 procedures) and `rea mcp doctor` (255 tools) pass with both 12.1.4 and 12.2 on JDK 25 | `rea doctor`, real analysis, MCP initialize/tool call |
| ILSpy GUI | 11.2 self-contained | current GitHub release | 11.2 | verified installed; no GUI launch this pass | catalog/receipts |
| `ilspycmd` | 11.2.0.10050 | current NuGet tool | 11.2.0.10050 | verified installed; .NET 10 required | catalog/receipts |
| .NET SDK | 10 (observed SDK list retained) | stable shared prerequisite | 10 | all installed SDK lines are parsed; highest suitable SDK is reported | `tests/test_upstreams.py` |
| Java/JDK | 25 observed via `JAVA_HOME` | selected JDK, not PATH by default | Ghidra 12.1.4 declares min 21, no max | `within-ghidra-bounds`; verified REA/Ghidra 12.1.4 pairing | `scripts/check_upstreams.py`, `rea doctor` |
| Capstone | 5.0.9 test baseline | test-only pin in `requirements-test.txt` | 5.0.9 | AOB fixtures pass | `tests/test_aob_gen.py` |
| GhidraMCP plugin/bridge | `/health` + MCP initialize | optional local bridge | current upstream | protocol probes mocked only; real bridge not handshaken on Windows | `tests/test_ghidra_mcp_up.py` |
| Reverse API Engineer | 0.14.0 pinned PyPI release | stable only; review main separately | 0.14.0 | CLI `--version`, `list --json` and `agent --dry-run` pass; live capture/model call not run | `catalog/tools.json`, `docs/web-api.md`, `tests/test_web_api.py` |

## Policy

1. The catalog may resolve newer releases for ordinary tools, but major runtime
   boundaries require a review and a Windows smoke test.
2. REA moves only by an exact pin bump after an isolated install plus `rea doctor`,
   a real analysis and `rea mcp doctor` pass (6.9.0 did on 2026-11-13).
3. Ghidra, ILSpy and `ilspycmd` are separate components; do not infer one
   component's compatibility from another.
4. Capstone is test-only. The AOB generator is validated against the pinned
   test baseline; do not silently move the runtime dependency across majors.
5. The live companion/upstream check is scheduled or manual. Regular CI uses
   offline fixtures so unrelated README wording cannot block every release.
   Run `python scripts/check_upstreams.py` (source checkout or extracted
   release) for a read-only currency report on Ghidra, GhidraMCP, REA, ILSpy,
   `ilspycmd`, .NET and Capstone. It reports observed installed versions,
   catalog/report baselines, latest releases, update status and compatibility
   separately; it never labels an unobserved version as installed, and it never
   blocks CI merely because an upstream release appeared. `--offline` reports
   `offline`, not a network failure. Installed evidence is a validated state
   receipt whose `kit_root`, tool directory and receipt hashes still match; a
   moved, stale, malformed or hashed-mismatched row is never promoted to
   `installed`. Catalog/test pins stay in `baseline`/`catalog_pin`.
6. A missing real bridge, GUI or game target is recorded as unavailable, not
   reported as a passed runtime test.
7. Java evidence is not a substitute for REA's doctor. The report reads the
   selected Ghidra installation's `application.java.min`/`max` bounds and
   reports `within-ghidra-bounds`, `outside-ghidra-bounds`, `unverified-bounds`
   or `missing-java`. A JDK that satisfies Ghidra can still be an unsupported
   REA/Ghidra pairing; no hardcoded Java-21 rule is used. Both `JAVA_HOME` and
   the `java` on PATH are recorded, including a mismatched pair.
8. Every file receipt must carry a complete 64-hex SHA-256. Empty, truncated,
   non-hex or path-escaping digests are `malformed`, never a valid install.

Update this table when a pin changes, and record the date and actual evidence.
