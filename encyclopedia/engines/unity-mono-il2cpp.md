# Unity Mono / IL2CPP

## Fingerprint

| Signal | Mono | IL2CPP |
|---|---|---|
| Player | `UnityPlayer.dll` | `UnityPlayer.dll` |
| Runtime | `MonoBleedingEdge\` | `GameAssembly.dll` |
| Game code | `*_Data\Managed\Assembly-CSharp.dll` | `GameAssembly.dll` + `*_Data\il2cpp_data\Metadata\global-metadata.dat` |
| Managed assemblies | Many `.dll` files | Stripped; metadata is the map |
| Loader | BepInEx 5, BepInEx 6 (pre-release), MelonLoader | MelonLoader, BepInEx 6 IL2CPP (pre-release), Il2CppInterop |
| Inspector | UnityExplorer (BepInEx/MelonLoader builds) | UnityExplorer MelonLoader IL2CPP build |

`MonoBleedingEdge` plus `Assembly-CSharp.dll` means Mono. `GameAssembly.dll` plus `il2cpp_data` means IL2CPP. Do not install a Mono plugin into an IL2CPP game.

## Coordinates

| Property | Value |
|---|---|
| Handedness | Left-handed |
| Up axis | `+Y` |
| Forward | `+Z` |
| Unit scale | 1 Unity unit = 1 meter |
| Rotations | Quaternions; `Transform.eulerAngles` is degrees, yaw around Y |

Conversion to a Z-up centimeter runtime:

```
X_out =  X_unity * 100
Y_out = -Z_unity * 100
Z_out =  Y_unity * 100
```

## Depth

Unity's D3D11/D3D12/Vulkan renderers commonly use a reversed-Z depth buffer; some paths and older renderers use standard depth. Read the depth texture and test near/far before writing reprojection math.

## Loaders

| Loader | Runtime | Notes |
|---|---|---|
| BepInEx 5 | Mono | Current stable line for Mono games |
| BepInEx 6 | Mono / IL2CPP | Pre-release; pin the exact build |
| MelonLoader | Mono / IL2CPP | Current x64 zip; IL2CPP support is the reason it is here |
| UnityExplorer | Matching loader/runtime | In-game scene inspector, not a loader |

Copy the loader into the game folder; do not replace `UnityPlayer.dll` unless the loader explicitly documents that route.

## Harmony patterns

```csharp
[HarmonyPatch(typeof(PlayerController), nameof(PlayerController.Update))]
static class PlayerControllerUpdatePatch
{
    static void Prefix(PlayerController __instance) { /* before original */ }
    static void Postfix(PlayerController __instance) { /* after original */ }
    static IEnumerable<CodeInstruction> Transpiler(IEnumerable<CodeInstruction> instructions)
    {
        // Rewrite IL only after dumping the original instructions.
        return instructions;
    }
}
```

Rules:

1. Prefix/postfix first; a transpiler is the last resort.
2. Dump the original IL before rewriting it; keep a diff.
3. Guard every patch with a config toggle and a try/catch that logs once.
4. Re-check the patch after every game update; managed method signatures move.

## Proxy DLLs

| Name | Use | Conflict |
|---|---|---|
| `winmm.dll` | Proxy host | Audio overlays |
| `version.dll` | Proxy host | Version shims |
| `dinput8.dll` | Proxy host | Input mods |
| `dxgi.dll` | ReShade / overlay | Other DXGI hooks |

## Verification

- BepInEx console or `BepInEx\LogOutput.log` shows the plugin loaded.
- UnityExplorer shows the patched object or the spawned proxy.
- A downstream sink fires (UI text, frame counter, or `Present`).
- Disable the plugin and confirm the original behavior returns.
