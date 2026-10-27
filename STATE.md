# Reverse THIS! 1.4.0 verified release handoff

- Goal: an independently installable analysis workbench with one canonical owner, shared runtimes, safe updates and preserved private analysis/settings.
- Owner: this Git checkout. Public version 1.4.0; source/tag 979fa17c7a9b7687a433e4f6a1e4689940d3b756. Previous public rollback baseline: 1.3.0, retained in Git tags, release archives and installed payload/state backups.
- Published: https://github.com/SenjuWoo/reverse-this/releases/tag/v1.4.0 . PR #7 and its corrected head/main checks/security passed. The deterministic source archive passed CRC/extraction and extracted catalog/standalone tests. Both public assets were downloaded and matched local bytes, GitHub digests and SHA256SUMS.
- Public ZIP: 108,789 bytes; SHA256 4087251269e6da95ffa563837ad4b6c684b4d60d52fe9873b3a6874351d5c24b.
- Done: canonical owner reuse, isolated explicit roots, shared Python/Node bootstrap and manager-owned patch policy, normal owned-package updates with pin/newer preservation, validated external receipts, source-update backup/rollback and race protection, and selected Java/Node binding in all generated shims.
- Verification: seven offline checks on PowerShell 5.1 and 7, real batch/filesystem boundaries, catalog 58 entries, extracted-package proof, and exact-SHA CI/security. Negative controls prove the source-version race and Node-binding regressions. Hidden AppData and expected native-failure exit handling are covered under the actual Actions shell invocation.
- Source implementation/publication remaining: none. Cross-product live installation and provider proof are tracked by the Starter Bundle STATE.md; source status is not installed-target certification.
- Companion boundaries: Starter Bundle owns general AI/build tools and project build-system guidance; Skyrim Forge owns Skyrim tools/SDK guidance. Their presence is optional. This workbench never rewrites provider trust or model choices.
- Run: powershell -NoProfile -ExecutionPolicy Bypass -File Install-Modkit.ps1 . Select tools with -Only id1,id2; -Doctor/-Offline are read-only. Explicit -InstallRoot isolates state without registering another shared owner.
- Source update: Update-ReverseThis.ps1 -Destination <absolute kit> [-Archive <zip> -Sha256 <expected digest>]. RELEASE.json binds public source files to their release commit; edited files are preserved/refused.
- Logs: <kit>/sandbox/log/modkit.log and source-update.log; -DebugLog enables details. Private tools/targets/state/backups remain outside Git/releases.
- Runtime limit: actual game/app GUI targets, paid APIs, guest Sandbox sessions and real missing-prerequisite installation were not certified by these offline source gates.
