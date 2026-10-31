# Ghidra MCP over Streamable HTTP

## Ports (do not conflate them)

| Process | Default | What it is |
|---|---|---|
| GhidraMCP plugin | `127.0.0.1:8080` | Ghidra-side HTTP bridge (REST-style endpoints) |
| MCP bridge | `127.0.0.1:8081` | MCP server, transport `streamable-http`, endpoint `/mcp` |

The MCP client talks to `8081/mcp`, not `8080/mcp`. The bridge talks to the Ghidra plugin on `8080`. Verify each layer separately.

## Start

```powershell
# 1. Ghidra with the GhidraMCP extension installed; open the target project.
#    Keep the Ghidra GUI responsive: do not open modal dialogs while indexing.

# 2. Start the MCP bridge (uvx resolves the package).
uvx --from git+https://github.com/LaurieWired/GhidraMCP ghidra-mcp `
  --transport streamable-http --mcp-host 127.0.0.1 --mcp-port 8081 `
  --ghidra-server http://127.0.0.1:8080/
```

## Verify

```powershell
curl.exe -s http://127.0.0.1:8080/methods | Select-Object -First 1
curl.exe -s -X POST http://127.0.0.1:8081/mcp `
  -H "Content-Type: application/json" `
  -H "Accept: application/json, text/event-stream" `
  -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-03-26\",\"capabilities\":{},\"clientInfo\":{\"name\":\"reverse-this\",\"version\":\"1\"}}}'
```

The kit's `ghidra-mcp-up.cmd` probes both ports and prints the exact failing layer.

## Operating rules

1. **List before inspect.** Call `list_project_files` first; the active program may not be the one you assume.
2. **Wait for indexing.** After opening a large binary, `get_function_count` and similar calls can lag. Retry with a bounded backoff (1 s, 2 s, 4 s, 8 s); do not hammer the bridge.
3. **No GUI modals.** A modal dialog blocks the Swing thread and the HTTP bridge stops answering. Close dialogs before calling tools; if the bridge times out, check the Ghidra window first.
4. **One program per call.** Pass the program name/path explicitly when the project has more than one.
5. **Batch reads, not writes.** Renames, comments and type changes are separate, auditable calls; do not script a bulk mutation without a backup of the project.
6. **Record the evidence.** For every finding, keep the function address, the decompiled excerpt and the tool call that produced it.

## Failure map

| Symptom | Check | Fix |
|---|---|---|
| `8081` connection refused | Bridge not started | Start `ghidra-mcp` with `--transport streamable-http` |
| `8080` connection refused | Ghidra plugin not loaded | Enable the GhidraMCP extension and reopen the project |
| Calls hang | GUI modal or long analysis | Close the dialog, wait for analysis, retry |
| Empty function list | Wrong program active | `list_project_files`, then select the program |
| 406 on `POST /mcp` | Missing `Accept: text/event-stream` | Send both JSON and SSE in `Accept` |
