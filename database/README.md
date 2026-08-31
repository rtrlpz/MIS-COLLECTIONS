# Database Layer — PostgreSQL 15 + pgAdmin

This directory contains everything needed to spin up the collections data warehouse.

## Contents

| Path | Purpose |
|------|---------|
| `docker-compose.yml` | PostgreSQL 15 + pgAdmin (port 5433 / 8081) |
| `migrations/001_create_tables.sql` | DDL for 16 tables (8 dim + 7 fact + etl_load_log) |
| `migrations/002_kpi_views.sql` | 15 KPI views (contact, promise, recovery, etc.) |
| `migrations/003_constraints.sql` | 15 CHECK constraints |
| `migrations/004_agents_scorecards.sql` | `v_agent_scorecards` (composite weighted) |
| `migrations/005_indexes.sql` | 27 indexes |
| `migrations/006_comments.sql` | 63 COMMENT ON |
| `seeds/001_dim_products.sql` | 3 products (Tarjeta, Prestamo, Hipoteca) |
| `seeds/002_dim_calendar.sql` | 396 calendar rows (Dec 2024 + 2025) |

## Quick Start

```bash
# Run migrations (from project root)
bash database/migrate.sh
```

## Connection

| Field | Value |
|-------|-------|
| Host | localhost |
| Port | 5433 |
| Database | MIS_CollectionsDB |
| User | postgres |
| Password | (set in `.env`) |
| pgAdmin | http://localhost:8081 |

See project root `docs/QUICKSTART.md` for full setup instructions.
