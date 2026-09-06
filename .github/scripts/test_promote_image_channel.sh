#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
call_log="$(mktemp)"
gh_count="$(mktemp)"
trap 'rm -f "$call_log" "$gh_count"' EXIT

gh() {
  printf 'gh %s\n' "$*" >> "$CALL_LOG"
  count="$(($(cat "$GH_COUNT") + 1))"
  printf '%s\n' "$count" > "$GH_COUNT"
  if [ "$GH_MODE" = 'advances-once' ] && [ "$count" -eq 1 ]; then
    printf 'old-sha\n'
  else
    printf 'current-sha\n'
  fi
}

docker() {
  printf 'docker %s\n' "$*" >> "$CALL_LOG"
}

sleep() {
  :
}

export CALL_LOG="$call_log"
export GH_COUNT="$gh_count"
export GITHUB_REPOSITORY='example/mona'
export GH_MODE='stable'
export -f gh docker sleep

printf '0\n' > "$gh_count"

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
  'docker buildx imagetools inspect ghcr.io/example/stick-it-web:current-sha' \
  "$call_log"
grep -Fxq \
  'docker buildx imagetools create --tag ghcr.io/example/stick-it-web:snapshot ghcr.io/example/stick-it-web:current-sha' \
  "$call_log"
grep -Fxq \
  'Promoted ghcr.io/example/stick-it-web:current-sha to :snapshot' \
  <<< "$output"

printf '0\n' > "$gh_count"
: > "$call_log"
export GH_MODE='advances-once'

bash "$script_dir/promote_image_channel.sh" \
  'ghcr.io/example/stick-it-server-go' \
  'develop' \
  'snapshot'

if grep -Fq \
  'docker buildx imagetools create --tag ghcr.io/example/stick-it-server-go:snapshot ghcr.io/example/stick-it-server-go:old-sha' \
  "$call_log"; then
  echo 'promotion mutated the snapshot tag before verifying the branch head' >&2
  exit 1
fi
grep -Fxq \
  'docker buildx imagetools create --tag ghcr.io/example/stick-it-server-go:snapshot ghcr.io/example/stick-it-server-go:current-sha' \
  "$call_log"
