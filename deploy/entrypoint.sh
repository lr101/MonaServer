#!/bin/sh
set -eu
: "${POSTGRES_USER:?POSTGRES_USER is required}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
export DATABASE_URL="postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/monaserver?sslmode=disable"
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
