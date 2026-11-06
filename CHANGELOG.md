## 1.14.9 (2026-11-06)

- The upstream report selects the JDK REA/Ghidra actually use: a valid
  `JAVA_HOME` wins over an unrelated `java` on PATH. Evidence now records the
  PATH version, the JAVA_HOME version, the selected binary and its source.
- Added a mismatched-JDK regression test: PATH 25 versus JAVA_HOME 21 must report
  the JAVA_HOME value and `selected_source: JAVA_HOME`.
- Verified REA 6.8.0 with official Ghidra 12.1.4 alongside the existing 12.2
  install: JDK 25 satisfies Ghidra's `application.java.min=21`, so no JDK 21 was
  installed. `rea doctor`, real read-only analysis, and an MCP initialize plus
  `open_binary`/`binary_overview`/`list_procedures` call passed.

## 1.14.8 (2026-11-06)

- A file receipt must contain a complete 64-hex SHA-256. Empty, truncated,
  non-hex and path-escaping digests are reported `malformed`, never promoted to
  `installed`.
- Java compatibility is no longer a hardcoded Java-21 check. The currency report
  reads the selected Ghidra installation's `application.java.min`/`max` bounds
  and separates `within-ghidra-bounds`, `outside-ghidra-bounds`,
  `unverified-bounds` and `missing-java`; it records `JAVA_HOME` and PATH
  evidence and does not substitute for REA's own doctor.
- Regression tests cover empty/malformed/traversing receipt digests and Java
  bounds at 17, 21 and 25 against Ghidra 12.1 and 12.2 metadata.

## 1.14.7 (2026-11-06)

- The currency report no longer treats catalog pins or the Capstone test pin as installed tools. A tool appears in `installed` only when its owner-state receipt still matches this root, its directory and every receipt hash. Missing, stale, moved, malformed, changed and unverified states remain distinguishable.
- `.NET` probing parses every `dotnet --list-sdks` line and reports the highest suitable SDK plus the complete observed list, instead of trusting the first line.
- `--offline` has its own `offline` status. `network-unavailable` is reserved for a failed request.
- REA compatibility uses the published 6.8.0 policy: Ghidra 12.1.x is compatible, other 12.x lines are incompatible, missing Ghidra is explicit, and an unknown/new REA release is `unknown-version` rather than assumed compatible. Java is reported separately, including the stable REA JDK 21 boundary.

## 1.14.6 (2026-11-06)

- Scheduled-task ownership now parses the actual generated command template instead of matching text anywhere in the command. Encoded commands are decoded as UTF-16LE and must resolve to `Maintain.ps1 -All` under the recorded owner; comments, unrelated strings, appended commands, wrong executables, extra actions and mismatched owner paths are rejected. Removal requires the task owner to match the current root and still previews without mutating under `-WhatIf`.
- The MCP SSE reader is a line-oriented state machine that handles CR, LF and CRLF, including mixed combinations and splits at every byte. An event is dispatched only after a blank-line terminator; incomplete EOF, invalid JSON, unrelated events and wrong IDs are ignored.
- `aob_gen.py` now rejects PE optional headers smaller than the fixed fields it reads and bounds section counts, matching the strict reconnaissance parser.
- `scripts/check_upstreams.py` ships in the release ZIP and has a packaged `--offline` execution test. It reports observed installed versions, catalog/report baselines, latest releases, update status and compatibility separately; a missing .NET observation is no longer represented as installed.
- PE reconnaissance groups string indicators as anti-cheat, DRM/anti-tamper and protector/packer instead of treating them as equivalent detections. Existing `anti_cheat_markers` remains for compatibility; the grouped `security_indicators` field is added.

## 1.14.5 (2026-11-06)

