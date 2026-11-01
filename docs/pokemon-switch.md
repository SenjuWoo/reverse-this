# Pokémon Switch titles on Windows: extraction, modding and native-port route

This note covers *Pokémon Sword/Shield*, *Scarlet/Violet*, *Legends: Arceus*
and *Legends: Z-A*. It is a route, not a claim that a supported one-click
converter exists. Use dumped files and keys only for games you own; do not
redistribute the ROM, extracted assets or keys.

## What engine these games use

These are Game Freak's proprietary Switch titles. They are **not Unity and not
Unreal Engine**, so AssetRipper, FModel, UABEANext and UE4SS do not convert
them. The games use NSP containers and a RomFS tree with Pokémon-specific
model/data formats such as `TRMDL`, `TRMSH`, `TRMBF`, `TRSKL`, `TRANIM`,
`BNTX`, plus game data and archive files. Confirm the actual tree for the
specific build with `nstool`; do not assume a path from another title.

## Can they be converted to a native Windows game?

There is no automatic emulator-to-native converter. A native Windows version
is a new game project that reuses extracted assets and reimplements the game
systems. For a fusion project, pick one target engine first:

| Target | Fit | Trade-off |
|---|---|---|
| **Godot 4.x** | Best default for a stylised Pokémon-scale fusion; light editor, C#, fast iteration; the kit already has Godot. | You rebuild battle, spawn, UI and save systems; third-party asset import is less mature than Unity. |
| **Unity** | Strong C# ecosystem, mature FBX/glTF importers, easier character/animation tooling. | Larger editor and project; licence/terms apply to the project and assets. |
| **Unreal Engine 5** | Only when high-fidelity rendering, large worlds or a team pipeline justify it. | Heavy editor and shader/material rebuild; usually slower to iterate for a stylised monster-battler fusion. |

For most Pokémon fusions, **Godot or Unity is more efficient than UE5**. Engine
choice does not make the port automatic: models, textures, animations, data,
battle logic and UI all need reconstruction or reimplementation.

## Extraction and conversion pipeline

1. **Inspect the container.** Keep the dump and keys outside the repository.
   Use `nstool -k <prod.keys> --fstree <game.nsp>` to list the NSP, then extract
   with `-x`. For an NCA, use the matching ticket (`--tik`) and `--fstree`
   before extracting the RomFS. Verify the title ID and build, and keep a
   read-only copy of the original dump.
2. **Textures.** `switch-toolbox` opens BNTX and many common Switch formats.
   Its TRMDL viewing is incomplete for Scarlet/Violet (upstream issue #658);
   prefer the Blender importer for models.
3. **Models and animations.** The
   [Pokémon Switch Model Importer/Exporter for Blender](https://github.com/ChicoEevee/Pokemon-Switch-Model-Importer-Blender)
   imports TRMDL/TRMSH/TRMBF and animations. It targets Blender 4.x/5.x. Its
   README says Z-A models are not working yet (checked 2026-11-01). Export to
   FBX or glTF, then import into Godot/Unity. Rebuild materials and shaders;
   do not expect the Switch material graph to survive.
4. **Game data.** `pkNX` edits Sword/Shield data; its README says Scarlet/Violet
   and Z-A are dump-only in the current build. Build it from source; it has no
   GitHub release asset. Use a copy of the dump and keep a clean backup.
5. **Saves and testing.** `PKHeX` can edit saves for test scenarios. Test asset
   swaps in the emulator with a LayeredFS `romfs` mod before rebuilding them in
   the native project.
6. **Native project.** Import only the assets you own into the chosen engine;
   build a data-driven species/move/encounter schema, then reimplement battle,
   AI, UI and save logic. A fusion of two titles means one project with a
   merged data model, not two executables glued together.

## Modding route

Ryujinx (or a compatible emulator) can load a `romfs` LayeredFS mod from the
game's mod directory. This is the fastest way to test model, texture or data
changes. It is still emulation, not a native port. Keep mods and extracted
assets out of Git unless their licences and your ownership allow distribution.

## Tool status on this kit

| Tool | Status |
|---|---|
| `nstool` | Installed, MIT, small CLI for NSP/XCI/NCA/RomFS inspection and extraction. You supply the keyset. |
| `switch-toolbox` | Installed, GPL-3.0 GUI, 44 MB. Useful for BNTX and common formats; TRMDL support is incomplete. |
| Pokémon Switch Blender importer | Manual Blender add-on; no release binary. Install the repository's add-on ZIP in Blender. |
| `pkNX` | Manual source build; GPL-3.0; Sword/Shield editing, Scarlet/Violet and Z-A dumping only. |
| `PKHeX` | Manual/upstream save editor; not an asset converter. |
| `UABEANext` | Unity-only modern UABEA fork; no stable release. Use its nightly build or source when the target is Unity, not these Pokémon titles. |
| `Kuriimu2` | Manual legacy route for supported archives; last release 1.2.1 (2021) needs .NET Core 3.1. |

## Verification

- Confirm the NSP title ID and build before extracting.
- Confirm one model imports into Blender and exports to FBX/glTF before
  converting a whole roster.
- Confirm one texture and one animation in the target engine before building a
  fusion scene.
- Record the exact game version, tool version and conversion path; a successful
  extraction is not a successful native port.
