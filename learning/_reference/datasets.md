# datasets.md — Where the data lives

This is the **shared data map** for the entire `learning/` environment. Every tool (SQL, Python, Notebooks, Excel, Power BI) draws from the **same datasets** — that is the point. When you master a metric in SQL, you will re-encounter the same numbers in Python, and then again in Power BI. Knowing *where* data comes from is the first skill.

> **Respect the data rules**
> - `data_sources/raw/` CSVs are **generated**. NEVER edit them. All tools only *read*.
> - The live database is PostgreSQL 15 in Docker. Connection params come from the root `.env` (git-ignored — never commit or paste credentials).
> - All KPI numbers you verify in SQL/Python later must match the project's own `v_` views — that consistency check is your training ground.

---

## 1. Two entry points, one source

| Entry point | What it holds | Used by |
|---|---|---|
| **PostgreSQL** `MSI_CollectionsDB` (localhost:5433) | 11 tables (star schema), ~1.8M rows, 13 KPI views | SQL (all levels), Notebooks (medium+), Power BI (import) |
| **Raw CSVs** `data_sources/raw/` | Same data, file-per-month layout, pre-DB | Python (all levels), Notebooks (basic), Excel (all levels) |

The CSVs and the DB are the **same content**. The ETL (`etl/data_to_pg.py`) loads CSVs → DB. This is by design: SQL exercises run on the DB; Python exercises read the CSVs. Identical answers = proof you understood both paths.

---

## 2. Folder layout of `data_sources/raw/`

```
data_sources/raw/
├── shared/                    ← dimension tables (one file each, full 12 months)
│   ├── Dim_Accounts.csv       (~15.5K accounts)
│   ├── Dim_Calendar.csv       (365 rows, full year 2025)
│   ├── Dim_Clients.csv        (10,000 clients)
│   ├── Dim_Employees.csv      (88 people: 8 supervisors + 80 agents)
│   └── Dim_Products.csv       (3 products)
├── january_2025/ ... december_2025/   ← fact tables, one folder per month
│   ├── Fact_Agent_Time_Log.csv
│   ├── Fact_EOM_Snapshot.csv
│   ├── Fact_Interactions.csv  (~1.36M rows across all months)
│   ├── Fact_Payments.csv
│   ├── Fact_PTP_Log.csv
│   └── Fact_Writeoffs.csv
└── anomaly_report.csv         (injected edge cases — do NOT treat as fact)
```

**Why month folders?** Real data warehouse teams partition hot transactional data by date — it makes incremental loads and scoped analysis feasible. You will learn to *recombine* these months yourself in the Python and Excel tracks.

---

## 3. Database tables (star schema)

| Table | Type | Grain | Row estimate (12 mo) | KEY columns |
|---|---|---|---|---|
| `dim_employees` | Dimension | 1 agent/supervisor | 88 | `agent_id`, `agent_name`, `employee_type`, `supervisor_id`, `team_name`, `region`, `hire_date`, `experience_tier`, `cost_per_hour`, `tenure_cohort`, `contact_skill`, `negotiation_skill`, `efficiency_skill` |
| `dim_clients` | Dimension | 1 client | 10,000 | `client_id`, `full_name`, `dob`, `segment`, `income_bracket`, `risk_score` |
| `dim_products` | Dimension | 1 product | 3 | `product_id`, `product_name`, `product_type`, `annual_rate_pct`, `grace_days`, `min_payment_rule` |
| `dim_calendar` | Dimension | 1 day | 365 | `date` (PK), `year`, `quarter`, `month_num`, `month_name`, `iso_week`, `day_of_week`, `day_name`, `is_weekday`, `is_month_end`, `is_payday_week`, `payday_factor` |
| `dim_accounts` | Dimension | 1 account | 15,482 | `account_id`, `client_id`, `product_id`, `product_type`, `open_date`, `credit_limit`, `due_day`, `min_payment`, `initial_balance`, `initial_status` |
| `fact_interactions` | Fact | 1 call row | 1,355,587 | `interaction_id`, `interaction_date`, `interaction_time`, `agent_id`, `account_id`, `calls_attempted`, `calls_connected`, `rpc_flag`, `call_outcome`, `channel`, `aht_seconds`, `acw_seconds`, `rpc_arrears`, `dpd_at_contact` |
| `fact_ptp_log` | Fact | 1 promise | 58,811 | `ptp_id`, `ptp_date`, `ptp_time`, `agent_id`, `account_id`, `promised_amount`, `promised_date`, `grace_until_date`, `status`, `rpc_arrears_at_contact` |
| `fact_payments` | Fact | 1 payment | 49,419 | `payment_id`, `payment_date`, `payment_time`, `account_id`, `ptp_id`, `agent_id`, `amount_paid`, `payment_method`, `is_cured`, `cure_flag`, `dpd_at_payment`, `balance_before/after`, `arrears_before/after`, `amount_to_arrears`, `amount_to_principal`, `dpd_after_payment` |
| `fact_agent_time_log` | Fact | 1 agent-day | 20,880 | `log_id`, `log_date`, `agent_id`, `login_time`, `logout_time`, `break_minutes`, `operational_hours`, `tht_hours`, `utilization`, `schedule_hours`, `cost_per_hour`, `total_cost` |
| `fact_eom_snapshot` | Fact | 1 account-month | 185,784 | `snapshot_date`, `snapshot_month`, `account_id`, `status`, `balance`, `arrears`, `dpd`, `dpd_bucket`, `min_payment` |
| `fact_writeoffs` | Fact | 1 write-off | 222 | `writeoff_id`, `writeoff_date`, `account_id`, `product_type`, `writeoff_amount`, `balance_before`, `dpd_at_writeoff` |

