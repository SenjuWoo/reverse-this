# Security

Report a vulnerability in this repository through GitHub private vulnerability reporting on the repository.

https://github.com/SenjuWoo/reverse-this/security

Do not open a public issue for a security report.

The installer resolves official GitHub releases/source commits, RenderDoc stable archives and the official Fighter Factory portable page. HTTPS is required for downloads and redirects. GitHub assets use their exact SHA-256 digest or matching filename checksum when available; otherwise the manifest labels the locally computed hash. A locally computed hash records bytes but is not publisher authentication. NuGet, PyPI and npm tools keep their own registry trust model; npm lifecycle scripts are disabled. Versions are resolved at install time, so this is not an offline or reproducible dependency lock.

Required executables are checked before replacing a tool, with prior payloads retained under `sandbox/backups`. JSON state is replaced atomically; one installer holds an exclusive per-kit lock. This protects installation state, not the behavior of downloaded tools or analyzed targets.

The `sandbox` folder is not isolation. `Start-IsolatedLab.ps1` creates an optional Windows Sandbox configuration with networking and clipboard disabled, read-only tools/inputs and only `sandbox/work/isolated` writable from the guest. Guest output persists on the host: inspect it before opening or executing it. Guest runtimes and target compatibility need separate verification. Do not publish private dumps, proprietary targets or reconstructed code without appropriate rights.
