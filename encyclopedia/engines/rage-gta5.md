# RAGE / GTA V (Legacy and Enhanced)

## Fingerprint

| Signal | Legacy | Enhanced |
|---|---|---|
| Executable | `GTA5.exe` | `GTA5_Enhanced.exe` |
| Build reference | Legacy build `3889` (verify per install) | Enhanced build numbers move independently |
| Archives | `.rpf` (`x64a.rpf`, `update\update.rpf`) | `.rpf` |
| Anti-cheat | None in single-player | BattlEye |
| Script loader | ScriptHookV (`dinput8.dll` or `xinput1_4.dll` per build), ASI loader | ScriptHookV build matching the Enhanced edition |
| Graphics overlays | ReShade (`dxgi.dll` / `d3d11.dll`), ENB | Same, but verify the proxy slot |

The Enhanced edition is not a drop-in replacement for Legacy. A ScriptHookV build, ASI plugin or offset table is not binary-compatible across editions; use the matching edition's build.

## Coordinates

| Property | Value |
|---|---|
| Handedness | Right-handed |
| Up axis | `+Z` |
| Forward | `+Y` |
| Unit scale | 1 unit ≈ 1 meter |
| Rotations | Heading/yaw in degrees; pitch and roll around the local axes |

Conversion to a Y-up meter runtime:

```
X_out =  X_gta
Y_out =  Z_gta
Z_out = -Y_gta
```

## Depth

GTA V uses a reversed-Z depth buffer (`1.0` near, `0.0` far). ReShade's GTA V depth fix and community depth guides confirm it. Re-read the depth buffer after a graphics update; do not hard-code the polarity.

## Loaders and proxy DLLs

| Name | Use | Conflict |
|---|---|---|
| `dinput8.dll` | ScriptHookV / ASI host | Input mods |
| `xinput1_4.dll` | ScriptHookV host on some builds | Controller remappers |
| `dxgi.dll` | ReShade / overlay host | Other DXGI hooks |
| `d3d11.dll` | ReShade / ENB host | Other D3D11 hooks |
| `winmm.dll` | Proxy host | Audio overlays |

`-nobattleye` disables BattlEye for single-player only. It is not an online route, and it does not make a modified client safe to take online. Do not test a Tier 4-6 hook with BattlEye active.

## Verification

- `ScriptHookV.log` and the ASI loader log show the plugin loaded.
- A downstream sink fires (`Present`, a UI notification, or a frame counter).
- The script spawns one object, reads its position back, and removes it.
- Disable the hook and confirm the original behavior returns.

## Known traps

- Rockstar updates replace the executable; every offset and pattern must be re-resolved.
- ReShade and ENB can both claim `dxgi.dll`/`d3d11.dll`; only one owns the slot.
- `update\update.rpf` overrides the base archives; edit the update archive when the asset is patched there.