- AOB wildcard matching now compiles one binary regex with `DOTALL` and searches from each previous match's start offset without copying the remaining file. Wildcards match `00`, `0A`, `0D` and `FF`; empty patterns terminate; invalid patterns return a structured JSON error.
- The MCP SSE reader keeps raw chunk boundaries and finds LF/CRLF/CR event terminators in the accumulated buffer, so an event split at any byte is recognized without EOF. Regression coverage exercises every split point of a valid event, keepalives, multiple data lines and matching JSON-RPC IDs.
- MCP readiness now completes the lifecycle with `notifications/initialized`, forwards the session and negotiated protocol version, rejects lifecycle failure, and requires identity, health and initialization for `ready=true`. Session cleanup remains best-effort.
- Scheduled-task validation counts actions, decodes `-EncodedCommand` as UTF-16LE, verifies the actual `Maintain.ps1 -All` invocation, accepts only a recognized legacy action, and refuses another existing checkout's task. Isolated fixtures exercise foreign, multi-action, malformed and valid encoded tasks without touching the real scheduler.
- Owner repair now fails loudly on ambiguous records, linked paths and missing manifests; `-All` stops before tool updates when ownership validation fails. A missing pointer parent is created only after link checks, with backups and rollback preserved.
- The installer rejects linked tool files, linked owner ancestors/pointers and linked shim targets. Generated shims now carry a SHA-256 receipt; Doctor detects missing, changed and linked shims, and cached installs regenerate a shim without downloading the large payload. Legacy rows without shim digests are reported explicitly.
- `pe_recon.py` rejects unsupported optional-header magic, truncated/out-of-bounds headers, directory and section tables, and raw section ranges; anti-cheat and proxy results are labelled indicators/candidates rather than guarantees.
- Packaging coverage now executes `pe_recon.py` from the extracted release payload and checks that `aob_gen.py` starts without the source module path.
- Added a read-only `scripts/check_upstreams.py` report for Ghidra, GhidraMCP, REA, ILSpy, `ilspycmd`, .NET and Capstone. It never blocks CI on upstream drift.

## 1.14.4 (2026-11-06)

- GhidraMCP health now uses the official JSON `/health` envelope; server identity, health and loaded-program state are separate. The MCP bridge probe accepts JSON or Streamable HTTP SSE, validates the initialize ID/result/serverInfo, handles keepalives and fragmented events with time/byte/event bounds, and cleans up sessions best-effort. Ten offline fixtures cover malformed, unrelated, error and oversize responses. No real bridge handshake was available on this machine; `analyzeHeadless` remains the fallback.
- Scheduled-task registration now refuses an existing task without a Reverse THIS! owner marker and keeps `-Remove` usable without the former `Maintain.ps1`. The task command is encoded rather than interpolating paths into PowerShell source, and `-At` is parsed as a real time.
- Partial owner repair validates pointer and manifest independently, regenerates a missing pointer from an intact manifest, refuses reparse-point writes, and retries transient Windows file-replace locks.
- AOB signatures now use overlapping match counts, executable-section selection for `--pattern`, executable-only `--rva`/`--offset`, section-bounded disassembly and structural PE validation. Nine synthetic PE fixtures cover overlaps, header duplicates, multiple executable sections, truncation and unsupported machines.
- Companion drift checks parse `-Packs reverse` or combined pack examples instead of one brittle literal; offline fixtures gate the parser in regular CI.
- Windows `test_delivery.py` now runs in both PowerShell matrix jobs via `PSHOST`; the live companion check remains scheduled/manual.
- Documentation now states that `Maintain.ps1 -Test` is not the full integration suite, and adds a dated compatibility inventory.

## 1.14.3 (2026-11-06)

- Scheduled maintenance previews: `-RunNow -WhatIf`, `-Remove -WhatIf` and registration `-WhatIf` cannot execute a child process, unregister a task, or falsely report success. Isolated what-if tests never touch real tasks.
- Owner repair now validates the pointer and `installed.json` independently; a current pointer with a stale manifest is repaired without requiring cleanup candidates, with backups and rollback.
- Re-registering the optional weekly task reports an obsolete owner before replacing it; its absolute task path remains visible and fails in Task Scheduler if the old checkout is gone instead of running stale source.
- AOB fixtures now require a pinned test dependency (`capstone==5.0.9`); both CI jobs install it and the three encoding tests are mandatory rather than skipped.

