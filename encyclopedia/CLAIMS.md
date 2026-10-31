# Capability Claims: Dated Observations, Not Permanent Laws

Every limit in this encyclopedia is an observation about a named tool, version and mechanism on a date. It is not a statement about what is possible forever. A later runtime, loader, decompiler or technique may remove it. When that happens, update the card and the test; do not defend the old sentence.

## Write a limit like this

- Name the mechanism: "a ReShade effect", "a UE4 cooked package", "this installer".
- Name the version and date: "as of ReShade 6.x (2026-10)".
- Name the escape hatch: "a ReShade add-on can issue draws", "runtime introspection may recover names".
- Name the re-test trigger: "re-check when the runtime exposes writable depth".

Bad: "ReShade cannot write depth."

Good: "As of the ReShade 6.x effect runtime (2026-10), the game depth texture is exposed read-only; an add-on or a draw hook is the current route to geometry. Re-test after a runtime change."

## Current scoped limits

| Limit | Scope | Escape hatch and re-test |
|---|---|---|
| ReShade effect depth input is read-only | ReShade effect runtime, 6.x (2026-10) | A ReShade add-on (C++ API) can issue draws; a D3D11 draw/depth hook is the engine-level route. Re-test if effects gain writable depth. |
| A ReShade effect renders a fullscreen pass, not a mesh | ReShade effect runtime | Use an add-on, a proxy DLL or an engine hook for geometry. Re-test after an effect-runtime API change. |
| UE3/UE4 cooked packages strip source names | Cooked UE builds | Runtime object-name tables, SDK dumps, or a reimplementation. Re-test with a newer cooker or a title that ships symbols. |
| Native decompilers output approximations | Named decompiler and version | Use a debugger or tracer as ground truth; a newer decompiler may improve the result. |
| The catalog installs one verified asset per tool | This installer's current catalog | Place any other tool in `sandbox/manual/<name>/`; update the catalog pattern when upstream changes. |
| One live kit per user | This installer's ownership model | Use `-InstallRoot` for isolated kits; the pointer is a safety rule, not a capability limit. |
| Anti-cheat tolerance is game- and patch-specific | The game's current official policy, not a tool capability | Check the policy and record its date; cosmetic-only, no competitive advantage, user accepts the account risk. Re-test after a patch. See `anticheat-risk.md`. |

## What is not a capability limit

Validation gates, backups, license/provenance rules, and anti-cheat risk decisions stay. They exist to avoid data loss and account loss, not to declare what a tool can do. Keep them separate from capability statements. Anti-cheat is a dated policy assessment, not a permanent "no": see `anticheat-risk.md`.

## Retiring a limit

1. Reproduce the old limit on the current version.
2. If it still holds, add the version and date to the card.
3. If it is gone, update the card, the error registry and the test; keep a one-line history in `CHANGELOG.md`.
4. If a new mechanism only partly removes it, record both: what still holds and what changed.
