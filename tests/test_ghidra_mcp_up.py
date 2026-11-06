"""Deterministic GhidraMCP health and Streamable HTTP initialize checks."""

import importlib.util
import json
import socket
import threading
import time
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("ghidra_mcp_up", ROOT / "kit/ghidra_mcp_up.py")
ghidra_mcp_up = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ghidra_mcp_up)

HEALTH = {
    "success": True,
    "data": {
        "status": "ok",
        "version": "1.4.0",
        "ghidra_version": "12.2",
        "mode": "read-only",
        "capabilities": ["read", "write"],
        "program": None,
    },
}


class Handler(BaseHTTPRequestHandler):
    deletes = 0

    def _json(self, payload, status=200):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _init(self, server_name="ghidra-mcp", request_id=1):
        return {
            "jsonrpc": "2.0",
            "id": request_id,
            "result": {
                "protocolVersion": "2025-06-18",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": server_name, "version": "1.0"},
            },
        }

    def do_GET(self):
        if self.path == "/health":
            self._json(HEALTH)
        elif self.path == "/health-program":
            data = dict(HEALTH)
            data["data"] = {**HEALTH["data"], "program": {"name": "sample.exe"}}
            self._json(data)
        elif self.path == "/health-unhealthy":
            self._json({"success": False, "data": {"status": "starting", "version": "1.4.0", "ghidra_version": "12.2"}})
        elif self.path == "/health-wrong":
            self._json({"success": True, "data": {"status": "ok", "service": "other"}})
        elif self.path == "/health-malformed":
            body = b"{not-json"
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif self.path == "/health-plain":
            body = b"GhidraMCP"
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif self.path == "/health-timeout":
            time.sleep(1)
            self._json(HEALTH)
        else:
            self._json({"error": "unknown"}, 404)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        request = json.loads(self.rfile.read(length) or b"{}")
        request_id = request.get("id", 1)
        if self.path == "/mcp-json":
            self._json(self._init(request_id=request_id))
        elif self.path == "/mcp-session":
            body = json.dumps(self._init(request_id=request_id)).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Mcp-Session-Id", "fixture-session")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif self.path in ("/mcp-sse", "/mcp-sse-frag"):
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.end_headers()
            events = (
                b": keepalive\n\n"
                b"event: message\n"
                b'data: {"jsonrpc":"2.0","method":"notifications/initialized"}\n\n'
                b"event: message\n"
                b"data: " + json.dumps(self._init(request_id=request_id)).encode() + b"\n\n"
            )
            if self.path == "/mcp-sse-frag":
                middle = len(events) // 2
                self.wfile.write(events[:middle])
                self.wfile.flush()
                time.sleep(0.05)
                self.wfile.write(events[middle:])
            else:
                self.wfile.write(events)
            self.close_connection = True
        elif self.path == "/mcp-bad-id":
            self._json(self._init(request_id=request_id + 1))
        elif self.path == "/mcp-unrelated":
            self._json(self._init(server_name="other-mcp", request_id=request_id))
        elif self.path == "/mcp-invalid":
            self._json({"jsonrpc": "2.0", "id": request_id, "result": {"protocolVersion": "2025-06-18"}})
        elif self.path == "/mcp-malformed":
            body = b"{not-json"
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif self.path == "/mcp-large":
            body = json.dumps({"jsonrpc": "2.0", "id": request_id, "result": "x" * (ghidra_mcp_up.MAX_BODY + 100)}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif self.path == "/mcp-timeout":
            time.sleep(1)
            try:
                self._json(self._init(request_id=request_id))
            except OSError:
                pass
        else:
            self._json({"error": "unknown"}, 404)

    def do_DELETE(self):
        Handler.deletes += 1
        self.send_response(204)
        self.end_headers()

    def log_message(self, *_):
        pass


class GhidraMcpTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.base = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=5)

    def test_health_identity_health_and_program_state_are_separate(self):
        health = ghidra_mcp_up.probe_ghidra(self.base + "/health")
        self.assertEqual(health["identity"], "ghidra")
        self.assertTrue(health["healthy"])
        self.assertFalse(health["program_loaded"])
        self.assertEqual(health["ghidra_version"], "12.2")
        loaded = ghidra_mcp_up.probe_ghidra(self.base + "/health-program")
        self.assertTrue(loaded["program_loaded"])

    def test_health_rejects_plain_and_other_services_but_recognizes_unhealthy_backend(self):
        for path in ("/health-plain", "/health-wrong"):
            with self.subTest(path=path):
                result = ghidra_mcp_up.probe_ghidra(self.base + path)
                self.assertEqual(result["identity"], "unknown")
                self.assertFalse(result["healthy"])
        unhealthy = ghidra_mcp_up.probe_ghidra(self.base + "/health-unhealthy")
        self.assertEqual(unhealthy["identity"], "ghidra")
        self.assertFalse(unhealthy["healthy"])

    def test_health_reports_malformed_and_http_errors(self):
        malformed = ghidra_mcp_up.probe_ghidra(self.base + "/health-malformed")
        self.assertEqual(malformed["identity"], "unknown")
        self.assertIn("malformed", malformed["error"])
        missing = ghidra_mcp_up.probe_ghidra(self.base + "/missing")
        self.assertTrue(missing["up"])
        self.assertEqual(missing["status"], 404)
        self.assertEqual(missing["identity"], "unknown")

    def test_connection_refused_and_timeout_are_not_ready(self):
        sock = socket.socket()
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
        sock.close()
        refused = ghidra_mcp_up.probe_ghidra(f"http://127.0.0.1:{port}/health", timeout=0.3)
        self.assertFalse(refused["up"])
        timed = ghidra_mcp_up.probe_ghidra(self.base + "/health-timeout", timeout=0.2)
        self.assertEqual(timed["identity"], "unknown")
        self.assertFalse(timed["healthy"])

    def test_json_initialize_is_recognized(self):
        result = ghidra_mcp_up.probe_mcp(self.base + "/mcp-json")
        self.assertEqual(result["identity"], "mcp")
        self.assertTrue(result["healthy"])
        self.assertEqual(result["server_name"], "ghidra-mcp")
        self.assertEqual(result["protocol"], "2025-06-18")

    def test_sse_initialize_with_keepalive_and_notification(self):
        result = ghidra_mcp_up.probe_mcp(self.base + "/mcp-sse")
        self.assertEqual(result["identity"], "mcp", result)
        self.assertTrue(result["healthy"])

    def test_fragmented_sse_initialize(self):
        result = ghidra_mcp_up.probe_mcp(self.base + "/mcp-sse-frag")
        self.assertEqual(result["identity"], "mcp", result)

    def test_bad_id_invalid_result_and_unrelated_server_are_rejected(self):
        for path, expected in (("/mcp-bad-id", "id"), ("/mcp-invalid", "serverInfo"), ("/mcp-unrelated", "unrelated")):
            with self.subTest(path=path):
                result = ghidra_mcp_up.probe_mcp(self.base + path)
                self.assertEqual(result["identity"], "unknown")
                self.assertFalse(result["healthy"])
                self.assertIn(expected, result["error"])

    def test_malformed_http_and_oversize_fail_closed(self):
        malformed = ghidra_mcp_up.probe_mcp(self.base + "/mcp-malformed")
        self.assertEqual(malformed["identity"], "unknown")
        self.assertIn("malformed", malformed["error"])
        missing = ghidra_mcp_up.probe_mcp(self.base + "/missing")
        self.assertEqual(missing["status"], 404)
        large = ghidra_mcp_up.probe_mcp(self.base + "/mcp-large")
        self.assertEqual(large["identity"], "unknown")
        self.assertIn("exceeded", large["error"])

    def test_session_is_cleaned_up(self):
        before = Handler.deletes
        result = ghidra_mcp_up.probe_mcp(self.base + "/mcp-session")
        self.assertTrue(result["healthy"])
        self.assertTrue(result["session"])
        self.assertGreater(Handler.deletes, before)


if __name__ == "__main__":
    unittest.main()
