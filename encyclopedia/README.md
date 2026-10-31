# AI Game Modding & Reverse Engineering Encyclopedia

This directory is the Context7-indexed knowledge base for the Reverse THIS! workbench. It is written for an agent that has to make a decision and run a command, not for a reader who wants an overview.

## Start here

| Need | File |
|---|---|
| Choose the cheapest viable modding route | [ROUTING.md](ROUTING.md) |
| Identify an engine and its coordinate/depth conventions | [engines/](engines/) |
| Copy a drop-in IPC, shader or proxy bridge | [blueprints/](blueprints/) |
| Operate Ghidra MCP, Frida or AOB signatures | [re-recipes/](re-recipes/) |
| Record a target's pinned build | [games/TEMPLATE.md](games/TEMPLATE.md) |
| Map an error signature to a cause | [ERROR-REGISTRY.json](ERROR-REGISTRY.json) |
| See where the Gemini draft was wrong | [VALIDATION.md](VALIDATION.md) |
| Scope a limit to a tool, version and escape hatch | [CLAIMS.md](CLAIMS.md) |
| Decide whether an online mod is tolerated | [anticheat-risk.md](anticheat-risk.md) |

## Non-negotiables

- A successful install is not a successful hook. Prove it with a downstream sink.
- A decompiled function is a hypothesis until it runs under a debugger or tracer.
- A pattern match is a candidate until it resolves in two different builds.
- In the ReShade effect runtime (6.x, 2026-10), the game depth texture is read-only; an add-on or a draw hook is the current route to geometry. Treat that as a versioned limit, not a law.
- Anti-cheat is a risk tier, not a blanket ban: some games tolerate cosmetic client-side mods, others flag the injection method itself. Check the current policy, keep online changes cosmetic and reversible, and do not ship a competitive-advantage change. See [anticheat-risk.md](anticheat-risk.md).
- A limit is a dated observation: name the mechanism, version and escape hatch, and re-test when either changes. See [CLAIMS.md](CLAIMS.md).

## Layout

```
encyclopedia/
  ROUTING.md                 6-tier escalation ladder and stop rules
  CLAIMS.md                  how limits are scoped and retired
  anticheat-risk.md          risk tiers and dated policy evidence
  engines/                   engine fingerprints, axes, units, depth, proxy DLLs
  blueprints/                C++/HLSL/Python templates and offline harnesses
  re-recipes/                Ghidra, Frida and AOB playbooks
  games/                     version-pinned field notes
  ERROR-REGISTRY.json        error signature -> cause -> fix
```

Context7 reads this directory because `context7.json` at the repository root sets `"folders": ["encyclopedia"]`. Root markdown is always indexed by Context7; the runtime directories (`sandbox`, `bin`, `.git`, `tests`, `node_modules`, `**/temp`) are excluded.
