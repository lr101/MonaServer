#!/usr/bin/env bash
# migrate-to-go.sh — Cut over from the Kotlin Spring Boot server to the Go server.
#
# Usage:
#   ./scripts/migrate-to-go.sh [--dry-run] [--db-url <DSN>]
#
# --dry-run   Print every action but do not execute it.
# --db-url    Override DATABASE_URL for the schema_migrations seed step.
#
# Prerequisites:
#   - psql (PostgreSQL client) in PATH
#   - docker / docker compose in PATH
#   - DATABASE_URL env var set (or --db-url flag), pointing at the production DB
#   - All Go env vars set (see MIGRATION.md)

set -euo pipefail

# ── Helpers ──────────────────────────────────────────────────────────────────

DRY_RUN=false
DB_URL="${DATABASE_URL:-}"
GO_SERVER_PORT="${PORT:-8080}"
SMOKE_HOST="${SMOKE_HOST:-http://localhost:${GO_SERVER_PORT}}"

usage() {
    grep '^#' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

log()  { echo "[migrate-to-go] $*"; }
die()  { echo "[migrate-to-go] ERROR: $*" >&2; exit 1; }
run()  {
    if $DRY_RUN; then
        echo "[DRY-RUN] $*"
    else
        eval "$@"
    fi
}

# ── Parse args ────────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)   DRY_RUN=true; shift ;;
        --db-url)    DB_URL="$2"; shift 2 ;;
        -h|--help)   usage ;;
        *) die "Unknown argument: $1" ;;
    esac
done

[[ -n "$DB_URL" ]] || die "DATABASE_URL is not set. Export it or pass --db-url."

# ── Step 0: Pre-flight ────────────────────────────────────────────────────────

log "Pre-flight checks..."
command -v psql  >/dev/null 2>&1 || die "psql not found in PATH"
command -v docker >/dev/null 2>&1 || die "docker not found in PATH"

# Detect if Flyway schema history exists (confirms this is a Kotlin prod DB).
FLYWAY_EXISTS=$(psql "$DB_URL" -tAc \
    "SELECT EXISTS(SELECT 1 FROM information_schema.tables WHERE table_name='flyway_schema_history');" \
    2>/dev/null || echo "false")

if [[ "$FLYWAY_EXISTS" == "t" ]]; then
    log "Flyway schema history detected — production database."
else
    log "No flyway_schema_history found — assuming fresh or already-migrated DB."
fi

# Check highest applied Flyway version.
if [[ "$FLYWAY_EXISTS" == "t" ]]; then
    MAX_VERSION=$(psql "$DB_URL" -tAc \
        "SELECT COALESCE(MAX(installed_rank), 0) FROM flyway_schema_history WHERE success = true;" \
        2>/dev/null || echo "0")
    log "Highest applied Flyway version: $MAX_VERSION"
    [[ "$MAX_VERSION" -ge 22 ]] || \
        die "Expected at least 22 Flyway migrations, found $MAX_VERSION. Abort."
fi

# ── Step 1: Seed schema_migrations ───────────────────────────────────────────

log "Step 1: Seeding schema_migrations table to version 22..."
run psql "$DB_URL" -c "
CREATE TABLE IF NOT EXISTS schema_migrations (
    version bigint  NOT NULL PRIMARY KEY,
    dirty   boolean NOT NULL
);
INSERT INTO schema_migrations (version, dirty)
VALUES (22, false)
ON CONFLICT (version) DO NOTHING;
"
log "schema_migrations seeded."

# ── Step 2: Build Go image ────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

log "Step 2: Building Go server Docker image..."
run docker build -t go-server:latest "$REPO_ROOT"
log "Image built: go-server:latest"

# ── Step 3: Validate required env vars ────────────────────────────────────────

log "Step 3: Validating required environment variables..."
REQUIRED_VARS=(
    DATABASE_URL
    JWT_SECRET
    TOKEN_ADMIN_USERNAME
)
MISSING=()
for v in "${REQUIRED_VARS[@]}"; do
    [[ -n "${!v:-}" ]] || MISSING+=("$v")
