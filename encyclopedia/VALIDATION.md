# Validation of the Gemini draft

The draft was technically useful but wrong or unsafe in the places below. The implementation in this directory follows the corrected column.

| # | Draft claim | Verdict | Correction and evidence |
|---|---|---|---|
| 1 | `context7.json` with `projectTitle`, `description`, `folders`, `excludeFolders`, `excludeFiles`, `rules` | Correct | The schema also supports `$schema` and `previousVersions`; `excludeFiles` takes filenames only. Confirmed at <https://context7.com/docs/library-owners>. `$schema` was added. |
| 2 | Creation Engine card covers `.bsa`/`.ba2` | Wrong | Skyrim LE/SE use `.bsa`; Fallout 4 and Starfield use `.ba2` (Creation Engine 2). Do not present them as interchangeable. |
| 3 | Strip `FILE_FLAG_NO_BUFFERING` from `CreateFileW` | Unsafe | Unbuffered I/O requires sector-aligned buffers and offsets; stripping the flag changes cache behavior and can break the loader. Hook only for path redirection, preserve flags, and mirror them in any replacement handle. |
| 4 | Ghidra MCP over Streamable HTTP at `http://127.0.0.1:8080/mcp` | Wrong port | GhidraMCP's Ghidra-side HTTP server listens on `127.0.0.1:8080`; the MCP bridge is a separate process (default `127.0.0.1:8081`, transport `streamable-http`). Probe both. See <https://github.com/LaurieWired/GhidraMCP>. |
| 5 | ReShade shader performs hardware depth testing and 6-DoF depth reprojection | Partly wrong | As of the ReShade 6.x effect runtime (2026-10), the game depth texture is read-only: an effect can read it and reproject color, but cannot write it or inject geometry. A ReShade **add-on** (C++ API) can issue draw calls; a D3D11 draw/depth hook is the engine-level route. Re-test after a runtime change. See the ReShade FX reference (fullscreen-triangle example) and the add-on event list. |
| 6 | `pefile` and `capstone` for AOB generation | Half right | `capstone` is required to decode instruction shapes. `pefile` is not: the helper maps RVA to file offset from the PE section table with the standard library, so only `capstone` is installed. |
| 7 | BepInEx 6 as a general loader | Imprecise | BepInEx 6 is still a pre-release line. Mono targets use BepInEx 5; IL2CPP targets use MelonLoader (or a pinned BepInEx 6 build when the target requires it). |
| 8 | GTA V card: `-nobattleye` and ScriptHookV | Correct with a limit | `-nobattleye` and ScriptHookV are single-player only; the Enhanced edition is `GTA5_Enhanced.exe` and ships BattlEye. This is not an online route. |
| 9 | GTA V reversed-Z | Correct | ReShade's GTA V depth fix and community depth guides confirm the reversed buffer; the card still requires a readback before shipping. |
| 10 | UE "1.0 = 1cm" | Correct for UE4/5 | UE4/5 default to 1 Unreal Unit = 1 cm and Z-up, left-handed. UE3 titles frequently rescale; verify per game. |
| 11 | Skyrim units | Missing | Creation Engine uses 64 units per yard: 1 unit = 0.5625 in = 1.42875 cm; 128 units ≈ 1.8288 m. Added to the card. |
| 12 | Field notes with build IDs but no hashes | Incomplete | The template requires EXE SHA256 and loader version. Unknown values are marked `not recorded`; no hash was invented. |

## What was kept

The 6-tier ladder, downstream-sink discipline, offline-harness gate, seqlock header, proxy-entity bridge, AOB masking approach and the error registry are sound. They are implemented as written, with the corrections above.
