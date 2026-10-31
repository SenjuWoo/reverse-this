# Frida downstream-sink synthesis

Use this when a static finding needs runtime proof and the obvious wrapper hook stays silent.

## Static -> dynamic hook

1. In Ghidra, find the leaf function that touches the target data (the one that reads/writes the field, not the public wrapper).
2. Record the module base-relative RVA, the calling convention and the argument registers.
3. In Frida, resolve the module by name and attach at `base + rva`:

```javascript
const mod = Process.getModuleByName("Target.exe");
const fn = mod.base.add(0x1A2B30);
Interceptor.attach(fn, {
  onEnter(args) {
    this.obj = args[0];
    console.log("enter", this.obj, Thread.backtrace(this.context, Backtrace.FunctionType.FULL).map(DebugSymbol.fromAddress).join("\n"));
  },
  onLeave(retval) {
    console.log("leave", retval);
  }
});
```

4. If the hook never fires, the leaf is not on the path you think. Move to the downstream sink.

## Downstream Sink Protocol

1. Pick a sink that must run every frame or every UI update: `IDXGISwapChain::Present`, `EndScene`, a UI text draw, or a frame counter.
2. Attach a counter and a backtrace at the sink:

```javascript
const present = Module.getExportByName("dxgi.dll", "Present");
Interceptor.attach(present, {
  onEnter() {
    this.n = (this.n || 0) + 1;
    if (this.n % 60 === 0) {
      console.log("frame", this.n);
      console.log(Thread.backtrace(this.context, Backtrace.FunctionType.FULL)
        .slice(0, 12).map(DebugSymbol.fromAddress).join("\n"));
    }
  }
});
```

3. Walk the backtrace from the sink until you find the producer that should have called your hook.
4. Hook the producer's leaf, not its wrapper or constructor. Wrapper/constructor hooks commonly run on a different thread or a copy of the object.
5. Once the hook fires, log a payload hash and the frame number. That is the canary.

## When the sink itself is silent

- The game may use a different swap chain (DX12 `Present` on `IDXGISwapChain3/4`, Vulkan `vkQueuePresentKHR`, or a launcher's overlay chain).
- The process may render in a child process; enumerate processes, not just the main module.
- The overlay may hook before you; check the import table and the loaded modules for other overlays.

## Runtime dumping (PyArmor example)

PyArmor-protected Python ships `pyarmor_runtime.pyd/.so` plus encrypted code objects. At runtime the code objects are decrypted in memory.

1. Attach to the process, enumerate modules, find `pyarmor_runtime`.
2. Locate the decrypted code object by scanning for `PyCodeObject` structures or by hooking `PyEval_EvalCode`/`exec`.
3. Dump the `co_code`, `co_consts` and `co_names` for the target module; write them to a lab directory.
4. Record the PyArmor and Python versions; the structure and the decryption path change between releases.

Caveats: native extensions and anti-debug checks can defeat a naive dump; a dumped code object is not original source; and the target must be one you own or are authorized to analyze. Keep the dump and the target out of releases.

## Verification

- The sink counter advances.
- The leaf hook fires with the expected argument values.
- A known field changes at the expected time.
- Disable the hook and confirm the original behavior returns.