> **Naming rule (project convention, reproduced here):** `Dim_` = descriptive side of the star; `Fact_` = measurable/transactional side. You will rediscover *why* this matters when you first join a fact to two dims.

---

## 4. KPI views (the answer key you must reproduce)

These are the project's **reference implementations**. When your SQL/Python reproduces them, you are doing real analyst work — not toy exercises.

| View | Answers |
|---|---|
| `v_contact_metrics` | RPC%, connections, RPC/op-hr |
| `v_promise_metrics` | PTP%, KP%, bucket conversion (BB) |
| `v_recovery_metrics` | cure rate, cured accounts/amount |
| `v_productivity_metrics` | utilization% |
| `v_handle_time_metrics` | AHT/ACW by RPC status |
| `v_daily_mis` | the daily management information sheet (all core rates) |
| `v_monthly_summary` | monthly rollup at agent/team/portfolio level |
| `v_dpd_migration_matrix` | how accounts move across DPD buckets month-over-month |
| `v_weekly_agent_summary` | weekly agent-level KPIs |
| `v_etl_load_summary` | what was loaded when (data ops) |
| `v_data_freshness` | how recent the data is (data ops) |
| `v_rls_supervisor_map` | supervisor↔agent mapping (row-level security in PBIX) |
| `v_agent_scorecards` | composite weighted score (RPC 25% / KP 25% / Cure 20% / Util 15% / AHT 15%) |

---

## 5. Connecting (SQL track prerequisite)

The SQL track requires the DB running with data loaded:

```bash
docker-compose -f database/docker-compose.yml up -d   # start Postgres
./run_pipeline.bat                                     # generate + load data (if empty)
```

Connection (from `.env` at project root): `host=localhost`, `port=5433`, `db=MSI_CollectionsDB`. **Never hardcode or share credentials** — read them from `.env`, or use a client that sources them (DBeaver / pgAdmin can import `.env`-style params).

One-line psql smoke test (fills values from your `.env`):
```bash
PGPASSWORD=<password> psql -h localhost -p 5433 -U <user> -d MSI_CollectionsDB -c "SELECT COUNT(*) FROM fact_interactions;"
```
Expect ~1.36M. If you see 0, data isn't loaded — run the pipeline first.

---

## 6. Typical number ranges (so results "feel right")

| Metric | Healthy range (this portfolio) | Notes |
|---|---|---|
| RPC% | 35–60% | of connected calls reaching the account holder |
| PTP% | 5–40% | of RPCs that produce a promise (median ~15 on 12-mo data) |
| KP% (kept promise) | 65–90% | of evaluated promises honored |
| Utilization | 30–60% | operational ÷ scheduled hours |
| Cures / THT | 0.02–0.15 | cures per total-handle-time hour (median ~0.05) |
| ACW (RPC) | 80–180s | after-call work, RPC calls |

> Ranges calibrated on the full 12-month DB (Aug 2026). They are directional
> sanity checks for your outputs, not hard business targets.

---

## 7. Glossary quick-hit (full detail in `kpi_glossary.md`)

`RPC` = Right Party Contact · `PTP` = Promise To Pay · `KP` = Kept Promise · `Cure` = delinquent account brought current · `DPD` = Days Past Due · `THT` = Total Handle Time · `AHT` = Average Handle Time · `ACW` = After-Call Work · `BB Conversion` = PTP% × KP%.

---

## 8. Housekeeping for `learning/`

- **Your `work/` folders** are git-ignored (`learning/**/work/*`). Save every attempt there — never in the reference folders.
- `.ipynb_checkpoints/` is git-ignored project-wide (Jupyter auto-save noise).
- Follow the discipline from `../README.md` (master guide): attempt → review → then peek at `results.md`.