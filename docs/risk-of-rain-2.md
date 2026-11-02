# Risk of Rain 2 survivor mods: source-to-Unity route

Risk of Rain 2 is Unity Mono (observed 2021.3.45f2 on this install). Mods load
through BepInEx and R2API; Thunderstore packages are ZIPs with a manifest,
plugins and optional assets. The kit supplies analysis/conversion tools, not a
survivor template or a finished Unity project.

## Gnar — League of Legends source

The local Gnar resource bundle used this verified route:

1. `wadtools` lists/extracts `Champions\Gnar.wad.client` and the `en_US` audio
   WAD.
2. `ritobin-tools` converts League BIN definitions to readable JSON.
3. `ltk-tex-utils` decodes League TEX files to PNG.
4. `lol2gltf` converts `skn` + `skl` + `anm` to a glTF with the character clips.
5. `bnk-extract` extracts the Wwise BNK/WPK; `vgmstream` decodes the WEMs to WAV.
6. The glTF validator checks the output; DirectXTex handles DDS HUD icons.
7. Unity imports the glTF/textures/audio, a BepInEx + R2API project builds the
   survivor and asset bundles, and Thunderstore packages the result.

`ritobin-tools`, `lol2gltf` and `vgmstream` are installed now. `ltk-tex-utils`
and `bnk-extract` are manual routes because their releases have no declared
licence. The existing `wadtools` and DirectXTex tools are already installed.

## Ultron — Marvel Rivals source

The Ultron workspace used a source-built CUE4Parse checkout plus a
`mappings.usmap`, then baked the meshes, textures and audio into the Unity
project. FModel/repak/retoc/UE4SS are the installed Unreal alternatives; they
are not a drop-in replacement for that exact CUE4Parse pipeline. Marvel Rivals
is an online, anti-cheat-protected game: use extracted assets only in the
offline RoR2 project, never to modify or bypass the live client.

## Kisame — Naruto Storm 4 source (WIP)

Kisame's source assets are CyberConnect2 `.xfbin` files extracted from the
Naruto Storm 4 CPK. The workspace carries `xfbin_lib` and `probe_xfbin.py`.
The upstream `xfbin_parser` v1.2.2 is archived and has no declared licence, so
it is documented as a manual route, not auto-installed. Extract the CPK with a
CPK tool, parse the XFBIN chunks, convert the mesh/textures in Blender or your
DCC, then import into Unity/R2API.

## What the kit does not fake

A model conversion is not a working survivor. You still need Unity prefabs,
materials, animator setup, R2API content registration, networking, balance,
and a game test. Keep source-game assets out of public packages unless you have
the rights to distribute them.
