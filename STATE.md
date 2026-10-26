# Reverse THIS! state

Version: 1.4.0 source candidate (2026-10-26)

Goal: keep the workbench independently installable and safely reusable alongside the Starter Bundle and Skyrim Forge. Preserve one canonical owner, shared runtimes, private analysis, installed choices and newer compatible tools.

Done:

- A different source checkout reuses the registered canonical owner. Explicit absolute non-root `-InstallRoot` isolates tool state and never registers or moves the shared pointer.
- Shared Python resolves Process/User `UABS_PYTHON` before validated base discovery; official manager setup and current-feature patch updates are independent of the bundle. Shared Node/npm compatibility and ownership govern official setup/updates; app runtimes and unowned incompatible installations are preserved.
- Normal runs resolve owned package updates; intentional pins and newer valid versions remain. `-NoUpdate` keeps valid installed versions and runtime bindings while repairing missing matched capa support. `-Offline`/`-Doctor` inspect files without network, setup or writes.
- Explicit external owner receipts bind launchers/package metadata to hashes and retain their directories. Capa shims use the selected support owner paths.
- `Update-ReverseThis.ps1` deploys verified public source into an empty destination or an unchanged released kit. It requires the archive digest and release receipt, refuses Git/link roots, local edits and path collisions, retains source backups and preserves private sandbox content.
- Standalone setup, companion routes and supplied upstream snapshot provenance are documented. CI runs the added standalone boundary test in both PowerShell editions.

Validation: all seven offline checks pass in Windows PowerShell 5.1 and PowerShell 7; all source PowerShell files parse in both editions. The Python standard-library catalog gate passes for 58 tools and version 1.4.0. See VALIDATION.md for commands and limits. Disposable fixtures exercised local archives and actual filesystem/batch boundaries; they did not install or update live tools.

Next: parent release workflow reviews the source diff, pushes the exact revision, converges CI/security checks, packages and verifies public archive bytes. Live deployment is a separate remaining gate; the installed kit and pointer remain unchanged by this source work.

Last good public version: 1.3.0, commit f91aec703857d77cfa0d423ddbcbe77cb20c5cf2. Its source/archive and installed payload/state backups remain the rollback baseline.

Logs: canonical `<kit>/sandbox/log/modkit.log`; source updates use `<kit>/sandbox/log/source-update.log`. `-DebugLog` enables details. Private work, installed state, tools, logs and backups stay outside Git/public releases.

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File Install-Modkit.ps1`; select installed choices with `-Only id1,id2`. Source update: `Update-ReverseThis.ps1 -Destination <absolute kit> [-Archive <zip> -Sha256 <expected digest>]`. Each source archive's `RELEASE.json` binds its commit and public files.

Limits: no actual missing-runtime winget installation, network package upgrade, Windows Sandbox guest, GUI/game target execution or 1.4 public release was certified in this pass. Prior 1.3 REA CLI/static-fixture evidence and prior release tool smoke evidence remain historical, not proof of every current target workflow.
