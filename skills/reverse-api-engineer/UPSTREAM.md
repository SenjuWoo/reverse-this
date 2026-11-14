# Upstream agent skill (vendored, unmodified)

- Source: https://github.com/kalil0321/reverse-api-engineer, `skills/reverse-api-engineer`
- Tag `v0.15.0`, commit `276e37667de5e290487c97c351c09ea53b11b468`
- Licence: MIT, copied as `LICENSE` in this folder
- Matches the CLI pin in `catalog/tools.json` (`reverse-api-engineer` 0.15.0)

`SKILL.md` and `references/` are byte-for-byte upstream so a later pin can be
diffed directly. Kit-specific differences:

- Install with `.\Install-Modkit.ps1 -Only reverse-api-engineer`, not
  `uv tool install`; call `sandbox\bin\reverse-api-engineer.cmd` (never `rae`,
  which belongs to REA).
- Run from `sandbox\work\web-api` so runs, HAR files and synced clients stay in
  an ignored folder.
- New configs default to `agent_provider: chrome-mcp` (the user's Chrome, no
  HAR). For a reusable capture set `"agent_provider": "auto"` in
  `~/.reverse-api/config.json` with the user's agreement, or add `--headless`
  for public data.

Agents reach this skill through the Starter Bundle's `reverse-engineering`
skill and `docs/web-api.md`; Reverse THIS! does not install it into provider
skill folders. To refresh: change the pin, fetch the same folder at the new
tag, diff, rerun `tests/test_web_api.py` and the dry runs in `docs/web-api.md`.
