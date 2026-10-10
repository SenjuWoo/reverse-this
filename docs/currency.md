# What is in the kit, and what was left out

The installer resolves the current official release at install time. This page is the cut list. It names projects, not pins, except where the pin itself is the thing being rejected.

## Installed on purpose

- Ghidra's current public release, with JDK 25. Headless is `analyzeHeadless`.
- ImHex's Windows portable x64 zip. Not the NoGPU build, not the arm64 build, not the MSI.
- Detect It Easy's win64 portable zip from `horsicq/DIE-engine`. `diec` is the CLI. `detectiteasy.com` is not an official download.
- x64dbg's current snapshot zip, the x64 debugger. Not the symbols zip.
- PE-bear's Qt 6 x64 Windows zip.
- dnSpyEx's `dnSpy-net-win64` zip. Not the .NET Framework build.
- ILSpy's self-contained Windows x64 zip, plus the `ilspycmd` dotnet tool.
- AssetRipper's Windows x64 zip.
- Il2CppDumper's Windows zip (`Il2CppDumper-win-`), not the net6 or net7 framework-dependent zips.
- FModel's current zip.
- repak and retoc Windows x64 CLI zips. repak is `.pak`. retoc is IoStore. Neither replaces the other.
- UAssetGUI's published exe, and the current DirectXTex `texconv`, `texassemble` and `texdiag` exes. Not the arm64 exes.
- UABEA's Windows zip. That is the Unity asset editor that still publishes a binary.
- BepInEx 5's current Windows x64 release, for Mono games.
- MelonLoader's current x64 zip, for Mono and IL2CPP.
- UnityExplorer builds from the yukieiji fork: BepInEx 5 Mono, BepInEx 6 Mono, and MelonLoader IL2CPP. Those are plugins, not loaders.
- UE4SS from the `experimental-latest` release, asset `UE4SS_*.zip` only. Not `zDEV`, not `zCustomGameConfigs`, not `zMapGenBP`.
- RenderDoc's stable portable x64 zip from `renderdoc.org`, using the version of the current GitHub release tag. Not the nightly. Not the MSI.
- MinHook's bin zip, for C. SafetyHook's amalgamated Zydis sources, for new C++.
- Frida tools in a venv under `sandbox/tools/frida`.
- Frosty Editor and Frosty Mod Manager from the current stable release (`FrostyEditor.zip` and `FrostyModManager.zip`). Not the bundled prereq installers. Those stay inside the unpacked zip and are not shims.
- Godot's current stable mono win64 zip. The shim is the console executable. Not the win32 zip, not the arm64 zip, not the non-mono `.exe.zip`.
- GDRE Tools' Windows zip, for packed Godot games.
- IKEMEN Go's Windows zip. Not the Android, Linux, or macOS zips.
- Pixelorama's Windows 64-bit zip. Not the 32-bit zip and not the setup exe.

## Left out

- `assetstudio`: the AssetStudio repository is archived. Use `assetripper`.
- `dnspy`: the original dnSpy repository is archived. Use `dnspyex`.
- `uabe`: original UABE is unsupported. Use `uabea`. UABEANext is the active source tree and publishes no release binary, so it is not unpacked.
- `umodel-ue4`: UModel is not the UE4/UE5 browser. Use `fmodel`, `repak` and `retoc`. UModel still matters for much older Unreal, and it is not in the one-click set.
- `cpp2il-2022-binary`: Cpp2IL's last published binary is the 2022 release. The source repository has continued and has not published a replacement binary. Use `il2cppdumper`.
- `ue4ss-stable`: the stable UE4SS tag lags the experimental release. The kit installs `ue4ss` from `experimental-latest`.
- `bepinex6-pre2`: BepInEx 6.0.0-pre.2 is an old prerelease. Mono games get current BepInEx 5. IL2CPP gets current MelonLoader. The UnityExplorer BepInEx 6 plugin is included for a game that already has that loader.
- `cheat-engine-download`: the Cheat Engine GitHub release ships no Windows binary. The kit does not download the website installer. A portable copy can be placed in `sandbox/manual/cheat-engine/` by hand.
- `reclass-rar`: ReClass.NET's published asset is an old rar. The kit does not unpack rars.
- `3dmigoto-tag`: the tagged 3Dmigoto release is years behind the repository. It is not part of the one-click set.
- `sinai-unityexplorer`: `sinai-dev/UnityExplorer` is archived. The kit uses the yukieiji builds.
- `frosty-rewrite`: `FrostyToolsuite/FrostyToolsuite` publishes no release. Use `frosty-editor` and `frosty-modmanager`.
- `ldtk-installer`: LDtk's Windows asset is an installer. A portable copy can be placed in `sandbox/manual/ldtk/` by hand.
- `openbor-rar`: OpenBOR's Windows asset is a rar. The kit does not unpack rars. A portable copy can be placed in `sandbox/manual/openbor/` by hand.
- `fighter-factory-installer`: the dump only has an installer. A portable copy can be placed in `sandbox/manual/fighter-factory/` by hand.

Also not unpacked, because they install into their own directories or are not redistributable here: ReShade, NVIDIA Nsight, PIX, RTX Remix, and paid shader packs.

The dump's other new folders are not a second kit. `GoDot/LimboAi` is another Godot editor build, not the LimboAI addon. IKEMEN Forge is a Claude Code plugin (`nategarelik/ikemen-forge`), not a bench executable. `UE-Modding-Tools` is a link list: the commonly used packers are already `repak`, `retoc`, FModel and UAssetGUI. ZenTools is deprecated upstream in favor of retoc. kismet-analyzer publishes no release binary. QuickBMS and the old UnrealPak rar are not unpacked.

Helldivers 2 runtimes, SDKs and ModBuilder stay out. That game has anti-cheat. Sleeping Dogs TheoryEngine, its SDK, and `sdhdship.exe` are game-owned. R2API is a Risk of Rain 2 library tree, not a bench executable. None of those are downloaded.

Duplicate trees of the same UE4SS build (`zDEV` next to the release) are not installed. One copy is enough.
