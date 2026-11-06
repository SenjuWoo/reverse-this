# Compatibility inventory

Last checked: 2026-11-06. This is a dated report, not a promise that a newer
upstream release works. The catalog remains dynamic; only the compatibility
boundaries below are reviewed.

| Component | Installed / baseline | Catalog policy | Upstream stable | Status | Evidence |
|---|---|---|---|---|---|
| Ghidra | 12.2 + JDK 25 | current official GitHub release | 12.2 | verified installed; not re-smoked this pass | `-Doctor`, deal/PE workflows |
| REA (`rea-agents`) | 6.8.0 | exact npm pin + integrity | 6.8.0 | known limitation: rejects Ghidra 12.2 | npm install, `rea doctor` |
| ILSpy GUI | 11.2 self-contained | current GitHub release | 11.2 | verified installed; no GUI launch this pass | catalog/receipts |
| `ilspycmd` | 11.2.0.10050 | current NuGet tool | 11.2.0.10050 | verified installed; .NET 10 required | catalog/receipts |
| .NET SDK | 10 | stable shared prerequisite | 10 | verified prerequisite route | `tests/test_dotnet_prerequisite.ps1` |
| Capstone | 5.0.9 test baseline | test-only pin in `requirements-test.txt` | 5.0.9 | AOB fixtures pass | `tests/test_aob_gen.py` |
| GhidraMCP plugin/bridge | `/health` + MCP initialize | optional local bridge | current upstream | protocol probes mocked only; real bridge not handshaken on Windows | `tests/test_ghidra_mcp_up.py` |

## Policy

1. The catalog may resolve newer releases for ordinary tools, but major runtime
   boundaries require a review and a Windows smoke test.
2. REA stays at the published `6.8.0` pin until a released combination accepts
   Ghidra 12.2 and passes a real install check.
3. Ghidra, ILSpy and `ilspycmd` are separate components; do not infer one
   component's compatibility from another.
4. Capstone is test-only. The AOB generator is validated against the pinned
   test baseline; do not silently move the runtime dependency across majors.
5. The live companion/upstream check is scheduled or manual. Regular CI uses
   offline fixtures so unrelated README wording cannot block every release.
6. A missing real bridge, GUI or game target is recorded as unavailable, not
   reported as a passed runtime test.

Update this table when a pin changes, and record the date and actual evidence.
