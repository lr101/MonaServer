#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

runtime_dir="$test_root/runtime"
web_root="$test_root/web"
slug=123456789012345678901234567890123456789012345678
mkdir -p "$runtime_dir/worktrees" "$web_root"
touch "$web_root/index.html"

DEV_NGINX_RUNTIME_DIR="$runtime_dir" \
DEV_NGINX_PORT=18080 \
  "$script_dir/render-nginx-master-config.sh" "$runtime_dir/nginx.conf"

DEV_SLUG="$slug" \
DEV_DOMAIN_SUFFIX=dev.dell.lr-projects.de \
DEV_NGINX_PORT=18080 \
DEV_API_PORT=23100 \
DEV_STORAGE_PORT=23102 \
DEV_STORAGE_CONSOLE_PORT=23103 \
DEV_WEB_ROOT="$web_root" \
DEV_PUBLIC_SCHEME=http \
  "$script_dir/render-nginx-worktree-config.sh" \
    "$runtime_dir/worktrees/$slug.conf"

nginx -t -c "$runtime_dir/nginx.conf" -p "$runtime_dir"
grep -Fq 'server_names_hash_bucket_size 128;' "$runtime_dir/nginx.conf"
grep -Fq "server_name api-$slug.dev.dell.lr-projects.de;" "$runtime_dir/worktrees/$slug.conf"
grep -Fq "server_name web-$slug.dev.dell.lr-projects.de;" "$runtime_dir/worktrees/$slug.conf"
grep -Fq "server_name storage-$slug.dev.dell.lr-projects.de;" "$runtime_dir/worktrees/$slug.conf"
grep -Fq 'log_format dev_safe' "$runtime_dir/nginx.conf"
grep -Fq 'access_log '"$runtime_dir"'/logs/access.log dev_safe;' "$runtime_dir/nginx.conf"
grep -Fq 'user nobody nogroup;' "$runtime_dir/nginx.conf"
grep -Fq 'proxy_pass http://127.0.0.1:23100;' "$runtime_dir/worktrees/$slug.conf"
grep -Fq 'proxy_pass http://127.0.0.1:23102;' "$runtime_dir/worktrees/$slug.conf"
grep -Fq "root \"$web_root\";" "$runtime_dir/worktrees/$slug.conf"
grep -Fq "Access-Control-Allow-Origin http://web-$slug.dev.dell.lr-projects.de" "$runtime_dir/worktrees/$slug.conf"

echo 'nginx worktree config checks passed'
