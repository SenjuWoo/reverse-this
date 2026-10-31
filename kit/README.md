# kit/ — local, dependency-light workbench helpers

These scripts are installed as `local-script` catalog tools. The installer copies
the selected script into `sandbox/tools/<id>/` and writes a versionless shim in
`sandbox/bin/`. They are part of the product ZIP; `sandbox/` is not.

| Tool | Shim | Runtime | What it does |
|---|---|---|---|
| `pe_recon.py` | `pe-recon.cmd` | shared Python, stdlib only | JSON PE fingerprint: bitness, graphics APIs, anti-cheat markers, RTTI strings, proxy DLL candidates |
| `aob_gen.py` | `aob-gen.cmd` | `capstone` venv | Wildcard AOB signature from an RVA or byte pattern; masks relocatable bytes only |
| `ghidra_mcp_up.py` | `ghidra-mcp-up.cmd` | shared Python, stdlib only | Probes the Ghidra plugin (8080) and MCP bridge (8081); `--launch` waits only when `GHIDRA_MCP_CMD` or an optional start.cmd exists. MCP is optional; unattended Ghidra uses `analyzeHeadless`. |

## Install

```powershell
.\Install-Modkit.ps1 -Only pe-recon,aob-gen,ghidra-mcp-up
```

`aob-gen` pulls `capstone` automatically. The other two use the kit's shared
Python; the installer provisions it when missing.

## Examples

```powershell
pe-recon "C:\Games\Target\Target.exe"
aob-gen "C:\Games\Target\Target.exe" --rva 0x1A2B30 --instructions 24
ghidra-mcp-up
ghidra-mcp-up --launch   # waits for both layers when GHIDRA_MCP_CMD or an optional start.cmd exists
```

## Rules

- These helpers read files and print JSON; they do not execute the target.
- `aob-gen` returns a signature, not a patch. Validate uniqueness in two builds.
- `ghidra-mcp-up` probes; it does not pretend to start a server that is not configured. If no launcher exists, use `analyzeHeadless` and leave MCP off.
