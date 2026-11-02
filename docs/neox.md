# NeoX engine and NPK archives

NetEase's NeoX engine stores shipped assets in `.npk` / `.npkx` archives.
*Once Human* is a NeoX title; its install has `res_global-normal_*.npk` files
in the game root. The same container family appears in other NetEase titles,
but keys, compression and config differ by game and build.

## Installed tools

| Tool | Use |
|---|---|
| `neoxtractor` | GUI browser/extractor for NPK/EXPK; select the archive, choose the game config, and extract entries. Some titles need an XOR key in its Config Manager. |
| `quickbms` | Generic script-driven archive extractor. Tested on `Once Human\res_global-normal_pack_17.npk` with a community NXPK BMS script: 6 files extracted, including PVR textures. |

QuickBMS needs a `.bms` script. The kit does not redistribute a Once Human
script because the community script used for the test has no declared licence.
Download a script from a source you trust, inspect it, create the output folder
first, and run:

```text
mkdir out
quickbms.exe <script.bms> "<game>\res_global-normal_pack_*.npk" "out"
```

QuickBMS asks for confirmation when the output folder does not exist and fails
in non-interactive shells, so create it up front.

`neoxtractor` is the out-of-box GUI route; QuickBMS is the scriptable route.
Neither is a universal decrypter: a game-specific key/config may still be
needed.

## Release selection

On 2026-11-02, upstream NeoXtractor v3.3 was published without release assets;
v3.2 still supplied the Windows ZIP. Reverse THIS! 1.13.1 selects that newest
installable stable build and logs the fallback, without pinning NeoXtractor to
v3.2. A newer stable Windows binary is selected automatically when available.
The cached v3.2 payload is verified and reused rather than downloaded again.

## Once Human-specific route

[Rime](https://dtzxporter.com/tools/rime) by DTZxPorter is a dedicated Once
Human asset extractor. It is closed-source and hosted outside GitHub, so it is
manual-only here. Do not download random mirrors; use the official page and
verify the file. Aexadev's NeoX extractor advertises Once Human support but is
not publicly distributed; it is not bundled.

## Scope

Use the archives from a game you own. Do not redistribute NPK contents,
extracted models/textures/audio, or keys. This is a local analysis route, not
an online-game bypass.
