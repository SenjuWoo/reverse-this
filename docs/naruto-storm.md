# Naruto Storm and Shinobi Striker route

## NARUTO X BORUTO Ultimate Ninja Storm Connections

`NSUNSC.exe` is a CyberConnect2 title. Its shipped data is in
`data/launch/*.cpk` (including `data1.cpk`, `data3.cpk`, `platform*.cpk`,
`sound*.cpk`) and `data/disc/movie2.cpk`; the executable also references
`data/**/*.xfbin` scripts and records. CPK is CRIWARE's archive format and
XFBIN is CyberConnect2's serialized data format.

The practical route is:

1. Back up the original `.cpk` files.
2. Extract a CPK with a CPK tool that supports the archive's encryption and
   layout. The commonly used open-source route is
   [CriPakTools](https://github.com/esperknight/CriPakTools) (list/extract/
   replace); it has no packaged release and no declared licence, so this kit
   does not redistribute it. Build it from source or use a tool you are
   licensed to run.
3. Edit `.xfbin` data with a Storm-specific toolbox such as
   [NSC-Toolbox](https://github.com/TheLeonX/NSC-Toolbox) (21 MB release;
   no declared licence, so it is manual-only here).
4. Repack or load the changed files through the game's supported mod/overlay
   route. Keep the original archive and test one change at a time.

The CPK contains copyrighted game data. Do not redistribute extracted files,
rebuilt CPKs or converted assets.

## Naruto to Boruto: Shinobi Striker

This is an Unreal Engine 4 game (`Engine/`, `NARUTO/Content/`) protected by
EasyAntiCheat. The existing Unreal tools apply to local inspection:
`fmodel`, `repak`, `retoc`, `uassetgui` and UE4SS. EAC means online play and
modded clients are a risk; use offline/cosmetic work only, never attempt to
disable or bypass EAC, and expect a modified client to be rejected.

## What is installed

`nstool` and `switch-toolbox` are for Nintendo Switch titles and do not apply
here. The Naruto CPK/XFBIN route is documented as manual because the useful
tools have no permissive redistributable release. The Unreal route uses the
already-installed Unreal tools.
