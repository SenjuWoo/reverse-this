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
- 7-Zip's current x64 MSI. `msiexec /a` extracts it into `sandbox/tools/7zip`. It is not installed for the machine. Not the arm64 build, not the 32-bit package, not the exe installer. `7z.exe` plus `7z.dll` is what unpacks the two tools below.
- LDtk's current Windows installer. 7-Zip extracts the 64-bit `app-64.7z` payload only. The installer is not executed. Not the 32-bit payload, not the macOS or Ubuntu zips.
- OpenBOR's current Windows rar. Not the Android apk and not the Linux AppImages.
- Fighter Factory's current official Windows portable zip. The download page is read at install time and the first Windows portable topic is the one that is downloaded. The shim is x64 `ffs.exe`. Not `ffs.qt4.exe`, not the 32-bit build, and not the installer topic.
- HD2Runtime's current SDK, runtime, example projects, and mod template zips, as four separate tools. HD2Runtime ModBuilder's current Windows x64 zip. The shim is `HD2RuntimeModBuilder.exe`, not the `HD2RuntimeGUI.exe` compatibility copy. The community SDK zip. Bingus Shared Loader's loader zip, not its source zip.
- R2API source for the current release tag. That repository publishes source, not a bench executable.
- Sleeping Dogs TheoryEngine source, SDK source (the repository's default branch), and the SDK playground examples. These trees contain no game executable.

## Left out

- `assetstudio`: the AssetStudio repository is archived. Use `assetripper`.
- `dnspy`: the original dnSpy repository is archived. Use `dnspyex`.
- `uabe`: original UABE is unsupported. Use `uabea`. UABEANext is the active source tree and publishes no release binary, so it is not unpacked.
- `umodel-ue4`: UModel is not the UE4/UE5 browser. Use `fmodel`, `repak` and `retoc`. UModel still matters for much older Unreal, and it is not in the one-click set.
- `cpp2il-2022-binary`: Cpp2IL's last published binary is the 2022 release. The source repository has continued and has not published a replacement binary. Use `il2cppdumper`.
- `ue4ss-stable`: the stable UE4SS tag lags the experimental release. The kit installs `ue4ss` from `experimental-latest`.
- `bepinex6-pre2`: BepInEx 6.0.0-pre.2 is an old prerelease. Mono games get current BepInEx 5. IL2CPP gets current MelonLoader. The UnityExplorer BepInEx 6 plugin is included for a game that already has that loader.
- `cheat-engine-download`: the Cheat Engine GitHub release ships no Windows binary. The website installer bundles offers. The kit does not download it. A portable copy can be placed in `sandbox/manual/cheat-engine/` by hand.
- `reclass-rar`: ReClass.NET's only published binary is the 2019 v1.2 rar. The source kept changing through 2024 and published no newer binary. The kit can unpack a current rar. This one is stale. A portable copy can be placed in `sandbox/manual/reclass/` by hand.
- `3dmigoto-tag`: the tagged 3Dmigoto release is from 2018, the repository has continued, and that one release attaches every historical zip. A pattern cannot select a single current file. It is not part of the one-click set.
- `sinai-unityexplorer`: `sinai-dev/UnityExplorer` is archived. The kit uses the yukieiji builds.
- `frosty-rewrite`: `FrostyToolsuite/FrostyToolsuite` publishes no release. Use `frosty-editor` and `frosty-modmanager`.
- `ldtk-installer`: the old id for LDtk's installer. The installed tool is `ldtk`.
- `openbor-rar`: the old id for OpenBOR's rar. The installed tool is `openbor`.
- `fighter-factory-installer`: the old id for the dump's installer. The installed tool is `fighter-factory`.

Also not unpacked, because they install into their own directories or are not redistributable here: ReShade, NVIDIA Nsight, PIX, RTX Remix, and paid shader packs.

The Sleeping Dogs game executable and its PDB are not downloaded. TheoryEngine's README points at a file host for "Game Executable" and "Debug Symbols (PDB)". Those are the game, not a tool. The public GitHub source trees are what the kit installs.

The dump's other new folders are not a second kit. `GoDot/LimboAi` is another Godot editor build, not the LimboAI addon. IKEMEN Forge is a Claude Code plugin (`nategarelik/ikemen-forge`), not a bench executable. `UE-Modding-Tools` is a link list: the commonly used packers are already `repak`, `retoc`, FModel and UAssetGUI. ZenTools is deprecated upstream in favor of retoc. kismet-analyzer publishes no release binary. QuickBMS and the old UnrealPak rar are not unpacked.

Helldivers 2's public runtime, SDKs, ModBuilder, and loader are installed. Sleeping Dogs TheoryEngine, its SDK, and the SDK playground are installed from their public source archives. R2API is installed from the current release tag's source archive. None of those downloads include a game executable.

Duplicate trees of the same UE4SS build (`zDEV` next to the release) are not installed. One copy is enough.
