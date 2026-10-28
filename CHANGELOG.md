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
