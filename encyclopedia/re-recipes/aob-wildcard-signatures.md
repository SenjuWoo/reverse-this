# AOB wildcard signatures

An Array-of-Bytes signature is a byte pattern with wildcards for bytes that move between builds. The goal is a pattern that is unique, ASLR-safe and survives compiler/layout changes.

## What moves, what stays

| Bytes | Stability | Action |
|---|---|---|
| Opcode + ModRM | Usually stable | Keep |
| RIP-relative `disp32` | Moves with layout | Wildcard all 4 bytes |
| `rel8`/`rel32` branch targets | Move with layout | Wildcard 1 or 4 bytes |
| Absolute addresses (imm64) | Move with ASLR/rebuild | Wildcard |
| Stack offsets, struct offsets | Change with code changes | Keep only if the build is pinned |
| Function prologue/epilogue | Often stable | Good anchor |

Do not wildcard the opcode or the ModRM; that turns a signature into a loose string and produces false positives.

## Algorithm

1. Read the PE, map `RVA -> file offset` from the section table.
2. Find the candidate byte pattern in the `.text` section (or at the given RVA).
3. Disassemble a window (16-32 instructions) with Capstone.
4. For each instruction, mask the displacement/immediate bytes:
   - `call rel32`, `jmp rel32`, `jcc rel32` -> last 4 bytes
   - `call rel8`, `jmp rel8`, `jcc rel8` -> last 1 byte
   - `mov reg, [rip+disp32]` -> last 4 bytes of the instruction
   - `mov reg, imm64` -> last 8 bytes
5. Emit `48 8B 05 ?? ?? ?? ?? 48 85 C0` with `??` for masked bytes.
6. Verify the pattern is unique in the module and that it resolves at the same address in a second build.

## Reference implementation

`kit/aob_gen.py` does steps 1-5 with the standard library plus Capstone. It takes a file, an RVA or a hex pattern, and a window size:

```powershell
aob-gen "C:\Games\Target\Target.exe" --rva 0x1A2B30 --instructions 24
aob-gen "C:\Games\Target\Target.exe" --pattern "48 8B 05 ?? ?? ?? ??" --instructions 24
```

Output is JSON: `{"pattern": "...", "rva": "...", "bytes": N, "wildcards": N, "unique": true}`. `unique` is checked against the whole file; if false, extend the window.

## Validation

- The signature matches exactly once in the current build.
- It matches exactly once in the previous build (if available).
- The resolved address lands on the same instruction, not a nearby function.
- A patched byte in the wildcarded region does not break the match; a patched opcode does.
- Record the build id, file hash and the signature in the field note. A signature without its build is a guess.

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Multiple matches | Window too short or too generic | Extend the window; add a unique prologue |
| No match after an update | Opcode or layout changed | Re-derive from the new build; do not widen blindly |
| Match lands mid-instruction | Pattern started at an operand | Anchor at a function prologue or a known instruction boundary |
| Works in IDA, not in the injector | Injector scans mapped memory, not the file | Use the module's mapped image and the correct section protections |
