#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
test_root=$(mktemp -d)
alpha_pid=
beta_pid=
timeout_pid=
using_shared_gateway=false
runtime_dir="$test_root/runtime"
if [[ -n "${DEV_TEST_SHARED_NGINX_RUNTIME_DIR:-}" ]]; then
  runtime_dir=$DEV_TEST_SHARED_NGINX_RUNTIME_DIR
  using_shared_gateway=true
  [[ -s "$runtime_dir/nginx.pid" ]] || {
    echo 'requested shared nginx runtime is not active' >&2
    exit 1
  }
  test_nginx_port=18080
else
  test_nginx_port=18080
  if ! python3 - "$test_nginx_port" >/dev/null 2>&1 <<'PY'
import socket
import sys

try:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("0.0.0.0", int(sys.argv[1])))
except OSError:
    sys.exit(1)
PY
  then
    echo 'port 18080 is already in use; set DEV_TEST_SHARED_NGINX_RUNTIME_DIR to test with the active gateway' >&2
    exit 1
  fi
fi
slug_prefix=${DEV_TEST_SLUG_PREFIX:-worktree}
alpha_slug="${slug_prefix}-a"
beta_slug="${slug_prefix}-b"
timeout_slug="${slug_prefix}-timeout"
alpha_web_host="web-${alpha_slug}.dev.dell.lr-projects.de"
beta_web_host="web-${beta_slug}.dev.dell.lr-projects.de"

stop_launcher() {
  local pid=${1:-}
  local signal=${2:-TERM}
  [[ -n "$pid" ]] || return 0
  if kill -0 "$pid" >/dev/null 2>&1; then
    kill -"$signal" -- "-$pid" >/dev/null 2>&1 || kill -"$signal" "$pid" >/dev/null 2>&1 || true
  fi
  wait "$pid" >/dev/null 2>&1 || true
}

check_web_route() {
  local host=$1
  for _ in $(seq 1 20); do
    if curl --fail --silent --show-error \
      --header "Host: $host" "http://127.0.0.1:$test_nginx_port/" | grep -Fxq 'fake flutter worktree'; then
      return 0
    fi
    sleep 0.1
  done
  find "$runtime_dir/worktrees" -maxdepth 1 -type f -printf '%f\n' >&2 || true
  cat "$runtime_dir/logs/error.log" >&2 || true
  return 1
}

cleanup() {
  stop_launcher "$alpha_pid"
  stop_launcher "$beta_pid"
  stop_launcher "$timeout_pid"
  rm -rf -- "$test_root"
}
trap cleanup EXIT

port_state_dir="$test_root/ports"
env_file="$test_root/env.dev"
fake_bin="$test_root/bin"
mkdir -p -- "$fake_bin"
ln -s "$script_dir/test-fixtures/fake-mise.sh" "$fake_bin/mise"
ln -s "$script_dir/test-fixtures/fake-pg-isready" "$fake_bin/pg_isready"
printf '%s\n' \
  'DATABASE_URL=postgres://local:local@db:5432/monaserver?sslmode=disable' \
  'RUSTFS_ACCESS_KEY=test-access' \
  'RUSTFS_SECRET_KEY=test-secret' \
  > "$env_file"

export PATH="$fake_bin:$PATH"
export DEV_ENV_FILE="$env_file"
export DEV_RUSTFS_BIN="$script_dir/test-fixtures/fake-rustfs.sh"
export DEV_NGINX_RUNTIME_DIR="$runtime_dir"
export DEV_PORT_STATE_DIR="$port_state_dir"
export DEV_NGINX_PORT="$test_nginx_port"
export DEV_WEB_ROOT="$test_root/web"
export DEV_STACK_MAX_SECONDS=120
export FAKE_MISE_CAPTURE_API_ENV="$test_root/api-env.log"
mkdir -p -- "$DEV_WEB_ROOT"
chmod 0755 "$test_root" "$DEV_WEB_ROOT"

if ((EUID == 0)); then
  deny_runuser_bin="$test_root/deny-runuser"
  mkdir -p -- "$deny_runuser_bin"
  cat > "$deny_runuser_bin/runuser" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "$deny_runuser_bin/runuser"
  if PATH="$deny_runuser_bin:$PATH" DEV_SLUG=permission-check \
    "$repo_root/scripts/dev/start-nginx-worktree.sh" --repo-root "$repo_root" \
    >"$test_root/preflight.log" 2>&1; then
    echo 'launcher did not reject an inaccessible nginx worktree path' >&2
    exit 1
  fi
  grep -q 'cannot traverse .*before the Flutter build' "$test_root/preflight.log"
  if grep -q '^Building Flutter web app' "$test_root/preflight.log"; then
    echo 'launcher started Flutter before checking nginx path access' >&2
    exit 1
  fi
fi

