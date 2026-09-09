#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "render-nginx-master-config: $*" >&2
  exit 1
}

output_file=${1:-${DEV_NGINX_CONFIG_FILE:-}}
[[ -n "$output_file" ]] || die 'pass an output file or set DEV_NGINX_CONFIG_FILE'

runtime_dir=${DEV_NGINX_RUNTIME_DIR:-/tmp/serve-dev-worktree/nginx}
case "$runtime_dir" in
  /*) ;;
  *) die 'DEV_NGINX_RUNTIME_DIR must be an absolute path' ;;
esac
case "$runtime_dir" in
  *[!A-Za-z0-9_./-]*) die 'DEV_NGINX_RUNTIME_DIR contains shell-special characters' ;;
esac

nginx_port=${DEV_NGINX_PORT:-8080}
case "$nginx_port" in
  ''|*[!0-9]*) die 'DEV_NGINX_PORT must be a TCP port' ;;
esac
normalized_port=$(printf '%s' "$nginx_port" | sed 's/^0*//')
normalized_port=${normalized_port:-0}
if [[ "$normalized_port" == 0 || ${#normalized_port} -gt 5 || ( ${#normalized_port} -eq 5 && "$normalized_port" > 65535 ) ]]; then
  die 'DEV_NGINX_PORT must be between 1 and 65535'
fi
nginx_port=$normalized_port

worktree_dir="$runtime_dir/worktrees"
log_dir="$runtime_dir/logs"
mkdir -p -- "$worktree_dir" "$log_dir" "$(dirname -- "$output_file")"
if [[ ! -e "$worktree_dir/.empty.conf" ]]; then
  printf '# Kept so nginx can load an empty worktree registry.\n' > "$worktree_dir/.empty.conf"
fi

temporary_file="$output_file.tmp.$$"
cleanup() {
  rm -f -- "$temporary_file"
}
trap cleanup EXIT HUP INT TERM

cat > "$temporary_file" <<EOF
worker_processes 1;
pid $runtime_dir/nginx.pid;
error_log $log_dir/error.log warn;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    types {
        application/javascript mjs;
        application/json map;
    }

    map \$http_x_forwarded_proto \$dev_forwarded_proto {
        default \$http_x_forwarded_proto;
        "" \$scheme;
    }

    sendfile on;
    client_max_body_size 25m;
    access_log $log_dir/access.log;
    include $worktree_dir/*.conf;
}
EOF

mv -- "$temporary_file" "$output_file"
trap - EXIT HUP INT TERM
