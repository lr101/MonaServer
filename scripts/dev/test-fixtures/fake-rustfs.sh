#!/usr/bin/env bash
set -euo pipefail

[[ "${1:-}" == server ]] || exit 2
exec python3 - "${RUSTFS_ADDRESS:?RUSTFS_ADDRESS is required}" <<'PY'
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import sys


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = b"fake rustfs\n"
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        pass


host, port = sys.argv[1].rsplit(":", 1)
ThreadingHTTPServer((host, int(port)), Handler).serve_forever()
PY
