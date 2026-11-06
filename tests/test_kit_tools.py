"""Local helper checks. Run: python tests/test_kit_tools.py

Compiles the C++ harnesses when g++ is available; skips those checks otherwise.
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BLUE = ROOT / "encyclopedia/blueprints"
KIT = ROOT / "kit"


def run(args, cwd=None, timeout=120, env=None):
    return subprocess.run(args, cwd=cwd, capture_output=True, text=True, timeout=timeout, env=env)


class KitTools(unittest.TestCase):
    def test_pe_recon_notepad(self):
        notepad = Path(os.environ.get("WINDIR", r"C:\Windows")) / "System32/notepad.exe"
        if not notepad.is_file():
            self.skipTest("notepad.exe not available")
        result = run([sys.executable, str(KIT / "pe_recon.py"), str(notepad)])
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(result.stdout)
        self.assertEqual(data["bitness"], 64)
        self.assertTrue(data["sections"])
        self.assertIn("proxy_candidates", data)

    def test_ipc_seqlock_python_demo(self):
        result = run([sys.executable, str(BLUE / "ipc_seqlock.py")])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PASS", result.stdout)

    def test_ghidra_mcp_launch_without_launcher(self):
        env = os.environ.copy()
        for key in ("GHIDRA_MCP_CMD", "GHIDRA_MCP_WAIT", "REVERSE_THIS_KIT_ROOT"):
            env.pop(key, None)
        with tempfile.TemporaryDirectory(prefix="rt-no-launcher-") as td:
            env["REVERSE_THIS_KIT_ROOT"] = td
            result = run([sys.executable, str(KIT / "ghidra_mcp_up.py"), "--launch"], env=env, timeout=30)
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("analyzeHeadless", result.stdout)

    def test_cpp_harnesses(self):
        gxx = shutil.which("g++")
        if not gxx:
            self.skipTest("g++ not available")
        with tempfile.TemporaryDirectory(prefix="rt-cpp-") as td:
            ipc = Path(td) / "ipc_link_test.exe"
            result = run([gxx, "-std=c++17", "-O2", "-pthread", str(BLUE / "ipc_link_test.cpp"), "-o", str(ipc)])
            self.assertEqual(result.returncode, 0, result.stderr)
            result = run([str(ipc)])
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("PASS", result.stdout)

            d3d = Path(td) / "fake_host_d3d11.exe"
            result = run([gxx, "-std=c++17", "-O2", str(BLUE / "fake_host_d3d11.cpp"), "-o", str(d3d), "-ld3d11", "-ld3dcompiler"])
            if result.returncode != 0:
                self.skipTest("MinGW D3D11 headers/libs unavailable: " + result.stderr[:200])
            result = run([str(d3d)])
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn("PASS reversed-Z", result.stdout)

    def test_aob_gen(self):
        capstone_python = Path(os.environ.get("CAPSTONE_PYTHON", ROOT / "sandbox/tools/capstone/Scripts/python.exe"))
        if not capstone_python.is_file():
            self.skipTest("capstone venv not installed")
        notepad = Path(os.environ.get("WINDIR", r"C:\Windows")) / "System32/notepad.exe"
        if not notepad.is_file():
            self.skipTest("notepad.exe not available")
        info = json.loads(run([sys.executable, str(KIT / "pe_recon.py"), str(notepad)]).stdout)
        result = run([str(capstone_python), str(KIT / "aob_gen.py"), str(notepad), "--rva", info["entry_rva"], "--instructions", "8"])
        data = json.loads(result.stdout)
        self.assertIn("pattern", data)
        self.assertGreater(data["bytes"], 0)

    def test_ghidra_mcp_identity_not_any_http_answer(self):
        import importlib.util
        from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
        import threading

        spec = importlib.util.spec_from_file_location("ghidra_mcp_up", KIT / "ghidra_mcp_up.py")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                body = b"GhidraMCP plugin" if self.path == "/good" else b"not the expected service"
                self.send_response(200)
                self.end_headers()
                self.wfile.write(body)

            def do_POST(self):
                body = json.dumps({"jsonrpc": "2.0", "id": 1, "result": {"serverInfo": {"name": "GhidraMCP"}}}).encode()
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(body)

            def log_message(self, *_):
                pass

        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            base = f"http://127.0.0.1:{server.server_port}"
            good = module.probe_ghidra(base + "/good")
            bad = module.probe_ghidra(base + "/wrong")
            mcp = module.probe_mcp(base + "/mcp")
            self.assertEqual(good["identity"], "ghidra")
            self.assertEqual(bad["identity"], "unknown")
            self.assertEqual(mcp["identity"], "mcp")
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=5)


if __name__ == "__main__":
    unittest.main()
