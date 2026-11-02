# NeoX / NeoX Engine (NetEase)

## Fingerprint

| Signal | Value |
|---|---|
| Engine | NetEase NeoX |
| Shipped archives | `.npk`, sometimes `.npkx`; Once Human uses `res_global-normal_*.npk` |
| Strings | `NeoX`, `nxpk`, `NeoXEngine`, `res_global` |
| Executables | A launcher plus the game executable; anti-cheat may be present in online titles |
| Runtime data | `.pvr` textures, mesh/material bundles, Wwise audio in some titles |
| First-party tooling | None published; community extractors only |

NeoX is not Unreal or Unity. Do not apply `.pak`/`.ucas` or AssetBundle tooling to an NPK archive.

## Coordinates

NeoX titles vary by project. Do not assume a global axis convention from the engine
name. Read one known mesh/transform from the target build, compare it with a
landmark in-game, and record the tested conversion in the game card. A common
Y-up conversion is only a starting hypothesis; mirrored or rotated imports are
usually an axis-sign error, not a broken mesh.

## Depth

Depth convention is title-specific. Capture a near and far sample before writing
reprojection or depth-based effects; do not assume reversed-Z because another
NeoX game uses it.

## Extraction route

1. Identify the archive set and whether it is encrypted (try a small pack first).
2. `neoxtractor` (GUI) for NPK/EXPK browsing and extraction; use the per-game
   config/XOR key when required.
3. `quickbms` with a trusted NXPK `.bms` script for scripted extraction. Create
   the output folder first. The kit does not bundle a Once Human script whose
   licence is undeclared.
4. For Once Human specifically, Rime is the dedicated manual route.

Models, textures and audio need format-specific importers after extraction;
there is no general NPK-to-Unity/Unreal converter.

## Verification

- The archive lists a plausible file count and extracts without truncation.
- A small texture opens in an image tool and a mesh imports with sane bounds.
- The same archive version and key reproduce the result on a second run.
- Keep extracted assets out of public packages unless distribution rights are
  clear. Online-game anti-cheat is a separate boundary from offline analysis.
