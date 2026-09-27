#!/usr/bin/env bash
set -euo pipefail

[[ "${1:-}" == exec ]] || exit 2
shift
[[ "${1:-}" == -- ]] && shift

if [[ -n "${FAKE_MISE_DELAY:-}" ]]; then
  sleep "$FAKE_MISE_DELAY"
fi

case "${1:-}" in
  flutter)
    shift
    case "${1:-}" in
      pub)
        exit 0
        ;;
      build)
        web_root=${DEV_WEB_ROOT:-build/web}
        mkdir -p -- "$web_root"
        printf '%s\n' 'fake flutter worktree' > "$web_root/index.html"
        exit 0
        ;;
    esac
    ;;
  go)
    shift
    [[ "${1:-}" == run ]] || exit 2
    exec python3 - "${PORT:?PORT is required}" <<'PY'
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import sys


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = b'{"fake":true}\n'
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_args):
        pass


ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
PY
    ;;
esac

exit 2