## 1.14.2 (2026-11-06)

- Log the optional weekly maintenance task output to `%LOCALAPPDATA%\ReverseThis\maintenance.log` and document removal with `-Remove`. This is the only change after the 1.14.1 correctness release.

## 1.14.1 (2026-11-06)

- Reject a cached tool when any file bound by its existing receipt is missing or changed. A modified executable can no longer be legitimized by rerunning the installer; Doctor continues to fail changed bytes, and the prior payload remains recoverable.
- Bound maintenance cleanup to explicitly owned directories; source caches only under `scripts/`, `tests/` and `kit/`; refuse reparse points; honor the installer lock; and repair `kit.json` plus `sandbox/installed.json` together with rollback backups, independently of cleanup candidates.
- Make `-Test` work from the published ZIP with packaged catalog/version checks while retaining the full developer suite in a checkout. Add `Register-Maintenance.ps1` as an explicit opt-in weekly user task.
- Correct AOB wildcarding to use Capstone encoding offsets, distinguish RIP displacement from immediates, handle short/near branches and reject unsupported architectures; uniqueness is checked in executable sections.
- Fix `JAVA_HOME` discovery and validate HTTP service identity for the optional Ghidra MCP bridge instead of accepting any response.

## 1.14.0 (2026-11-05)

- Add `Maintain.ps1`/`maintain.cmd`: dry-run by default; `-Apply` prunes kit-owned temp, caches and rollback copies with a two-copy recovery floor, repairs a stale owner pointer after a move, `-UpdateTools` refreshes and runs Doctor, and `-Test` runs local checks.
- Add the maintenance CI job and weekly read-only contract check.
- Rewrite the README around the add-on model: Bundle recommended but optional, forges independent, no duplicated authoring stacks.
- Follow the moved `Github/` and `Ai tools/` roots and split owners; NeoXtractor current to v3.3. Catalog remains 92 tools.

## 1.13.3 (2026-11-05)

- Follow the moved tool roots and bundle scope split without copying sibling projects: `Github/rea-main`, `Github/CLI-Anything-main`, `Github/context-mode-main`, `Github/CLibDT`, `Github/zIDK`.
- Document the `Ai tools` game forges, `Github/Unity-MCP-1/2`, Blender, and the `Bundle-Splits` owners (`img2threejs`, `uabs-image-stack`/comfy-kit) as separate owners. Reverse THIS! stays the RE addon; it does not install their templates, MCPs, model assets or game-specific toolchains.
- Link Risk of Rain 2 authoring to `Tools/Ai tools/Risk-Of-Rain-2-Forge`; extraction/conversion remains in this kit.
- Catalog remains 92 tools. Local kit at the moved path reports 92 installed, NeoXtractor now v3.3, Doctor clean.

## 1.13.2 (2026-11-03)

- Read `GH_TOKEN` or `GITHUB_TOKEN` when `gh` is missing or not logged in. Anonymous GitHub API calls are capped at 60 per hour, fewer than one full catalog run needs.
- The `rea` shim points `GHIDRA_INSTALL_DIR` at the kit Ghidra unless the caller set one. REA 6.8.0 still refuses Ghidra 12.2 (it accepts 12.1.x); upstream main already accepts 12.x, so the Ghidra provider starts working with the next REA release.
- Correct the docs: Context7 has not indexed `/senjuwoo/reverse-this`, so agents read `encyclopedia/` from disk first. Add an REA row to the agent tool table and refresh the companion snapshot table (REA main, CLI-Anything, Context Mode, CLibDT, zIDK).

## 1.13.1 (2026-11-02)

