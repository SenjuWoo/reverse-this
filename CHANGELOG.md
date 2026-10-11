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
