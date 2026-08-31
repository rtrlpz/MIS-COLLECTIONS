#!/bin/bash
# migrate.sh - Run database migrations (idempotent)
# Usage: bash migrate.sh [--fresh]
#   --fresh  : Force full rebuild (runs 001 DROP/CREATE)
#   default  : Idempotent - skips 001 if core tables exist, runs seeds + 002-010

set -euo pipefail

CONTAINER="postgres_collections"
DB_USER="rtrlpz"
DB_NAME="MIS_CollectionsDB"
FORCE_FRESH="${1:-}"

echo "Running migrations${FORCE_FRESH:+ (--fresh mode)}..."

# Check if core dimension tables exist
TABLES_EXIST=$(docker exec "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -A -c "
    SELECT COUNT(*) FROM information_schema.tables
    WHERE table_schema='public' AND table_name IN ('dim_employees','dim_accounts','fact_interactions');
" | tr -d '[:space:]')

if [[ "$FORCE_FRESH" == "--fresh" ]] || [[ "$TABLES_EXIST" != "3" ]]; then
    echo "  Core tables missing or --fresh requested → running 001_create_tables.sql (full rebuild)"
    cat database/migrations/001_create_tables.sql | docker exec -i "$CONTAINER" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1
    echo "  [OK] 001_create_tables.sql"
else
    echo "  Core tables exist → skipping 001_create_tables.sql (idempotent mode)"
fi

# Always ensure etl_load_log exists (idempotent)
echo "  Creating etl_load_log table if not exists..."
docker exec "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -c "
CREATE TABLE IF NOT EXISTS etl_load_log (
    id SERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    rows_loaded INT,
    loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status TEXT,
    csv_checksum TEXT
);" >/dev/null 2>&1
echo "  [OK] etl_load_log table"

# Seeds (idempotent via ON CONFLICT DO NOTHING)
for f in database/seeds/001_dim_products.sql \
         database/seeds/002_dim_calendar.sql \
         database/seeds/003_dim_delinquency_bucket.sql \
         database/seeds/004_dim_calendar_extension.sql; do
    cat "$f" | docker exec -i "$CONTAINER" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1
    echo "  [OK] $(basename "$f")"
done

# Idempotent migrations: 003, 002, 004, 005, 006, 007-010
for f in database/migrations/003_constraints.sql \
         database/migrations/002_kpi_views.sql \
         database/migrations/004_agents_scorecards.sql \
         database/migrations/005_indexes.sql \
         database/migrations/006_comments.sql \
         database/migrations/007_remove_post_writeoff_snapshots.sql \
         database/migrations/008_dim_delinquency_bucket.sql \
         database/migrations/009_strategy_scd2.sql \
         database/migrations/010_fact_recoveries.sql; do
    cat "$f" | docker exec -i "$CONTAINER" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$DB_NAME" >/dev/null 2>&1
    echo "  [OK] $(basename "$f")"
done

# ── Post-migration assertion: all expected views must exist ─────────────────
EXPECTED_VIEWS=16
ACTUAL_VIEWS=$(docker exec "$CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -A -c \
  "SELECT COUNT(*) FROM pg_views WHERE schemaname='public' AND viewname LIKE 'v\\_%';" | tr -d '[:space:]')
if [[ "$ACTUAL_VIEWS" != "$EXPECTED_VIEWS" ]]; then
  echo "  [FAIL] Expected $EXPECTED_VIEWS views, found '$ACTUAL_VIEWS'. Migration drift detected."
  exit 1
fi
echo "  [OK] view count = $EXPECTED_VIEWS"

echo "Migrations complete."