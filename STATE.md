# Reverse THIS! 1.4.1 verified release handoff

- Goal: independently installable analysis tools with one owner, shared runtimes and preserved private targets/settings.
- Published: https://github.com/SenjuWoo/reverse-this/releases/tag/v1.4.1 from b21a41427dd38cbb6f76cd00ddcca9df8808781e (PR #8). Exact-main CI/security PASS.
- Public ZIP: 108,340 bytes; SHA256 76b7ce541f313defbecb832a14dac4b8934a5fa8fde2ca1724639244306f0826. Both public assets match the deterministic local build, GitHub digests and checksum file. Extracted PowerShell 5.1/7 and catalog checks PASS.
- Fixed: PowerShell 5.1 stripped dictionary-key quotes from the shared Python probe. Quote-free construction retains all validation. A real native Python regression fails before the fix and passes afterward; production discovery handles multiple launchers.
- Validation: all offline installer tests in both shells, catalog 58 entries, exact-SHA CI/security, deterministic double build, CRC/extraction and downloaded bytes. One Windows runner timed out at batch startup; its failed job passed on retry without code/test changes.
- Source implementation/publication remaining: none. The approved live source is 1.4.1; its selected tool update completed 56 successful, zero failed, followed by the owner doctor. Official shared Python 3.14.10 is installed in place. Bundle STATE.md tracks cross-product/provider certification and the required AI-app reconnect.
- Last good rollback: 1.4.0 at 979fa17c7a9b7687a433e4f6a1e4689940d3b756; prior releases, payload/state backups and private work retained. No tag or asset was replaced.
- Companions: Starter Bundle owns general AI/build tools; Skyrim Forge owns Skyrim tooling/SDK guidance. Both are optional and mutually recommended.
- Run: install.cmd; read-only checks: Install-Modkit.ps1 -Doctor/-Offline. Update-ReverseThis.ps1 updates verified public source; Install-Modkit.ps1 refreshes the existing selection.
- Logs: <kit>/sandbox/log/modkit.log and source-update.log. Private tools, targets, state and backups remain outside Git/releases. Actual game/app GUI targets, paid APIs and guest sessions are not certified by source gates.
