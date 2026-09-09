#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

runtime_dir="$test_root/runtime"
web_root="$test_root/web"
mkdir -p "$runtime_dir/worktrees" "$web_root"
touch "$web_root/index.html"

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

nginx -t -c "$runtime_dir/nginx.conf" -p "$runtime_dir"
grep -Fq 'server_name api-feature-a.dev.dell.lr-projects.de;' "$runtime_dir/worktrees/feature-a.conf"
grep -Fq 'server_name web-feature-a.dev.dell.lr-projects.de;' "$runtime_dir/worktrees/feature-a.conf"
grep -Fq 'server_name storage-feature-a.dev.dell.lr-projects.de;' "$runtime_dir/worktrees/feature-a.conf"
grep -Fq 'proxy_pass http://127.0.0.1:23100;' "$runtime_dir/worktrees/feature-a.conf"
grep -Fq 'proxy_pass http://127.0.0.1:23102;' "$runtime_dir/worktrees/feature-a.conf"
grep -Fq "root \"$web_root\";" "$runtime_dir/worktrees/feature-a.conf"
grep -Fq 'Access-Control-Allow-Origin https://web-feature-a.dev.dell.lr-projects.de' "$runtime_dir/worktrees/feature-a.conf"

echo 'nginx worktree config checks passed'
