# 6-Tier Modding Route Escalation Ladder

Pick the lowest tier that can produce the required behavior. A higher tier is not more impressive; it is more expensive, more fragile and harder to verify. Record the tier in the target's field note.

| Tier | Route | Use when | Cost | Minimum proof |
|---|---|---|---|---|
| 1 | Data overrides (loose files, plugin records, INI/CVAR, pak patch) | The engine already loads the asset or value from a replaceable source | Minutes; no code | Changed value appears in game and survives a restart |
| 2 | Loader APIs (SKSE, BepInEx, MelonLoader, UE4SS, ScriptHookV, ASI) | A supported script/plugin surface exists for the behavior | Hours; version-locked to the loader | Loader log shows the plugin loaded; downstream sink fires |
| 3 | Managed patching (Harmony prefix/postfix/transpiler, Mono.Cecil, IL2CPP detour) | The behavior lives in managed code or a stable managed entry point | Hours to days; update-sensitive | Patched method runs; original behavior preserved when disabled |
| 4 | Native proxy DLL / IAT hook / inline detour | No supported surface, or the behavior is in native code | Days; crash-prone | Hook fires under a debugger; unhook restores original bytes |
| 5 | Headless simulation / decompiler library (Ghidra headless, Unicorn, custom reimplementation) | You need to understand or replay the system without the game | Days; may not be runtime-compatible | Reimplementation matches recorded input/output traces |
| 6 | Concurrent shared-memory passthrough | Two runtimes must coexist frame-by-frame and no in-engine route exists | Weeks; timing and lifetime bugs | Offline IPC harness passes; live run shows aligned frames with no torn reads |

## Stop rules

1. Do not climb a tier because it is familiar. Climb only when the lower tier does not express the behavior (yet).
2. Tier 3 and below may be tested in a live single-player session with saves backed up.
3. Tier 4-6 require the offline harness first: `blueprints/fake_host_d3d11.cpp` for depth/pixel math and `blueprints/ipc_link_test.cpp` for shared memory.
4. Anti-cheat is a risk tier, not a blanket ban: check the current policy, keep online changes cosmetic and reversible, and do not ship a competitive-advantage change. Tier 4-6 hooks in a live anti-cheat session are high risk; validate offline first. See [anticheat-risk.md](anticheat-risk.md).
5. If a higher tier does not name its downstream sink, it is not ready.

## Retiring a limit

A limit in this ladder is current, not eternal. If a higher tier now solves what a lower tier could not, or a runtime change removes a blocker, record the tool version and date, update the tier row, and add a line to `CHANGELOG.md`. See [CLAIMS.md](CLAIMS.md) for the wording rule.

## Downstream Sink Protocol

A hook that installs without crashing is not proof. Trace forward from the hook to an observable sink:

1. **Choose the sink before writing the hook.** `IDXGISwapChain::Present`, `EndScene`, a UI text draw, a frame counter written to a log, or a game event with a visible result.
2. **Attach a counter at the sink.** Log frame number, hook invocation count and a payload hash.
3. **If the hook is silent, walk backward.** Set a breakpoint or Frida `Thread.backtrace()` at the sink and walk the stack until you find the producer that should have called your hook.
4. **If the sink never fires, the hook is on the wrong path.** Wrapper/constructor hooks commonly miss the real call site; hook the leaf function the sink actually uses.
5. **Record the evidence** (log excerpt, frame numbers, hash) in the field note. "It works" is not evidence.

## Coordinate conversion checklist

Before writing a conversion, record all six values:

- handedness (left/right)
- up axis (+Y or +Z)
- forward axis and sign
- unit scale to meters
- rotation convention (degrees/radians, yaw origin, sign)
- parent/child transform order

Then write the matrix and test one known landmark in both runtimes. A conversion that looks right but mirrors one axis will pass a single-point test and fail a traversal.
