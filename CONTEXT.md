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
├── README.md                          # Project overview & interview pitch
├── requirements.txt                   # Python deps (pandas, numpy, psycopg2, faker, python-dotenv)
├── .gitignore                         # Excludes CSVs, .pbix, .docx, .env, pgdata, generated files
│
├── 01_data_sources/                   # DATA GENERATION LAYER
│   ├── data_generator_v7.py           # Star schema generator (810 lines) — current version
│   ├── schema_dictionary_v7.md        # Column-level schema docs for all 6 dims + 5 facts
│   └── raw_csv/                       # GENERATED CSVs (git-ignored)
│       ├── shared/                    # 6 dimension tables (Dim_*)
│       ├── october_2025/              # 5 fact tables (Fact_*)
│       ├── november_2025/             # 5 fact tables
│       └── december_2025/             # 5 fact tables
│
├── 02_database/                       # DATABASE LAYER
│   ├── docker-compose.yml             # Postgres 15 + pgAdmin services
│   ├── .env                           # DB credentials (git-ignored in prod)
│   ├── data/                          # PostgreSQL data directory (git-ignored)
│   ├── init/01_create_tables.sql      # DDL: 11 tables with FK constraints
│   ├── data_to_pg.py                  # ETL: CSV → PostgreSQL via COPY FROM
│   └── kpi_views.sql                  # EMPTY — pending KPI view definitions
│
├── 03_sql_analysis/                   # ANALYSIS LAYER
│   ├── eda_supervisors.sql            # 464 lines — supervisor-level EDA queries (DONE)
│   ├── agents_monthly_scorecard.sql   # EMPTY — pending
│   ├── eda_agents.sql                 # EMPTY — pending
│   └── portofolio_health.sql          # EMPTY — pending
│
├── 04_dashboards/                     # VISUALIZATION LAYER
│   ├── collections_dashboard_v2.pbix  # Power BI dashboard (git-ignored)
│   ├── screenshots/
│   │   └── architecture_diagram.svg   # System architecture diagram
│   └── docs/                          # DAX docs, requirements (git-ignored)
│
├── 05_excel_reports/                  # EXCEL REPORTING LAYER
│   ├── daily_mis_template.xlsx        # Daily MIS template
│   └── sample_output_oct2025.xlsx     # Sample output (git-ignored)
│
├── 06_docs/                           # DOCUMENTATION LAYER
│   ├── data_dictionary.md             # Full data dictionary (10 tables)
│   ├── kpi_definitions.md             # Comprehensive KPI reference
│   └── unused/                        # ARCHIVE — old versions, test files, templates
│       ├── data_generator_v1–v6.py    # Previous generator iterations
│       ├── estructura.md              # Original data structure spec
│       ├── prueba-tecnica.sql         # 30 SQL test questions
│       ├── Prueba-Tecnia/             # Technical test answers + data
│       ├── scripts/                   # Utility scripts (emf_to_svg, old generators)
│       ├── dashboard_templates/       # Power BI theme JSON, ~330 icons
│       ├── general_docs/              # PDFs, Excel files, glossaries
│       └── [PDFs, Word docs, resumes] # Reference materials
│
└── 07_interview_prep/                 # INTERVIEW PREPARATION
    ├── mis_collections_business_guide.html  # Full BI guide (994 lines, polished)
    ├── sql_cheatsheet.md              # EMPTY — pending
    └── talking_points.md              # EMPTY — pending
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
- CSVs in `raw_csv/` are generated, never manually edited
- Old/unused versions kept in `06_docs/unused/` for reference
- All documentation in Markdown or HTML

## Commands
```bash
# Generate data
python 01_data_sources/data_generator_v7.py

# Start database
docker-compose -f 02_database/docker-compose.yml up -d

# Ingest data into PostgreSQL
python 02_database/data_to_pg.py

# Create tables manually (if needed)
psql -h localhost -p 5433 -U rtrlpz -d MSI_CollectionsDB -f 02_database/init/01_create_tables.sql
```

## Current State & Pending Work
- **DONE**: Data generator (v7), PostgreSQL schema, ETL pipeline, supervisor EDA, Power BI dashboard, Excel template, full documentation, interview prep guide
- **PENDING**: KPI views, agent scorecard, agent EDA, portfolio health analysis, SQL cheatsheet, talking points
- **EMPTY FILES** (intentionally blank, awaiting content): `kpi_views.sql`, `agents_monthly_scorecard.sql`, `eda_agents.sql`, `portofolio_health.sql`, `sql_cheatsheet.md`, `talking_points.md`

## Important Notes
- CSV data files are git-ignored (generated on demand)
- `.env` contains local DB credentials — never commit
- `.pbix` files are git-ignored (binary, large)
- `06_docs/unused/` contains archive of 6+ generator iterations and technical test materials
- Architecture diagram at `04_dashboards/screenshots/architecture_diagram.svg` shows full data flow
