#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
call_log="$(mktemp)"
trap 'rm -f "$call_log"' EXIT

gh() {
  printf 'gh %s\n' "$*" >> "$CALL_LOG"
  printf 'abc123\n'
}

docker() {
  printf 'docker %s\n' "$*" >> "$CALL_LOG"
}

sleep() {
  :
}

export CALL_LOG="$call_log"
export GITHUB_REPOSITORY='example/mona'
export -f gh docker sleep

output="$(
  bash "$script_dir/promote_image_channel.sh" \
    'ghcr.io/example/stick-it-web' \
    'develop' \
    'snapshot'
)"

grep -Fxq \
  'gh api repos/example/mona/git/ref/heads/develop --jq .object.sha' \
  "$call_log"
grep -Fxq \
  'docker buildx imagetools inspect ghcr.io/example/stick-it-web:abc123' \
  "$call_log"
grep -Fxq \
  'docker buildx imagetools create --tag ghcr.io/example/stick-it-web:snapshot ghcr.io/example/stick-it-web:abc123' \
  "$call_log"
grep -Fxq \
  'Promoted ghcr.io/example/stick-it-web:abc123 to :snapshot' \
  <<< "$output"
