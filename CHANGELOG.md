# Changelog

## 1.0.0

- One-click Windows installer. Tools unpack under `sandbox/tools` and are called through stable shims in `sandbox/bin`.
- Machine pointer at `%LOCALAPPDATA%\ReverseThis\kit.json` for a chat that was not opened inside the clone.
- Catalog cut list: archived projects, stale binaries, and non-portable installers are not downloaded.
- Asset patterns are locked to a fixture so a broad match cannot grab the wrong zip.