- Fix NeoXtractor breaking the companion install when upstream published v3.3 without binaries. Unpinned GitHub archive tools now select the newest stable release containing their required Windows asset, with a visible fallback log instead of a permanent version pin.
- Preserve exact release pins, asset-ambiguity failures, digest verification and newer installed payloads. Automatically take a newer release once its matching binary exists.
- Add offline regression checks for source-only latest releases, paginated history, draft/prerelease exclusion, exact pins, ambiguous assets, missing binaries and API failures. Fresh and cached NeoXtractor installs verified against upstream v3.3/v3.2.

## 1.13.0 (2026-11-01)

- Add `encyclopedia/engines/neox.md` with the NPK fingerprint, the honest per-title coordinate/depth caveats, the NeoXtractor/QuickBMS/Rime route and verification steps.
- Encyclopedia is 29 files / 8 registry rows.

## 1.12.1 (2026-11-01)

- Clarify the QuickBMS NPK route: create the output folder first, because QuickBMS prompts for confirmation and fails in non-interactive shells.
- Correct the vgmstream licence wording in `docs/currency.md`.

## 1.12.0 (2026-11-01)

- Add NeoX NPK coverage: `neoxtractor` (GUI, AGPL-3.0, 75 MB) and `quickbms` (GPL-2.0, 16 MB). QuickBMS extracted `Once Human\res_global-normal_pack_17.npk` with a community NXPK BMS script; NeoXtractor is the out-of-box GUI route.
- Add the League source/mod pipeline tools used by the Gnar workspace: `ritobin-tools`, `lol2gltf` and `vgmstream`.
- Add [docs/neox.md](docs/neox.md) and [docs/risk-of-rain-2.md](docs/risk-of-rain-2.md), covering Once Human NPK, Gnar's League route, Ultron's CUE4Parse/UE5 route, and Kisame's XFBIN/Naruto Storm 4 route.
- Catalog is 92 tools. Manual-only: Rime (Once Human), ltk-tex-utils, BnkExtractor, xfbin_parser and CUE4Parse where their releases/licences do not permit clean bundling.

## 1.11.0 (2026-11-01)

- Add `wadtools` (GPL-3.0, 2.96 MB Windows ZIP) for League of Legends/Teamfight Tactics `.wad.client` listing and extraction. Verified against the installed `DATA.wad.client`: 4,653 chunks, 145.6 MB uncompressed.
- Add the [League WAD/LTK route](docs/league.md) and the [Naruto CPK/XFBIN and UE4 route](docs/naruto-storm.md). Document LTK Manager, CriPakTools and NSC-Toolbox as manual-only where their licences/releases do not permit bundling.
- Catalog is 87 tools. ReXGlue remains a manual Xbox 360 route.

## 1.10.0 (2026-11-01)

- Add `nstool` (MIT, 487 KB Windows ZIP) for Nintendo Switch NSP/XCI/NCA/RomFS inspection and extraction.
- Add `switch-toolbox` (GPL-3.0, 44 MB) for BNTX textures and common Switch formats; TRMDL viewing is incomplete for Scarlet/Violet.
- Add the [Pokémon Switch native-port and modding route](docs/pokemon-switch.md): Game Freak's proprietary engine, extraction, Blender model conversion, pkNX data limits, and the Godot/Unity/UE5 trade-off. No automatic emulator-to-native converter is claimed.
- Document UABEANext as a manual/nightly Unity route; it has no stable release. ReXGlue remains a manual Xbox 360 route.

## 1.9.7 (2026-11-01)

