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
web_a="$test_root/web-a"
web_b="$test_root/web-b"
mkdir -p -- "$runtime_dir/worktrees" "$web_a" "$web_b"
chmod 0755 "$test_root" "$web_a" "$web_b"
printf '%s\n' 'worktree-a' > "$web_a/index.html"
printf '%s\n' 'worktree-b' > "$web_b/index.html"

DEV_NGINX_RUNTIME_DIR="$runtime_dir" DEV_NGINX_PORT=18081 \
  "$script_dir/render-nginx-master-config.sh" "$runtime_dir/nginx.conf"

DEV_SLUG=feature-a DEV_DOMAIN_SUFFIX=dev.dell.lr-projects.de \
DEV_NGINX_PORT=18081 DEV_API_PORT=23200 DEV_STORAGE_PORT=23202 \
DEV_STORAGE_CONSOLE_PORT=23203 DEV_WEB_ROOT="$web_a" \
  "$script_dir/render-nginx-worktree-config.sh" "$runtime_dir/worktrees/feature-a.conf"
DEV_SLUG=feature-b DEV_DOMAIN_SUFFIX=dev.dell.lr-projects.de \
DEV_NGINX_PORT=18081 DEV_API_PORT=23300 DEV_STORAGE_PORT=23302 \
DEV_STORAGE_CONSOLE_PORT=23303 DEV_WEB_ROOT="$web_b" \
  "$script_dir/render-nginx-worktree-config.sh" "$runtime_dir/worktrees/feature-b.conf"

nginx -t -c "$runtime_dir/nginx.conf" -p "$runtime_dir" >/dev/null
nginx -p "$runtime_dir" -c "$runtime_dir/nginx.conf" -g 'daemon off;' \
  >"$runtime_dir/nginx.log" 2>&1 &
nginx_pid=$!
for _ in $(seq 1 50); do
  [[ -s "$runtime_dir/nginx.pid" ]] && break
  sleep 0.1
done

curl --fail --silent --show-error \
  --header 'Host: web-feature-a.dev.dell.lr-projects.de' \
  http://127.0.0.1:18081/ | grep -Fxq 'worktree-a'
curl --fail --silent --show-error \
  --header 'Host: web-feature-b.dev.dell.lr-projects.de' \
  http://127.0.0.1:18081/ | grep -Fxq 'worktree-b'

rm -f -- "$runtime_dir/worktrees/feature-a.conf"
nginx -t -c "$runtime_dir/nginx.conf" -p "$runtime_dir" >/dev/null
nginx -s reload -p "$runtime_dir" -c "$runtime_dir/nginx.conf" >/dev/null
curl --fail --silent --show-error \
  --header 'Host: web-feature-b.dev.dell.lr-projects.de' \
  http://127.0.0.1:18081/ | grep -Fxq 'worktree-b'

echo 'nginx shared worktree checks passed'
