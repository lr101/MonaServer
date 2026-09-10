#!/usr/bin/env bash
set -euo pipefail

die() {
  echo "render-nginx-worktree-config: $*" >&2
  exit 1
}

output_file=${1:-}
[[ -n "$output_file" ]] || die 'pass an output file'

slug=${DEV_SLUG:-}
domain_suffix=${DEV_DOMAIN_SUFFIX:-dev.dell.lr-projects.de}
api_host=${DEV_API_HOST:-api-${slug}.${domain_suffix}}
web_host=${DEV_WEB_HOST:-web-${slug}.${domain_suffix}}
storage_host=${DEV_STORAGE_HOST:-storage-${slug}.${domain_suffix}}
console_host=${DEV_CONSOLE_HOST:-console-${slug}.${domain_suffix}}
web_root=${DEV_WEB_ROOT:-}
public_scheme=${DEV_PUBLIC_SCHEME:-https}
nginx_port=${DEV_NGINX_PORT:-18080}

[[ -n "$slug" ]] || die 'DEV_SLUG must be set'
case "$slug" in
  ''|*[!a-z0-9-]*) die 'DEV_SLUG must contain only lowercase letters, digits, and hyphens' ;;
esac
case "$domain_suffix" in
  ''|*[!A-Za-z0-9.-]*|.*|*.|*..*) die 'DEV_DOMAIN_SUFFIX must be a DNS suffix' ;;
esac
for host in "$api_host" "$web_host" "$storage_host" "$console_host"; do
  case "$host" in
    ''|*[!A-Za-z0-9.-]*|.*|*.|*..*) die "invalid development hostname: $host" ;;
  esac
done
[[ -d "$web_root" ]] || die 'DEV_WEB_ROOT must be an existing directory'
case "$public_scheme" in
  http|https) ;;
  *) die 'DEV_PUBLIC_SCHEME must be http or https' ;;
esac

validate_port() {
  local name=$1
  local value=${!name}
  local normalized
  case "$value" in
    ''|*[!0-9]*) die "$name must be a TCP port" ;;
  esac
  normalized=$(printf '%s' "$value" | sed 's/^0*//')
  normalized=${normalized:-0}
  if [[ "$normalized" == 0 || ${#normalized} -gt 5 || ( ${#normalized} -eq 5 && "$normalized" > 65535 ) ]]; then
    die "$name must be between 1 and 65535"
  fi
  printf -v "$name" '%s' "$normalized"
}

validate_port DEV_NGINX_PORT
validate_port DEV_API_PORT
validate_port DEV_STORAGE_PORT
if [[ -n "${DEV_STORAGE_CONSOLE_PORT:-}" ]]; then
  validate_port DEV_STORAGE_CONSOLE_PORT
fi

escape_nginx_string() {
  printf '%s' "$1" | sed 's/[\\"]/[\\&]/g'
}
escaped_web_root=$(escape_nginx_string "$web_root")

output_dir=$(dirname -- "$output_file")
mkdir -p -- "$output_dir"
temporary_file="$output_file.tmp.$$"
cleanup() {
  rm -f -- "$temporary_file"
}
trap cleanup EXIT HUP INT TERM

cat > "$temporary_file" <<EOF
server {
    listen $nginx_port;
    server_name $api_host;

    location / {
        proxy_pass http://127.0.0.1:$DEV_API_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Proto \$dev_forwarded_proto;
        proxy_set_header Connection "";
    }
}

server {
    listen $nginx_port;
    server_name $web_host;
    root "$escaped_web_root";
    index index.html;

    location ^~ /assets/ {
        try_files \$uri =404;
    }

    location ~* \\.(?:css|js|mjs|wasm|json|bin|png|jpe?g|gif|ico|ttf|map|symbols)\$ {
        try_files \$uri =404;
    }

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}

server {
    listen $nginx_port;
    server_name $storage_host;

    location / {
        if (\$request_method = OPTIONS) {
            add_header Access-Control-Allow-Origin $public_scheme://$web_host always;
            add_header Access-Control-Allow-Methods "GET, OPTIONS" always;
            add_header Access-Control-Allow-Headers "*" always;
            add_header Access-Control-Max-Age 86400 always;
            return 204;
        }

        proxy_pass http://127.0.0.1:$DEV_STORAGE_PORT;
        proxy_http_version 1.1;
        proxy_request_buffering off;
        proxy_buffering off;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Proto \$dev_forwarded_proto;
        proxy_set_header Connection "";
        proxy_hide_header Access-Control-Allow-Origin;
        proxy_hide_header Access-Control-Allow-Methods;
        proxy_hide_header Access-Control-Allow-Headers;
        add_header Access-Control-Allow-Origin $public_scheme://$web_host always;
        add_header Access-Control-Allow-Methods "GET, OPTIONS" always;
        add_header Access-Control-Allow-Headers "*" always;
        add_header Vary Origin always;
    }
}
EOF

if [[ -n "${DEV_STORAGE_CONSOLE_PORT:-}" ]]; then
  cat >> "$temporary_file" <<EOF

server {
    listen $nginx_port;
    server_name $console_host;

    location / {
        proxy_pass http://127.0.0.1:$DEV_STORAGE_CONSOLE_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Proto \$dev_forwarded_proto;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF
fi

mv -- "$temporary_file" "$output_file"
trap - EXIT HUP INT TERM
