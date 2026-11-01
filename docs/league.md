# League of Legends and Teamfight Tactics asset route

League stores its shipped assets in `.wad.client` archives under
`Game/DATA/FINAL/`. `wadtools` is installed for read-only listing and extraction:

```text
wadtools list  -i "C:\Riot Games\League of Legends\Game\DATA\FINAL\DATA.wad.client" -F json
wadtools extract -i "<archive>.wad.client" -o "sandbox\work\league\<archive>"
```

`wadtools` scans `.bin` chunks to recover paths by default. The first listing
may download/update its shared hash tables; keep that cache outside the repo.
`DATA.wad.client` on the inspected install resolved 4,653 chunks and about
145.6 MB uncompressed, so extraction is real data work, not a metadata-only
dump.

## LTK Manager

[LTK Manager](https://github.com/LeagueToolkit/ltk-manager) is the official
LeagueToolkit mod manager and modding IDE (GPL-3.0). It is a user-facing mod
manager, not a portable extractor: its installer changes a client-side mod
setup. It is documented here but not auto-installed by this kit. Use it only
for authorised cosmetic mods you have the right to use, keep a backup, and do
not expect it to bypass Vanguard or any anti-cheat. `wadtools` is the safe
read-only route when you only need to inspect or extract assets.

## Scope

- Do not redistribute Riot assets, extracted files or mod packs.
- Do not use asset changes to gain a competitive advantage.
- Vanguard and Riot's terms still apply; a local skin mod is not permission to
  modify the online client or evade detection.
- Test against a copy and keep the original `.wad.client` files.
