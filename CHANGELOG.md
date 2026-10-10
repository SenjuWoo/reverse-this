# Changelog

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
