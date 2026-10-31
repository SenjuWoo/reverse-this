# Arkham Knight x Spider-Man

## Identity

| Field | Value |
|---|---|
| Host game / store edition | Spider-Man (Insomniac engine), Steam |
| Guest game / store edition | Batman: Arkham Knight, Steam `v4.0630` |
| Host build id | not recorded |
| Guest build id | `v4.0630` (user-provided) |
| Host EXE SHA256 | not recorded |
| Guest EXE SHA256 | not recorded |
| Loader / proxy DLL | Host `dinput8.dll`; guest `winmm.dll` |
| Loader version | not recorded |
| Toolchain | not recorded |
| Date verified | 2026-10-31 (design review only) |
| Owner / workspace | local lab |

## Coordinate conversion

Arkham Knight is UE3: Z-up, left-handed, 1 Unreal Unit = 1 cm (verify per build). The Insomniac host is Y-up, meters.

Matrix (Arkham -> host):

```
X_h =  X_ak * 0.01
Y_h =  Z_ak * 0.01
Z_h = -Y_ak * 0.01
```

Yaw (UE yaw is around +Z; host yaw is around +Y):

```
Yaw_h = -Yaw_ak
```

Known landmark: the clock tower roof edge. Record the guest and host positions before trusting the matrix.

## IPC

| Field | Value |
|---|---|
| Mapping name | `Local\ArkWeb_v1` |
| Header version | 1 |
| Slots | 3 (seqlock, `ipc_seqlock.h`) |
| Frame fields | RGBA, linear depth, near/far, guest view-projection, camera world, frame id |
| Bridge transport | WebSocket `127.0.0.1` for commands; shared memory for per-frame pose/depth |

## Authority matrix

| Interaction | Authority | Fallback |
|---|---|---|
| Traversal (swing, wall-run, grapple) | Host | Guest camera follows host root; guest animation is cosmetic |
| Freeflow combat | Guest | Host renders proxy entities and forwards damage |
| Bone scaling (combat hit reactions) | Guest during Freeflow, Host during traversal | Swap on a state transition, not per frame |
| Collision blocks | Host | Guest sends block placement; host spawns hidden collision props |
| Camera | Host during traversal, Guest during combat | Blend for 0.25 s at the swap; never snap |

The bone-scaling authority swap is the fragile part. Gate it on an explicit combat state, not on animation names. On swap, send the current pose and scale once, then let the new authority drive.

## Command log and floor clamp

`logs\ak_cmd.txt` is the guest command log. Parse the last command per tick and clamp the guest Z to the host floor height plus a margin:

```
z_guest = max(z_guest, host_floor_z + 0.05)
```

The clamp prevents the guest capsule from falling through a host-only floor during a traversal-to-combat transition. Log every clamp; a silent clamp hides a conversion bug.

## Known engine traps

- UE3 cooked packages do not expose source names; a hook on a wrapper may not run in a cooked build.
- The guest and host may both apply root motion during the swap frame; disable one for that frame.
- Insomniac's host uses meters; a 100x scale error looks like "the camera is inside the floor".
- `winmm.dll` and `dinput8.dll` must be loaded before the guest's first frame; a late load loses the first pose.

## Verification evidence

| Check | Result | Evidence |
|---|---|---|
| Offline IPC harness | pending | `ipc_link_test.exe` |
| Reversed-Z pixel test | pending | `fake_host_d3d11.exe` |
| Downstream sink fires | pending | `Present` counter |
| One traversal | pending | |
| One combat exchange | pending | |
| Save / reload | pending | |

## Rollback

- Backups: guest save folder copied before the first run.
- Disable order: stop the bridge, remove `winmm.dll`, remove `dinput8.dll`, restore saves.
- Last known good: not recorded.
