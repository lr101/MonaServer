#!/bin/sh
set -eu

upstream=${API_UPSTREAM:-https://stick-it.lr-projects.de}
case "$upstream" in
  http://*|https://*) ;;
  *)
    echo 'API_UPSTREAM must be an HTTP or HTTPS origin' >&2
    exit 1
    ;;
esac

# Keep this value deployment-owned and origin-only. In particular, a request
# path cannot select an arbitrary upstream or inject Nginx configuration.
case "$upstream" in
  */) upstream=${upstream%/} ;;
esac
authority=${upstream#*://}
if [ -z "$authority" ] || printf '%s' "$authority" | grep -Eq '[/\?#@[:space:]|&\\$]'; then
  echo 'API_UPSTREAM must be an origin without credentials, a path, or shell/Nginx metacharacters' >&2
  exit 1
fi

sed "s|__API_UPSTREAM__|$upstream|g" \
  /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

exec /docker-entrypoint.sh "$@"
