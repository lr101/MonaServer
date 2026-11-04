#!/usr/bin/env bash
set -euo pipefail

# Keep this terminal open; Flutter receives r/R here for hot reload/restart.
e2e_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
flutter_dir="$(cd -- "$e2e_dir/.." && pwd)"
port="${FLUTTER_DEBUG_PORT:-4173}"
api_url="${E2E_API_URL:-http://127.0.0.1:8081}"

if [[ ! "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
  echo 'FLUTTER_DEBUG_PORT must be a valid port number.' >&2
  exit 2
fi
if ! mise exec -- node -e 'try { const u = new URL(process.argv[1]); if (!["http:", "https:"].includes(u.protocol) || !["127.0.0.1", "localhost", "[::1]"].includes(u.hostname) || u.username || u.password) process.exit(1); } catch { process.exit(1); }' "$api_url"; then
  echo 'E2E_API_URL must be a loopback HTTP(S) URL without credentials.' >&2
  exit 2
fi

# Playwright's pinned Chromium supplies a headless Chrome for Flutter's
# debugger too. A connected Chrome device is required for real hot reload;
# web-server alone needs a Dart Debug extension in each browser.
chromium="$(cd "$e2e_dir" && mise exec -- node -e "process.stdout.write(require('@playwright/test').chromium.executablePath())")"
if [[ ! -x "$chromium" ]]; then
  echo 'Playwright Chromium is missing; run mise run flutter-playwright-setup.' >&2
  exit 1
fi
wrapper_dir="$(mktemp -d "${TMPDIR:-/tmp}/flutter-debug-chrome.XXXXXXXX")"
trap 'rm -rf -- "$wrapper_dir"' EXIT
printf '%s\n' "$port" > "$wrapper_dir/app-port"
cat > "$wrapper_dir/chrome" <<'EOF'
#!/usr/bin/env bash
args=(--headless --disable-dev-shm-usage)
if [[ "$(id -u)" == 0 ]]; then args+=(--no-sandbox); fi
for arg in "$@"; do
  case "$arg" in
    --remote-debugging-port=*) printf '%s\n' "${arg#*=}" > "$FLUTTER_DEBUG_STATE_DIR/chrome-port" ;;
  esac
done
exec "$FLUTTER_DEBUG_CHROMIUM" "${args[@]}" "$@"
EOF
chmod 700 "$wrapper_dir/chrome"
export FLUTTER_DEBUG_CHROMIUM="$chromium"
export FLUTTER_DEBUG_STATE_DIR="$wrapper_dir"
export CHROME_EXECUTABLE="$wrapper_dir/chrome"
cd "$flutter_dir"
echo "Starting Flutter debug web on http://127.0.0.1:$port; press r to reload, R to restart, q to quit."
echo "Debug session state: $wrapper_dir"
mise exec -- flutter run -d chrome --web-hostname 127.0.0.1 --web-port "$port" --no-pub --dart-define="API_HOST=$api_url"
