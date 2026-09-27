#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
launcher="$repo_root/scripts/dev/start-nginx-worktree.sh"
[[ -x "$launcher" ]] || {
  echo 'nginx worktree launcher is missing' >&2
  exit 1
}

runtime_dir=$(mktemp -d)
trap 'rm -rf "$runtime_dir"' EXIT

output=$(
  DEV_SLUG=feature-a \
  DEV_NGINX_PORT=18080 \
  DEV_API_PORT=23100 \
  DEV_STORAGE_PORT=23102 \
  DEV_STORAGE_CONSOLE_PORT=23103 \
  DEV_NGINX_RUNTIME_DIR="$runtime_dir" \
    "$launcher" --repo-root "$repo_root" --dry-run
)

grep -Fxq 'project=feature-a' <<<"$output"
grep -Fxq 'api_url=https://api-feature-a.dev.dell.lr-projects.de' <<<"$output"
grep -Fxq 'web_url=https://web-feature-a.dev.dell.lr-projects.de' <<<"$output"
grep -Fxq 'storage_url=https://storage-feature-a.dev.dell.lr-projects.de' <<<"$output"
grep -Fxq 'rustfs_external_endpoint=https://storage-feature-a.dev.dell.lr-projects.de' <<<"$output"
grep -Fxq 'nginx_port=18080' <<<"$output"
grep -Fxq 'api_port=23100' <<<"$output"
grep -Fxq 'storage_port=23102' <<<"$output"
grep -Fxq 'storage_console_port=23103' <<<"$output"
grep -Fxq "nginx_runtime_dir=$runtime_dir" <<<"$output"

full_lifetime_output=$(DEV_STACK_MAX_SECONDS=86400 "$launcher" --repo-root "$repo_root" --dry-run)
grep -Fxq 'timeout_run_seconds=86370' <<<"$full_lifetime_output"
grep -Fxq 'timeout_cleanup_seconds=30' <<<"$full_lifetime_output"

short_lifetime_output=$(DEV_STACK_MAX_SECONDS=1 "$launcher" --repo-root "$repo_root" --dry-run)
grep -Fxq 'timeout_run_seconds=1' <<<"$short_lifetime_output"
grep -Fxq 'timeout_cleanup_seconds=0' <<<"$short_lifetime_output"

if DEV_NGINX_PORT=18081 \
  "$launcher" --repo-root "$repo_root" --dry-run >/dev/null 2>&1; then
  echo 'launcher accepted an nginx port other than 18080' >&2
  exit 1
fi

if DEV_STACK_MAX_SECONDS=86401 \
  "$launcher" --repo-root "$repo_root" --dry-run >/dev/null 2>&1; then
  echo 'launcher accepted a duration longer than 24 hours' >&2
  exit 1
fi

echo 'nginx worktree launcher checks passed'
