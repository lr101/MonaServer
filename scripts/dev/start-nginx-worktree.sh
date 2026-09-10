#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/../.." && pwd)
dry_run=false
original_args=("$@")

usage() {
  cat >&2 <<'EOF'
Usage: start-nginx-worktree.sh [--repo-root PATH] [--dry-run]

Starts the native development services for one worktree and registers their
hosts in the shared local nginx gateway.
EOF
}

die() {
  echo "start-nginx-worktree: $*" >&2
  exit 1
}

while (($# > 0)); do
  case "$1" in
    --repo-root)
      (($# >= 2)) || die '--repo-root needs a path'
      repo_root=$(cd -- "$2" 2>/dev/null && pwd) || die "repository does not exist: $2"
      shift 2
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      die "unknown argument: $1"
      ;;
  esac
done

[[ -f "$repo_root/go-server/go.mod" ]] || die "not a MonaServer worktree: $repo_root"
[[ -f "$repo_root/flutter/pubspec.yaml" ]] || die "Flutter app is missing: $repo_root/flutter"

master_renderer="$script_dir/render-nginx-master-config.sh"
worktree_renderer="$script_dir/render-nginx-worktree-config.sh"
[[ -x "$master_renderer" ]] || die "missing executable: $master_renderer"
[[ -x "$worktree_renderer" ]] || die "missing executable: $worktree_renderer"

normalize_port() {
  local value=$1
  local name=$2
  local normalized

  case "$value" in
    ''|*[!0-9]*) die "$name must be a TCP port" ;;
  esac
  normalized=$(printf '%s' "$value" | sed 's/^0*//')
  normalized=${normalized:-0}
  if [[ "$normalized" == 0 || ${#normalized} -gt 5 || ( ${#normalized} -eq 5 && "$normalized" > 65535 ) ]]; then
    die "$name must be between 1 and 65535"
  fi
  printf '%s\n' "$normalized"
}

validate_slug() {
  local value=$1
  [[ -n "$value" ]] || die 'DEV_SLUG must not be empty'
  [[ ${#value} -le 48 ]] || die 'DEV_SLUG must be at most 48 characters'
  case "$value" in
    [a-z0-9]|[a-z0-9][a-z0-9-]*[a-z0-9]) ;;
    *) die 'DEV_SLUG must contain lowercase letters, digits, and hyphens and may not start or end with a hyphen' ;;
  esac
}

validate_domain_suffix() {
  local value=$1
  case "$value" in
    ''|*[!A-Za-z0-9.-]*|.*|*.|*..*) die 'DEV_DOMAIN_SUFFIX must be a DNS suffix' ;;
  esac
}

branch_slug() {
  local branch
  branch=$(git -C "$repo_root" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
  if [[ -z "$branch" ]]; then
    branch=worktree
  fi
  branch=$(printf '%s' "$branch" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g; s/--*/-/g; s/^-*//; s/-*$//')
  branch=${branch:-worktree}
  local path_hash
  path_hash=$(printf '%s' "$repo_root" | sha256sum | cut -c1-8)
  branch=${branch:0:$((48 - 9))}
  branch=${branch%-}
  printf '%s-%s\n' "$branch" "$path_hash"
}

slug=${DEV_SLUG:-$(branch_slug)}
validate_slug "$slug"

domain_suffix=${DEV_DOMAIN_SUFFIX:-dev.dell.lr-projects.de}
validate_domain_suffix "$domain_suffix"

api_host=${DEV_API_HOST:-api-${slug}.${domain_suffix}}
web_host=${DEV_WEB_HOST:-web-${slug}.${domain_suffix}}
storage_host=${DEV_STORAGE_HOST:-storage-${slug}.${domain_suffix}}
console_host=${DEV_CONSOLE_HOST:-console-${slug}.${domain_suffix}}
for host in "$api_host" "$web_host" "$storage_host" "$console_host"; do
  case "$host" in
    ''|*[!A-Za-z0-9.-]*|.*|*.|*..*) die "invalid development hostname: $host" ;;
  esac
done

traefik_tls=${TRAEFIK_TLS:-true}
case "$traefik_tls" in
  1|true|TRUE|yes|YES|on|ON)
    traefik_tls=true
    ;;
  0|false|FALSE|no|NO|off|OFF)
    traefik_tls=false
    ;;
  *)
    die 'TRAEFIK_TLS must be true or false'
    ;;
esac

if [[ -n "${DEV_PUBLIC_SCHEME:-}" ]]; then
  public_scheme=$DEV_PUBLIC_SCHEME
else
  public_scheme=$([[ "$traefik_tls" == true ]] && printf 'https' || printf 'http')
fi
case "$public_scheme" in
  http|https) ;;
  *) die 'DEV_PUBLIC_SCHEME must be http or https' ;;
esac

nginx_port=$(normalize_port "${DEV_NGINX_PORT:-18080}" DEV_NGINX_PORT)
runtime_dir=${DEV_NGINX_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/tmp}/serve-dev-worktree/nginx}
case "$runtime_dir" in
  /*) ;;
  *) die 'DEV_NGINX_RUNTIME_DIR must be an absolute path' ;;
esac
case "$runtime_dir" in
  *[!A-Za-z0-9_./-]*) die 'DEV_NGINX_RUNTIME_DIR contains shell-special characters' ;;
esac

stack_max_seconds=${DEV_STACK_MAX_SECONDS:-86400}
case "$stack_max_seconds" in
  ''|*[!0-9]*) die 'DEV_STACK_MAX_SECONDS must be a positive integer' ;;
esac
stack_max_seconds=$(printf '%s' "$stack_max_seconds" | sed 's/^0*//')
stack_max_seconds=${stack_max_seconds:-0}
if [[ "$stack_max_seconds" == 0 || ${#stack_max_seconds} -gt 5 || ( ${#stack_max_seconds} -eq 5 && "$stack_max_seconds" > 86400 ) ]]; then
  die 'DEV_STACK_MAX_SECONDS must be between 1 and 86400'
fi

if [[ "${DEV_STACK_TIMEOUT_ACTIVE:-false}" != true ]]; then
  command -v timeout >/dev/null 2>&1 || die 'required command is missing: timeout'
  DEV_STACK_TIMEOUT_ACTIVE=true exec timeout --foreground --signal=TERM --kill-after=30s \
    "$stack_max_seconds" "$0" "${original_args[@]}"
fi

api_url="$public_scheme://$api_host"
web_url="$public_scheme://$web_host"
storage_url="$public_scheme://$storage_host"
console_url="$public_scheme://$console_host"

if [[ -n "${DEV_API_PORT:-}" ]]; then
  requested_api_port=$DEV_API_PORT
else
  requested_api_port=
fi
if [[ -n "${DEV_STORAGE_PORT:-}" ]]; then
  requested_storage_port=$DEV_STORAGE_PORT
else
  requested_storage_port=
fi
if [[ -n "${DEV_STORAGE_CONSOLE_PORT:-}" ]]; then
  requested_console_port=$DEV_STORAGE_CONSOLE_PORT
else
  requested_console_port=
fi

if [[ "$dry_run" == true ]]; then
  api_port=${requested_api_port:-random}
  storage_port=${requested_storage_port:-random}
  storage_console_port=${requested_console_port:-random}
  [[ "$api_port" == random ]] || api_port=$(normalize_port "$api_port" DEV_API_PORT)
  [[ "$storage_port" == random ]] || storage_port=$(normalize_port "$storage_port" DEV_STORAGE_PORT)
  [[ "$storage_console_port" == random ]] || storage_console_port=$(normalize_port "$storage_console_port" DEV_STORAGE_CONSOLE_PORT)
  cat <<EOF
project=$slug
api_url=$api_url
web_url=$web_url
storage_url=$storage_url
storage_console_url=$console_url
nginx_port=$nginx_port
api_port=$api_port
storage_port=$storage_port
storage_console_port=$storage_console_port
nginx_runtime_dir=$runtime_dir
stack_max_seconds=$stack_max_seconds
EOF
  exit 0
fi

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command is missing: $1"
}

for command_name in curl flock mise nginx pg_isready python3 sha256sum setsid timeout; do
  require_command "$command_name"
done
env_file=${DEV_ENV_FILE:-$repo_root/.env.dev}
[[ -f "$env_file" ]] || die "missing $env_file"

rustfs_bin=${DEV_RUSTFS_BIN:-}
if [[ -z "$rustfs_bin" ]]; then
  rustfs_bin=$(command -v rustfs || true)
fi
[[ -n "$rustfs_bin" && -x "$rustfs_bin" ]] || die 'RustFS is missing; set DEV_RUSTFS_BIN or install rustfs'

set -a
# shellcheck disable=SC1091
source "$env_file"
set +a

[[ -n "${DATABASE_URL:-}" ]] || die 'DATABASE_URL is required in .env.dev'
[[ -n "${JWT_SECRET:-}" ]] || die 'JWT_SECRET is required in .env.dev'
[[ -n "${TOKEN_ADMIN_USERNAME:-}" ]] || die 'TOKEN_ADMIN_USERNAME is required in .env.dev'

rustfs_access_key=${RUSTFS_ACCESS_KEY:-${MINIO_ACCESS_KEY:-}}
rustfs_secret_key=${RUSTFS_SECRET_KEY:-${MINIO_SECRET_KEY:-}}
[[ -n "$rustfs_access_key" ]] || die 'RUSTFS_ACCESS_KEY is required in .env.dev'
[[ -n "$rustfs_secret_key" ]] || die 'RUSTFS_SECRET_KEY is required in .env.dev'
rustfs_bucket=${RUSTFS_BUCKET:-${MINIO_BUCKET:-monaserver}}

native_database_url=$DATABASE_URL
native_database_url=${native_database_url//@db:5432/@127.0.0.1:5432}
native_database_url=${native_database_url//@postgres:5432/@127.0.0.1:5432}
native_database_url=${native_database_url//@localhost:5433/@127.0.0.1:5432}
pg_isready -h 127.0.0.1 -p 5432 >/dev/null 2>&1 || die 'PostgreSQL is not ready on 127.0.0.1:5432'

mkdir -p -- "$runtime_dir" "$runtime_dir/worktrees" "$runtime_dir/logs" "$runtime_dir/data/$slug"
nginx_config="$runtime_dir/nginx.conf"
nginx_pid_file="$runtime_dir/nginx.pid"
nginx_port_file="$runtime_dir/nginx.port"
nginx_lock_file="$runtime_dir/nginx.lock"
worktree_dir="$runtime_dir/worktrees"
log_dir="$runtime_dir/logs"
snippet_file="$worktree_dir/$slug.conf"
snippet_owner_file="$worktree_dir/$slug.owner"
nginx_log_file="$log_dir/nginx.log"
api_log_file="$log_dir/$slug-api.log"
rustfs_log_file="$log_dir/$slug-rustfs.log"
web_root=${DEV_WEB_ROOT:-$repo_root/flutter/build/web}

port_state_dir=${DEV_PORT_STATE_DIR:-${XDG_RUNTIME_DIR:-/tmp}/serve-dev-worktree/ports}
mkdir -p -- "$port_state_dir"
port_lock_file="$port_state_dir/.lock"
exec {port_lock_fd}>"$port_lock_file"
exec {nginx_lock_fd}>"$nginx_lock_file"

declare -A seen_ports=()
reserved_ports=()
seen_ports[$nginx_port]=1

port_is_free() {
  local port=$1
  python3 - "$port" <<'PY'
import socket
import sys

port = int(sys.argv[1])
with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(("127.0.0.1", port))
PY
}

reservation_is_live() {
  local reservation=$1
  [[ -f "$reservation" ]] || return 1
  local owner_pid
  read -r owner_pid _ < "$reservation" || return 1
  [[ "$owner_pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$owner_pid" >/dev/null 2>&1
}

reserve_port() {
  local requested=$1
  local name=$2
  local candidate reservation

  flock "$port_lock_fd"
  if [[ -n "$requested" ]]; then
    candidate=$(normalize_port "$requested" "$name")
    [[ -z "${seen_ports[$candidate]+set}" ]] || die "$name duplicates another development port"
    reservation="$port_state_dir/$candidate"
    if [[ -e "$reservation" ]] && ! reservation_is_live "$reservation"; then
      rm -f -- "$reservation"
    fi
    [[ ! -e "$reservation" ]] || die "$name $candidate is reserved by another worktree"
    if ! port_is_free "$candidate"; then
      die "$name $candidate is already in use"
    fi
  else
    for _ in $(seq 1 100); do
      candidate=$(python3 - <<'PY'
import socket

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
)
      [[ -z "${seen_ports[$candidate]+set}" ]] || continue
      reservation="$port_state_dir/$candidate"
      if [[ -e "$reservation" ]] && ! reservation_is_live "$reservation"; then
        rm -f -- "$reservation"
      fi
      [[ ! -e "$reservation" ]] || continue
      port_is_free "$candidate" || continue
      break
    done
    [[ -n "${candidate:-}" && -z "${seen_ports[$candidate]+set}" && ! -e "$port_state_dir/$candidate" ]] || die "could not allocate a free $name"
  fi
  printf '%s %s\n' "$$" "$slug" > "$port_state_dir/$candidate"
  seen_ports[$candidate]=1
  reserved_ports+=("$candidate")
  reserved_port=$candidate
  flock -u "$port_lock_fd"
}

release_ports() {
  local reservation port owner_pid
  flock "$port_lock_fd"
  for reservation in "$port_state_dir"/[0-9]*; do
    [[ -f "$reservation" ]] || continue
    port=$(basename -- "$reservation")
    read -r owner_pid _ < "$reservation" || continue
    if [[ "$owner_pid" == "$$" ]]; then
      rm -f -- "$port_state_dir/$port"
    fi
  done
  flock -u "$port_lock_fd"
}

trap release_ports EXIT
reserved_port=
reserve_port "$requested_api_port" DEV_API_PORT
api_port=$reserved_port
reserve_port "$requested_storage_port" DEV_STORAGE_PORT
storage_port=$reserved_port
reserve_port "$requested_console_port" DEV_STORAGE_CONSOLE_PORT
storage_console_port=$reserved_port

nginx_process_alive() {
  [[ -s "$nginx_pid_file" ]] || return 1
  local nginx_pid
  nginx_pid=$(sed -n '1p' "$nginx_pid_file")
  [[ "$nginx_pid" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$nginx_pid" >/dev/null 2>&1 || return 1
  [[ -r "/proc/$nginx_pid/cmdline" ]] || return 1
  tr '\0' ' ' < "/proc/$nginx_pid/cmdline" | grep -Fq -- "$nginx_config"
}

nginx_stop() {
  local nginx_pid
  if ! nginx_process_alive; then
    rm -f -- "$nginx_pid_file" "$nginx_port_file"
    return 0
  fi
  nginx_pid=$(sed -n '1p' "$nginx_pid_file")
  kill -QUIT "$nginx_pid" >/dev/null 2>&1 || true
  for _ in $(seq 1 50); do
    kill -0 "$nginx_pid" >/dev/null 2>&1 || break
    sleep 0.1
  done
  if kill -0 "$nginx_pid" >/dev/null 2>&1; then
    kill -TERM "$nginx_pid" >/dev/null 2>&1 || true
  fi
  rm -f -- "$nginx_pid_file" "$nginx_port_file"
}

start_nginx_locked() {
  if nginx_process_alive; then
    [[ -f "$nginx_port_file" ]] || die 'shared nginx is running without a port marker'
    [[ "$(sed -n '1p' "$nginx_port_file")" == "$nginx_port" ]] || die 'shared nginx is running on a different port'
    return 0
  fi

  if ! port_is_free "$nginx_port"; then
    die "DEV_NGINX_PORT $nginx_port is already in use"
  fi
  DEV_NGINX_RUNTIME_DIR="$runtime_dir" DEV_NGINX_PORT="$nginx_port" \
    "$master_renderer" "$nginx_config"
  nginx -t -p "$runtime_dir" -c "$nginx_config" >/dev/null
  nginx -p "$runtime_dir" -c "$nginx_config" -g 'daemon off;' >>"$nginx_log_file" 2>&1 &
  local launcher_pid=$!
  for _ in $(seq 1 50); do
    if nginx_process_alive; then
      printf '%s\n' "$nginx_port" > "$nginx_port_file"
      return 0
    fi
    if ! kill -0 "$launcher_pid" >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done
  cat "$nginx_log_file" >&2 || true
  die 'nginx did not start'
}

reload_nginx_locked() {
  nginx -t -p "$runtime_dir" -c "$nginx_config" >/dev/null
  nginx -s reload -p "$runtime_dir" -c "$nginx_config" >/dev/null
}

route_registered=false
route_claimed=false

add_nginx_route() {
  flock "$nginx_lock_fd"
  if [[ -f "$snippet_owner_file" ]]; then
    local owner_pid
    owner_pid=$(sed -n '1p' "$snippet_owner_file")
    if [[ "$owner_pid" =~ ^[0-9]+$ ]] && kill -0 "$owner_pid" >/dev/null 2>&1; then
      die "worktree slug is already active: $slug"
    fi
    rm -f -- "$snippet_owner_file" "$snippet_file"
  fi

  DEV_SLUG="$slug" \
  DEV_DOMAIN_SUFFIX="$domain_suffix" \
  DEV_API_HOST="$api_host" \
  DEV_WEB_HOST="$web_host" \
  DEV_STORAGE_HOST="$storage_host" \
  DEV_CONSOLE_HOST="$console_host" \
  DEV_NGINX_PORT="$nginx_port" \
  DEV_API_PORT="$api_port" \
  DEV_STORAGE_PORT="$storage_port" \
  DEV_STORAGE_CONSOLE_PORT="$storage_console_port" \
  DEV_WEB_ROOT="$web_root" \
  DEV_PUBLIC_SCHEME="$public_scheme" \
    "$worktree_renderer" "$snippet_file"
  route_claimed=true

  DEV_NGINX_RUNTIME_DIR="$runtime_dir" DEV_NGINX_PORT="$nginx_port" \
    "$master_renderer" "$nginx_config"
  if nginx_process_alive; then
    reload_nginx_locked
  else
    start_nginx_locked
  fi
  printf '%s\n' "$$" > "$snippet_owner_file"
  route_registered=true
  flock -u "$nginx_lock_fd"
}

remove_nginx_route() {
  flock "$nginx_lock_fd"
  if [[ -f "$snippet_owner_file" ]]; then
    local owner_pid
    owner_pid=$(sed -n '1p' "$snippet_owner_file")
    if [[ "$owner_pid" == "$$" || "$route_claimed" == true ]]; then
      rm -f -- "$snippet_owner_file" "$snippet_file"
    fi
  elif [[ "$route_claimed" == true ]]; then
    rm -f -- "$snippet_file"
  fi

  local active_routes
  active_routes=$(find "$worktree_dir" -maxdepth 1 -type f -name '*.conf' ! -name '.empty.conf' -print | wc -l)
  if ((active_routes > 0)); then
    if nginx_process_alive; then
      reload_nginx_locked || true
    fi
  else
    nginx_stop
  fi
  flock -u "$nginx_lock_fd"
}

api_pid=
rustfs_pid=
cleanup_done=false

cleanup() {
  local exit_status=$?
  [[ "$cleanup_done" == true ]] && exit "$exit_status"
  cleanup_done=true
  set +e

  if [[ -n "$api_pid" ]]; then
    kill TERM -- "-$api_pid" >/dev/null 2>&1 || kill TERM "$api_pid" >/dev/null 2>&1 || true
    wait "$api_pid" >/dev/null 2>&1 || true
  fi
  if [[ -n "$rustfs_pid" ]]; then
    kill TERM -- "-$rustfs_pid" >/dev/null 2>&1 || kill TERM "$rustfs_pid" >/dev/null 2>&1 || true
    wait "$rustfs_pid" >/dev/null 2>&1 || true
  fi
  if [[ "$route_claimed" == true ]]; then
    remove_nginx_route
  fi
  release_ports
  exit "$exit_status"
}
trap cleanup EXIT INT TERM

# RustFS itself is a loopback HTTP service in the native profile. Traefik
# terminates the public TLS connection, so the Go server needs separate
# internal and external object-store schemes.
rustfs_use_ssl=false
rustfs_external_use_ssl=${RUSTFS_EXTERNAL_USE_SSL:-}
if [[ -z "$rustfs_external_use_ssl" ]]; then
  rustfs_external_use_ssl=$([[ "$public_scheme" == https ]] && printf 'true' || printf 'false')
fi
case "$rustfs_external_use_ssl" in
  1|true|TRUE|yes|YES|on|ON) rustfs_external_use_ssl=true ;;
  0|false|FALSE|no|NO|off|OFF) rustfs_external_use_ssl=false ;;
  *) die 'RUSTFS_EXTERNAL_USE_SSL must be true or false' ;;
esac

echo 'Building Flutter web app...' >&2
(cd "$repo_root/flutter" && mise exec -- flutter pub get && mise exec -- flutter build web --wasm --release --no-pub --dart-define="API_HOST=$api_url")
[[ -d "$web_root" ]] || die "Flutter build did not create $web_root"

add_nginx_route

rustfs_data_dir="$runtime_dir/data/$slug"
echo "Starting RustFS on 127.0.0.1:$storage_port..." >&2
(
  export RUSTFS_ACCESS_KEY="$rustfs_access_key"
  export RUSTFS_SECRET_KEY="$rustfs_secret_key"
  export RUSTFS_ADDRESS="127.0.0.1:$storage_port"
  export RUSTFS_CONSOLE_ADDRESS="127.0.0.1:$storage_console_port"
  export RUSTFS_CONSOLE_ENABLE=true
  export RUSTFS_CORS_ALLOWED_ORIGINS="$web_url"
  exec setsid "$rustfs_bin" server "$rustfs_data_dir"
) >"$rustfs_log_file" 2>&1 &
rustfs_pid=$!

wait_for_host() {
  local host=$1
  local path=$2
  local label=$3
  for _ in $(seq 1 120); do
    if curl --fail --silent --show-error --max-time 2 \
      --header "Host: $host" "http://127.0.0.1:$nginx_port$path" >/dev/null 2>&1; then
      return 0
    fi
    if ! kill -0 "$rustfs_pid" >/dev/null 2>&1; then
      cat "$rustfs_log_file" >&2 || true
      die "RustFS exited while waiting for $label"
    fi
    if [[ -n "$api_pid" ]] && ! kill -0 "$api_pid" >/dev/null 2>&1; then
      cat "$api_log_file" >&2 || true
      die "API exited while waiting for $label"
    fi
    sleep 0.5
  done
  return 1
}

wait_for_required_host() {
  local host=$1
  local path=$2
  local label=$3
  if ! wait_for_host "$host" "$path" "$label"; then
    if [[ "$label" == RustFS ]]; then
      cat "$rustfs_log_file" >&2 || true
    else
      cat "$api_log_file" >&2 || true
    fi
    die "$label did not become ready"
  fi
}

wait_for_storage() {
  for _ in $(seq 1 120); do
    local status
    status=$(curl --silent --show-error --max-time 2 --output /dev/null \
      --write-out '%{http_code}' --header "Host: $storage_host" \
      "http://127.0.0.1:$nginx_port/health/ready" || true)
    case "$status" in
      2??|3??|4??) return 0 ;;
    esac
    if ! kill -0 "$rustfs_pid" >/dev/null 2>&1; then
      cat "$rustfs_log_file" >&2 || true
      die 'RustFS exited while waiting for health'
    fi
    sleep 0.5
  done
  cat "$rustfs_log_file" >&2 || true
  die 'RustFS health endpoint did not become ready'
}

wait_for_storage

echo "Starting Go API on 127.0.0.1:$api_port..." >&2
(
  export PORT="$api_port"
  export APP_URL="$api_url"
  export APP_REDIRECT_URL="$web_url"
  export DATABASE_URL="$native_database_url"
  export RUSTFS_ENDPOINT="127.0.0.1:$storage_port"
  export RUSTFS_EXTERNAL_ENDPOINT="$storage_host"
  export RUSTFS_ACCESS_KEY="$rustfs_access_key"
  export RUSTFS_SECRET_KEY="$rustfs_secret_key"
  export RUSTFS_BUCKET="$rustfs_bucket"
  export RUSTFS_USE_SSL="$rustfs_use_ssl"
  export RUSTFS_EXTERNAL_USE_SSL="$rustfs_external_use_ssl"
  cd "$repo_root/go-server"
  exec setsid mise exec -- go run ./cmd/server
) >"$api_log_file" 2>&1 &
api_pid=$!

wait_for_required_host "$api_host" /public/api-docs 'Go API'
wait_for_required_host "$web_host" / 'Flutter web app'

cat <<EOF
project=$slug
api_url=$api_url
web_url=$web_url
storage_url=$storage_url
storage_console_url=$console_url
nginx_upstream=http://127.0.0.1:$nginx_port
nginx_port=$nginx_port
api_port=$api_port
storage_port=$storage_port
storage_console_port=$storage_console_port
nginx_runtime_dir=$runtime_dir
nginx_config=$nginx_config
worktree_config=$snippet_file
stack_max_seconds=$stack_max_seconds
EOF

echo 'Development stack is ready; press Ctrl-C to stop it.' >&2
while kill -0 "$rustfs_pid" >/dev/null 2>&1 && kill -0 "$api_pid" >/dev/null 2>&1; do
  sleep 1
done

if ! kill -0 "$rustfs_pid" >/dev/null 2>&1; then
  cat "$rustfs_log_file" >&2 || true
  die 'RustFS exited unexpectedly'
fi
cat "$api_log_file" >&2 || true
die 'Go API exited unexpectedly'
