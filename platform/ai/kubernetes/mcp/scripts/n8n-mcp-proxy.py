#!/usr/bin/env python3
"""Proxy n8n MCP and coerce tools/call arguments from JSON null to {}.

n8n's TypeScript MCP SDK rejects params.arguments: null. kagent encodes a
missing argument map as null. This proxy rewrites only that field, then
streams the upstream response, including server-sent events.
"""

import json
import os
import sys
from http.client import HTTPConnection, HTTPSConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit

UPSTREAM = urlsplit(os.environ.get("UPSTREAM_ORIGIN", "http://127.0.0.1:5678"))
PORT = int(os.environ.get("PORT", "8080"))

SKIP_HEADERS = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailers",
    "transfer-encoding",
    "upgrade",
    "content-length",
    "host",
}


def coerce_null_arguments(message):
    """Return True when a tools/call arguments field was null and is now {}."""
    changed = False
    if isinstance(message, list):
        for item in message:
            changed = coerce_null_arguments(item) or changed
        return changed
    if not isinstance(message, dict) or message.get("method") != "tools/call":
        return False
    params = message.get("params")
    if isinstance(params, dict) and params.get("arguments", False) is None and "arguments" in params:
        params["arguments"] = {}
        return True
    return False


def rewrite_body(body, content_type):
    if not body:
        return body, False
    media = content_type.split(";", 1)[0].strip().lower()
    if media not in ("", "application/json"):
        return body, False
    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        return body, False
    if not coerce_null_arguments(payload):
        return body, False
    return json.dumps(payload, separators=(",", ":"), ensure_ascii=False).encode(), True


class ProxyHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_GET(self):
        self._handle()

    def do_POST(self):
        self._handle()

    def do_PUT(self):
        self._handle()

    def do_DELETE(self):
        self._handle()

    def do_HEAD(self):
        self._handle()

    def log_message(self, fmt, *args):
        sys.stdout.write("%s - %s\n" % (self.address_string(), fmt % args))
        sys.stdout.flush()

    def _handle(self):
        path = self.path.split("?", 1)[0]
        if path == "/healthz":
            self._send(200, b"ok\n", "text/plain")
            return
        length = int(self.headers.get("Content-Length", "0") or "0")
        raw = self.rfile.read(length) if length else b""
        body, rewritten = rewrite_body(raw, self.headers.get("Content-Type", ""))
        if rewritten:
            self.log_message("rewrote tools/call arguments null to {}")
        self._forward(body)

    def _send(self, status, body, content_type):
        self.close_connection = True
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def _forward(self, body):
        if UPSTREAM.scheme == "https":
            conn = HTTPSConnection(UPSTREAM.hostname, UPSTREAM.port or 443, timeout=None)
        else:
            conn = HTTPConnection(UPSTREAM.hostname, UPSTREAM.port or 80, timeout=None)
        headers = {
            key: value
            for key, value in self.headers.items()
            if key.lower() not in SKIP_HEADERS
        }
        if body:
            headers["Content-Length"] = str(len(body))
        started = False
        try:
            conn.request(self.command, self.path, body=body or None, headers=headers)
            upstream = conn.getresponse()
            self.close_connection = True
            self.send_response(upstream.status)
            for key, value in upstream.getheaders():
                if key.lower() in SKIP_HEADERS:
                    continue
                self.send_header(key, value)
            self.send_header("Transfer-Encoding", "chunked")
            self.send_header("Connection", "close")
            self.end_headers()
            started = True
            if self.command == "HEAD":
                return
            while True:
                chunk = upstream.read(16384)
                if not chunk:
                    break
                self.wfile.write(b"%X\r\n" % len(chunk))
                self.wfile.write(chunk)
                self.wfile.write(b"\r\n")
                self.wfile.flush()
            self.wfile.write(b"0\r\n\r\n")
            self.wfile.flush()
        except Exception as exc:
            self.log_message("upstream error: %s", exc.__class__.__name__)
            if not started:
                self._send(502, b"upstream unavailable\n", "text/plain")
        finally:
            conn.close()


def main():
    server = ThreadingHTTPServer(("0.0.0.0", PORT), ProxyHandler)
    server.daemon_threads = True
    print("n8n mcp proxy listening on %s -> %s" % (PORT, UPSTREAM.geturl()), flush=True)
    server.serve_forever()


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        original = b'{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"search_nodes","arguments":null}}'
        rewritten, changed = rewrite_body(original, "application/json")
        assert changed
        assert json.loads(rewritten)["params"]["arguments"] == {}
        untouched, changed = rewrite_body(
            b'{"method":"tools/call","params":{"name":"search_nodes","arguments":{"queries":["webhook"]}}}',
            "application/json",
        )
        assert not changed and b"webhook" in untouched
        same, changed = rewrite_body(b'{"method":"initialize","params":{}}', "application/json")
        assert not changed and same.startswith(b"{")
        omitted, changed = rewrite_body(
            b'{"method":"tools/call","params":{"name":"get_workflow_sdk_reference"}}',
            "application/json",
        )
        assert not changed and b"arguments" not in omitted
        batched, changed = rewrite_body(
            b'[{"method":"tools/call","params":{"name":"search_nodes","arguments":null}}]',
            "application/json",
        )
        assert changed and json.loads(batched)[0]["params"]["arguments"] == {}
        print("ok")
    else:
        main()
