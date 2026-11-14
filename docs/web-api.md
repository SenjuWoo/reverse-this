# Web API reconstruction (optional)

`reverse-api-engineer` discovers a website's private HTTP API and generates a
typed client. It is a separate optional capability from REA: use REA for
binaries, applications and runtime behavior; use this tool when the target is a
website and no official API or maintained SDK covers the task.

The catalog pins the published MIT release from PyPI; `catalog/tools.json` is
the single source of truth for the version. Do not install the unreleased
`main` branch or mix its skill instructions with the stable CLI.

The upstream agent skill for the same release ships in
`skills/reverse-api-engineer/` (unmodified; provenance and kit differences in
its `UPSTREAM.md`). Read its `SKILL.md` for the step-by-step run: reuse an
earlier capture, preflight, capture in the background, verify, iterate.

What changed in 0.15.0 that matters here:

- New configs default to `agent_provider: chrome-mcp` (the user's own Chrome,
  no HAR). A headed run needs Chrome remote debugging; `agent --dry-run`
  reports `chrome-mcp:auto-connect` as an error until it is enabled. For public
  data add `--headless`; for a reusable HAR set `"agent_provider": "auto"`.
- Claude sessions no longer load the user's Claude Code settings, `CLAUDE.md`,
  hooks, plugins or MCP servers. A normal Claude Code login still
  authenticates; set `claude_setting_sources` only when authentication lives in
  a settings file.
- `--json` and `--json-stream` report `status: error` (`engine_failure`) when
  no client was written, so `status: ok` now means a client exists.

## Install and check

Call the shim from PowerShell. Git Bash hands a `.cmd` to `cmd /c`, which
strips the outer quotes when the kit path has spaces and an argument is quoted.

```powershell
.\Install-Modkit.ps1 -Only reverse-api-engineer
.\sandbox\bin\reverse-api-engineer.cmd --version
```

The installer creates a private virtual environment under
`sandbox\tools\reverse-api-engineer` and a stable shim under `sandbox\bin`; it
does not change the global Python environment, start a browser, register an MCP
server, or alter provider/model settings. The command is
`reverse-api-engineer`, never the `rae` alias used by REA.

Agent mode requires Node.js 20.19+ and a supported browser/provider. Manual
Playwright capture is an optional extra and is not installed by this catalog
entry. Model authentication is also the caller's responsibility; this kit does
not copy API keys.

## Model provider

The default SDK is Claude Code. It needs an authenticated `claude` session or
`ANTHROPIC_API_KEY`. `agent --dry-run` only checks that the environment variable
exists; it does not prove that the provider is signed in or can run.

The pinned release also supports OpenCode as its SDK. To use an existing
OpenCode/OpenRouter setup, configure RAE's interactive settings with
`sdk: "opencode"` and a connected provider/model pair, for example OpenRouter
with a DeepSeek model. OpenCode owns that authentication; select a pair from the
tool's settings rather than inventing model IDs. Node.js and `npx` must be on
PATH when RAE starts its managed OpenCode server.

Hermes is not an RAE SDK: this Hermes/DeepSeek session does not authenticate the
tool's model calls. Do not point RAE at Hermes credentials or change existing
model defaults unless the user explicitly chooses that setup.

## Workflow

Run from a private work directory so `real_time_sync` cannot write generated
clients into a source checkout. `sandbox\work` is ignored by Git.

```powershell
$rae = "$PWD\sandbox\bin\reverse-api-engineer.cmd"
$work = "$PWD\sandbox\work\web-api"
New-Item -ItemType Directory -Force $work | Out-Null
Set-Location $work

& $rae list --json
& $rae show <run_id> --json
& $rae agent -p "<what data you need>" -u "https://example.com" `
    -o "$work\runs" --dry-run
```

After the dry run passes, start a capture in the background with
`--json-stream` (or `--json` when a long foreground wait is acceptable). Check
the final result line for `status`, `run_id`, `script_path`, `har_path`,
`usage.total_cost_usd` and `error_kind`. Then inspect the model-written client
and its README before running it:

```powershell
& $rae run <run_id> --ls
& $rae run <run_id> --file <client-file> --json -- <args>
```

Prefer a reusable HAR capture for public fixtures. A `chrome-mcp` run can use
the user's Chrome session, but upstream documents that it does not preserve a
reusable HAR; do not claim it can be regenerated with `engineer`. Use
`chrome-mcp` only for a task the user has authorized, and never paste cookies,
tokens, CSRF values or captured bodies into logs, commits or reports.

## Output and privacy

Keep runs, HAR files and generated clients under `sandbox\work\web-api` or
another ignored workspace. They may contain session cookies and personal data.
Review generated code before execution; it is model-written and may need
dependency installation or edits. Only copy a reviewed client into a project
when the user explicitly chooses to import it.
