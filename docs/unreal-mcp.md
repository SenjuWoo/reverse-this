# Unreal archives for an agent: FModel MCP (optional)

`fmodel-mcp` is a local stdio MCP server built on CUE4Parse, the parser behind
FModel. It lets an agent open a game's `.pak` or IoStore (`.utoc`/`.ucas`)
archives, browse and search assets, read package properties, decompile
Blueprints to pseudocode, preview textures and export textures, meshes,
animations, audio and worlds, without driving the FModel GUI. Use FModel itself
when a person is browsing; use repak or retoc to unpack or repack archives.

## Install and check

```powershell
.\Install-Modkit.ps1 -Only fmodel-mcp
.\sandbox\bin\fmodel-mcp.cmd --help
```

The catalog installs the official self-contained release zip (the .NET runtime
is included) after checking its GitHub SHA-256 digest. It does not run the
upstream `Install-Mcp.ps1`, write `%LOCALAPPDATA%\FModelMcp`, or register the
server with any MCP client. Registration is the user's choice.

## Configuration

The server reads only the folders listed in a JSON file passed with
`--config <absolute path>` (or `FMODEL_MCP_CONFIG`). Without one it may read
only its working directory, which the MCP client chooses, so always pass a
config. Keep it and the exports in the ignored work folder:

```json
{
  "inputRoots": [
    "D:/Games/MyGame/MyGame/Content/Paks",
    "D:/Unreal/Mappings"
  ],
  "outputRoot": "<kit>/sandbox/work/fmodel-mcp/exports"
}
```

Save it as `sandbox\work\fmodel-mcp\config.json`. Unknown fields are rejected.
Optional fields: `oodleLibrary` (an x64 Oodle DLL for Oodle-compressed games),
`fmodelSettingsPath` (FModel's `AppSettings.json`, to reuse a game already set
up in FModel with its engine profile, AES keys and mapping), and the limits
`maxSessions`, `maxJobs`, `maxBatchAssets`, `maxReadBytes`,
`maxResponseChars`. The full field and tool reference is in the release's
`docs/` folder.

For a game without a saved FModel profile, the agent calls `fmodel_open_game`
with the CUE4Parse engine profile (`fmodel_list_options` lists them), an
absolute `.usmap` path for unversioned games and AES keys if the archives are
encrypted. Never write AES keys into the config, a log, a commit or a report.

## Registering it with a client

Point the client at the kit shim and the config. A generic stdio entry:

```json
{
  "command": "<kit>\\sandbox\\bin\\fmodel-mcp.cmd",
  "args": ["--config", "<kit>\\sandbox\\work\\fmodel-mcp\\config.json"]
}
```

For Claude Code: `claude mcp add fmodel -- "<kit>\sandbox\bin\fmodel-mcp.cmd" --config "<kit>\sandbox\work\fmodel-mcp\config.json"`.
Server 1.2.0 negotiates MCP protocol revisions up to `2025-11-25` in
`initialize`.

## Limits

- The input allowlist, confined export folders and size limits are the
  server's own checks, not an operating-system sandbox. A malicious archive
  could exploit a parser bug; open only archives you trust.
- A game patch can change the engine version, mapping or keys; a session that
  opened yesterday is not proof for today's build.
- The upstream security notes list advisories in the ImageSharp version that
  CUE4Parse pins; it is used only to write landscape heightmaps on export.

## Bringing exports into Blender or Unreal

FModel and the MCP can export models and animations as UEFormat
(`.uemodel`, `.ueanim`, `.ueworld`). The importers are
[UEFormat](https://github.com/h4lfheart/UEFormat)'s Blender add-on and Unreal
plugin. They belong to the DCC side, so this kit does not install them; glTF or
PSK/PSA exports work with stock importers.
