# Pokémon Switch titles — engine and native-port route

## Engine fingerprint

*Sword/Shield*, *Scarlet/Violet*, *Legends: Arceus* and *Legends: Z-A* are
Game Freak's proprietary Switch titles. They are **not Unity** and **not
Unreal Engine**; AssetRipper, FModel, UABEANext and UE4SS do not convert them.
Their containers are NSP/XCI and their RomFS trees carry Pokémon-specific
formats such as `TRMDL`, `TRMSH`, `TRMBF`, `TRSKL`, `TRANIM`, `BNTX` and
game-data archives. Verify the specific build's tree before assuming a path.

## Native-port reality

No supported emulator-to-native converter exists. A Windows version is a new
project that reuses extracted assets and reimplements the game systems.

| Engine | Use it when | Cost |
|---|---|---|
| Godot 4.x | Default for a stylised Pokémon-scale fusion; light editor, C#, fast iteration. | Rebuild battle, spawn, UI and save systems. |
| Unity | You need mature FBX/glTF and character/animation tooling. | Larger editor and project; project/licence terms apply. |
| Unreal Engine 5 | High-fidelity rendering, large worlds or a team pipeline justify it. | Heavy editor and material/shader rebuild; slower iteration. |

For most fusions, Godot or Unity is more efficient than UE5. Engine choice does
not make the port automatic.

## Working pipeline

1. `nstool -k <keys> --fstree <game.nsp>`; extract the NSP and the matching
   NCA/RomFS with its ticket. Keep the original dump read-only.
2. `switch-toolbox` for BNTX textures and common formats. Its TRMDL viewing is
   incomplete for Scarlet/Violet (upstream issue #658).
3. The [Pokémon Switch Model Importer/Exporter for Blender](https://github.com/ChicoEevee/Pokemon-Switch-Model-Importer-Blender)
   imports TRMDL/TRMSH/TRMBF and animations in Blender 4.x/5.x. Z-A models were
   not working per its README on 2026-11-01. Export FBX/glTF and rebuild
   materials in the target engine.
4. `pkNX` edits Sword/Shield data; Scarlet/Violet and Z-A are dump-only in its
   current README. `PKHeX` is a save editor, not an asset converter.
5. Test asset swaps in the emulator with a LayeredFS `romfs` mod before
   rebuilding them natively.
6. Build one native project with a merged, data-driven species/move/encounter
   schema. A fusion is not two executables glued together.

The full guide, including tool status and limits, is
[docs/pokemon-switch.md](../../docs/pokemon-switch.md).

## Coordinates

The Blender importer applies the game's model orientation; do not assume Unity
or Unreal axes. Export a test model, record the axis/scale transform used, and
verify it in the target engine before batch conversion.

## Depth

These workflows are asset and data ports. They do not need a runtime depth
buffer hook; that is only relevant to rendering-injection projects.

## Verification

- Confirm the title ID/build before extraction.
- Import one model, one texture and one animation before converting a roster.
- Record game version, tool version and conversion path. A successful
  extraction is not a successful native port.

## Scope

Use dumps and keys only for games you own. Do not redistribute ROMs, keys,
extracted assets or converted asset packs.
