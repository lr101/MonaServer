#!/usr/bin/env bash

set -euo pipefail

if [[ "$#" -ne 3 ]]; then
  echo "usage: $0 IMAGE VERSION BRANCH" >&2
  exit 2
fi

image="$1"
version="$2"
branch="$3"

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "version must be a semantic version" >&2
  exit 2
fi

case "$branch" in
  main)
    printf '%s\n' "$image:$version" "$image:latest"
    ;;
  develop)
    printf '%s\n' "$image:develop"
    ;;
  *)
    echo "refusing to publish tags for unsupported branch: $branch" >&2
    exit 2
    ;;
esac
