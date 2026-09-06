#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: $0 IMAGE SOURCE_BRANCH CHANNEL_TAG" >&2
  exit 2
fi

: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY must be set}"

image="$1"
source_branch="$2"
channel_tag="$3"

for attempt in 1 2 3 4 5 6; do
  current_sha="$(
    gh api "repos/$GITHUB_REPOSITORY/git/ref/heads/$source_branch" \
      --jq '.object.sha'
  )"
  if docker buildx imagetools inspect "$image:$current_sha" >/dev/null 2>&1; then
    verified_sha="$(
      gh api "repos/$GITHUB_REPOSITORY/git/ref/heads/$source_branch" \
        --jq '.object.sha'
    )"
    if [ "$verified_sha" = "$current_sha" ]; then
      docker buildx imagetools create \
        --tag "$image:$channel_tag" \
        "$image:$current_sha"
      echo "Promoted $image:$current_sha to :$channel_tag"
      exit 0
    fi
    echo "::notice::$source_branch advanced during promotion; retrying with its current image."
  else
    echo "::notice::The current $source_branch image is not available yet; retrying."
  fi
  sleep 10
done

echo "::notice::No stable current $source_branch image was available; leaving :$channel_tag unchanged."
