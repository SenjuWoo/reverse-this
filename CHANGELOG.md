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
