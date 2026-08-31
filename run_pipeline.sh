#!/bin/bash
# run_pipeline.sh — MIS Collections full pipeline (Linux/macOS)
# Usage:
#   ./run_pipeline.sh              # normal: generate + ETL (skip migrations if DB exists)
#   ./run_pipeline.sh --fresh      # fresh rebuild: down -v + bootstrap + generate + ETL
#   ./run_pipeline.sh --migrate    # run migrations only (after fresh up)
#   ./run_pipeline.sh --generate   # generate data only
#   ./run_pipeline.sh --etl        # ETL load only

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="database/docker-compose.yml"
ENV_FILE=".env"
CONTAINER="postgres_collections"
DB_USER="rtrlpz"
DB_NAME="MIS_CollectionsDB"
DB_PORT="5432"

MODE="normal"
for arg in "$@"; do
    case $arg in
        --fresh) MODE="fresh" ;;
        --migrate) MODE="migrate" ;;
        --generate) MODE="generate" ;;
        --etl) MODE="etl" ;;
        -h|--help)
            echo "Usage: $0 [--fresh|--migrate|--generate|--etl]"
            echo "  --fresh     Full rebuild: down -v, up, migrate, generate, ETL"
            echo "  --migrate   Run migrations only (after fresh up)"
            echo "  --generate  Generate data only"
            echo "  --etl       ETL load only"
            exit 0
            ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

log() { echo -e "${BLUE}[PIPELINE]${NC} $*"; }
ok()  { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err() { echo -e "${RED}[ERROR]${NC} $*"; }

timestamp() { date +%s; }

step_start=0
elapsed() { echo $(( $(timestamp) - step_start )); }

# --- Pre-flight checks ---
log "Checking prerequisites..."
command -v docker >/dev/null || { err "docker not found"; exit 1; }
command -v docker compose >/dev/null || { err "docker compose (v2) not found"; exit 1; }
[[ -f "$ENV_FILE" ]] || { err ".env not found at project root"; exit 1; }
command -v uv >/dev/null || { err "uv not found (need Python env manager)"; exit 1; }
[[ -d ".venv" ]] || { err ".venv not found (run: uv venv --python 3.12 .venv && uv pip install -r requirements.txt)"; exit 1; }

log "Prerequisites OK."

# --- Mode: fresh ---
if [[ "$MODE" == "fresh" ]]; then
    log "=== FRESH REBUILD ==="
    step_start=$(timestamp)
    log "Stopping and removing volumes..."
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down -v
    ok "Volumes removed. ($(elapsed)s)"

    log "Starting containers (auto-applies migrations on first boot)..."
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d
    step_start=$(timestamp)

    # Wait for Postgres ready
    log "Waiting for PostgreSQL..."
    for i in {1..30}; do
        if docker exec "$CONTAINER" pg_isready -h localhost -p 5432 -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1; then
            ok "PostgreSQL ready. ($(elapsed)s)"
            break
        fi
        sleep 2
        [[ $i -eq 30 ]] && { err "PostgreSQL did not become ready"; exit 1; }
    done

    # Apply seeds (not in init mount)
    log "Applying seeds..."
    for f in database/seeds/*.sql; do
        cat "$f" | docker exec -i "$CONTAINER" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" >/dev/null
    done
    ok "Seeds applied. ($(elapsed)s)"

    # Verify 16 views
    step_start=$(timestamp)
    VIEWS=$(docker exec "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "SELECT COUNT(*) FROM pg_views WHERE schemaname='public' AND viewname LIKE 'v\_%';" | tr -d '[:space:]')
    [[ "$VIEWS" == "16" ]] || { err "Expected 16 views, found $VIEWS"; exit 1; }
    ok "View count = 16. ($(elapsed)s)"

    # Fall through to generate + ETL
    MODE="normal"
fi

# --- Mode: migrate only ---
if [[ "$MODE" == "migrate" ]]; then
    log "=== RUN MIGRATIONS ==="
    bash database/migrate.sh
    ok "Migrations complete."
    exit 0
fi

# --- Mode: generate only ---
if [[ "$MODE" == "generate" ]]; then
    log "=== GENERATE DATA ==="
    step_start=$(timestamp)
    UV_PROJECT_ENVIRONMENT=.venv uv run python data_sources/data_generator_v7.py
    ok "Data generated. ($(elapsed)s)"
    exit 0
fi

# --- Mode: etl only ---
if [[ "$MODE" == "etl" ]]; then
    log "=== ETL LOAD ==="
    step_start=$(timestamp)
    UV_PROJECT_ENVIRONMENT=.venv uv run python etl/data_to_pg.py
    ok "ETL complete. ($(elapsed)s)"
    exit 0
fi

# --- Normal mode: generate + ETL ---
log "=== NORMAL RUN: GENERATE + ETL ==="
total_start=$(timestamp)

# Ensure DB is up
log "Checking database..."
if ! docker ps --filter "name=$CONTAINER" --filter "status=running" --format "{{.Names}}" | grep -q "^$CONTAINER$"; then
    err "Container $CONTAINER not running. Use --fresh or start it first."
    exit 1
fi
ok "Database container running."

# Generate
log "Generating data..."
step_start=$(timestamp)
UV_PROJECT_ENVIRONMENT=.venv uv run python data_sources/data_generator_v7.py
ok "Data generated. ($(elapsed)s)"

# ETL
log "Loading data into PostgreSQL..."
step_start=$(timestamp)
UV_PROJECT_ENVIRONMENT=.venv uv run python etl/data_to_pg.py
ok "ETL complete. ($(elapsed)s)"

# Summary
total_elapsed=$(( $(timestamp) - total_start ))
log "========================================"
ok "Pipeline complete."
ok "Total elapsed time: ${total_elapsed}s"
log "========================================"