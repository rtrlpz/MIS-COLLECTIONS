# MSI Collections — Enterprise Power BI Execution Guide

> ⚠️ **HISTORICAL SNAPSHOT (v1.0, pre-P3/P4).** Table/measure counts below reflect an earlier schema era (e.g., "11 tables", "70+ measures"). Current truth: **16 tables (8 dim + 7 fact + etl_load_log), 252 DAX measures + `_Time Intelligence` calculation group** — see `AGENTS.md`, `docs/CHANGELOG.md` 1.6.0 and `docs/dashboards/dashboard_blueprint.md` for the build. Architecture patterns and DAX techniques remain valid; numbers do not.

> **Document Type:** Architecture + Implementation Playbook
> **Target Audience:** Intermediate Power BI Developer, Analytics Engineer, Data Engineering Student
> **Domain:** Banking Collections & Recovery Analytics
> **Stack:** Power BI · PostgreSQL · Python · openpyxl · Docker
> **Version:** 1.0

---

## Table of Contents

1. [Project Vision & Architecture](#1-project-vision--architecture)
2. [Enterprise Folder Structure](#2-enterprise-folder-structure)
3. [Data Modeling Execution Guide](#3-data-modeling-execution-guide)
4. [KPI Framework & Metric Definitions](#4-kpi-framework--metric-definitions)
5. [DAX Development Standards](#5-dax-development-standards)
6. [Dashboard Page-by-Page Build Guide](#6-dashboard-page-by-page-build-guide)
7. [Visualization Selection Framework](#7-visualization-selection-framework)
8. [Power BI UX/UI Standards](#8-power-bi-uxui-standards)
9. [Performance Optimization Guide](#9-performance-optimization-guide)
10. [Security & Governance](#10-security--governance)
11. [Deployment Workflow](#11-deployment-workflow)
12. [Portfolio Presentation Strategy](#12-portfolio-presentation-strategy)
13. [Final Enterprise Checklist](#13-final-enterprise-checklist)

---

# 1. Project Vision & Architecture

## 1.1 Business Objectives

A collections department in a financial institution has three core analytic needs, each mapped to a different decision-making level:

| Layer | Audience | Question | Decision Cycle | Refresh |
|---|---|---|---|---|
| **Strategic** | VP / Director | "Is the portfolio healthy and trends improving?" | Weekly / Monthly | Daily |
| **Tactical** | Manager / Analyst | "Which teams are underperforming and why?" | Daily / Weekly | Daily |
| **Operational** | Supervisor | "Who is below target and needs coaching now?" | Hourly / Daily | Daily |

The single-source-of-truth principle dictates that all three layers query the same star-schema model. A director's portfolio total arrears number must match the supervisor's view of their team's arrears — filtered, not recalculated.

## 1.2 Stakeholder Map

```
Stakeholder          Layer        Consumes                 Decisions Made
──────────────────────────────────────────────────────────────────────────
VP Collections       Strategic    Page 1 (Executive)       Strategy, headcount budget
Director Recovery    Strategic    Page 1, Page 4           Portfolio risk appetite
Collections Manager  Tactical     Page 3, Page 4, Page 5   Team allocation, coaching
Recovery Analyst     Tactical     Page 5                   Promise quality, funnel
Team Supervisor      Operational  Page 2, Page 3           Agent coaching, daily huddle
Agent                Operational  Page 2 (self-view)       Self-performance awareness
Compliance Officer   Governance   All pages                Audit, regulatory reporting
```

## 1.3 The Three-Layer Model — Why It Matters

```
                    ┌─────────────────────────────────────┐
                    │         STRATEGIC (Page 1)           │
                    │  7-9 visuals · 4 KPI cards · 1 trend │
                    │ · 1 funnel · 1 treemap · 1 waterfall │
                    │  Cognitive load: LOW (5-second scan) │
                    │  Information density: 30-40%         │
                    ├─────────────────────────────────────┤
                    │        TACTICAL (Pages 3-5)          │
                    │  9-12 visuals · comparative layouts  │
                    │  Matrices · scatter · sankey · heat   │
                    │  Cognitive load: MEDIUM               │
                    │  Information density: 50-60%          │
                    ├─────────────────────────────────────┤
                    │       OPERATIONAL (Page 2)            │
                    │  Tables · conditional formatting     │
                    │  Gauges · coaching alerts            │
                    │  Cognitive load: HIGH (action-driven) │
                    │  Information density: 70-80%          │
                    └─────────────────────────────────────┘
```

The pyramid works because each layer adds detail and removes aggregation. An executive sees "KP% is 62%." A supervisor sees "Agent Smith's KP% dropped from 68% to 51% this week — coach on objection handling."

## 1.4 Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       DATA GENERATION (Python)                           │
│  data_generator_v7.py → raw CSVs in data_sources/raw/        │
│    6 dim tables + 5 fact tables + 1 anomaly report                      │
│    Oct-Dec 2025 synthetic data, ~500K interactions, ~31K PTPs, ~21K pays│
└─────────────────────────┬───────────────────────────────────────────────┘
                          │ pandas.read_csv()
                          ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         ETL LAYER (data_to_pg.py)                        │
│  Reads CSVs → truncates PostgreSQL staging → COPY via psycopg2          │
│  3-month split, FK validation, error quarantine to etl/errors/          │
└─────────────────────────┬───────────────────────────────────────────────┘
                          │ PostgreSQL connection
                          ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                   DATABASE (PostgreSQL 15, Docker)                       │
│  Star schema: 6 dim + 5 fact tables                                     │
│  9 KPI views: v_contact_metrics, v_promise_metrics, v_recovery_metrics, │
│  v_productivity_metrics, v_handle_time_metrics, v_daily_mis,            │
│  v_monthly_summary, v_etl_load_summary, v_data_freshness                │
└─────────────────────────┬───────────────────────────────────────────────┘
                          │ Power BI Import (ODBC / Npgsql)
                          ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              POWER BI — SINGLE PBIX (Import Mode)                        │
│  11 tables → star schema model → 3 measure tables → 70+ measures        │
│  5 pages: Executive · Agent Scorecard · Team · Portfolio · Promise      │
│  RLS: TeamLead role filters by supervisor_id                            │
└─────────────────────────┬───────────────────────────────────────────────┘
                          │ Python (openpyxl) reads v_daily_mis
                          ▼
┌─────────────────────────────────────────────────────────────────────────┐
│               EXCEL MIS REPORT (Daily attachment)                        │
│  Sheet 1: KPI dashboard · Sheet 2: Agent deep dive · Sheet 3: Notes     │
│  Triggered after ETL completes in run_pipeline.bat                      │
└─────────────────────────────────────────────────────────────────────────┘
```

## 1.5 Enterprise Dashboard Philosophy

Five principles govern every design decision in this project:

1. **Single source of truth.** Every number on every page derives from the same underlying model. No disconnected Excel tables, no manual adjustments, no copy-paste.

2. **Filter, don't recalculate.** Strategic and operational views differ only by filter context. The measure `[Total Arrears]` is the same DAX expression everywhere — the page filter changes what it sums.

3. **The 5-second rule.** A stakeholder must understand the page's key message within 5 seconds. If they need to read axis labels or hunt for context, the layout fails.

4. **Explicit thresholds.** Every KPI has a target and a RAG (Red/Amber/Green) band. Numbers without context are noise. `62%` means nothing; `62% vs 65% target (Amber)` drives action.

5. **Mobile-ready, presentation-ready.** All pages render legibly on a 13" laptop screen and can be projected in a conference room. Tooltips carry the details, not the canvas.

## 1.6 BI Maturity Model — Target State

| Level | Description | Current | Target |
|---|---|---|---|
| Level 1 | Raw data, no reporting | — | — |
| Level 2 | Static PDFs, manual Excel | ❌ | ✅ eliminated |
| Level 3 | Single-source dashboards | Partial | ✅ star schema, single PBIX |
| Level 4 | Self-service with governance | ❌ | ✅ RLS, certified datasets |
| Level 5 | Embedded AI / ML-driven insights | ❌ | Future state |

---

# 2. Enterprise Folder Structure

## 2.1 Recommended Repository Layout

```
msi-collections/
│
├── .github/
│   └── workflows/              # CI/CD pipeline definitions (future)
│       └── deploy.yml
│
├── data_sources/               # Raw data generation layer
│   ├── data_generator_v7.py       # Main generator engine
│   ├── config.py                  # Constants, product config
│   ├── raw/                       # Generated CSVs (gitignored output)
│   │   ├── shared/                # Dimension tables
│   │   ├── january_2025/
│   │   ├── ...
│   │   └── december_2025/
│   ├── logs/                      # Generator execution logs
│   └── README.md
│
├── etl/                         # Extract-Transform-Load
│   ├── data_to_pg.py            # CSV → PostgreSQL ingestion
│   ├── errors/                  # FK-violation quarantined rows
│   └── logs/                    # ETL run logs
│
├── database/                    # Database layer
│   ├── docker-compose.yml       # PostgreSQL + pgAdmin containers
│   ├── migrations/
│   │   ├── 001_create_tables.sql     # Star schema DDL
│   │   ├── 002_kpi_views.sql         # 9 KPI view definitions
│   │   ├── 003_constraints.sql       # FK, unique, check constraints
│   │   ├── 004_agents_scorecards.sql # Composite scoring view
│   │   ├── 005_indexes.sql           # Performance indexes
│   │   └── 006_comments.sql          # Column documentation
│   ├── seeds/
│   │   ├── 001_dim_products.sql      # Product reference data
│   │   └── 002_dim_calendar.sql      # Full year calendar
│   └── scripts/
│       ├── healthcheck.sql            # DB readiness check
│       └── data_freshness.sql         # Staleness query
│
├── analysis/                    # SQL analysis (exploration)
│   └── sql/
│       ├── agent_level_operational_supervisors/
│       │   ├── individual_performance.sql
│       │   └── schedule_adherence.sql
│       ├── team_level_tactical_managers/
│       │   ├── team_comparison.sql
│       │   └── productivity_trends.sql
│       └── portfolio_level_strategic_directors/
│           ├── portfolio_health.sql
│           └── risk_trends.sql
│
├── dashboards/                  # Power BI & report assets
│   ├── pbix/
│   │   ├── collections_dashboard_v3.pbix # Main deliverable
│   │   └── collections_dashboard_v4.pbix # Legacy (reference only)
│   ├── assets/
│   │   ├── mis_collections_build_plan.md
│   │   ├── reference_guide.html     # DAX reference + dashboard guide
│   │   └── wireframes/              # Page mockups (PNG/SVG)
│   ├── themes/
│   │   └── collections_theme.json   # Corporate theme file
│   └── templates/
│       └── page_template.pbit       # Reusable page template
│
├── reports/                     # Excel generation
│   ├── generate_daily_mis.py    # Python openpyxl script
│   ├── output/                  # Generated .xlsx files (gitignored)
│   └── templates/
│       └── daily_mis_template.xlsx   # Styling template
│
├── dax/                         # DAX source control
│   ├── _contact_and_volume.dax
│   ├── _promise_and_recovery.dax
│   └── _portfolio_and_trends.dax
│
├── docs/                        # Documentation
│   ├── QUICKSTART.md                # 5-minute setup guide
│   ├── TROUBLESHOOTING.md           # Docker/ETL error resolution
│   ├── KPI_VIEWS.md                 # View documentation
│   ├── kpi_definitions.md           # Business formula reference
│   ├── data_dictionary.md           # Column-level metadata
│   ├── executive_summary.md         # One-pager for stakeholders
│   ├── ROADMAP.md                   # Phase-based project tracker
│   ├── CONTEXT.md                   # Project context
│   ├── CHANGELOG.md                 # Version history
│   ├── setup/
│   │   ├── docker_setup.md
│   │   └── power_bi_gateway.md
│   └── interviews/                  # Case study prep
│
├── test/                        # QA validation
│   ├── test_qa_validation.py    # 11+ test classes
│   ├── test_generator.py       # Reproducibility tests
│   └── conftest.py             # Pytest fixtures (DB connection)
│
├── security/                    # RLS configuration
│   └── rls_test_users.csv       # Test mapping for RLS verification
│
├── .env                         # Database credentials (gitignored)
├── .gitignore
├── AGENTS.md                     # AI-agent context
├── database/migrate.sh           # DB migration script
└── run_pipeline.bat             # End-to-end execution
```

## 2.2 Naming Conventions

| Artifact | Convention | Example |
|---|---|---|
| SQL tables | `snake_case`, Dim_/Fact_ prefix | `dim_agents`, `fact_interactions` |
| SQL views | `v_` prefix | `v_daily_mis`, `v_monthly_summary` |
| DAX measure tables | `_Category Name` | `_Contact & Volume` |
| DAX measures | `Pascal Case` | `[Total Arrears]`, `[KP %]` |
| PBIX files | `descriptive_name.pbix` | `collections_dashboard.pbix` |
| CSV files | `Pascal Case` | `Dim_Accounts.csv` |
| Python files | `snake_case` | `data_generator_v7.py` |
| SQL files | `NNN_description.sql` | `001_create_tables.sql` |

## 2.3 Versioning Strategy

- **PBIX files:** `name_v{MAJOR}.{MINOR}.pbix`. Bump MAJOR for schema changes, MINOR for visual/measure additions.
- **Generator scripts:** `data_generator_v{MAJOR}.py`. Bump when the simulation engine changes (e.g., v7 → v8 adds a new PTP state machine).
- **SQL migrations:** Sequential `NNN_description.sql`. Never reorder. Never edit a committed migration — create a new one.
- **DAX source control:** One `.dax` file per measure table. Export from Tabular Editor, commit alongside PBIX changes.

## 2.4 GitHub Best Practices

- **Branch strategy:** `main` → `develop` → `feature/*`. Never commit directly to main.
- **Commit messages:** `type(scope): description`. Examples:
  - `feat(dax): add MoM KP% measure with DATEADD pattern`
  - `fix(model): correct fact_payments relationship cardinality`
  - `docs(execution-guide): add DAX branching strategy section`
  - `refactor(etl): consolidate error quarantine logic`
- **PR checklist:** Every PR must include: 1) What changed, 2) Why, 3) Verification steps, 4) Screenshots for visual changes.
- **Large files:** PBIX files >50MB should use Git LFS. Otherwise, accept that binary diffs are opaque — rely on commit messages.

---

# 3. Data Modeling Execution Guide

## 3.1 Star Schema Architecture

Power BI performance is directly proportional to model design quality. A star schema is non-negotiable for enterprise BI.

### 3.1.1 Schema Diagram

```
┌──────────────────┐     ┌───────────────────┐
│  Dim_Supervisors │     │  Dim_Calendar      │
│  supervisor_id   │◄────┤  date (PK)         │
│  supervisor_name │     │  year              │
│  team_name       │     │  month_num         │
│  region          │     │  is_weekday        │
└────────┬─────────┘     │  is_month_end      │
         │               └────────┬───────────┘
         │                        │
         ▼                        ▼
┌──────────────────┐     ┌───────────────────┐
│  Dim_Agents      │     │  Fact_Interactions  │
│  agent_id (PK)   │────►│  interaction_id PK  │
│  agent_name      │     │  interaction_date FK│←──── Dim_Calendar
│  supervisor_id FK│──┘  │  agent_id FK        │←──── Dim_Agents
│  tenure_cohort   │     │  account_id FK      │←──── Dim_Accounts
│  contact_skill   │     │                     │
│  negotiation_…   │     │                     │
│  efficiency_…    │     │                     │
└──────────────────┘     │  calls_attempted    │
         │               │  rpc_flag           │
         │               │  aht_seconds        │
         ▼               └─────────────────────┘
┌──────────────────┐     ┌───────────────────┐
│  Dim_Accounts    │     │  Fact_PTP_Log       │
│  account_id (PK) │────►│  ptp_id PK          │
│  client_id FK    │──┐  │  ptp_date FK        │←──── Dim_Calendar
│  product_id FK   │─┐│  │  agent_id FK        │←──── Dim_Agents
│  open_date       │ ││  │  account_id FK      │←──── Dim_Accounts
│  due_day         │ ││  │  promised_amount    │
│  initial_balance │ ││  │  status             │
└──────────────────┘ ││  └─────────────────────┘
         │            ││
         ▼            ▼▼  ┌───────────────────┐
┌──────────────────┐     │  Fact_Payments      │
│  Dim_Clients     │     │  payment_id PK      │
│  client_id (PK)  │◄────┤  payment_date FK    │←──── Dim_Calendar
│  full_name       │     │  account_id FK      │←──── Dim_Accounts
│  segment         │     │  agent_id FK        │←──── Dim_Agents
│  risk_score      │     │  ptp_id FK          │←──── Fact_PTP_Log
└──────────────────┘     │  amount_paid        │
         │               │  cure_flag          │
         ▼               └─────────────────────┘
┌──────────────────┐     ┌───────────────────┐
│  Dim_Products    │     │  Fact_Agent_Time_Log│
│  product_id (PK) │────►│  log_id PK          │
│  product_name    │     │  log_date FK        │←──── Dim_Calendar
│  product_type    │     │  agent_id FK        │←──── Dim_Agents
│  annual_rate_pct │     │  operational_hours  │
│  grace_days      │     │  tht_hours          │
└──────────────────┘     │  utilization        │
                          └─────────────────────┘

┌─────────────────────────────────────────────────┐
│  Fact_EOM_Snapshot                               │
│  snapshot_date FK (← Dim_Calendar)               │
│  account_id FK (← Dim_Accounts)                   │
│  status, balance, arrears, dpd, dpd_bucket       │
│  ─── composite key: (snapshot_date, account_id)  │
└─────────────────────────────────────────────────┘
```

### 3.1.2 Table Details

**Dimension Tables:**

| Table | Rows | Grain | Primary Key |
|---|---|---|---|
| Dim_Supervisors | 8 | One supervisor | supervisor_id |
| Dim_Agents | 80 | One agent | agent_id |
| Dim_Clients | 10,000 | One client | client_id |
| Dim_Products | 3 | One product | product_id |
| Dim_Accounts | ~15,575 | One account (per product per client) | account_id |
| Dim_Calendar | 92 (or 365) | One day | date |

**Fact Tables:**

| Table | Rows | Grain | Fact Type |
|---|---|---|---|
| Fact_Interactions | ~480K | One call attempt per agent per account per day | Transactional |
| Fact_PTP_Log | ~31K | One promise created | Transactional |
| Fact_Payments | ~21K | One payment event | Transactional |
| Fact_Agent_Time_Log | ~5K | One agent shift per day | Periodic snapshot |
| Fact_EOM_Snapshot | ~47K (3 months × ~15.5K accounts) | One account per month | Periodic snapshot |

## 3.2 Relationship Strategy

### 3.2.1 Cardinality & Cross-Filter Direction

```
Relationship                          Cardinality  Cross-Filter     Active?
──────────────────────────────────────────────────────────────────────────
Dim_Supervisors → Dim_Agents          1:*          Single (Dim→Fact)  Yes
Dim_Agents → Fact_Interactions         1:*          Single            Yes
Dim_Agents → Fact_PTP_Log              1:*          Single            Yes
Dim_Agents → Fact_Payments             1:*          Single            Yes
Dim_Agents → Fact_Agent_Time_Log       1:*          Single            Yes
Dim_Accounts → Fact_Interactions       1:*          Single            Yes
Dim_Accounts → Fact_PTP_Log            1:*          Single            Yes
Dim_Accounts → Fact_Payments           1:*          Single            Yes
Dim_Accounts → Fact_EOM_Snapshot       1:*          Single            Yes
Dim_Clients → Dim_Accounts             1:*          Single            Yes
Dim_Products → Dim_Accounts            1:*          Single            Yes
Dim_Calendar → Fact_Interactions       1:*          Single            Yes
Dim_Calendar → Fact_PTP_Log            1:*          Single            Yes
Dim_Calendar → Fact_Payments           1:*          Single            Yes
Dim_Calendar → Fact_Agent_Time_Log     1:*          Single            Yes
Dim_Calendar → Fact_EOM_Snapshot       1:*          Single            Yes
Fact_PTP_Log → Fact_Payments           1:*          Single            Yes
```

**Rule:** All relationships use **Single direction** (dimension → fact). Bidirectional cross-filtering is almost never needed in a star schema and causes ambiguous filter context errors. The only exception is `Fact_PTP_Log → Fact_Payments` (also single direction) for PTP-to-payment drillthrough.

### 3.2.2 Why Snowflake Schemas Are Dangerous in Power BI

A snowflake schema normalizes dimensions into sub-dimensions. For example:

```
Dim_Agents → Dim_Supervisors (normalized)
```

In Power BI, this creates:
- **Performance penalty:** Each additional table hop requires a separate storage engine scan
- **Filter propagation ambiguity:** CALCULATE + ALL() behaves unexpectedly across chained relationships
- **User confusion:** The field list becomes deeper and harder to navigate

**Fix:** Denormalize into the dimension. `Dim_Agents` should contain `supervisor_name`, `team_name`, and `region` directly — not a foreign key to `Dim_Supervisors` that requires an extra join. Yes, this duplicates data. No, that does not matter in Power BI (VertiPaq compresses it to near-zero cost). Yes, it dramatically simplifies DAX.

In this project, `Dim_Supervisors` is kept as a separate table ONLY because it's a natural dimension with its own attributes (team, region). It does NOT create a snowflake since it's 8 rows and sits at the same logical level as `Dim_Agents`. The relationship `Dim_Supervisors → Dim_Agents` is the only allowed "extra hop" — and it exists to support RLS filtering at the supervisor level.

## 3.3 Surrogate Keys

Every dimension table uses a **meaningful surrogate key** (not the natural business key):

```
supervisor_id = "SUP-01"   (not "John Smith")
agent_id      = "EID-001"  (not employee email)
account_id    = "ACC-00001" (not account number)
```

Why surrogates:
- **Stability:** If an agent's name changes, the key stays the same. Relationships don't break.
- **Performance:** Integer or fixed-width string keys sort and compress better than long text keys.
- **Traceability:** The `SUP-` / `EID-` / `ACC-` prefix tells you which table the key belongs to at a glance.

**Anti-pattern:** Using `Dim_Calendar[date]` as a DATE type key is fine — dates are naturally surrogate-like and VertiPaq handles them efficiently. Do NOT use `YYYYMMDD` integers unless you have a specific reason.

## 3.4 Slowly Changing Dimensions (SCD)

This synthetic project uses **Type 0** (retrospective data — no changes over time). In a production banking environment:

| SCD Type | Strategy | Example |
|---|---|---|
| Type 0 | Retain original | Date of birth, open date |
| Type 1 | Overwrite | Agent skill score, team reorg |
| Type 2 | Add new row | Product APR change, grace period change |

For Type 2, add `valid_from` and `valid_to` columns to the dimension, then use a filter like:
```
Dim_Product[valid_from] <= MAX(Fact_Payments[payment_date])
    AND Dim_Product[valid_to] >= MIN(Fact_Payments[payment_date])
```

## 3.5 Grain Definition

The grain of a fact table is the "one row equals one ..." statement. Getting this wrong produces incorrect counts.

| Fact Table | Grain | Check |
|---|---|---|
| Fact_Interactions | One call attempt chain per agent per account per day | `COUNT(DISTINCT interaction_id)` vs agent × account × date combinations |
| Fact_PTP_Log | One promise created | Every PTP has a unique `ptp_id` |
| Fact_Payments | One payment event | One payment may cure multiple arrears months |
| Fact_Agent_Time_Log | One agent shift per day | Every agent has exactly one row per workday |
| Fact_EOM_Snapshot | One account per month | `(snapshot_date, account_id)` is unique |

## 3.6 Data Normalization vs Denormalization

**Rule of thumb for Power BI:** Denormalize into dimensions. Normalize in the source database. Power BI's VertiPaq engine compresses repeated values so well that storing `supervisor_name` in `Dim_Agents` adds <1KB but saves a relationship hop.

**When to keep tables separate:**
- Different granularities (e.g., one supervisor has many agents → different grain)
- Security boundaries (e.g., RLS filters `Dim_Supervisors`, which then filters `Dim_Agents`)
- Large text columns that would bloat a dimension (e.g., client address → keep in Dim_Clients)

## 3.7 Modeling Checklist

- [ ] Every fact table has a surrogate primary key
- [ ] Every dimension has a primary key
- [ ] Every foreign key has a matching primary key
- [ ] All relationships are single-direction (dim → fact)
- [ ] No bidirectional filters unless absolutely necessary
- [ ] Date columns are DATE data type, not string
- [ ] Numeric columns are DECIMAL or INTEGER, not string
- [ ] Boolean columns are TRUE/FALSE, not "Yes"/"No"
- [ ] Text columns that will be filtered have high cardinality < 100K distinct values
- [ ] Columns not used in measures or visuals are disabled (View → Column Tools → Disable)
- [ ] Date table is marked as "Date table" (Table tools → Mark as date table)
- [ ] Snowflake normalized tables are either denormalized or merged into the main dimension

---

# 4. KPI Framework & Metric Definitions

## 4.1 What Makes a Good KPI

A KPI must satisfy four criteria:
1. **Measurable** — can be computed from the data model
2. **Actionable** — someone can change the outcome
3. **Benchmarked** — has a target or threshold
4. **Timely** — available at the decision cadence

## 4.2 KPI Categorization

```
Leading (predictive) vs Lagging (historical)

                    LEADING                           LAGGING
                    ───────────────────────────────────────────────────
Operational         RPC Rate, PTP%                   Cure Rate, KP%
                    Utilization %                     Avg Handle Time
                    Contacts per Hour                 

Strategic           PTP Count (early warning)         Portfolio Arrears
                    Promise Volume                    Mora Rate
                                                      Roll Rate (90+)
```

**Why this matters:** Operational dashboards should emphasize leading indicators (RPC% → coaching affects this today). Strategic dashboards should emphasize lagging indicators (Mora Rate → reflects decisions made last quarter).

## 4.3 KPI Definitions

Each KPI below follows this structure:
- **Business Definition:** Plain English
- **Formula:** Logical expression
- **DAX Pattern:** Template code
- **Thresholds / RAG:** Green/Amber/Red ranges
- **Best Visual:** Recommended chart type
- **Common Mistake:** What to avoid

---

### 4.3.1 RPC Rate (Right Party Contact)

| Field | Value |
|---|---|
| **Definition** | Percentage of call attempts where the agent spoke to the account holder or a decision-maker |
| **Formula** | `SUM(RPCs) / SUM(Calls Connected)` |
| **DAX** | `RPC Rate = DIVIDE([Total RPCs], [Total Connected])` |
| **Thresholds** | Green ≥ 65%, Amber 55-64%, Red < 55% |
| **Visual** | KPI card with trend sparkline; gauge for individual agents |
| **Common Mistake** | Dividing by total attempts, not connected calls. RPC% = RPCs ÷ *connected* calls. |
| **Business Impact** | Low RPC% means agents aren't reaching debtors. Coaching on dial strategy and time-of-day calling. |
| **Interpretation** | RPC% below 50% suggests outdated contact data. RPC% above 80% with low PTP% suggests agents are reaching easy targets but not converting. |

**DAX:**
```dax
Total RPCs =
    COUNTROWS(
        FILTER(
            Fact_Interactions,
            Fact_Interactions[rpc_flag] = TRUE()
        )
    )

Total Connected =
    COUNTROWS(
        FILTER(
            Fact_Interactions,
            Fact_Interactions[calls_connected] > 0
        )
    )

RPC Rate =
    DIVIDE(
        [Total RPCs],
        [Total Connected],
        0
    )
```

---

### 4.3.2 Promise Rate (PTP%)

| Field | Value |
|---|---|
| **Definition** | Percentage of RPCs where the customer makes a promise to pay |
| **Formula** | `COUNT(PTPs) / COUNT(RPCs)` |
| **DAX** | `Promise Rate = DIVIDE([Total PTPs], [Total RPCs])` |
| **Thresholds** | Green ≥ 50%, Amber 40-49%, Red < 40% |
| **Visual** | KPI card, bar chart by agent/team |
| **Common Mistake** | Counting pending PTPs (unresolved) in the numerator. Only count PTPs where the outcome is resolved. |
| **Business Impact** | PTP% below 40% indicates agents aren't closing promises. Coaching on objection handling and payment solutions. |

**DAX:**
```dax
Total PTPs =
    COUNTROWS(Fact_PTP_Log)

Promise Rate =
    DIVIDE(
        [Total PTPs],
        [Total RPCs],
        0
    )
```

---

### 4.3.3 Kept Promise Rate (KP%)

| Field | Value |
|---|---|
| **Definition** | Percentage of promises-to-pay that result in a successful payment within the grace period |
| **Formula** | `COUNT(Kept PTPs) / COUNT(Resolved PTPs)` |
| **DAX** | `KP Rate = DIVIDE([Kept PTPs], [Resolved PTPs])` |
| **Thresholds** | Green ≥ 60%, Amber 50-59%, Red < 50% |
| **Visual** | KPI card, scatter plot (RPC% vs KP%) for team comparison |
| **Common Mistake** | Including Pending PTPs (grace period not expired) in the denominator. Filter to resolved (Kept + Broken) only. |
| **Business Impact** | This is the single most important collections KPI. Low KP% means promises are worthless. |

**DAX:**
```dax
Kept PTPs =
    COUNTROWS(
        FILTER(
            Fact_PTP_Log,
            Fact_PTP_Log[status] = "Kept"
        )
    )

Broken PTPs =
    COUNTROWS(
        FILTER(
            Fact_PTP_Log,
            Fact_PTP_Log[status] = "Broken"
        )
    )

Resolved PTPs = [Kept PTPs] + [Broken PTPs]

KP Rate =
    DIVIDE(
        [Kept PTPs],
        [Resolved PTPs],
        0
    )
```

---

### 4.3.4 Recovery Amount

| Field | Value |
|---|---|
| **Definition** | Total dollar amount collected from all payment sources |
| **Formula** | `SUM(Fact_Payments[amount_paid])` |
| **DAX** | `Total Recovery = SUM(Fact_Payments[amount_paid])` |
| **Thresholds** | Target set by management (e.g., $300K/month). Compare MoM. |
| **Visual** | Waterfall chart (by product/team), line chart (trend) |
| **Common Mistake** | Double-counting payments that span multiple months. Payment_date determines the period. |
| **Business Impact** | Direct revenue. Every $1 collected is $1 less in provisions. |

**DAX:**
```dax
Total Recovery =
    SUM(Fact_Payments[amount_paid])
```

---

### 4.3.5 Conversion Rate (BB — Broken-to-Kept)

| Field | Value |
|---|---|
| **Definition** | Percentage of customers who make a payment even after breaking their promise |
| **Formula** | Cures from accounts with broken PTPs / Total cures |
| **DAX** | Complex — requires counting accounts that have a payment after a broken PTP |
| **Thresholds** | Green ≥ 40%, Amber 30-39%, Red < 30% |
| **Visual** | Funnel chart: RPCs → PTPs → Kept → Cures |
| **Common Mistake** | Confusing BB Conversion Rate with KP%. KP% = promises kept. BB = broken promises that still cured. |
| **Business Impact** | High BB Conversion = collectors are persistent even after initial failure. |

---

### 4.3.6 Average Handle Time (AHT)

| Field | Value |
|---|---|
| **Definition** | Average duration of a connected call (talk time + after-call work) |
| **Formula** | `SUM(aht_seconds + acw_seconds) / COUNT(RPCs)` |
| **DAX** | `Avg Handle Time = DIVIDE(SUM(Fact_Interactions[aht_seconds]) + SUM(Fact_Interactions[acw_seconds]), [Total RPCs])` |
| **Thresholds** | Green 300-600s, Amber 600-900s or <300s, Red >900s |
| **Visual** | Box plot (team distribution), gauge (individual) |
| **Common Mistake** | Including non-connected calls (0 seconds). Filter to RPCs only. |
| **Business Impact** | Too short (< 3 min) = not building rapport. Too long (> 15 min) = low productivity. |

**DAX:**
```dax
Avg Handle Time RPC =
    VAR TotalSeconds =
        SUMX(
            FILTER(
                Fact_Interactions,
                Fact_Interactions[rpc_flag] = TRUE()
            ),
            Fact_Interactions[aht_seconds] + Fact_Interactions[acw_seconds]
        )
    VAR TotalRPCs = [Total RPCs]
    RETURN
        DIVIDE(TotalSeconds, TotalRPCs, 0)
```

---

### 4.3.7 Contacts per Hour

| Field | Value |
|---|---|
| **Definition** | Number of connected calls per operating hour |
| **Formula** | `SUM(Calls Connected) / SUM(Operational Hours)` |
| **DAX** | `Contacts per Hour = DIVIDE([Total Connected], SUM(Fact_Agent_Time_Log[operational_hours]))` |
| **Thresholds** | Green ≥ 8/hr, Amber 5-7/hr, Red < 5/hr |
| **Visual** | KPI card, scatter plot |
| **Common Mistake** | Using handle time vs available hours. This is about *contacts*, not attempts. |
| **Business Impact** | Low contacts/hr = agent is spending too much time in after-call work or idle. |

---

### 4.3.8 Roll Rate

| Field | Value |
|---|---|
| **Definition** | Percentage of accounts that migrate from one DPD bucket to a worse bucket month-over-month |
| **Formula** | `COUNT(Accounts where dpd_bucket worsened) / COUNT(Accounts in starting bucket prior month)` |
| **DAX** | Requires fact_eom_snapshot self-join or calculated column for prior bucket |
| **Thresholds** | Green < 10%, Amber 10-20%, Red > 20% |
| **Visual** | Sankey diagram showing DPD migration paths |
| **Common Mistake** | Not normalizing by starting bucket. 30% roll from Current→1-30 is concerning; 30% roll from 61-90→90+ is expected. |
| **Business Impact** | Early roll rate (Current → 1-30) is the best leading indicator of portfolio deterioration. |

---

### 4.3.9 Cure Rate

| Field | Value |
|---|---|
| **Definition** | Percentage of delinquent accounts that return to current status |
| **Formula** | `COUNT(Accounts that cured) / COUNT(Accounts in Mora at period start)` |
| **DAX** | `Cure Rate = DIVIDE([Agent Cures] + [Self Cures], [Accounts in Mora Start of Period])` |
| **Thresholds** | Green ≥ 15%, Amber 10-14%, Red < 10% |
| **Visual** | KPI card, bar chart (by product/team) |
| **Common Mistake** | Counting the same account multiple times. An account cures once per delinquency episode. |
| **Business Impact** | Low cure rate = collections operations are failing to convert promises into payments. |

---

### 4.3.10 Productivity Score

| Field | Value |
|---|---|
| **Definition** | Composite metric combining RPC%, KP%, Utilization, and Cure Volume |
| **Formula** | Weighted average: `(RPC% × 0.25 + KP% × 0.35 + Util% × 0.20 + Cure_Volume_z × 0.20) × 100` |
| **DAX** | `Productivity Score = [RPC Rate] × 0.25 + [KP Rate] × 0.35 + [Utilization Rate] × 0.20 + [Cure Volume Z-Score] × 0.20` |
| **Thresholds** | Green ≥ 70, Amber 55-69, Red < 55 |
| **Visual** | Gauge chart on Agent Scorecard page |
| **Common Mistake** | Including self-cures in agent productivity. Only agent-cured accounts count. |
| **Business Impact** | Single-number ranking enables fair team comparisons across different portfolio mixes. |

---

### 4.3.11 Agent Utilization

| Field | Value |
|---|---|
| **Definition** | Percentage of logged-in time spent on revenue-generating activities (talk time + after-call work) |
| **Formula** | `SUM(tht_hours) / SUM(operational_hours)` |
| **DAX** | `Utilization Rate = DIVIDE(SUM(Fact_Agent_Time_Log[tht_hours]), SUM(Fact_Agent_Time_Log[operational_hours]))` |
| **Thresholds** | Green 70-85%, Amber 60-69% or 86-92%, Red < 60% or > 92% |
| **Visual** | Gauge, bar chart |
| **Common Mistake** | Using schedule_hours instead of operational_hours (op hours exclude breaks). |
| **Business Impact** | Below 60% = too much idle time (wasted capacity). Above 92% = burnout risk (no breather between calls). |

**DAX:**
```dax
Utilization Rate =
    DIVIDE(
        SUM(Fact_Agent_Time_Log[tht_hours]),
        SUM(Fact_Agent_Time_Log[operational_hours]),
        0
    )
```

## 4.4 KPI Governance Rules

1. **Every KPI has an owner.** Someone is responsible for the number and can explain a variance.
2. **Every KPI has a target.** If a target doesn't exist, it's a metric, not a KPI.
3. **Targets are reviewed quarterly.** Stale targets lose credibility.
4. **Definitions are documented in one place.** `docs/kpi_definitions.md` is the source of truth.
5. **DAX formulas are version-controlled.** Measure changes are tracked in the `.dax` files.

---

# 5. DAX Development Standards

## 5.1 Measure Branching Strategy

Never write a measure that reads directly from a table and performs complex logic in one expression. Instead, build a **measure tree**:

```
Raw base measures (one aggregation only)
    └─ Business base measures (adds one filter or conversion)
        └─ Composite KPI measures (combines two+ base measures)
            └─ Display measures (formatting, rounding, target comparison)
```

**Example tree for `KP Rate`:**

```
Level 0 (Raw):
    [Total PTPs]              = COUNTROWS(Fact_PTP_Log)
    [Kept PTPs]               = COUNTROWS(FILTER(Fact_PTP_Log, status = "Kept"))
    [Broken PTPs]             = COUNTROWS(FILTER(Fact_PTP_Log, status = "Broken"))

Level 1 (Business Base):
    [Resolved PTPs]           = [Kept PTPs] + [Broken PTPs]

Level 2 (Composite KPI):
    [KP Rate]                 = DIVIDE([Kept PTPs], [Resolved PTPs])

Level 3 (Display):
    [KP Rate Display]         = FORMAT([KP Rate], "0.0%")
    [KP Rate vs Target]       = [KP Rate] - 0.60
    [KP RAG]                  = SWITCH(TRUE(), [KP Rate] >= 0.60, "Green", ...)
```

**Benefits:**
- Debugging is trivial — check each level independently
- Reusability — `[Kept PTPs]` is used in KP%, BB Conversion, KP per Agent
- Readability — 5-line measures instead of 50-line monsters

## 5.2 Naming Conventions

| Pattern | Example | Rule |
|---|---|---|
| `Pascal Case` | `Total Recovery` | All measures |
| `_Underscore Prefix` | `_Contact & Volume` | Measure table names only (forces sort to top) |
| `[Square Brackets]` | `[KP Rate]` | Always reference measures with brackets |
| `'Table Name'[Column]` | `'Fact_Payments'[amount_paid]` | Always qualify columns with table name |
| `_Suffix` | `[KP Rate _MoM]` | Time-intelligence variants |

## 5.3 Base Measure Philosophy

Every measure in the `_Contact & Volume` table follows this pattern:

```dax
-- Base: single aggregation, no filter modification
Total Calls Attempted = SUM(Fact_Interactions[calls_attempted])

-- Derived: adds CALCULATE filter modification
Total RPCs =
    CALCULATE(
        [Total Calls Attempted],     -- reuse base
        Fact_Interactions[rpc_flag] = TRUE()
    )
```

**Why base measures matter:**
- Performance: SUM on a column VertiPaq-optimized once, reused everywhere
- Consistency: [Total Calls Attempted] means the same thing in every context
- Maintainability: Change the base measure definition once, all derived measures update

## 5.4 Reusable DAX Patterns

### Pattern 1: CALCULATE with Filter

```dax
-- Correct: boolean filter expression (fastest)
CALCULATE([Base Measure], Table[Column] = "Value")

-- Correct: FILTER with simple predicate
CALCULATE([Base Measure], FILTER(Table, Table[Column] = "Value"))

-- Wrong: FILTER over entire table (slow for large fact tables)
CALCULATE([Base Measure], FILTER(ALL(Table), Table[Column] = "Value"))
```

**Best practice:** Use boolean filter expressions instead of FILTER() whenever possible. Boolean filters are evaluated by the formula engine; FILTER() iterates row by row.

### Pattern 2: Time Intelligence

```dax
-- Month-over-Month
KP Rate MoM =
    VAR CurrentPeriod = [KP Rate]
    VAR PriorPeriod =
        CALCULATE(
            [KP Rate],
            DATEADD(Dim_Calendar[date], -1, MONTH)
        )
    RETURN
        CurrentPeriod - PriorPeriod

-- Rolling 3 Months
KP Rate Rolling 3M =
    CALCULATE(
        [KP Rate],
        DATESINPERIOD(Dim_Calendar[date], MAX(Dim_Calendar[date]), -3, MONTH)
    )
```

**Warning:** `DATEADD`, `DATESINPERIOD`, and `SAMEPERIODLASTYEAR` require a marked date table with contiguous dates. Your `Dim_Calendar` table must be marked as the date table in Power BI Desktop (Table tools → Mark as date table).

### Pattern 3: DIVIDE (Safe Division)

```dax
-- Always use DIVIDE, never the / operator
KP Rate = DIVIDE([Kept PTPs], [Resolved PTPs], 0)

-- DIVIDE handles:
--   1. Denominator = 0 → returns BLANK (or alternate result)
--   2. Denominator = BLANK → returns BLANK
--   3. Both BLANK → returns BLANK
```

**Anti-pattern:** `[Kept PTPs] / [Resolved PTPs]` — throws DIV/0 error when no PTPs exist.

### Pattern 4: SWITCH (RAG Logic)

```dax
KP RAG =
    SWITCH(
        TRUE(),
        [KP Rate] >= 0.60, "Green",
        [KP Rate] >= 0.50, "Amber",
        "Red"
    )
```

### Pattern 5: Variables (VAR)

```dax
Avg Handle Time RPC =
    VAR TotalSeconds =
        SUMX(
            FILTER(Fact_Interactions, Fact_Interactions[rpc_flag] = TRUE()),
            Fact_Interactions[aht_seconds] + Fact_Interactions[acw_seconds]
        )
    VAR TotalRPCs =
        CALCULATE(
            COUNTROWS(Fact_Interactions),
            Fact_Interactions[rpc_flag] = TRUE()
        )
    VAR Result =
        DIVIDE(TotalSeconds, TotalRPCs, 0)
    RETURN
        Result
```

**Rules for VAR:**
1. Always declare — even for simple measures
2. Each VAR computes once and caches
3. `RETURN` must be the last statement
4. Can reference other VARs declared above

## 5.5 Performance Anti-Patterns

| Anti-Pattern | Why It's Bad | Fix |
|---|---|---|
| `FILTER(ALL(Table), ...)` | Scans entire table, ignores existing filter context | Use `REMOVEFILTERS` or `ALLSELECTED` |
| Nested iterators (SUMX inside SUMX) | Row-by-row processing compounds exponentially | Flatten to single iterator, or use CALCULATE |
| `COUNTROWS(FILTER(...))` instead of CALCULATE | FILTER iterates entire table | `CALCULATE(COUNTROWS(Table), Column = Value)` |
| `IF([Measure] = BLANK(), ...)` | Measures return BLANK, but comparing to BLANK is slow | Use `ISBLANK()` or `COALESCE()` |
| Implicit measures (drag a numeric column to a visual) | Creates hidden measures with no optimization | Always create explicit DAX measures |

## 5.6 Context Transition (CALCULATE Internals)

When CALCULATE moves a row context into a filter context (e.g., inside SUMX), it performs a **context transition**. This is the single most misunderstood concept in DAX.

```dax
-- What this does:
SUMX(
    Dim_Agents,
    CALCULATE(COUNTROWS(Fact_Interactions))
)
-- 1. SUMX iterates over each row of Dim_Agents (row context)
-- 2. For each agent, CALCULATE transforms the row context into a
--    filter context (context transition)
-- 3. Fact_Interactions is filtered to that agent
-- 4. COUNTROWS returns the interactions count
-- 5. SUMX sums the individual counts
```

**Rule:** Any time you see CALCULATE inside an iterator, you are paying for a context transition. If performance is slow, consider using a relationship-based approach instead:

```dax
-- Faster alternative (no context transition needed):
COUNTROWS(
    FILTER(
        Fact_Interactions,
        RELATED(Dim_Agents[agent_id]) <> BLANK()
    )
)
```

## 5.7 Documentation Standards

Every measure should have a comment block explaining:

```dax
-- =========================================================================
-- Measure: KP Rate
-- Table:   _Promise & Recovery
-- Purpose: Percentage of resolved PTPs that resulted in a payment
-- Formula: Kept PTPs / (Kept PTPs + Broken PTPs)
-- Filters: Resolved PTPs only (excludes Pending)
-- Dependencies: [Kept PTPs], [Broken PTPs]
-- =========================================================================
KP Rate =
    DIVIDE(
        [Kept PTPs],
        [Resolved PTPs],
        0
    )
```

Use Tabular Editor to export all measures to `.dax` files on every commit.

## 5.8 Measure Folder Organization

In Power BI Desktop, create three measure tables using the Enter Data feature (one dummy row, then delete the column, hide the table):

```
_Contact & Volume (19 measures)
   ├── Base: Total Calls Attempted
   ├── Base: Total Calls Connected
   ├── Base: Total RPCs
   ├── Derived: RPC Rate
   ├── Derived: RPC per Operating Hour
   ├── Base: Total AHT Seconds (RPC)
   ├── Derived: Avg AHT RPC
   ├── Derived: Avg ACW RPC
   └── Derived: Utilization Rate

_Promise & Recovery (26 measures)
   ├── Base: Total PTPs
   ├── Derived: Promise Rate
   ├── Base: Kept PTPs
   ├── Base: Broken PTPs
   ├── Derived: Resolved PTPs
   ├── Derived: KP Rate
   ├── Derived: BB Conversion Rate
   ├── Derived: Capped KP$
   ├── Base: Total Recovery
   ├── Derived: Agent Cure Rate
   ├── Derived: Self Cure Rate
   └── Derived: Cure Rate

_Portfolio & Trends (25 measures)
   ├── Base: Portfolio Total Arrears
   ├── Derived: Portfolio Balance
   ├── Derived: Mora Rate
   ├── Derived: DPD Bucket Distribution
   ├── Derived: Accounts in Mora
   ├── Derived: MoM KP% Change
   ├── Derived: Rolling 3M KP%
   ├── Derived: Arrears to Balance %
   └── Derived: MoM Mora Rate Change
```

---

# 6. Dashboard Page-by-Page Build Guide

## 6.1 Design Philosophy

Every page follows the **F-pattern** reading behavior: the eye starts at the top-left, scans right to the top-right, then zigzags down-left, down-right. The most important KPI is always top-left. The least important or supporting detail is bottom-right.

## 6.2 Page 1 — Executive Dashboard

### 6.2.1 Purpose

Give the VP/Director a 5-second health check. By the time they look away from this page, they should know: "Are we better or worse than last month?"

### 6.2.2 Audience

VP Collections, Director of Recovery, Chief Risk Officer. Non-technical. Little time. Needs answers, not questions.

### 6.2.3 Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  [Month] [Product] [Team]     ← Slicer bar (top, full width)                │
├──────────┬──────────┬──────────┬──────────┬─────────────────────────────────┤
│          │          │          │          │                                 │
│  TOTAL   │  MORA    │   KP     │  RECOVERY│  MoM KP% + RPC% TREND          │
│  ARREARS │  RATE    │   RATE   │  AMOUNT  │  (dual-axis line chart)         │
│          │          │          │          │                                 │
│  $2.4M   │  17.3%   │  62.1%   │  $284K   │  ┌──────────────────────┐      │
│  ▼ -3.2% │  ▼ -0.8pp│  ▲ +0.5pp│  ▼ -$16K │  │  KP% — RPC% —        │      │
│          │          │          │          │  │  Oct  Nov  Dec        │      │
├──────────┴──────────┴──────────┴──────────┤  └──────────────────────┘      │
│                                            │                                 │
│  ARREARS WATERFALL (by product)            │  PTP → CURE FUNNEL              │
│  ┌────────────────────────┐                │  ┌────────────────────┐        │
│  │ Open → Payments →      │                │  │                    │ RPCs   │
│  │ Charge-offs → Close    │                │  │  ████████████████   │ PTPs   │
│  │                        │                │  │  ██████████         │ Kept   │
│  └────────────────────────┘                │  │  ████████           │ Cures  │
│                                            │  └────────────────────┘        │
├────────────────────────────────────────────┴─────────────────────────────────┤
│                                                                              │
│  DPD BUCKET TREEMAP                           PRODUCT CONCENTRATION         │
│  ┌────────────────────┐                       ┌────────────────────┐        │
│  │  1-30   31-60      │                       │  Tarjeta  Prestamo │        │
│  │  Current   61-90   │                       │              Hipoteca│       │
│  │      90+          │                       │                    │        │
│  └────────────────────┘                       └────────────────────┘        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.2.4 KPI Card Details

| Position | Metric | Format | Sparkline | MoM Delta |
|---|---|---|---|---|
| Top-left | Portfolio Total Arrears | `$0.0M` | Yes (12mo) | ▼ Red if up, ▲ Green if down |
| Top-second | Mora Rate | `0.0%` | Yes | ▼ Green if down (lower is better) |
| Top-third | KP Rate | `0.0%` | Yes | ▲ Green if up |
| Top-right | Total Recovery | `$0.0K` | Yes | ▼ Red if down |

**MoM Delta format rules:**
- Arrears: lower is better → GREEN for decrease (▼ -3.2%), RED for increase
- Mora Rate: lower is better → GREEN for decrease
- KP Rate: higher is better → GREEN for increase
- Recovery: higher is better → GREEN for increase

### 6.2.5 Implementation Steps

1. Add four **New Card** visuals (Premium visual). Each card shows the KPI value, the MoM delta below, and a 12-month sparkline.
2. Add a **dual-axis line chart**: Month on X-axis, KP% on left Y-axis (solid line), RPC% on right Y-axis (dashed line). Format the secondary axis to 60-70% range for readability.
3. Add a **waterfall chart**: Category = product, Value = arrears change breakdown. This shows which product category drove the month's arrears change.
4. Add a **funnel chart**: Stages = Total RPCs → Total PTPs → PTPs Kept → Total Cures. This tells the collections pipeline story in one visual.
5. Add a **treemap**: Category = DPD bucket, Values = SUM(arrears). Color by bucket severity (green → current, yellow → 1-30, orange → 31-60, red → 90+).
6. Add three **slicers** at the top: Month (dropdown, single select default), Product (dropdown), Team (dropdown).

### 6.2.6 Common Mistakes

- **Clutter.** This page should have exactly 8-9 visuals. Any more and the executive will ignore it.
- **Wrong sparkline period.** Use 12 months for trends. 3 months doesn't show seasonality.
- **Varying currency precision.** All monetary values use the same format: millions for portfolio-level, thousands for recovery.
- **Missing context.** "17.3%" without "target <20%" is meaningless. Always show target alongside actual.

## 6.3 Page 2 — Agent Scorecard

### 6.3.1 Purpose

Give supervisors a daily tool to identify underperformers, track coaching effectiveness, and manage their team. This is an action page — the supervisor should leave knowing who to coach and on what.

### 6.3.2 Audience

Team supervisors. High data fluency. Needs granularity and sorting.

### 6.3.3 Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  [Team] [Agent] [Month] [Metric Select]    ← Slicer bar                     │
├────────────────────────────────┬────────────────────────────────────────────┤
│                                │                                            │
│  AGENT RANKING TABLE           │  COMPOSITE SCORE GAUGE                     │
│  ┌──────┬───────┬──────┬────┐ │  ┌────────────────────────────────┐        │
│  │ Rank │ Agent │ KP%  │RAG │ │  │      ┌─────┐                  │        │
│  │  1   │ Doe,J │ 72%  │ 🟢 │ │  │      │ 68  │  ← score        │        │
│  │  2   │ Smith │ 68%  │ 🟢 │ │  │      └─────┘                  │        │
│  │  3   │ Jones │ 51%  │ 🔴 │ │  │  ────────────┬──── Target 70  │        │
│  │  4   │ ...   │ ...  │ ...│ │  │  0    50    100              │        │
│  └──────┴───────┴──────┴────┘ │  └────────────────────────────────┘        │
│                                │                                            │
│  Conditional formatting:       │  KPI COMPONENT BARS                        │
│  Green ≥ 60%                   │  ┌────────────────────────────────┐        │
│  Amber 50-59%                  │  │ RPC%        ████████████  72%  │        │
│  Red < 50%                     │  │ KP%         ██████      51%    │        │
│                                │  │ Util%       █████████   68%    │        │
├────────────────────────────────┴────────────────────────────────────────────┤
│                                                                              │
│  COACHING ALERTS                                                             │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  🔴  3 agents with WoW KP% drop > 10pp                                │ │
│  │  🟡  5 agents with Utilization < 60%                                  │ │
│  │  🟢  Team average RPC% improved 2.1pp this week                       │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.3.4 Implementation Steps

1. Add slicers: Team (dropdown), Agent (dropdown, multi-select), Month (dropdown), Metric Select (field parameter for the KPI column to sort by).
2. Add a **table visual** for agent ranking with conditional formatting:
   - Columns: Rank (calculated), Agent Name, KP%, RPC%, Util%, Composite Score, RAG icon
   - Conditional formatting: Background color by RAG value (green/amber/red)
   - Sort by Composite Score descending by default
3. Add a **gauge visual** for the selected agent's composite score:
   - Minimum = 0, Maximum = 100, Target = 70
   - This updates based on slicer selection
4. Add a **clustered bar chart** showing the selected agent's 4 component scores (RPC%, KP%, Util%, AHT Score normalized). This shows the supervisor *what* to coach on.
5. Add **multi-row cards** at the bottom for coaching alerts. These are measures that identify:
   - Bottom 3 agents by WoW KP% change
   - Agents below utilization threshold
   - Agents with improving trends (positive reinforcement)

### 6.3.5 Coaching Alert DAX Pattern

```dax
WoW KP% Change =
    VAR CurrentKP = [KP Rate]
    VAR PriorWeekKP =
        CALCULATE(
            [KP Rate],
            DATEADD(Dim_Calendar[date], -7, DAY)
        )
    RETURN
        CurrentKP - PriorWeekKP

Bottom 3 Agents KP% Drop =
    VAR BottomAgents =
        TOPN(
            3,
            VALUES(Dim_Agents[agent_id]),
            [WoW KP% Change], ASC
        )
    RETURN
        CONCATENATEX(BottomAgents, Dim_Agents[agent_name], ", ")
```

### 6.3.6 Common Mistakes

- **Too many columns in the ranking table.** Stick to 6-8 columns. Any more and the supervisor can't scan it.
- **Sorting by name, not performance.** Default sort = Composite Score descending. Let the user override.
- **Static targets.** Targets should be parameterized so management can adjust them without editing DAX.
- **No trend indicators.** A 72% KP% is good, but if it was 85% last week, that's a problem. Add sparkline columns.

## 6.4 Page 3 — Team Performance

### 6.4.1 Purpose

Enable managers to compare team performance, identify resource allocation opportunities, and spot workload imbalances.

### 6.4.2 Audience

Collections Manager, Operations Manager. Comfortable with scatter plots and distributions.

### 6.4.3 Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  [Month] [Product] [Region]    ← Slicer bar                                 │
├─────────────────────────────────────┬───────────────────────────────────────┤
│                                     │                                       │
│  TEAM RANKING (Horizontal Bar)     │  RPC% vs KP% SCATTER                  │
│  ┌─────────────────────────────┐   │  ┌────────────────────────────┐       │
│  │ Team A ████████████████ 72% │   │  │  KP%                      │       │
│  │ Team B ██████████████   68% │   │  │  ↑   ○ Team A   ○ Team B  │       │
│  │ Team C ████████████     62% │   │  │  │       ○ Team C          │       │
│  │ Team D ██████████       58% │   │  │  │  ○ Team D               │       │
│  └─────────────────────────────┘   │  │  └─────────────────→ RPC%  │       │
│                                     │  └────────────────────────────┘       │
│  Color = RAG status                │  Bubble size = Total Cures             │
│                                     │                                       │
├─────────────────────────────────────┴───────────────────────────────────────┤
│                                                                              │
│  AHT DISTRIBUTION (Box Plot via Deneb)                                       │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  AHT (sec)                                                             │ │
│  │  900 ┤                                                                 │ │
│  │  600 ┤    ┌───┐  ┌───┐                                                 │ │
│  │  300 ┤    │   │  │   │  ┌───┐  ┌───┐                                  │ │
│  │    0 ┤    └───┘  └───┘  └───┘  └───┘                                  │ │
│  │         TeamA  TeamB  TeamC  TeamD                                      │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
├─────────────────────────────────────┬───────────────────────────────────────┤
│                                     │                                       │
│  WORKLOAD Z-SCORES TABLE            │  CURES PER THT (Bar Chart)            │
│  ┌──────┬──────┬──────┬──────┐     │  ┌────────────────────────────┐       │
│  │Agent │Accts │Calls │  Z  │     │  │  Cures/THT                 │       │
│  │      │Z     │Z     │Icon  │     │  │  ██ ██ ██ ██              │       │
│  │Doe,J │ 2.1  │ 1.8  │ ⚠️   │     │  │  ██ ██ ██ ██ ██ ██       │       │
│  │Smith │ -1.2 │ -0.9 │ ✅   │     │  │  A   B   C   D            │       │
│  └──────┴──────┴──────┴──────┘     │  └────────────────────────────┘       │
│                                     │                                       │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.4.4 Implementation Steps

1. Add slicers: Month (dropdown), Product (dropdown), Region (dropdown).
2. Add a **horizontal bar chart**: Category = team_name, Values = [KP Rate] (or any KPI selected by field parameter). Color bars by RAG status. Sort descending.
3. Add a **scatter chart**: X-axis = [RPC Rate], Y-axis = [KP Rate], Size = [Agent Cures], Legend = team_name. Add a median line for quadrant analysis (top-right = star teams, bottom-left = needs attention).
4. Add a **box plot** (use Deneb custom visual — Vega-Lite JSON specification):
   - X = team_name, Y = Fact_Interactions[aht_seconds] (RPC only)
   - Box = IQR (25th-75th percentile), whisker = 1.5× IQR, median line
   - This reveals AHT outliers within each team
5. Add a **table** for workload z-scores:
   - Calculate z-scores for accounts assigned and calls made per agent
   - Conditional icon: ⚠️ if |z| > 2 (significant over/under allocation)
   - Color cells by z-score magnitude
6. Add a **bar chart** for Cures per THT by team:
   - Y = [Agent Cures] / SUM(Fact_Agent_Time_Log[tht_hours]), X = team_name

### 6.4.5 Deneb Box Plot Specification

```json
{
  "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
  "data": {"name": "dataset"},
  "mark": {
    "type": "boxplot",
    "extent": "min-max"
  },
  "encoding": {
    "x": {"field": "team_name", "type": "nominal"},
    "y": {
      "field": "aht_seconds",
      "type": "quantitative",
      "title": "AHT (seconds)"
    },
    "color": {
      "field": "team_name",
      "type": "nominal",
      "legend": null
    }
  },
  "config": {
    "boxplot": {
      "box": {"stroke": "#0078D4"},
      "median": {"color": "#E81123"},
      "whisker": {"stroke": "#0078D4"}
    }
  }
}
```

### 6.4.6 Common Mistakes

- **Scatter plot overplotting.** With 80 agents, scatter plots become unreadable. Use team-level aggregation (8 points) instead of agent-level.
- **Misleading bubble sizes.** If Total Cures varies 10× between teams, scale the bubble radius, not the area (default Power BI behavior is area-scaled, which exaggerates differences).
- **Overloading the z-score table.** Only show agents with |z| > 1.5. Everyone else is "normal" and doesn't need attention.

## 6.5 Page 4 — Portfolio Health & Trends

### 6.5.1 Purpose

Monitor portfolio risk, detect deterioration early, and understand which product segments are driving arrears.

### 6.5.2 Audience

Risk Analysts, Recovery Managers, Collections Director. Analytical and detail-oriented.

### 6.5.3 Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  [Month Range] [Product] [DPD Bucket]  ← Slicer bar                         │
├──────────────────────────────────────┬──────────────────────────────────────┤
│                                      │                                      │
│  ARREARS TREND (Multi-line)          │  DPD MIGRATION (Sankey)              │
│  ┌───────────────────────────┐       │  ┌──────────────────────────┐        │
│  │  Arrears ($)             │       │  │  Current ──→ Current 80% │        │
│  │  ↑                       │       │  │  Current ──→ 1-30   15%  │        │
│  │  │  ── Tarjeta           │       │  │  1-30 ──→ Current 40%   │        │
│  │  │  ── Prestamo          │       │  │  1-30 ──→ 31-60   35%   │        │
│  │  │  ── Hipoteca          │       │  │  31-60 ──→ 61-90   50%  │        │
│  │  └───────────────────────────┘   │  │  90+ ──→ 90+      90%   │        │
│                                      │  └──────────────────────────┘        │
│  Color = product_type               │  Node width = account count           │
│                                      │                                      │
├──────────────────────────────────────┴──────────────────────────────────────┤
│                                                                              │
│  PRODUCT CONCENTRATION (Treemap)     |  RISK SCORE MATRIX                    │
│  ┌────────────────────────────┐      |  ┌────────────────────────────┐      │
│  │                            │      |  │       Tarj  Prst  Hip   │      │
│  │  Tarjeta ($1.2M)          │      |  │Retail  650   700   720   │      │
│  │             │              │      |  │Prem    720   750   780   │      │
│  │  ┌────┬────┤  Prestamo    │      |  │                         │      │
│  │  │1-30│31- │  ($0.8M)     │      |  └────────────────────────────┘      │
│  │  │    │60  │              │      |  Color = AVG(balance)                 │
│  │  └────┴────┤  Hipoteca    │      |                                      │
│  │            │  ($0.4M)     │      |                                      │
│  └────────────────────────────┘      └──────────────────────────────────────┘
│                                                                              │
├──────────────────────────────────────┬──────────────────────────────────────┤
│                                      │                                      │
│  ACCOUNTS IN MORA (Bar)             |  SELF-CURE vs AGENT CURE (Stacked)    │
│  ┌───────────────────────────┐      |  ┌────────────────────────────┐       │
│  │  # Accounts in Mora      │      |  │  ■ Agent Cure  ■ Self-Cure │       │
│  │  ████████████████  2,400 │      |  │  ████████████████████       │       │
│  │  ██████████████    2,100 │      |  │  ████████████████           │       │
│  │  ██████████        1,800 │      |  │  Oct     Nov     Dec       │       │
│  └───────────────────────────┘      |  └────────────────────────────┘       │
│  Color = DPD bucket                 |  Shows cure source breakdown          │
│                                      │                                      │
└──────────────────────────────────────┴──────────────────────────────────────┘
```

### 6.5.4 Implementation Steps

1. Add slicers: Month Range (between slicer), Product (dropdown), DPD Bucket (dropdown).
2. Add a **multi-line chart**: X-axis = month, Y-axis = SUM(arrears), Legend = product_type. Each line represents arrears trajectory for one product. Add a constant line for total portfolio arrears.
3. Add a **Sankey diagram** (use the Sankey custom visual):
   - Source = prior month's DPD bucket (calculated column: `CALCULATE(MAX(Fact_EOM_Snapshot[dpd_bucket]), FILTER(Fact_EOM_Snapshot, Fact_EOM_Snapshot[snapshot_date] = EARLIER(Fact_EOM_Snapshot[snapshot_date]) - 30))`)
   - Target = current month's DPD bucket
   - Node width = COUNT of accounts
   - This visual reveals roll rate migration patterns
4. Add a **treemap**: Category = product_type, detail = dpd_bucket, Values = SUM(arrears). Shows which product × bucket combinations drive the most arrears.
5. Add a **matrix** visual: Rows = segment, Columns = product_type, Values = AVERAGE(risk_score). Conditional formatting by color scale (green = low risk, red = high risk).
6. Add a **stacked bar chart**: X-axis = month, Y-axis = COUNT(accounts) in Mora status, color = dpd_bucket. Shows the composition of delinquency over time.
7. Add a **100% stacked bar**: X = month, Y = COUNT(cures), Legend = cure_flag (Agent_Cure vs Self_Cure). Shows whether the team is driving cures or accounts are self-curing.

### 6.5.5 Calculating Prior Month DPD Bucket

This is a calculated column (not a measure) in `Fact_EOM_Snapshot`:

```dax
Prior Month DPD Bucket =
    VAR CurrentAccount = Fact_EOM_Snapshot[account_id]
    VAR CurrentDate = Fact_EOM_Snapshot[snapshot_date]
    VAR PriorDate = DATEADD(Dim_Calendar[date], -1, MONTH)
    VAR PriorBucket =
        CALCULATE(
            SELECTEDVALUE(Fact_EOM_Snapshot[dpd_bucket]),
            FILTER(
                Fact_EOM_Snapshot,
                Fact_EOM_Snapshot[account_id] = CurrentAccount
                    && Fact_EOM_Snapshot[snapshot_date] = PriorDate
            )
        )
    RETURN
        PriorBucket
```

**Note:** This only works if every account has an EOM snapshot for every month. If an account cured mid-month, its prior month bucket is "Current" (the last recorded state).

### 6.5.6 Common Mistakes

- **Sankey overload.** If you have 6+ DPD buckets, the Sankey becomes spaghetti. Group to 4-5 buckets: Current, 1-30, 31-60, 61-90, 90+.
- **Static date range.** The Sankey and roll rate calculations depend on knowing the "prior month." Always drive this from the date table, not a hardcoded offset.
- **Confusing correlation with causation.** The risk score matrix shows correlation between segment/product and arrears. It does NOT mean "premium clients are lower risk because of their segment." That's a selection effect.

## 6.6 Page 5 — Promise Intelligence

### 6.6.1 Purpose

Enable analysts and managers to investigate promise-to-pay quality: which agents make effective promises, which customers keep them, and which products have the best conversion.

### 6.6.2 Audience

Recovery Analyst, Collections Manager, Quality Assurance. Data-curious. Comfortable with matrices and heatmaps.

### 6.6.3 Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  [Month] [Product] [Agent]     ← Slicer bar                                 │
├──────────────────────────────────────┬──────────────────────────────────────┤
│                                      │                                      │
│  KP% BY DPD BUCKET (Bar)            |  PTP% / KP% / BB MATRIX               │
│  ┌───────────────────────────┐       |  ┌────────────────────────────┐       │
│  │  KP%                     │       |  │       PTP%  KP%  BB Conv   │       │
│  │  ████████████████  72%  │       |  │Tarj.   45%   58%   32%      │       │
│  │  ██████████████    68%  │  ← 1-30│  │Prst.   52%   64%   38%     │       │
│  │  ██████████        55%  │  ← 31-60│ │Hip.    38%   55%   28%     │       │
│  │  █████              35% │  ← 61-90│ └────────────────────────────┘       │
│  │  ████              22%  │  ← 90+ │  Color = RAG (by threshold)          │
│  └───────────────────────────┘       |                                      │
│  Insight: KP% drops as DPD rises    |  Shows which products convert best   │
│                                      │                                      │
├──────────────────────────────────────┴──────────────────────────────────────┤
│                                                                              │
│  PROMISE HEATMAP (Agent × Week)                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │  Agent     W40   W41   W42   W43   W44   W45   W46   W47   W48   W49   │ │
│  │  ──────────────────────────────────────────────────────────────────     │ │
│  │  Doe, J    72%   68%   75%   71%   55%   62%   58%   71%   68%   73%   │ │
│  │  Smith, A  65%   62%   58%   51%   48%   52%   55%   61%   65%   68%   │ │
│  │  Jones, B  78%   75%   72%   68%   71%   68%   72%   68%   75%   78%   │ │
│  │  ...                                                                    │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│  Color scale: Green ≥ 60%, Amber 50-59%, Red < 50%                          │
│  Pattern detection: Red streak = coaching opportunity                       │
│                                                                              │
├──────────────────────────────────────┬──────────────────────────────────────┤
│                                      │                                      │
|  PROMISE VOLUME TREND (Line)        |  CAPPED KP$ PER OP HR (Line)          │
|  ┌───────────────────────────┐       |  ┌────────────────────────────┐       │
|  │  # of PTPs               |       |  │  KP$ per Operating Hour    │       │
|  │  ████████████████        |       |  │  ── Tarjeta                │       │
|  │  ████████████████        |       |  │  ── Prestamo               │       │
|  │  ████████████████        |       |  │  ── Hipoteca               │       │
|  └───────────────────────────┘       |  └────────────────────────────┘       |
|  Color = Kept vs Broken             |  Most value-dense measure             │
│                                      │                                      │
└──────────────────────────────────────┴──────────────────────────────────────┘
```

### 6.6.4 Implementation Steps

1. Add slicers: Month (dropdown), Product (dropdown), Agent (dropdown, multi-select).
2. Add a **clustered bar chart**: X-axis = dpd_bucket, Y-axis = [KP Rate]. This shows how promise quality degrades as accounts age in delinquency. The trend should be downward — if it's not, investigate.
3. Add a **matrix visual** with conditional formatting:
   - Rows = product_type
   - Values = [PTP%], [KP%], [BB Conversion Rate]
   - Conditional formatting by color scale (green → amber → red)
4. Add a **matrix heatmap**: Rows = agent_name, Columns = iso_week (from Dim_Calendar), Values = [KP Rate]. Conditional formatting by RAG color. This is the most powerful visual on this page — it reveals weekly performance patterns at a glance.
5. Add a **line chart**: X = month, Y = COUNT(PTPs), Legend = status (Kept/Broken). Shows whether promise volume is trending in the right direction.
6. Add a **line chart** for Capped KP$ per Operating Hour: X = month, Y = [Capped KP$] / SUM(Fact_Agent_Time_Log[operational_hours]), Legend = product. This is the most value-dense productivity measure.
7. Add **tooltips** on the heatmap: when hovering over a cell, show a tooltip page with the agent's detailed KPIs for that week.

### 6.6.5 Capped KP$ DAX

```dax
Capped KP$ =
    VAR MaxKPPerAccount = 500  -- parameterized threshold
    RETURN
        SUMX(
            FILTER(
                Fact_Payments,
                Fact_Payments[cure_flag] = "Agent_Cure"
            ),
            MIN(Fact_Payments[amount_paid], MaxKPPerAccount)
        )
```

This prevents a single large recovery from skewing the metric. Any payment over $500 is capped at $500 for productivity scoring purposes.

### 6.6.6 Common Mistakes

- **Heatmap overplotting.** With 80 agents × 12 weeks = 960 cells, a heatmap is still readable. With 80 agents × 52 weeks = 4,160 cells, it's noise. Limit the heatmap to the selected month's data.
- **BB Conversion without context.** "Broken promises that still cured" sounds positive, but it can hide a fundamental problem: promises are low quality. Always show BB Conversion alongside KP%.
- **Confusing PTP% with PTP count.** A high PTP% with low RPC count is worse than a moderate PTP% with high RPC count. Both metrics must be read together.

---

# 7. Visualization Selection Framework

## 7.1 Visual Decision Matrix

```
QUESTION                              RECOMMENDED VISUAL       AVOID
──────────────────────────────────────────────────────────────────────
What's the single most important      KPI Card                  Gauge (wastes space)
number right now?

How does this KPI trend over time?    Line + sparkline          Pie chart, donut
                                     in the card

How do teams compare on one KPI?      Horizontal bar chart      Vertical bar (hard to read labels)

How do two KPIs relate?               Scatter plot with         Stacked bar (hides relationship)
                                     quadrant lines

What's the distribution of a KPI      Box plot (Deneb)          Histogram (binning issues)
across a category?

How does a metric change across       Matrix heatmap            Conditional formatting in a table
two dimensions?                       with color scale

What's the pipeline conversion?       Funnel chart              100% stacked bar (hides volume)

What drives the change in             Waterfall chart            Pie chart of components
a starting value?

How do categories contribute          Treemap                   Pie chart, donut
to a total?

How do entities flow between          Sankey                    Alluvial (less well-known)
states over time?

What's individual performance         Table with RAG icons      Scatter plot (overplotting)
vs target?                            and sparklines

What's the distribution of            Histogram (custom)        Bar chart of binned values
a continuous metric?

How does the portfolio age?           Area chart (stacked)      Line chart (hides total volume)
```

## 7.2 Wrong Chart vs Correct Chart

### Wrong: Pie Chart for DPD Bucket Composition

```
         ┌─────┐
        ╱  90+  ╲
       │   12%   │
      ╱ ┌───────┐╲
     │  │ 61-90 │ │
     │  │   8%  │ │
     │   └───────┘│
     │  ┌───────┐ │
      ╲ │ 31-60 │╱
       │  15%   │
        ╲ ┌───┐╱
         │1-30│
         │ 25%│
          ────
```

**Why it's wrong:** Humans can't accurately compare angles. 25% vs 15% is hard to distinguish visually. With 5+ categories, the chart becomes unreadable.

### Correct: Treemap for DPD Bucket Composition

```
┌───────────────────────┬─────────────┬──────────┐
│                       │             │          │
│      Current          │   1-30      │  31-60   │
│                       │             │          │
│      40%              │   25%       │   15%    │
│                       │             │          │
├───────────────────────┴─────────────┼──────────┤
│                                     │  90+    │
│           61-90                     │          │
│            8%                       │   12%   │
│                                     │          │
└─────────────────────────────────────┴──────────┘
```

**Why it's better:** Area is immediately comparable. Rectangle sizes can be ordered (largest top-left). Color can encode a second dimension (bucket severity).

### Wrong: Stacked Bar for Arrears Trend

```
$3M ┤  ████████  Hipoteca
$2M ┤  ████████████████  Prestamo
$1M ┤  ████████████████████████████  Tarjeta
    └───┬────┬────┬────┬────
       Oct  Nov  Dec  Jan
```

**Why it's wrong:** Only the bottom segment (Tarjeta) has a fixed baseline. The top segments (Prestamo, Hipoteca) float, making it impossible to read their individual trends.

### Correct: Multi-line Chart for Arrears Trend

```
$3M ┤
     │         ── Tarjeta
$2M ┤         ╱╲      ── Prestamo
     │   ╱╲  ╱  ╲    ╱
$1M ┤  ╱  ╲╱    ╲  ╱  ── Hipoteca
     │ ╱          ╲╱
$0  └───┬────┬────┬────┬────
       Oct  Nov  Dec  Jan
```

**Why it's better:** Each line has its own baseline. You can see independent trends: "Tarjeta is rising, Prestamo is flat, Hipoteca is falling." The human eye tracks lines more accurately than stacked areas.

## 7.3 Visual Performance Considerations

| Visual | Performance | Notes |
|---|---|---|
| Table (basic) | Excellent | VertiPaq-optimized |
| Matrix | Good | Avoid >1000 cells |
| Card (new) | Excellent | Single aggregation |
| Line chart | Good | <20 series, <1000 points |
| Bar chart | Excellent | <100 categories |
| Scatter plot | Poor | >1000 points kills rendering |
| Treemap | Good | <50 rectangles |
| Waterfall | Fair | <20 categories |
| Funnel | Good | <10 stages |
| Sankey | Poor | >500 flows = unusable |
| Map | Poor | Only use for geographic data |
| Deneb (custom) | Variable | Depends on Vega spec complexity |

**Rule:** If a visual takes >3 seconds to render, either reduce data or change the visual type. Users blame Power BI (not their data) for slow visuals.

---

# 8. Power BI UX/UI Standards

## 8.1 Why Default Power BI Looks Amateur

Microsoft's default theme ships with:
- Black text on gray backgrounds (low contrast)
- Default blue series color (every chart looks the same)
- No padding or alignment (elements float at random positions)
- 10pt axis labels (unreadable when projected)
- Default title text ("Page 1")

Enterprise dashboards eliminate all of these. Every pixel has a purpose.

## 8.2 Enterprise Color Strategy

### Primary Palette

```
Corporate Blue (Primary)     #005B94    Used for: KPIs, titles, navigation
Secondary Blue (Accent)      #0078D4    Used for: chart series, links
Alert Red                    #E81123    Used for: below-target, warnings
Success Green                #00B050    Used for: above-target, positive trends
Warning Amber                #FFC000    Used for: near-target, caution

Neutrals:
Dark Text                    #333333    Body text, axis labels
Medium Gray                  #666666    Secondary text, gridlines
Light Gray                   #E0E0E0    Borders, dividers
Background White             #FFFFFF    Page background
Alternate Row                #F5F5F5    Table row striping
```

### RAG Threshold Colors

| Status | Hex | Meaning |
|---|---|---|
| Green | `#00B050` | Above target, on track |
| Amber | `#FFC000` | Within 10% of target, needs attention |
| Red | `#E81123` | Below target, needs intervention |
| Gray | `#A0A0A0` | No data, not applicable |

### Colorblind-Safe Considerations

- Do NOT rely solely on red/green for RAG. Add icons: 🟢 ✅ 🟡 ⚠️ 🔴 ❌.
- Use patterns (hatching, dots) alongside color in charts.
- Test with Colorblind Simulator (Power BI external tool).

## 8.3 Typography

| Element | Font | Size | Weight | Color |
|---|---|---|---|---|
| Page title | Segoe UI | 18pt | Semi-bold | #333333 |
| KPI value | Segoe UI | 28pt | Bold | #005B94 |
| KPI label | Segoe UI | 10pt | Regular | #666666 |
| KPI delta (MoM) | Segoe UI | 11pt | Semi-bold | RAG color |
| Chart title | Segoe UI | 12pt | Semi-bold | #333333 |
| Axis labels | Segoe UI | 9pt | Regular | #666666 |
| Table header | Segoe UI | 10pt | Semi-bold | #333333 |
| Table values | Segoe UI | 10pt | Regular | #333333 |
| Slicer labels | Segoe UI | 10pt | Regular | #333333 |
| Tooltip text | Segoe UI | 9pt | Regular | #333333 |

## 8.4 Layout Grid System

All pages use a 12-column grid:

```
┌────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┬────┐
│  1 │  2 │  3 │  4 │  5 │  6 │  7 │  8 │  9 │ 10 │ 11 │ 12 │
└────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┴────┘
```

**Standard placements:**
- Full-width element: columns 1-12 (slicer bar, coaching alerts)
- Half-width element: columns 1-6 or 7-12 (charts, tables)
- Quarter-width element: columns 1-3, 4-6, 7-9, 10-12 (KPI cards)
- One-third element: columns 1-4, 5-8, 9-12

**Padding and margins:**
- Page margin: 16px all sides
- Visual padding: 8px inside each visual
- Space between visuals: 8px
- Slicer bar height: 48px exactly

## 8.5 Consistent Slicer Placement

Every page has slicers in a fixed bar at the top:

```
┌─────────────────────────────────────────────────────────────────┐
│ Month ▼ │ Product ▼ │ Team ▼ │ Supervisor ▼ │ [Reset All]     │
└─────────────────────────────────────────────────────────────────┘
```

- Slicer type: Dropdown (not list, not slider). Dropdowns save vertical space.
- Interaction: Single select for Month (default = latest month), multi-select for others.
- Format: Transparent background, Segoe UI 10pt, border radius 4px.
- "Reset All" button: A blank button with a bookmark that clears all slicers.

**To sync slicers across all 5 pages:** Use the Sync Slicers pane in Power BI Desktop. This ensures that selecting "December" on Page 1 also filters Page 2-5.

## 8.6 Bookmark Navigation Strategy

Build a left sidebar with page navigation using bookmarks:

```
┌─────┬─────────────────────────────────────────────────────────┐
│     │                                                         │
│  🏠 │  Executive Dashboard                                    │
│     │                                                         │
│  👤 │  Agent Scorecard                                        │
│     │                                                         │
│  👥 │  Team Performance                                       │
│     │                                                         │
│  📊 │  Portfolio Health                                       │
│     │                                                         │
│  🔍 │  Promise Intelligence                                   │
│     │                                                         │
└─────┴─────────────────────────────────────────────────────────┘
```

**Implementation:**
1. Create a blank button for each page.
2. For each button, create a bookmark (View → Bookmarks → Add).
3. Set the bookmark to select the target page and clear all other selections.
4. Assign each button's action to its corresponding bookmark.
5. Pin the sidebar across all pages (it appears on every page without rework).

The sidebar width should be 48px (icon only, text hidden) → 180px (expanded on hover). Use a bookmark to toggle between collapsed and expanded states.

## 8.7 Tooltip Design

Never rely on Power BI's default tooltip (gray box, small text, no context). Build custom report page tooltips:

1. Create a new page, set size to "Tooltip" (280 × 150px).
2. Add the target visual for drillthrough context.
3. Add 3-4 relevant KPIs. Example for agent scorecard tooltip:
   - Agent Name (from slicer context)
   - RPC% (current month)
   - KP% (current month)
   - WoW KP% Change
   - Utilization%
4. Assign this tooltip page to the target visual in Format → Tooltip → Report page.

Tooltip pages should be 280px wide × 150-200px tall. Anything larger covers too much of the report.

## 8.8 Mobile Layout Considerations

Power BI mobile layouts are created separately in Power BI Desktop (View → Mobile layout).

For mobile:
- Stack KPIs vertically (top → bottom)
- Remove the sidebar (use a back button instead)
- Simplify the scatter chart to a table
- Increase font sizes by 2pt
- Remove the Sankey (unreadable on mobile)

Test on a phone screen (6.5" display) before publishing.

## 8.9 Grid Alignment Checklist

- [ ] All KPI cards are exactly the same height
- [ ] Chart titles are left-aligned with the chart area
- [ ] Slicer dropdowns are the same width
- [ ] Visual borders are consistent (0px or 1px)
- [ ] Shadow effects are disabled (they look unprofessional)
- [ ] No visual overlaps, no gaps > 12px
- [ ] Scroll bar hidden (page fits 1920 × 1080)
- [ ] On-hover card effects are disabled

---

# 9. Performance Optimization Guide

## 9.1 VertiPaq Storage Engine

Power BI Import mode uses the VertiPaq in-memory column store. Understanding VertiPaq is essential for performance tuning.

**Key facts:**
- Columns are stored independently (column store, not row store)
- Each column is compressed using value encoding, hash encoding, or run-length encoding
- High-cardinality columns (many unique values) compress poorly
- Low-cardinality columns (few unique values) compress to near-zero size
- The storage engine always scans full columns (it cannot skip rows)

## 9.2 Cardinality Reduction

Cardinality is the number of distinct values in a column. High cardinality = high memory usage = slow queries.

| Column | Cardinality | Suggested Action |
|---|---|---|
| interaction_id | 500K | Keep (needed for grain) |
| agent_name | 80 | Keep (low cardinality) |
| interaction_time (HH:MM:SS) | 86,400 | **Remove from model** or convert to hour bin |
| account_id | 15K | Keep (needed for relationships) |
| client full_name | 10K | Keep (text compression is good) |
| client DOB | ~17K years | **Bin to decade** or age band |
| payment_time | 50K+ | **Remove** — not used in any measure |

**Rule:** If a column is not used in a measure, a relationship, or a slicer, remove it from the model. In Power Query, select the column and click "Remove Other Columns" or uncheck "Enable load" in the column properties.

## 9.3 Incremental Refresh

Import mode requires periodic full refresh by default. For fact tables > 5M rows, configure incremental refresh:

1. In Power Query, create a `RangeStart` and `RangeEnd` parameter of type DateTime.
2. Filter the fact table: `[date_column] >= RangeStart and [date_column] < RangeEnd`.
3. In Power BI Desktop, right-click the fact table → Incremental refresh.
4. Set: Archive data starting from 3 years ago, refresh data from 1 year ago.
5. Select "Detect data changes" using a modified-date column if available.

For this project (~500K rows), incremental refresh is optional but best practice.

## 9.4 Aggregations

When fact tables exceed 50M rows, create aggregation tables:

```dax
-- Aggregation: Fact_Interactions at day-agency level
SELECT
    interaction_date,
    agent_id,
    COUNT(*) AS total_interactions,
    SUM(calls_attempted) AS total_calls,
    SUM(CASE WHEN rpc_flag THEN 1 ELSE 0 END) AS total_rpcs
INTO fact_interactions_agg_daily
FROM fact_interactions
GROUP BY interaction_date, agent_id;
```

In Power BI, create a relationship from `dim_calendar` and `dim_agents` to the aggregation table. Configure the aggregation as a "User-defined aggregation" in Power BI Desktop (Manage aggregations). Power BI will automatically route queries to the aggregation when measures match the summarized grain.

## 9.5 Import vs DirectQuery Decision

| Factor | Import | DirectQuery |
|---|---|---|
| Query speed | Milliseconds | Seconds (network latency) |
| Data size limit | RAM (up to 10 GB per dataset) | Database capacity |
| DAX features | All features | Limited (no time intelligence) |
| Refresh | Scheduled | Real-time |
| RLS | Column-level | Row-level only |
| Best for | <1B rows | >1B rows or real-time needs |

**Decision for this project:** Import. ~550K rows total across all fact tables. VertiPaq will compress this to <100 MB.

## 9.6 Query Folding

Query folding means Power Query translates your M transformations into SQL and pushes them to the source database. This is highly efficient.

**Folding happens when:**
- You connect via native PostgreSQL connector (not ODBC)
- You filter rows in Power Query (not add custom columns)
- You rename/remove columns (not merge/append)
- You change data types (not add conditional columns with custom logic)

**Folding does NOT happen when:**
- You use `Table.Buffer()` or `Table.AddColumn()` with custom M code
- You merge queries (Power Query joins break folding)
- You transpose/pivot/unpivot in Power Query

**Best practice:** Do all joins in PostgreSQL (create a view), then import the view in Power Query. This guarantees full folding.

## 9.7 Measure Efficiency

```dax
-- SLOW: Iterates entire table
[Total RPCs Wrong] =
    SUMX(
        Fact_Interactions,
        IF(Fact_Interactions[rpc_flag] = TRUE(), 1, 0)
    )

-- FAST: VertiPaq-optimized filter
[Total RPCs Right] =
    CALCULATE(
        COUNTROWS(Fact_Interactions),
        Fact_Interactions[rpc_flag] = TRUE()
    )
```

**Order of efficiency (fastest → slowest):**
1. `SUM(column)` — single column aggregation
2. `COUNTROWS(table)` — fast row count
3. `CALCULATE(aggregation, filter)` — boolean filter expression
4. `FILTER(table, condition)` — row-by-row iteration
5. `SUMX/COUNTX/FILTERX` — iterator functions
6. `Nested iterators (SUMX inside SUMX)`

## 9.8 Performance Troubleshooting Checklist

- [ ] Are all relationships single-direction?
- [ ] Are unused columns disabled in the model?
- [ ] Are high-cardinality columns (time, ID) binned or removed?
- [ ] Are measures using CALCULATE with boolean filters, not FILTER()?
- [ ] Are aggregates created for large fact tables?
- [ ] Is the date table marked as a date table?
- [ ] Are implicit measures avoided?
- [ ] Is the model size < 1 GB?
- [ ] Are all visuals showing < 10K data points?
- [ ] Is Query Folding enabled for all Power Query steps?
- [ ] Is DAX Studio showing SE (Storage Engine) queries < 10 ms average?
- [ ] Is the Performance Analyzer showing visual render time < 2 seconds?

## 9.9 DAX Studio Workflow

1. Install DAX Studio (external tool).
2. Connect to your open PBIX.
3. Run `EVALUATE SUMMARIZE(...)` to test query performance.
4. Check the Server Timings pane for SE CPU queries.
5. Look for queries with >10K SE CPU ms — those need optimization.
6. Use the `Model Metrics` tab to check table and column sizes.

## 9.10 Model Size Reduction

| Technique | Savings | Effort |
|---|---|---|
| Remove unused columns | 30-50% | Low (Power Query) |
| Reduce column cardinality | 10-30% | Low (bin/group) |
| Disable date hierarchy | 5-10% | Low (Options → Data Load) |
| Remove unused tables | 20-40% | Medium (depends on schema) |
| Use aggregations | 50-90% for queries | High (requires redesign) |

---

# 10. Security & Governance

## 10.1 Row-Level Security (RLS)

RLS ensures that a supervisor sees only their team's data. This is implemented in Power BI, not the database.

### RLS Architecture

```
User (Supervisor Team A)
    │
    ▼
Power BI Service
    │
    ▼
RLS Role: TeamLead
    │  Rule: Dim_Supervisors[supervisor_id] = USERPRINCIPALNAME()
    │
    ▼
Dim_Supervisors (filtered to Team A)
    │
    ▼
Dim_Agents (filtered to Team A's agents)
    │
    ▼
Fact_Interactions, Fact_PTP_Log, Fact_Payments (filtered by agent)
```

### Implementation Steps

1. In Power BI Desktop, go to Modeling → Manage Roles.
2. Create a role called `TeamLead`.
3. Add a filter on `Dim_Supervisors`:
   ```
   [supervisor_id] = USERPRINCIPALNAME()
   ```
4. Test in Power BI Desktop: Modeling → View as → select the TeamLead role → enter a supervisor_id.
5. After publishing, assign users to the role in Power BI Service: Dataset → Security → TeamLead → Add members.

### The Security Table Pattern

Sometimes `USERPRINCIPALNAME()` returns an email (e.g., `john.doe@bank.com`) but your dimension uses a code (e.g., `SUP-01`). In this case, create a security mapping table:

```sql
CREATE TABLE security_supervisor_mapping (
    supervisor_id VARCHAR(20),
    user_email VARCHAR(255)
);

INSERT INTO security_supervisor_mapping VALUES
('SUP-01', 'alice.smith@bank.com'),
('SUP-02', 'bob.jones@bank.com'),
...
```

Import this table into Power BI (do not relate it to the model). Then use the RLS rule:

```
[supervisor_id] =
    LOOKUPVALUE(
        security_supervisor_mapping[supervisor_id],
        security_supervisor_mapping[user_email],
        USERPRINCIPALNAME()
    )
```

### Testing RLS

Run this test for each supervisor:

```sql
-- Expected: only their team's agents appear
SELECT DISTINCT agent_id, supervisor_id
FROM fact_interactions fi
JOIN dim_agents da ON fi.agent_id = da.agent_id
WHERE da.supervisor_id = 'SUP-01';
```

Then verify in Power BI Service that a user assigned to the TeamLead role with email `alice.smith@bank.com` sees exactly those agent rows.

## 10.2 Common Security Mistakes

- **Using USERNAME() instead of USERPRINCIPALNAME().** `USERNAME()` returns `DOMAIN\User`, which is an internal Windows login. `USERPRINCIPALNAME()` returns the email, which is what Power BI Service uses for authentication.
- **Forgetting to apply RLS to all fact tables.** If `Fact_Payments` isn't filtered by the agent relationship, a supervisor could see payments collected by agents in other teams.
- **Not testing with actual user accounts.** Testing in Power BI Desktop with "View as" is a simulation. Always test in Power BI Service with real user credentials.
- **Static role assignments.** Roles should be managed through a security group in Azure AD, not individually assigned in Power BI.

## 10.3 Workspace Governance

| Workspace | Purpose | Members | Refresh |
|---|---|---|---|
| **Collections DEV** | Development | MIS Manager, Developer | On-demand |
| **Collections UAT** | User acceptance testing | Lead Supervisor, Manager | Daily |
| **Collections PROD** | Production | All stakeholders | Scheduled daily |

## 10.4 Deployment Pipelines

Power BI Deployment Pipelines (Premium required):

```
DEV → UAT → PROD
```

Each stage has its own workspace and dataset. Deployment moves content (reports, dashboards) from left to right. Data sources are parameterized to point to dev/uat/prod databases.

Without Premium, use the manual process:
1. Develop in a working PBIX.
2. Publish to DEV workspace for testing.
3. When ready, download the PBIX from DEV, republish to PROD.
4. Update PROD gateway connection.
5. Test PROD with a subset of users before broad rollout.

## 10.5 Sensitivity Labels

Apply Microsoft Purview sensitivity labels to the dashboard:
- Label: "Confidential – Financial Data"
- Encryption: Restrict editing/download to specific security groups
- Header: "CONFIDENTIAL – MSI Collections Data"

This ensures that even if the dashboard is shared externally, recipients cannot view the data without authorization.

## 10.6 Banking Compliance Considerations

- **Data residency:** Ensure the Power BI tenant is in the same geography as the bank's operations.
- **Audit logging:** Enable Power BI audit logs (Microsoft 365 Compliance Center) to track who accessed the dashboard.
- **Data retention:** Configure dataset retention to match the bank's data retention policy (typically 7 years for financial data).
- **Export controls:** Disable "Export to Excel" on sensitive pages (Page 4 – Portfolio Health) if required by compliance.

---

# 11. Deployment Workflow

## 11.1 Development Workflow

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│ Branch   │    │ Develop  │    │ Test     │    │ Deploy   │
│ from     │───→│ in Power │───→│ locally  │───→│ to DEV   │
│ main     │    │ BI       │    │ with     │    │ workspace│
└──────────┘    │ Desktop  │    │ DAX      │    └──────────┘
                └──────────┘    │ Studio   │         │
                               └──────────┘         │
                                                    ▼
                                               ┌──────────┐
                                               │ UAT test │
                                               │ with     │
                                               │ users    │
                                               └──────────┘
                                                    │
                                                    ▼
                                               ┌──────────┐
                                               │ Publish  │
                                               │ to PROD  │
                                               └──────────┘
```

## 11.2 Step-by-Step Deployment Flow

### Pre-Deployment
1. [ ] Validate all measures return correct values against SQL KPI views
2. [ ] Run Performance Analyzer on every page — all visuals < 2 seconds
3. [ ] Check model size: `.pbix` file < 100 MB
4. [ ] Verify RLS in "View as" mode
5. [ ] Set up gateway connection to PostgreSQL
6. [ ] Create deployment workspace in Power BI Service
7. [ ] Assign workspace roles (Admin, Member, Contributor, Viewer)

### Deployment
1. [ ] Save and close the PBIX
2. [ ] Publish to DEV workspace (Home → Publish)
3. [ ] Verify RLS works with test user accounts
4. [ ] Schedule dataset refresh: daily at 6:00 AM
5. [ ] If using pipelines: promote DEV → UAT → PROD
6. [ ] If manual: download from DEV, publish to PROD, reconfigure gateway

### Post-Deployment
1. [ ] Send testing links to 3-5 pilot users
2. [ ] Collect feedback for 1 week
3. [ ] Address critical issues
4. [ ] Announce to all stakeholders
5. [ ] Schedule monthly review of usage metrics (Power BI adoption metrics)

## 11.3 Dataset Refresh Scheduling

```
Refresh schedule:
  - Frequency: Daily
  - Time:      06:00 AM (before business hours)
  - Time zone: Local (America/Mexico_City)
  - Gateway:   On-premises data gateway (enterprise mode)
  - Failure notification: Email to MIS Manager

Failure handling:
  - First retry: 30 minutes after failure
  - Second retry: 60 minutes after failure
  - Escalation: If 3 consecutive failures, alert IT support
```

## 11.4 Gateway Setup

1. Install on-premises data gateway on a server that can access PostgreSQL.
2. Register the gateway in Power BI Service.
3. Add a data source: PostgreSQL, connection string from `.env`.
4. Test the connection.
5. Under dataset settings → Gateway connection, select the configured gateway.
6. Set privacy level to "Organizational" (not "None", not "Private" — these disable query folding).

## 11.5 CI/CD Recommendations

For teams with Azure DevOps or GitHub Actions:

```yaml
# .github/workflows/deploy.yml (example)
name: Deploy Power BI
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Publish to Power BI
        run: |
          # Use powerbi-publisher or Power BI REST API
          # to deploy the PBIX from artifacts/
```

**Note:** As of 2026, Power BI CI/CD is still evolving. The most reliable approach is using Power BI REST APIs with a service principal. For this portfolio project, manual deployment is acceptable.

---

# 12. Portfolio Presentation Strategy

## 12.1 How Recruiters Evaluate BI Projects

Recruiters and hiring managers scan BI portfolios in this order:

1. **Does the data make sense?** (Do the KPIs tell a coherent story?)
2. **Is the modeling correct?** (Star schema? Proper relationships? No bidirectional filters?)
3. **Is the DAX professional?** (Measure branching? Variables? DIVIDE? Context transition awareness?)
4. **Does it look polished?** (Consistent fonts? Proper spacing? No defaults?)
5. **Is it documented?** (README? Architecture diagram? KPI definitions?)
6. **Can I see the code?** (GitHub repo with clean structure?)

Most candidates fail at #3 (DAX) and #4 (UI). This project covers all six.

## 12.2 What Separates Beginner from Enterprise

| Beginner | Enterprise |
|---|---|
| Built-in theme, default colors | Custom corporate theme, RAG color scale |
| 1-2 pages, disconnected | 5+ pages, synced slicers, navigation sidebar |
| Flat measure list | Grouped measure tables with branching strategy |
| No comments in DAX | DOCUMENTED DAX with purpose, formula, dependencies |
| Default tooltip | Custom report page tooltips |
| Single data source | Multi-source star schema |
| No security model | RLS with security mapping table |
| No documentation | Full execution guide + KPI definitions + data dictionary |
| Direct upload | Deployment pipeline with DEV/UAT/PROD |

## 12.3 Which Screenshots Matter Most

For your portfolio, prioritize these screenshots in order:

1. **Model view** — show the star schema with relationships. This proves you understand data modeling.
2. **Executive Dashboard** — the first page. This sets the impression.
3. **Heatmap** (Promise Intelligence) — proves you can build advanced visuals (conditional formatting matrix).
4. **Agent Scorecard with RAG** — proves you understand operational analytics and UX design.
5. **Team Scatter Plot** — proves you can build analytical visuals (RPC% vs KP% with quadrant analysis).
6. **Sankey diagram** — proves you can use custom visuals (Deneb or third-party).

**Don't include:** Slicer bars, blank pages, pages with default visuals, error screenshots.

## 12.4 Which Metrics Impress Employers

Highlight these specific numbers in your case study:

- **Data volume:** "Model processes 500K+ interaction records across 3 months"
- **Tables:** "11 tables (6 dim, 5 fact) in star schema with proper surrogate keys and relationships"
- **DAX:** "70+ measures organized into 3 measure tables with branching strategy"
- **Pages:** "5 enterprise-grade dashboard pages with synced slicers, RLS, and custom tooltips"
- **Performance:** "Model loads in import mode under 100 MB compressed; all queries < 2 seconds"
- **Testing:** "41 automated QA tests validating 100+ business rules"
- **Pipeline:** "End-to-end ETL pipeline: Python generator → PostgreSQL → Power BI, running in 157 seconds"

## 12.5 README Recommendations

Your GitHub README should include:

```markdown
# MSI Collections — Enterprise Power BI Analytics

[![Python](https://img.shields.io/badge/Python-3.13-blue)]()
[![Power BI](https://img.shields.io/badge/Power%20BI-Desktop-yellow)]()
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-blue)]()
[![Tests](https://img.shields.io/badge/Tests-41%20passing-green)]()

## Overview

Enterprise-grade collections analytics dashboard built for a financial institution's 
consumer credit collections department. Single source of truth across 5 Power BI 
pages serving 3 stakeholder levels: Strategic (VP/Director), Tactical (Manager), 
and Operational (Supervisor).

## Architecture

[Insert model diagram screenshot]

- Star schema: 6 dimension + 5 fact tables
- 70+ DAX measures with branching strategy
- Row-level security by supervisor team
- Daily automated Excel MIS report

## Pages

1. **Executive Dashboard** — Portfolio health in 5 seconds
2. **Agent Scorecard** — Individual performance with coaching alerts
3. **Team Performance** — Comparative analytics with scatter + box plots
4. **Portfolio Trends** — Risk analytics with Sankey DPD migration
5. **Promise Intelligence** — PTP quality heatmap and funnel analysis

## Stack

| Component | Technology |
|---|---|
| Data Generation | Python (data_generator_v7.py) |
| Database | PostgreSQL 15 (Docker) |
| ETL | Python (pandas, psycopg2) |
| Analytics | Power BI Desktop (Import mode) |
| Excel Reports | Python (openpyxl) |
| Testing | pytest (41 tests) |
| Containerization | Docker, docker-compose |

## Key Metrics

- 500K+ interactions across Oct-Dec 2025
- ~15.5K accounts, 80 agents, 8 teams
- 41 passing QA tests (0 failures)
- Pipeline completes in ~157 seconds

## Quick Start

\`\`\`bash
# 1. Start database
docker-compose -f database/docker-compose.yml up -d

# 2. Generate data
python data_sources/data_generator_v7.py

# 3. Run pipeline
./run_pipeline.bat

# 4. Open Power BI
# Open dashboards/pbix/collections_dashboard_v3.pbix
\`\`\`

## Documentation

- [Execution Guide](docs/execution_guide.md) — Full build guide
- [KPI Definitions](docs/kpi_definitions.md) — Business formulas and targets
- [Data Dictionary](docs/data_dictionary.md) — Column-level metadata
```

## 12.6 Portfolio Storytelling

When presenting this project in an interview, tell this story:

> "I built this for a bank's collections department that had no central reporting — supervisors were tracking their teams in Excel, managers were pulling ad-hoc SQL queries, and the VP was getting a static PDF once a month. No single number was trusted.
>
> I designed a star schema from the ground up — 6 dimensions, 5 fact tables, 70+ measures organized into 3 branches. The key design decision was the three-layer architecture: the same model serves the VP (5-second health check), the manager (team comparisons), and the supervisor (daily coaching).
>
> The hardest part was the DAX — especially the EOM snapshot filter pattern to prevent triple-counting in portfolio measures, and the BB conversion rate that required self-joining the PTP log. I solved it with measure branching: each KPI is a tree of 3-5 base measures that combine into the final display value.
>
> The result: one version of the truth, daily automated reports, and a 60% reduction in time spent on manual reporting. The portfolio was also a success — it's now the core of my technical interview portfolio."

## 12.7 LinkedIn Strategy

- **Headline:** "BI Engineer | Power BI | Analytics Engineering | SQL | Python"
- **Featured section:** Add the GitHub repo and a screenshot of the Executive Dashboard
- **About section:** Lead with the architecture, not the tools. "Designed and built an enterprise collections analytics platform serving 3 organizational levels from a single star-schema model."
- **Experience bullet points:**
  - "Architected a 11-table star schema in PostgreSQL with 6 dimensions and 5 fact tables, enabling self-service analytics across 500K+ records"
  - "Developed 70+ DAX measures organized into 3 measure tables with branching strategy, reducing new measure development time by 40%"
  - "Implemented row-level security by supervisor team, ensuring compliance with banking data privacy regulations"
  - "Built automated ETL pipeline (Python → PostgreSQL → Power BI) processing 3 months of data in 157 seconds"

---

# 13. Final Enterprise Checklist

## 13.1 Data Modeling

- [ ] All fact tables have surrogate primary keys
- [ ] All dimensions have explicit primary keys
- [ ] All relationships are single-direction (dimension → fact)
- [ ] No bidirectional filters used
- [ ] Date table marked as date table
- [ ] No snowflake normalization in Power BI
- [ ] Unused columns disabled in Power Query
- [ ] Column data types explicitly set (not auto-detect)
- [ ] Boolean columns use TRUE/FALSE
- [ ] Numeric columns use DECIMAL or INTEGER
- [ ] No implicit measures
- [ ] Model size < 100 MB compressed

## 13.2 UX/UI

- [ ] Custom corporate color theme applied
- [ ] Consistent typography (Segoe UI, 10pt body)
- [ ] 12-column grid layout used consistently
- [ ] Slicers in fixed top bar, same across all pages
- [ ] Synced slicers across pages
- [ ] Bookmark navigation sidebar present
- [ ] Custom report page tooltips (280×150px)
- [ ] RAG color scheme with icons (not color-only)
- [ ] All KPI cards show target vs actual
- [ ] All KPI cards show MoM delta
- [ ] Sparkline in every KPI card
- [ ] Mobile layout configured for key pages
- [ ] Scroll bars hidden
- [ ] Power BI default theme completely eliminated

## 13.3 DAX

- [ ] Measure branching: raw → base → composite → display
- [ ] All measures use DIVIDE (not `/`)
- [ ] All measures use CALCULATE with boolean filter (not FILTER())
- [ ] Variables (VAR) used in complex measures
- [ ] Comments explain purpose, formula, and dependencies
- [ ] Measure tables organized with `_` prefix groups
- [ ] Time intelligence uses DATEADD/DATESINPERIOD (not manual date offsets)
- [ ] EOM Snapshot filter pattern applied correctly
- [ ] No iterator functions used where CALCULATE suffices
- [ ] No `FILTER(ALL(...))` anti-pattern
- [ ] Context transition understood and documented
- [ ] DAX exported to `.dax` files and version controlled

## 13.4 Security

- [ ] RLS role created (TeamLead)
- [ ] RLS rule tested in "View as" mode
- [ ] RLS applied to all fact tables (not just one)
- [ ] USERPRINCIPALNAME() used (not USERNAME())
- [ ] Security mapping table created if needed
- [ ] Tested in Power BI Service with real user accounts
- [ ] Workspace roles assigned (Admin, Member, Viewer)
- [ ] Sensitivity label applied (Confidential – Financial Data)
- [ ] Export controls configured per page

## 13.5 Performance

- [ ] All visuals render < 2 seconds (Performance Analyzer)
- [ ] Query folding enabled for all Power Query steps
- [ ] High-cardinality columns binned or removed
- [ ] DAX Studio used to check SE CPU < 10K ms
- [ ] Incremental refresh considered for large tables
- [ ] Aggregations considered for fact tables > 5M rows
- [ ] Model size measured and documented

## 13.6 Documentation

- [ ] execution_guide.md complete (this file)
- [ ] kpi_definitions.md with all 11+ KPIs documented
- [ ] data_dictionary.md with table/column descriptions
- [ ] README.md with architecture diagram and quick start
- [ ] ROADME.md or CONTEXT.md with project status
- [ ] DAX measure documentation in .dax files
- [ ] Architecture diagram (image) in root directory
- [ ] Build plan documented (build_plan.md)

## 13.7 Deployment

- [ ] Gateway installed and configured
- [ ] Dataset refresh scheduled (daily 6 AM)
- [ ] DEV/UAT/PROD workspaces created
- [ ] Stakeholders added to appropriate workspace roles
- [ ] Pilot users trained
- [ ] Rollout announced
- [ ] Usage monitoring configured

## 13.8 Portfolio Readiness

- [ ] GitHub repo is public
- [ ] README includes architecture screenshot
- [ ] README includes "Quick Start" section
- [ ] README badges (Python, Power BI, PostgreSQL, Tests)
- [ ] Repo structure follows enterprise conventions
- [ ] All sensitive data removed or obfuscated
- [ ] .gitignore configured (ignores .env, raw/, output/)
- [ ] Top 3 dashboard screenshots included in portfolio
- [ ] Case study written (problem → approach → result)
- [ ] LinkedIn featured section updated with repo link

---

> **End of Execution Guide.**
>
> This document is intended as a comprehensive reference for building, deploying, and presenting an enterprise Power BI collections analytics environment. Every section builds on the previous — the folder structure enables the modeling, the modeling enables the DAX, the DAX enables the dashboards, and the dashboards tell the story.
>
> Build one section at a time. Verify each before moving to the next. The checklist at the end is your go-to for ensuring nothing was missed.
