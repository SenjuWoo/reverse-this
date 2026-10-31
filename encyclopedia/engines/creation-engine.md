# Creation Engine (Skyrim SE/AE, Fallout 4, Starfield)

## Fingerprint

| Signal | Creation Engine 1 (Skyrim LE/SE) | Creation Engine 2 (Fallout 4, Starfield) |
|---|---|---|
| Executable | `SkyrimSE.exe` (SE/AE), `Skyrim.exe` (LE) | `Fallout4.exe`, `Starfield.exe` |
| Archives | `.bsa` | `.ba2` |
| Plugins | `.esp`, `.esm`, `.esl` | `.esp`, `.esm`, `.esl` |
| Script extender | `skse64_loader.exe`, `skse64_*.dll` | `f4se_loader.exe`, `sfse_loader.exe` |
| Scripts | `.pex` (Papyrus) | `.pex` (Papyrus) |
| Data root | `Data\` | `Data\` |

`.bsa` and `.ba2` are different formats. Do not feed a BA2 to a BSA reader or vice versa.

## Coordinates

| Property | Value |
|---|---|
| Handedness | Right-handed |
| Up axis | `+Z` |
| Forward | `+Y` (engine); actors face `+Y` at yaw 0 |
| Unit scale | 64 units = 1 yard; 1 unit = 0.5625 in = 1.42875 cm; 128 units ≈ 1.8288 m |
| Rotations | Plugin records use degrees; NIF transforms use radians/quaternions. Convert at the boundary, not inside the math. |

Conversion to a Y-up meter runtime:

```
X_out =  X_ce * 0.0142875
Y_out =  Z_ce * 0.0142875
Z_out = -Y_ce * 0.0142875
```

## Depth

Skyrim SE and Fallout 4 render with a standard D3D11 depth range (`0.0` near, `1.0` far). Do not assume reversed-Z. Confirm with a depth readback before using any reprojection math.

## Loaders and proxy DLLs

| Name | Use | Conflict |
|---|---|---|
| `dinput8.dll` | Common ASI/proxy host | Some input mods also claim it |
| `winmm.dll` | Proxy host, rarely used by the game | Audio capture overlays |
| `version.dll` | Proxy host | Version-check shims |
| `dxgi.dll` | ReShade / overlay host | ENB and other DXGI hooks |
| `d3d11.dll` | ENB host | ReShade and DXGI overlays |

SKSE is not a proxy DLL. It launches the game and injects; do not stack a second loader on the same executable without checking the log.

## IAT hook rules

1. Resolve the target module by full path, not by name alone.
2. Hook only the functions you need, and only in the target process.
3. Match `CreateFileW` by normalized path (`Data\*.bsa`, `Data\*.ba2`) and preserve every flag.
4. Never strip `FILE_FLAG_NO_BUFFERING`: unbuffered I/O requires sector-aligned buffers and offsets, and changing the flag can turn a working read into `ERROR_INVALID_PARAMETER`.
5. Archive warming is bounded: read the header and the blocks the cell needs. Do not map a multi-gigabyte archive to "warm" it.

## Verification

- `skse64.log` / `f4se.log` shows the plugin loaded and the runtime version matches.
- A downstream sink fires on the first archive read (log the path and byte count).
- One cell or interior loads, saves, and reloads without a crash.
- Disable the hook and confirm the original behavior returns.

## Known traps

- AE versus SE runtime offsets differ; a plugin built for 1.5.97 requires a matching address library to load on 1.6.x.
- Loose files win over archives; a "missing" asset may be an override, not a failed read.
- `Data\` may be virtualized by a mod manager; resolve the real path from the running process.
