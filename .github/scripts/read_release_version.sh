#!/usr/bin/env bash

set -euo pipefail

version="$(awk -F= '$1 == "version" { print $2; exit }' go-server/VERSION)"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "go-server/VERSION must contain a semantic version in version= form" >&2
  exit 1
fi

printf '%s\n' "$version"
