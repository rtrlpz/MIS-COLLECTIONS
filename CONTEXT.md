# MIS-COLLECTIONS — Project Context

## Project Overview
Simulated bank collections analytics portfolio project. Generates synthetic data for ~80 agents, ~10,000 clients, ~20,000 accounts across Credit Cards, Personal Loans, and Mortgages (Oct–Dec 2025). Models the full collections lifecycle: dialer interactions, RPC tracking, promise-to-pay management, payment/cure events, and agent utilization.

**Goal:** Portfolio piece demonstrating end-to-end data engineering + analytics for a Scotiabank-style collections department.

## Tech Stack
- **Python 3.x** — Data generation (Faker), ETL ingestion (pandas, psycopg2)
- **PostgreSQL 15** — Dockerized database with pgAdmin
- **SQL** — KPI views, exploratory analysis
- **Power BI** — Collections dashboard (.pbix)
- **Excel** — Daily MIS report templates
- **Docker Compose** — Postgres + pgAdmin orchestration

## Directory Structure
```
MIS-COLLECTIONS/
├── .github/ISSUE_TEMPLATE/        # bug_report.md, feature_request.md
├── .gitignore
├── CONTEXT.md                     # THIS FILE — single-source project overview
├── LICENSE
├── README.md                      # Project overview & interview pitch
├── requirements.txt               # Python deps
├── run_pipeline.bat               # Windows batch to run full pipeline
│
├── analysis/                      # SQL ANALYSIS LAYER
│   ├── README.md
│   └── sql/
│       ├── agent_level_operational_supervisors/   # 6 files — agent-level ops
│       ├── team_level_tactical_managers/          # 6 files — team-level tactics
│       └── portfolio_level_strategic_directors/   # 5 files — portfolio strategy
│
├── dashboards/                    # VISUALIZATION LAYER
│   ├── assets/
│   │   ├── reference_guide.html   # Business guide (994 lines)
│   │   └── screenshots/architecture_diagram.svg
│   └── dax_measures_dictionary.md # Exported DAX formulas
│
├── data_sources/                  # DATA GENERATION LAYER
│   ├── README.md
│   ├── generators/
│   │   └── data_generator_v7.py   # Star schema generator (810 lines)
│   └── schema/
│       └── dictionary.md          # Column-level docs for all tables
│
├── database/                      # DATABASE LAYER
│   ├── README.md
│   ├── docker-compose.yml         # Postgres 15 + pgAdmin services
│   ├── etl/
│   │   └── data_to_pg_V2.py       # ETL: CSV → PostgreSQL via COPY FROM
│   ├── migrations/
│   │   ├── 001_create_tables.sql  # DDL: 11 tables with FK constraints
│   │   ├── 002_kpi_views.sql      # PENDING — KPI view definitions
│   │   └── 003_agents_scorecards.sql  # PENDING — agent scorecard view
│   └── seeds/                     # Static lookup data (products, calendar)
│       └── README.md
│
├── docs/                          # DOCUMENTATION LAYER
│   ├── data_dictionary.md         # Full data dictionary (10 tables)
│   ├── executive_summary.md       # One-page summary for leadership
│   └── kpi_definitions.md         # Comprehensive KPI reference (319 lines)
│
├── reports/                       # EXCEL REPORTING LAYER
│   ├── templates/daily_mis.xlsx   # Daily MIS template
│   └── output/                    # Generated reports (git-ignored)
│
└── test/                          # TESTING LAYER
    ├── README.md
    ├── __init__.py
    ├── qa_validation.py           # PENDING — data integrity checks
    ├── test_generator.py          # PENDING — generator unit tests
    └── test_kpi_views.sql         # PENDING — KPI view tests
```

## Data Model (Star Schema)

### Dimension Tables (6)
| Table | Rows | Description |
|-------|------|-------------|
| Dim_Supervisors | 8 | Team leads with region, tenure, hire date |
| Dim_Agents | 80 | Agents with supervisor FK, region, hire date |
| Dim_Clients | 10,000 | Clients with region, risk score, segment |
| Dim_Products | 3 | Credit Card, Personal Loan, Mortgage |
| Dim_Accounts | ~20,000 | Accounts with product/client FK, balance, DPD |
| Dim_Calendar | ~365 | Date dimension with flags (weekday, month, quarter) |

### Fact Tables (5 per month)
| Table | Description |
|-------|-------------|
| Fact_Interactions | Dialer calls, RPC/non-RPC, connection flags |
| Fact_PTP_Log | Promise-to-pay events, state machine (kept/broken) |
| Fact_Payments | Payment transactions, cure events |
| Fact_Agent_Time_Log | Agent utilization, handle time, ACW |
| Fact_EOM_Snapshot | End-of-month account snapshots |

## Key Business Logic
- **Event-driven PTP state machine**: promises transition through scheduled → kept/broken
- **Payday seasonality**: payment probability spikes on specific days
- **DPD anchored to billing cycles**: days past due tied to account lifecycle
- **Agent-Cure vs Self-Cure**: distinguishes agent-driven recoveries from automatic payments
- **Weekday-only processing**: no collections activity on weekends
- **Anomaly injection**: realistic edge cases in the data
- **Mora replenishment**: accounts can re-enter delinquency

## KPI Framework
- **Contact**: Total connections, RPC, RPC%, RPC/Operating Hour, RPC Arrears
- **Promise**: PTP, PTP%, Kept, Broken, Kept%, Broken-to-Bucket conversion
- **Recovery**: Cures, Cured amount, Cures/Total Handle Time
- **Productivity**: Utilization%, No Touch Letter rate
- **Handle Time**: AHT-RPC, AHT-NonRPC, ACW-RPC, ACW-NonRPC

## Conventions
- Python scripts use `pandas` for data manipulation, `psycopg2` for DB connectivity
- SQL follows PostgreSQL dialect
- Table naming: `Dim_` prefix for dimensions, `Fact_` prefix for facts
- CSVs in `data_sources/raw_csv/` are generated, never manually edited
- Old/unused versions kept in `06_docs/unused/` (not tracked in repo)
- All documentation in Markdown or HTML

## Commands
```bash
# Generate data
python data_sources/generators/data_generator_v7.py

# Start database
docker-compose -f database/docker-compose.yml up -d

# Ingest data into PostgreSQL
python database/etl/data_to_pg_V2.py

# Create tables manually (if needed)
psql -h localhost -p 5433 -U rtrlpz -d MSI_CollectionsDB -f database/migrations/001_create_tables.sql

# Run full pipeline (Windows)
run_pipeline.bat
```

## Current State & Pending Work
- **DONE**: Project restructure, data generator (v7), PostgreSQL schema, ETL pipeline, supervisor EDA (moved to team-level), Power BI dashboard (binary, not tracked), Excel template, full documentation, issue templates, test scaffolding
- **PENDING**: KPI views (002), agent scorecard view (003), 17 analysis SQL files (all skeletoned), test implementations, data validation script, DAX export completion
- **EMPTY FILES** (skeletons awaiting content): All files under `analysis/sql/`, `database/migrations/002_`, `database/migrations/003_`, `test/test_generator.py`, `test/test_kpi_views.sql`, `test/qa_validation.py`

## Important Notes
- CSV data files are git-ignored (generated on demand)
- `.env` contains local DB credentials — never commit
- `.pbix` files are git-ignored (binary, large)
- Architecture diagram at `dashboards/assets/screenshots/architecture_diagram.svg`
- `analysis/sql/` is organized by audience: supervisors (operational), managers (tactical), directors (strategic)
- Database uses numbered migrations (001, 002, 003) for versioned schema changes