done
if [[ ${#MISSING[@]} -gt 0 ]]; then
    die "Missing required env vars: ${MISSING[*]}"
fi

# Warn if MINIO_ENDPOINT still has http:// prefix.
if [[ "${MINIO_ENDPOINT:-}" == http://* || "${MINIO_ENDPOINT:-}" == https://* ]]; then
    die "MINIO_ENDPOINT must not include the scheme (use 'host:port', not 'http://host:port')."
fi
log "Environment variables OK."

# ── Step 4: Start Go server ───────────────────────────────────────────────────

log "Step 4: Starting Go server container..."
run docker stop go-server-migration-test 2>/dev/null || true
run docker rm   go-server-migration-test 2>/dev/null || true

ENV_ARGS=""
for v in DATABASE_URL JWT_SECRET TOKEN_ADMIN_USERNAME TOKEN_ACCESS_EXPIRY \
          TOKEN_REFRESH_EXPIRY APP_MAX_LOGIN_ATTEMPTS APP_URL APP_REDIRECT_URL \
          MINIO_ENDPOINT MINIO_ACCESS_KEY MINIO_SECRET_KEY MINIO_BUCKET MINIO_USE_SSL \
          MAIL_HOST MAIL_PORT MAIL_USERNAME MAIL_PASSWORD MAIL_FROM \
          FIREBASE_CONFIG_PATH ACHIEVEMENT_MONA_GROUP_ID ACHIEVEMENT_CREATED_BEFORE PORT; do
    [[ -n "${!v:-}" ]] && ENV_ARGS="$ENV_ARGS -e $v=${!v}"
done

run docker run -d --name go-server-migration-test \
    $ENV_ARGS \
    -p "${GO_SERVER_PORT}:${PORT:-8080}" \
    go-server:latest

log "Waiting 5s for server to start..."
$DRY_RUN || sleep 5

# ── Step 5: Smoke test ────────────────────────────────────────────────────────

log "Step 5: Smoke testing..."

smoke() {
    local desc="$1"
    local expected="$2"
    shift 2
    if $DRY_RUN; then
        echo "[DRY-RUN] smoke: $desc — curl $*"
        return
    fi
    local status
    status=$(curl -s -o /dev/null -w "%{http_code}" "$@")
    if [[ "$status" == "$expected" ]]; then
        log "  PASS  $desc ($status)"
    else
        log "  FAIL  $desc — expected $expected, got $status"
        SMOKE_FAILED=true
    fi
}

SMOKE_FAILED=false

smoke "GET /api/v2/public/info"    200 "${SMOKE_HOST}/api/v2/public/info"
smoke "GET /api/v2/public/infos"   200 "${SMOKE_HOST}/api/v2/public/infos"
smoke "GET /api/v2/status (no auth)" 401 "${SMOKE_HOST}/api/v2/status"
smoke "POST /api/v2/auth/login (bad creds)" 401 \
    -X POST -H "Content-Type: application/json" \
    -d '{"username":"_smoke_test_","password":"_smoke_test_"}' \
    "${SMOKE_HOST}/api/v2/auth/login"
smoke "POST /api/v2/public/login (alias)" 401 \
    -X POST -H "Content-Type: application/json" \
    -d '{"username":"_smoke_test_","password":"_smoke_test_"}' \
    "${SMOKE_HOST}/api/v2/public/login"
smoke "POST /api/v2/auth/signup (invalid)" 400 \
    -X POST -H "Content-Type: application/json" \
    -d '{}' \
    "${SMOKE_HOST}/api/v2/auth/signup"
smoke "GET /api/v2/groups (no auth)" 401 "${SMOKE_HOST}/api/v2/groups"

if $SMOKE_FAILED; then
    log "One or more smoke tests failed. Review the output above."
    log "The container 'go-server-migration-test' is still running for manual inspection."
    log "To stop it: docker stop go-server-migration-test && docker rm go-server-migration-test"
    exit 1
fi

log "All smoke tests passed."
log ""
log "The Go server is running as container 'go-server-migration-test' on port ${GO_SERVER_PORT}."
log "Next steps:"
log "  1. Run integration tests against ${SMOKE_HOST}"
log "  2. Update your docker-compose / load balancer to point at the Go container."
log "  3. Stop the Kotlin server."
log "  4. Run: docker rename go-server-migration-test go-server"
log ""
log "To stop the test container: docker stop go-server-migration-test && docker rm go-server-migration-test"
