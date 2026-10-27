# Claude

Read [AGENTS.md](AGENTS.md) and follow it. The tools are in `sandbox/bin` after `Install-Modkit.ps1`. Do not search the disk for another copy.

## Target project ownership and publication

Before substantive target edits, establish one source project with `WORKSPACE_OWNERSHIP.md`; preserve existing records, source layout and repository. The kit owner and target project are different owners. When available, use workspace-organization/ensure_ownership.py; otherwise create the same explicit record before writing. Do not publish extracted third-party code or assets by assumption.

New work stays local/private until publication is requested. "Put it on GitHub" means public and MIT for original work by default, subject to third-party rights and platform terms; preserve existing licences and explicit choices. Generic publication uses the appropriate destination (normally Nexus Mods for Skyrim). A mod needing no compilation does not get a duplicate GitHub repository by default; add source hosting when requested or needed for development.

Target releases contain runtime product/mod files and required licences; keep changelogs, ownership/progress files, decompilation notes, tests and backups outside deployment ZIPs. Kit AGENTS/CLAUDE and docs are usage instructions, not target payloads.
