#!/bin/sh
set -eu
if [ -z "${DATABASE_URL:-}" ]; then
    : "${POSTGRES_USER:?POSTGRES_USER is required when DATABASE_URL is unset}"
    : "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required when DATABASE_URL is unset}"
    export DATABASE_URL="postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/monaserver?sslmode=disable"
fi
/app/monaserver &
api_pid=$!
nginx -g 'daemon off;' &
nginx_pid=$!
stop() {
    kill -TERM "$api_pid" "$nginx_pid" 2>/dev/null || true
    wait "$api_pid" "$nginx_pid" 2>/dev/null || true
}
trap 'stop; exit 0' TERM INT
while kill -0 "$api_pid" 2>/dev/null && kill -0 "$nginx_pid" 2>/dev/null; do
    sleep 1 & wait $!
done
stop
exit 1
