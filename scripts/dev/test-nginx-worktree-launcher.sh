#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
runtime_dir=$(mktemp -d)
trap 'rm -rf "$runtime_dir"' EXIT

output=$(
  DEV_SLUG=feature-a \
  DEV_NGINX_PORT=18080 \
  DEV_API_PORT=23100 \
  DEV_STORAGE_PORT=23102 \
  DEV_STORAGE_CONSOLE_PORT=23103 \
  DEV_NGINX_RUNTIME_DIR="$runtime_dir" \
    "$repo_root/scripts/dev/start-nginx-worktree.sh" \
      --repo-root "$repo_root" \
      --dry-run
)

grep -Fxq 'project=feature-a' <<<"$output"
grep -Fxq 'api_url=https://api-feature-a.dev.dell.lr-projects.de' <<<"$output"
grep -Fxq 'web_url=https://web-feature-a.dev.dell.lr-projects.de' <<<"$output"
grep -Fxq 'storage_url=https://storage-feature-a.dev.dell.lr-projects.de' <<<"$output"
grep -Fxq 'nginx_port=18080' <<<"$output"
grep -Fxq 'api_port=23100' <<<"$output"
grep -Fxq 'storage_port=23102' <<<"$output"
grep -Fxq 'storage_console_port=23103' <<<"$output"
grep -Fxq "nginx_runtime_dir=$runtime_dir" <<<"$output"

echo 'nginx worktree launcher checks passed'
