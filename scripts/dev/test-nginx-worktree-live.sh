#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
test_root=$(mktemp -d)
nginx_pid=
cleanup() {
  if [[ -n "$nginx_pid" ]] && kill -0 "$nginx_pid" >/dev/null 2>&1; then
    kill -QUIT "$nginx_pid" >/dev/null 2>&1 || true
    wait "$nginx_pid" >/dev/null 2>&1 || true
  fi
  rm -rf -- "$test_root"
}
trap cleanup EXIT

runtime_dir="$test_root/runtime"
web_root="$test_root/web"
mkdir -p -- "$runtime_dir/worktrees" "$web_root"
chmod 0755 "$test_root" "$web_root"
printf '%s\n' 'nginx worktree live route' > "$web_root/index.html"

DEV_NGINX_RUNTIME_DIR="$runtime_dir" \
DEV_NGINX_PORT=18080 \
  "$script_dir/render-nginx-master-config.sh" "$runtime_dir/nginx.conf"

DEV_SLUG=feature-a \
DEV_DOMAIN_SUFFIX=dev.dell.lr-projects.de \
DEV_NGINX_PORT=18080 \
DEV_API_PORT=23100 \
DEV_STORAGE_PORT=23102 \
DEV_STORAGE_CONSOLE_PORT=23103 \
DEV_WEB_ROOT="$web_root" \
DEV_PUBLIC_SCHEME=https \
  "$script_dir/render-nginx-worktree-config.sh" \
    "$runtime_dir/worktrees/feature-a.conf"

nginx -t -c "$runtime_dir/nginx.conf" -p "$runtime_dir" >/dev/null
nginx -p "$runtime_dir" -c "$runtime_dir/nginx.conf" -g 'daemon off;' \
  >"$runtime_dir/nginx.log" 2>&1 &
nginx_pid=$!

for _ in $(seq 1 50); do
  if [[ -s "$runtime_dir/nginx.pid" ]]; then
    break
  fi
  sleep 0.1
done
[[ -s "$runtime_dir/nginx.pid" ]]

curl --fail --silent --show-error \
  --header 'Host: web-feature-a.dev.dell.lr-projects.de' \
  http://127.0.0.1:18080/ | grep -Fxq 'nginx worktree live route'

echo 'nginx worktree live checks passed'
