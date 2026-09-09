#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
test_root=$(mktemp -d)
alpha_pid=
beta_pid=
timeout_pid=

stop_launcher() {
  local pid=${1:-}
  [[ -n "$pid" ]] || return 0
  if kill -0 "$pid" >/dev/null 2>&1; then
    kill -TERM "$pid" >/dev/null 2>&1 || true
  fi
  wait "$pid" >/dev/null 2>&1 || true
}

check_web_route() {
  local host=$1
  for _ in $(seq 1 20); do
    if curl --fail --silent --show-error \
      --header "Host: $host" "http://127.0.0.1:18082/" | grep -Fxq 'fake flutter worktree'; then
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

runtime_dir="$test_root/runtime"
port_state_dir="$test_root/ports"
env_file="$test_root/env.dev"
fake_bin="$test_root/bin"
mkdir -p -- "$fake_bin"
ln -s "$script_dir/test-fixtures/fake-mise.sh" "$fake_bin/mise"
ln -s "$script_dir/test-fixtures/fake-pg-isready" "$fake_bin/pg_isready"
printf '%s\n' \
  'DATABASE_URL=postgres://local:local@db:5432/monaserver?sslmode=disable' \
  'JWT_SECRET=test-only-secret' \
  'TOKEN_ADMIN_USERNAME=admin' \
  'RUSTFS_ACCESS_KEY=test-access' \
  'RUSTFS_SECRET_KEY=test-secret' \
  > "$env_file"

export PATH="$fake_bin:$PATH"
export DEV_ENV_FILE="$env_file"
export DEV_RUSTFS_BIN="$script_dir/test-fixtures/fake-rustfs.sh"
export DEV_NGINX_RUNTIME_DIR="$runtime_dir"
export DEV_PORT_STATE_DIR="$port_state_dir"
export DEV_NGINX_PORT=18082
export DEV_WEB_ROOT="$test_root/web"
export DEV_STACK_MAX_SECONDS=120
# The timeout wrapper is tested by the launcher validation below. Running the
# concurrent lifecycle test directly keeps each PID equal to its launcher,
# so stopping one worktree cannot accidentally target the other job.
export DEV_STACK_TIMEOUT_ACTIVE=true
mkdir -p -- "$DEV_WEB_ROOT"
chmod 0755 "$test_root" "$DEV_WEB_ROOT"

DEV_SLUG=worktree-a \
  "$repo_root/scripts/dev/start-nginx-worktree.sh" --repo-root "$repo_root" \
  >"$test_root/alpha.log" 2>&1 &
alpha_pid=$!
DEV_SLUG=worktree-b \
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

check_web_route web-worktree-a.dev.dell.lr-projects.de
check_web_route web-worktree-b.dev.dell.lr-projects.de
test -f "$runtime_dir/worktrees/worktree-a.conf"
test -f "$runtime_dir/worktrees/worktree-b.conf"

stop_launcher "$alpha_pid"
alpha_pid=
test ! -e "$runtime_dir/worktrees/worktree-a.conf"
test -e "$runtime_dir/worktrees/worktree-b.conf"
check_web_route web-worktree-b.dev.dell.lr-projects.de

stop_launcher "$beta_pid"
beta_pid=
test ! -e "$runtime_dir/nginx.pid"
test ! -e "$runtime_dir/worktrees/worktree-a.conf"
test ! -e "$runtime_dir/worktrees/worktree-b.conf"
if find "$port_state_dir" -maxdepth 1 -type f -name '[0-9]*' | grep -q .; then
  echo 'port reservations were not released' >&2
  find "$port_state_dir" -maxdepth 1 -type f -print >&2
  sed -n '1,240p' "$test_root/alpha.log" >&2 || true
  sed -n '1,240p' "$test_root/beta.log" >&2 || true
  exit 1
fi

set +e
FAKE_MISE_DELAY=3 DEV_STACK_MAX_SECONDS=1 DEV_STACK_TIMEOUT_ACTIVE=false DEV_SLUG=timeout-check \
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

echo 'nginx worktree lifecycle checks passed'