- Add a manual Xbox 360 XEX/PPC static-recompilation route for ReXGlue. It is not auto-installed: the official v0.10.0 Windows ZIP is 44.7 MB, and its `rexruntime.dll` is a known Defender heuristic false positive (28/71 engines, upstream issue #485). The route documents source/nightly verification, Visual Studio 2022/Clang 20, CMake, Ninja and the manual per-game work.

## 1.9.6 (2026-10-31)

- Refresh the dated currency note: `flare-capa` and capa-rules are now 10.0.0 (2026-10-16), and wasm-tools is 1.263.0 (2026-10-30). The installed kit already had both; the documentation was stale.

## 1.9.5 (2026-10-31)

- Add `scripts/check_companions.py` and the scheduled `companions` workflow: a read-only check of the Starter Bundle's reverse-this floor, asset template and owner, plus the Skyrim Forge ownership link. It reports drift without syncing or writing to either repository.
- Document the check in `docs/companions.md`.

## 1.9.4 (2026-10-31)

- Correct the last stale provider count: `docs/reverse-engineering.md` now says "all supported providers" instead of "five".
- Clarify that the kit may reuse an existing `um` installation rather than claiming it consumes one.
- Make the no-launcher Ghidra MCP test deterministic by pointing `REVERSE_THIS_KIT_ROOT` at an empty temporary kit.

## 1.9.3 (2026-10-31)

- Make the agent-first path explicit: the README says install once and then ask; `AGENTS.md` and `docs/reverse-engineering.md` say the agent runs the shim itself and never asks the user to start a server or open a GUI.
- `ghidra-mcp-up --launch` now resolves the kit root, waits for both layers when a launcher exists, and when none is configured returns an optional-MCP message pointing to `analyzeHeadless` instead of a missing manual start file. Added a regression test for the no-launcher path.
- Ghidra MCP is documented as optional; unattended Ghidra analysis uses `analyzeHeadless`, so one-click install needs no server setup.

## 1.9.2 (2026-10-31)

- Document the overlap and synchronization rule: detect the shared tool or runtime first, skip a current copy, update an older owned copy in place, preserve a newer or unknown copy, and never create a parallel installation. `-Force` is the explicit reinstall.
- Verified the behavior: a second `-Only pe-recon` run logs `skip pe-recon`, and the bundle path reuses the existing shared Python instead of installing another.

## 1.9.1 (2026-10-31)

- Fix `Update-ReverseThis.ps1` so its public-source allowlist accepts `encyclopedia/` and `kit/`. Without this, the bundle's optional `reverse` pack verified the 1.9.0 archive and then refused it as an unsafe source path.
- Add a delivery test that deploys the built product through `Update-ReverseThis.ps1` and checks `VERSION`, `context7.json`, `encyclopedia/` and `kit/`.

## 1.9.0 (2026-10-31)

- Add the Context7-indexed `encyclopedia/`: engine fingerprint cards (Creation, Unreal, Unity, RAGE), the 6-tier route ladder, IPC seqlock header and Python reader, ReShade reprojection template, WARP reversed-Z harness, IPC link harness, proxy-entity bridge, Ghidra/Frida/AOB recipes, version-pinned game notes and an error registry.
- Add the `local-script` catalog method and three helpers: `pe-recon` (JSON PE fingerprint), `aob-gen` (wildcard AOB signature) and `ghidra-mcp-up` (Ghidra plugin 8080 / MCP 8081 probe). They install from `kit/` with generated Python shims; `aob-gen` pulls the `capstone` catalog tool automatically.
- Correct the draft plan: BSA is Skyrim and BA2 is Fallout 4/Starfield; GhidraMCP's Ghidra-side HTTP is 8080 and the MCP bridge is 8081; a ReShade effect's depth input is read-only (as of the 6.x runtime), with an add-on or draw hook as the route to geometry; stripping `FILE_FLAG_NO_BUFFERING` is unsafe; `pefile` is not required for AOB mapping. See `encyclopedia/VALIDATION.md`.
- Tests: encyclopedia contract and link check, local helper harnesses (C++ only when g++ is present), and the product ZIP now includes the `kit/` helpers.
- Add `encyclopedia/CLAIMS.md`: every limit names its tool, version, mechanism and escape hatch, and the encyclopedia test rejects permanent "impossible" wording. Limits are dated observations, not hard blockers.
- Add `encyclopedia/anticheat-risk.md`: anti-cheat is a dated risk tier, not a blanket ban. It records the Marvel Rivals 2026-10-15 mod policy and the Monster Hunter Wilds modification warning, with cosmetic-only and no-competitive-advantage rules and an explicit account-risk decision.
- Document modular composition: the Starter Bundle is the base (providers, shared compilers/runtimes, general skills, GitHub/work hygiene), Reverse THIS! is the optional RE layer, and Skyrim Forge/other forges own game-specific authoring. The README and `AGENTS.md` state the ownership matrix and shared-payload contract. The product ZIP now includes `context7.json` and `encyclopedia/` so the local Context7 fallback works offline.

## 1.8.0 (2026-10-31)

- Add 21 tools for the gaps that generic app and game work kept hitting. Native: UPX, YARA, GoReSym, Dependencies, Rizin, System Informer and FLOSS. JVM/Android: Vineflower and uber-apk-signer. Unity scripting: UnityPy. Engines: WolvenKit (GUI and CLI), Mod Engine 2, Smithbox, Crowbar, BSPSource, Source 2 Viewer (GUI and CLI), UndertaleModTool (GUI and CLI) and RPFM.
- Re-verify every GitHub-release entry against its current upstream release: all 41 existing patterns match exactly one asset, and each new pattern was tested the same way before it was added.
- Keep the existing rules: one asset per release, digest-verified downloads, shims only for executables confirmed inside the archive, and shared JDK 25 for the Java tools (BSPSource needs Java 24+, Vineflower 17+, uber-apk-signer 8+).
- Document what stays manual or excluded: REFramework ships one zip per game, CodeWalker publishes no release, Cutter is an optional GUI over the installed rizin CLI, RetDec's last release is from 2023, and de4dot is archived.

## 1.7.0 (2026-10-29)

- `-Doctor` re-hashes the files each install receipt binds (shimmed executables and key files) and reports a changed one as `CHANGED` (exit 1) instead of present; a tool without a receipt is `UNVERIFIED`. All 59 tools on the maintainer kit verify. A regression test proves the old doctor accepted a changed binary.
- Releases publish themselves: `release.yml` runs after ci passes on main and a VERSION with no tag yet is the release request. It waits for every other check on that exact SHA, builds twice from the commit, requires identical bytes, attests the build, publishes and re-downloads to compare. The maintainer pushes to main after the local gate; rulesets block force-push and deletion, and Dependabot pull requests merge themselves when green.
- The ownership model is linked from the bundle README instead of restated; the bundle installs this kit's latest release (it pins none). CURRENT.txt had stayed at 1.6.0.
- Tests call `.\install.cmd` and `.\probe.cmd` explicitly, so they pass where `NoDefaultCurrentDirectoryInExePath` is set (hardened shells), as they already did on CI.

## 1.6.1 (2026-10-28)

- Correct replica-skill source provenance: default-branch discovery resolves and records an immutable commit and archive digest.
- Refresh the verified owner and dual-shell handoff; no tool catalog, provider settings or installed tool versions change.

## 1.6.0 (2026-10-27)

- Add the MIT replica-skill pack (app recon, clean-room rebuild, parity diff) as an optional source archive under sandbox/tools; the receipt records the installed commit. Load the skills with: Copy-Item -Recurse sandbox\tools\replica-skill\replica-* $HOME\.claude\skills\.

## 1.5.0 (2026-10-27)

- Add a reproducible repository-owned product builder from exact Git objects; private/untracked files, development ledgers and changelogs stay outside runtime ZIPs.
- Source updates back up and retire unchanged obsolete release-owned files with rollback; personal edits/collisions and private target work remain preserved.
- Explicit source/target ownership and local/publication defaults, including public GitHub/MIT for original work when requested.

## 1.4.1 (2026-10-26)

- Fix shared Python probing under Windows PowerShell 5.1: dictionary keyword arguments survive the native command boundary without embedded quote loss.
- Exercise an actual shared Python interpreter in both CI shells in addition to canned runtime fixtures.

## 1.4.0 (2026-10-26)

- Reuse the registered owner kit from another checkout and keep explicit isolated test roots separate from its pointer.
- Discover shared base Python and compatible Node/npm independently; provision missing official prerequisites and patch manager-owned installations without replacing app runtimes.
- Resolve owned pip, npm and NuGet package updates on normal runs; retain intentional pins, newer compatible versions and transactional backups. Add NoUpdate and read-only Offline modes.
- Reuse explicit owner tool receipts in place, including scoped UABS_TOOL_ROOTS candidates; validate file hashes without launching GUI tools.
- Add an official digest-verified source release updater with fresh empty-destination support, previous-release hash checks, local-edit/collision refusal and retained source backups; preserve Git development roots and private sandbox files.
- Retain selected Java/.NET/Node runtime bindings in normal and NoUpdate shims, repair missing matched capa support files and bind external capa support directories correctly. Recheck the installed source version under its lock to preserve a newer concurrent release.
- Document standalone setup, companion ownership and the supplied upstream snapshot licenses; test local source archives and runtime/receipt failure boundaries.
## 1.3.0 (2026-10-25)

- Own the optional REA CLI and specialist analysis guidance.
- Pin npm versions/integrity before activation; reuse matching global REA without changing it.
- Document shared compiler and Skyrim companion ownership.

# Changelog

## 1.2.1

- Roll back capa's matched package, rules and signatures together when an update fails; reject incomplete support payloads.
- Route full and support-only capa installs through the same transaction; retry transient Windows JSON replacement failures without deleting good state.
- Preserve batch exit codes, literal punctuation in command paths and deeply nested pointer extensions.
- Provision the .NET 10 SDK/runtime required by current ilspycmd, including alongside older Starter Bundle prerequisites.
- Test the real batch entrypoint, failed backups and dependency updates; build, modify and rebuild an owned APK and statically scan capa's own launcher.
- Correct the Cpp2IL retirement rationale and document its current preview as a manual analysis route.

## 1.2.0

- Add Android/Java decompilation and APK rebuilding, Electron ASAR, PyInstaller extraction, static capability triage, Kaitai format parsers, WebAssembly tools and LIEF binary analysis.
- Add an optional Windows Sandbox launcher with read-only inputs/tools, disabled networking and one writable output folder.
- Repair malformed installed records; recreate missing shims and preserve CLI working directories, environment and exit codes.
- Validate replacement executables before promotion; retain last-good payloads and roll back failed updates.
- Use exact GitHub asset digests, immutable source commits, atomic state writes and an exclusive install lock.
- Ignore private work, backups and state snapshots; document companion integration and remaining target/runtime limits.
- Test installer behavior and Sandbox configuration in Windows PowerShell 5.1 and PowerShell 7.

## 1.1.0

- 7-Zip, LDtk, OpenBOR, and the official Fighter Factory Windows portable are installed. LDtk's installer is unpacked and not run. OpenBOR's rar is unpacked with 7-Zip.
- Helldivers 2: HD2Runtime SDK, runtime, examples, and mod template; ModBuilder; the community SDK; Bingus Shared Loader.
- R2API source from the current release tag.
- Sleeping Dogs TheoryEngine source, SDK source, and the SDK example playground. The game executable and its PDB are not downloaded.

## 1.0.0

- One-click Windows installer. Tools unpack under `sandbox/tools` and are called through stable shims in `sandbox/bin`.
- Machine pointer at `%LOCALAPPDATA%\ReverseThis\kit.json` for a chat that was not opened inside the clone.
- Catalog cut list: archived projects, stale binaries, and non-portable installers are not downloaded.
- Asset patterns are locked to a fixture so a broad match cannot grab the wrong zip.
- Ghidra's JDK lookup no longer assigns PowerShell's read-only HOME variable.
- Frostbite: Frosty Editor and Frosty Mod Manager. The rewrite publishes no binary.
- Godot: current stable mono editor (console shim) and GDRE Tools for packed games.
- IKEMEN Go and Pixelorama.
- LDtk, OpenBOR and Fighter Factory stay manual. Their published Windows files are an installer or a rar.
- Helldivers 2 SDKs, Sleeping Dogs TheoryEngine and its SDK, and R2API are not downloaded.
