#!/bin/bash
# migrate.sh - Run all database migrations
# Called from run_pipeline.bat

set -e

echo "Running migrations..."

# Ensure etl_load_log table exists
echo "  Creating etl_load_log table if not exists..."
docker exec postgres_collections psql -U rtrlpz -d MSI_CollectionsDB -c "
CREATE TABLE IF NOT EXISTS etl_load_log (
    id SERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    rows_loaded INT,
    loaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status TEXT,
    csv_checksum TEXT
);" >/dev/null 2>&1
echo "  [OK] etl_load_log table"

# Run each SQL file
cat database/migrations/001_create_tables.sql | docker exec -i postgres_collections psql -v ON_ERROR_STOP=1 -U rtrlpz -d MSI_CollectionsDB >/dev/null 2>&1
echo "  [OK] 001_create_tables.sql"

cat database/seeds/001_dim_products.sql | docker exec -i postgres_collections psql -v ON_ERROR_STOP=1 -U rtrlpz -d MSI_CollectionsDB >/dev/null 2>&1
echo "  [OK] 001_dim_products.sql"

cat database/seeds/002_dim_calendar.sql | docker exec -i postgres_collections psql -v ON_ERROR_STOP=1 -U rtrlpz -d MSI_CollectionsDB >/dev/null 2>&1
echo "  [OK] 002_dim_calendar.sql"

cat database/migrations/003_constraints.sql | docker exec -i postgres_collections psql -v ON_ERROR_STOP=1 -U rtrlpz -d MSI_CollectionsDB >/dev/null 2>&1
echo "  [OK] 003_constraints.sql"

cat database/migrations/004_agents_scorecards.sql | docker exec -i postgres_collections psql -v ON_ERROR_STOP=1 -U rtrlpz -d MSI_CollectionsDB >/dev/null 2>&1
echo "  [OK] 004_agents_scorecards.sql"

cat database/migrations/005_indexes.sql | docker exec -i postgres_collections psql -v ON_ERROR_STOP=1 -U rtrlpz -d MSI_CollectionsDB >/dev/null 2>&1
echo "  [OK] 005_indexes.sql"

cat database/migrations/006_comments.sql | docker exec -i postgres_collections psql -v ON_ERROR_STOP=1 -U rtrlpz -d MSI_CollectionsDB >/dev/null 2>&1
echo "  [OK] 006_comments.sql"

cat database/migrations/002_kpi_views.sql | docker exec -i postgres_collections psql -v ON_ERROR_STOP=1 -U rtrlpz -d MSI_CollectionsDB >/dev/null 2>&1
echo "  [OK] 002_kpi_views.sql"

echo "Migrations complete."
