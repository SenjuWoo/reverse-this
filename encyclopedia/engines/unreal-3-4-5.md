# Unreal Engine 3 / 4 / 5

## Fingerprint

| Signal | UE3 | UE4 / UE5 |
|---|---|---|
| Executable | `Binaries\Win32\*.exe`, `Binaries\Win64\*.exe` | `Binaries\Win64\*.exe`, `*-Win64-Shipping.exe` |
| Cooked data | `.upk`, `.u`, `CookedPC*` | `.pak`, `.utoc` + `.ucas` (IoStore) |
| Project files | `.ini`, `.int` | `.uproject` (editor/source), `.ini` |
| Scripting | UnrealScript (cooked) | Blueprints (cooked), C++ |
| Loader | UE4SS (UE4/5), SDK dumpers | UE4SS (experimental), FModel, repak, retoc |
| Physics | PhysX | PhysX (UE4) / Chaos (UE5) |

UE3 packages and UE4/5 packages are not interchangeable. A `.upk` is not a `.pak`.

## Coordinates

| Property | Value |
|---|---|
| Handedness | Left-handed |
| Up axis | `+Z` |
| Forward | `+X` |
| Unit scale | UE4/5: 1 Unreal Unit = 1 cm. UE3: often 1 UU = 1 cm, but titles rescale; verify against a known actor. |
| Rotations | Yaw around Z, pitch around Y, roll around X; degrees in Blueprint/INI, radians in some native APIs |

Conversion to a Y-up meter runtime:

```
X_out =  X_ue * 0.01
Y_out =  Z_ue * 0.01
Z_out = -Y_ue * 0.01
```

UE is left-handed; a straight axis swap without the sign change mirrors the world. Test with a known landmark before shipping.

## Depth

UE4/5 default to a reversed-Z depth buffer (`1.0` near, `0.0` far) with a floating-point depth target. UE3 titles vary; read the depth buffer and test a near/far sample before writing reprojection math.

## Loaders and proxy DLLs

| Name | Use | Conflict |
|---|---|---|
| `dinput8.dll` | UE4SS and ASI hosts | Input mods |
| `winmm.dll` | Proxy host | Audio overlays |
| `xinput1_3.dll` / `xinput1_4.dll` | Proxy host, controller shims | Controller remappers |
| `dwmapi.dll` | Proxy host | Desktop composition overlays |
| `dxgi.dll` | ReShade / overlay host | Other DXGI hooks |

UE4SS ships as a set of DLLs and Lua scripts; copy the whole folder, not just `UE4SS.dll`.

## Hollow-shell streaming

For a hollow building shell, do not cook a second collision world. Stream collision tiles around the player:

1. Raycast down from the guest camera to find the floor.
2. Spawn host collision blocks for the tiles within the streaming radius.
3. Despawn tiles behind the player; keep a one-tile margin.
4. Re-run the floor raycast after every teleport; a stale floor height is the usual "falling through the world" bug.

PhysX (UE4) and Chaos (UE5) expose different trace APIs. A collision shape that works in one may be ignored by the other.

## Verification

- UE4SS log shows the Lua mod loaded and the SDK dump completed.
- A downstream sink fires (`Present`, a UI text, or an actor spawn log).
- One actor spawns, collides, and is removed without a crash.
- Disable the mod and confirm the original behavior returns.