DEV_PUBLIC_SCHEME=http DEV_SLUG="$alpha_slug" setsid \
  "$repo_root/scripts/dev/start-nginx-worktree.sh" --repo-root "$repo_root" \
  >"$test_root/alpha.log" 2>&1 &
alpha_pid=$!
DEV_SLUG="$beta_slug" setsid \
  "$repo_root/scripts/dev/start-nginx-worktree.sh" --repo-root "$repo_root" \
  >"$test_root/beta.log" 2>&1 &
beta_pid=$!

for _ in $(seq 1 120); do
  if grep -q '^Development stack is ready' "$test_root/alpha.log" && \
     grep -q '^Development stack is ready' "$test_root/beta.log"; then
    break
  fi
  if ! kill -0 "$alpha_pid" >/dev/null 2>&1 || ! kill -0 "$beta_pid" >/dev/null 2>&1; then
    sed -n '1,200p' "$test_root/alpha.log" >&2 || true
    sed -n '1,200p' "$test_root/beta.log" >&2 || true
    exit 1
  fi
  sleep 0.5
done
grep -q '^Development stack is ready' "$test_root/alpha.log"
grep -q '^Development stack is ready' "$test_root/beta.log"
grep -Fq "WEB_HOST=http://$alpha_web_host" "$FAKE_MISE_CAPTURE_API_ENV"
grep -Fq "WEB_HOST=https://$beta_web_host" "$FAKE_MISE_CAPTURE_API_ENV"

check_web_route "$alpha_web_host"
check_web_route "$beta_web_host"
test -f "$runtime_dir/worktrees/$alpha_slug.conf"
test -f "$runtime_dir/worktrees/$beta_slug.conf"
test "$(stat -c '%a' "$runtime_dir/logs/access.log")" = 600
test "$(stat -c '%a' "$runtime_dir/logs/nginx.log")" = 600

stop_launcher "$alpha_pid" INT
alpha_pid=
test ! -e "$runtime_dir/worktrees/$alpha_slug.conf"
test -e "$runtime_dir/worktrees/$beta_slug.conf"
check_web_route "$beta_web_host"

stop_launcher "$beta_pid"
beta_pid=
if [[ "$using_shared_gateway" == true ]]; then
  test -s "$runtime_dir/nginx.pid"
  if [[ -n "${DEV_TEST_PRESERVE_SLUG:-}" ]]; then
    test -e "$runtime_dir/worktrees/$DEV_TEST_PRESERVE_SLUG.conf"
  fi
else
  test ! -e "$runtime_dir/nginx.pid"
fi
test ! -e "$runtime_dir/worktrees/$alpha_slug.conf"
test ! -e "$runtime_dir/worktrees/$beta_slug.conf"
if find "$port_state_dir" -maxdepth 1 -type f -name '[0-9]*' | grep -q .; then
  echo 'port reservations were not released' >&2
  find "$port_state_dir" -maxdepth 1 -type f -print >&2
  sed -n '1,240p' "$test_root/alpha.log" >&2 || true
  sed -n '1,240p' "$test_root/beta.log" >&2 || true
  exit 1
fi

private_root="$test_root/private"
private_web_root="$private_root/web"
mkdir -p -- "$private_web_root"
chmod 0755 "$private_root" "$private_web_root"
if (umask 077; DEV_SLUG="${slug_prefix}-private" DEV_WEB_ROOT="$private_web_root" \
  "$repo_root/scripts/dev/start-nginx-worktree.sh" --repo-root "$repo_root") \
  >"$test_root/private-web.log" 2>&1; then
  echo 'launcher accepted a Flutter build that nginx cannot read' >&2
  exit 1
fi
grep -q 'nginx worker user nobody cannot read' "$test_root/private-web.log"

set +e
FAKE_MISE_DELAY=5 DEV_STACK_MAX_SECONDS=3 DEV_STACK_TIMEOUT_ACTIVE=true DEV_SLUG="$timeout_slug" \
  "$repo_root/scripts/dev/start-nginx-worktree.sh" --repo-root "$repo_root" \
  >"$test_root/timeout.log" 2>&1 &
timeout_pid=$!
wait "$timeout_pid"
timeout_status=$?
timeout_pid=
set -e
if [[ "$timeout_status" -ne 124 && "$timeout_status" -ne 143 ]]; then
  echo "launcher timeout returned unexpected status: $timeout_status" >&2
  sed -n '1,200p' "$test_root/timeout.log" >&2 || true
  exit 1
fi
if find "$port_state_dir" -maxdepth 1 -type f -name '[0-9]*' | grep -q .; then
  echo 'launcher timeout left port reservations behind' >&2
  find "$port_state_dir" -maxdepth 1 -type f -print >&2
  exit 1
fi
if [[ "$using_shared_gateway" == true && -n "${DEV_TEST_PRESERVE_SLUG:-}" ]]; then
  test -e "$runtime_dir/worktrees/$DEV_TEST_PRESERVE_SLUG.conf"
fi

echo 'nginx worktree lifecycle checks passed'
