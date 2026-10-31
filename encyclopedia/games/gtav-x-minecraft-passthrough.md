# GTA V x Minecraft Java (Fabric)

## Identity

| Field | Value |
|---|---|
| Host game / store edition | GTA V Legacy, Steam/Rockstar, build `3889` (user-provided) |
| Guest game / store edition | Minecraft Java, Fabric loader |
| Host build id | `3889` |
| Guest build id | not recorded |
| Host EXE SHA256 | not recorded |
| Guest EXE SHA256 | not recorded |
| Loader / proxy DLL | Host `dinput8.dll` (ScriptHookV) or `xinput1_4.dll`; ReShade `dxgi.dll` |
| Loader version | not recorded |
| Toolchain | ScriptHookV, ASI, Fabric, ReShade |
| Date verified | 2026-10-31 (design review only) |
| Owner / workspace | local lab |

The Enhanced edition is `GTA5_Enhanced.exe` with BattlEye; this note covers the Legacy single-player build. Never take a modified client online.

## Coordinate conversion

GTA V: Z-up, right-handed, 1 unit ≈ 1 meter. Minecraft: Y-up, right-handed, 1 block = 1 meter.

Matrix (GTA -> Minecraft):

```
X_mc =  X_gta
Y_mc =  Z_gta + Y_offset
Z_mc = -Y_gta
```

`Y_offset` is the host floor height at the conversion origin; record it per session.

Yaw:

```
Yaw_mc = 180 - Heading_gta
```

Normalize to `[-180, 180]`. Test with the player facing north and east; a single-point test will not catch a sign flip.

## IPC

| Field | Value |
|---|---|
| Mapping name | `Local\MCPassthroughFrame` |
| Header version | 1 |
| Slots | 3 (seqlock, `ipc_seqlock.h`) |
| Frame fields | RGBA, linear depth, near/far, view-projection, camera world, frame id |
| Bridge transport | Shared memory for pose/depth; loopback WebSocket for commands |

## ReShade composite

GTA V uses a reversed-Z depth buffer. In the shader set `HostDepthReversed = 1`; the host linearization is `near*far / (near + raw*(far-near))`. The guest (Minecraft) depth texture must use the same clip convention as the supplied `GuestInvViewProj`; verify that pair with `fake_host_d3d11.exe` before shipping.

The composite is a post-process: it can reject guest pixels behind GTA geometry, but an effect cannot write GTA's depth buffer; an add-on or a draw hook is the current route. Re-test after a ReShade runtime change.

## Authority matrix

| Interaction | Authority | Fallback |
|---|---|---|
| Player position | GTA (host) | Minecraft camera follows the host root |
| Block placement | Minecraft (guest) | Host spawns hidden collision props |
| Damage | Guest for guest entities, host for host entities | Never apply the same event twice |
| Vehicle physics | GTA | Guest is a passenger; no guest collision |
| Camera | GTA during driving, guest on foot | Blend at the transition |

## Known engine traps

- GTA heading and Minecraft yaw use different zero points and signs; the `180 - heading` formula assumes both are degrees.
- `update\update.rpf` overrides base archives; edit the update archive when the asset is patched there.
- ScriptHookV must match the exact build; a mismatch fails silently in `ScriptHookV.log`.
- ReShade and ENB can both claim `dxgi.dll`/`d3d11.dll`; only one owns the slot.
- Minecraft's chunk origin is not the player origin; convert the entity position, not the chunk coordinate.

## Verification evidence

| Check | Result | Evidence |
|---|---|---|
| Offline IPC harness | pending | `ipc_link_test.exe` |
| Reversed-Z pixel test | pending | `fake_host_d3d11.exe` |
| Downstream sink fires | pending | `Present` counter |
| One traversal | pending | |
| One block placement | pending | |
| Save / reload | pending | |

## Rollback

- Backups: GTA save folder and Minecraft world copied before the first run.
- Disable order: stop the bridge, remove the ASI/ScriptHookV DLLs, remove ReShade, restore saves.
- Last known good: not recorded.
