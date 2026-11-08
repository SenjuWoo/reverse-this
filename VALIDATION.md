# Validation gates

Run before every release; CI runs the same on both Windows PowerShell 5.1 and PowerShell 7.

| Gate | Command |
|---|---|
| Catalog, encyclopedia, delivery, kit helpers | `python tests/test_catalog.py`, `test_encyclopedia.py`, `test_delivery.py` (needs committed VERSION), `test_kit_tools.py` |
| Ghidra health/MCP probes | `python tests/test_ghidra_mcp_up.py` |
| AOB masking, PE bounds, overlap and section fixtures | `python tests/test_aob_gen.py` (Capstone test dependency) |
| PE parser malformed/valid fixtures | `python tests/test_pe_recon.py` |
| Companion parser fixtures (live checker is scheduled/manual) | `python tests/test_companions.py` |
| Upstream currency report fixtures | `python tests/test_upstreams.py` |
| Installer regressions (offline) | `tests/test_installer.ps1` |
| Isolation, entrypoint, .NET, standalone | `tests/test_isolation.ps1`, `test_entrypoint.ps1`, `test_dotnet_prerequisite.ps1`, `test_standalone.ps1` |
| Maintenance ownership, retention and scheduled previews | `tests/test_maintain.ps1`, `tests/test_register_maintenance.ps1` |
| Windows release delivery | `python tests/test_delivery.py` with `PSHOST` set to `powershell.exe` or `pwsh` |
| Runtime smoke (installed kit) | `tests/test_tool_smoke.ps1` |
| Companion live contract | `python scripts/check_companions.py` (scheduled/manual) |
| Critical upstream currency | `python scripts/check_upstreams.py` (read-only report) |
| Live kit | `Install-Modkit.ps1` then `-Doctor` |

## Comparing a local build with a release

`build_release.py` pins `core.autocrlf=false` and `core.eol=lf`, so a Windows build has the same file contents (and `RELEASE.json`) as the CI build. Zip bytes can still differ across hosts because Python builds ship different deflate libraries; compare extracted contents or `RELEASE.json`, not the zip hash. CI compares two builds on the same runner byte for byte.

## REA + Ghidra + MCP integration (2026-11-06)

- Installed official `Ghidra_12.1.4_build` asset `ghidra_12.1.4_PUBLIC_20260921.zip`
  side-by-side at `sandbox/tools/ghidra-12.1.4`; SHA-256
  `ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db`.
  Its `application.properties` declares `application.java.min=21`, no maximum,
  so the existing JDK 25 was accepted. No JDK 21 was installed.
- `GHIDRA_INSTALL_DIR` and `JAVA_HOME` were scoped to that pair for REA.
  `rea doctor --provider ghidra --json` returned `healthy: true`, Ghidra
  `12.1.4`, and all Ghidra checks true. `environment_healthy` is false only
  because optional IDA, JADX and Kuna providers are not configured.
- Read-only `rea analyze` of a copied `notepad.exe` (SHA-256
  `468ffe129c395abf6b21a09efdf261910a95fb98aa982ead73caa7b2b684577e`)
  returned `binary_overview`: 853 procedures, 638 strings, 10 segments, image
  base `0x140000000`.
- A real stdio MCP client completed `initialize`, `tools/list` (229 tools,
  6 prompts), `open_binary`, `binary_overview` and `list_procedures` against the
  same read-only fixture. `rea mcp doctor` also reported 229/229 tools and
  `request-flow: ok`.
- `rea setup --client hermes --yes` registered the server in the active Hermes
  profile with a backup; `rea doctor` reports the Hermes registration `aligned`
  and the REA skill installed. A running Hermes session needs a restart before
  the new MCP server appears as native tools.

## Web API reconstruction (2026-11-08)

- Selected the published **reverse-api-engineer v0.14.0** (MIT) rather than
  `main` `cd221e9ef5fe30d4fb66ad0d5198f179191aca57`; the stable wheel does not
  ship the unreleased `skills/` changes, so no mixed revision is installed.
- Added catalog entry `reverse-api-engineer` (`pip-venv`, pinned `0.14.0`) and
  installed it with `Install-Modkit.ps1 -Only reverse-api-engineer`:
  `ok=1 failed=0`. It uses the shared Python in a private venv.
- `sandbox/bin/reverse-api-engineer.cmd --version` → **0.14.0**;
  `list --json` → `[]`; `agent --dry-run` → `status: ok`,
  provider `auto`, SDK `claude`, Node `v26.13.0`. No browser or model run was
  started.
- Live capture and client generation are **unverified**: no model
  authentication was supplied and no target site was authorized for capture.
- Routing is in `AGENTS.md` and `docs/web-api.md`; generated output belongs
  under ignored `sandbox/work/web-api`, because upstream `real_time_sync`
  writes clients into the current directory.

## Latest local results (2026-11-08, 1.15.1 release, Windows PowerShell 5.1)

61 Python checks passed, including the web-API contract, delivery and upstream
fixtures. `tests/test_installer.ps1` passed with the isolated-Ghidra preference
and caller-override checks. Repeated `Install-Modkit.ps1 -Only rea` produced the
same shim hash; `Install-Modkit.ps1 -Doctor` exited 0. The installed kit is
1.15.1 with 93 tools. Default `rea doctor --provider ghidra` is healthy against
Ghidra 12.1.4, and the shim does not leak `GHIDRA_INSTALL_DIR` or `JAVA_HOME`
to the caller. The published `Reverse-This-1.15.1.zip` was re-downloaded and
verified: 166,210 bytes, SHA-256
`7016fd630c371b206fe0c58508724da8562c3805f4f5f7db151d3cc684f15851`,
59 entries and 93 catalog tools. Live `reverse-api-engineer` capture remains
unverified because no model/provider authentication was supplied.

## Earlier local results (2026-11-08, 1.15.0 release)

63 Python checks passed: catalog/encyclopedia/delivery scripts, 15 Ghidra MCP
fixtures, 12 AOB fixtures, 6 PE parser fixtures, 5 kit-tool checks, 4 companion
fixtures, 13 upstream-report fixtures and 3 web-API contract checks. The
published `Reverse-This-1.15.0.zip` was re-downloaded and its SHA-256 verified
against `SHA256SUMS.txt`; the extracted product reports
`packaged checks ok: 1.15.0, 93 tools`. The local kit is 1.15.0 and Doctor
exits 0.
