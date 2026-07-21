# MIS-COLLECTIONS — Collections Analytics Portfolio

**Stack:** Python 3, PostgreSQL 15 (Docker), SQL, Power BI, openpyxl
**Root:** `C:\Users\Leand\Desktop\Portafolio-Projects\MIS-COLLECTIONS`
**Conda env:** `mis-collections`

## Commands
- Generate data: `python data_sources/generators/data_generator_v7.py`
- Start DB: `docker-compose -f database/docker-compose.yml up -d`
- Run pipeline: `./run_pipeline.bat` (Windows CMD)
- Run migrations: `bash migrate.sh`
- Run tests (fast): `python -m pytest test/ -v -m "not slow"`
- Run all tests: `python -m pytest test/ -v`

## Critical Rules (must follow)
- NEVER commit .env files, credentials, or secrets
- NEVER modify generated CSVs (data_sources/generators/raw/)
- Table naming: Dim_ prefix for dimensions, Fact_ prefix for facts
- All SQL follows PostgreSQL dialect
- Tests use pytest with conftest.py fixtures
- DAX measures in CSV, NOT .pbix-first: CSV is source of truth, import into PBIX
- ANY file in `dashboards/assets/dax/` is editable (defines all measures)

## Project File Map (key paths only)

### Data Layer
| File | Purpose |
|---|---|
| `data_sources/generators/data_generator_v7.py` | Generator (11 tables, 500K+ rows, weekend-bug-fixed) |
| `data_sources/generators/config.py` | 45+ calibration params (CFG + PRODUCT_CFG) |
| `data_sources/schema/dictionary.md` | Column-level docs |
| `database/docker-compose.yml` | Postgres 15 + pgAdmin |
| `database/migrations/001_create_tables.sql` | DDL: 11 tables (star schema) |
| `database/migrations/002_kpi_views.sql` | 9 KPI views (contact, promise, recovery, productivity, handle time, daily_mis, monthly, etl, freshness) |
| `database/migrations/003_constraints.sql` | 15 CHECK constraints |
| `database/migrations/004_agents_scorecards.sql` | v_agent_scorecards (composite weighted: RPC 25%, KP 25%, Cure 20%, Util 15%, AHT 15%) |
| `database/migrations/005_indexes.sql` | 27 indexes |
| `database/migrations/006_comments.sql` | 63 COMMENT ON |
| `database/seeds/001_dim_products.sql` | 3 products (Tarjeta, Prestamo, Hipoteca) |
| `database/seeds/002_dim_calendar.sql` | 365 calendar rows (full year 2025) |
| `etl/data_to_pg.py` | CSV → PostgreSQL (idempotent, incremental, transactional) |

### Analysis Layer (17 SQL files in `analysis/sql/`)
| Directory | Files |
|---|---|
| `agent_level_operational_supervisors/` | agent_scorecard, agent_exception_report, coaching_opportunities, daily_agent_activity, eda_agents, schedule_adherence |
| `team_level_tactical_managers/` | team_comparison, agent_leaderboard, handle_time_benchmark, workload_distribution, campaign_effectiveness, eda_supervisors |
| `portfolio_level_strategic_directors/` | target_vs_actual, portfolio_concentration, recovery_trend_mom, roll_rate_analysis, portfolio_health |

### DAX Layer
| File | Content |
|---|---|
| `dashboards/assets/dax/collections_dax_v2.csv` | **207 measures** (87 base + 120 targets/comparisons). Source of truth. Import into PBIX. |
| `dashboards/assets/dax/dax_targets_and_comparisons.md` | **120 NEW measures**: 29 goals/targets, 91 time intelligence (MoM/WoW/DoD/YoY/OTC). 91 NOT in CSV yet. |
| `dashboards/assets/dax/collections_dax.csv` | Legacy v1 (73 measures, preserved as backup) |
| `dashboards/assets/docs/dax_measures_dictionary_v2.md` | Full v2.1 documentation (formulas, formats, dependencies) |
| `dashboards/assets/docs/legacy/dax_measures_dictionary.md` | Legacy v1 docs |
| `PLAN_DASHBOARDS.md` | **9-dashboard implementation plan** (320 DAX measures target, G1-G9 generator changes, schema updates) |

### PBIX Files
| File | Status |
|---|---|
| `dashboards/collections_project/collections_dashboard_v4.pbix` | Latest iteration (build plan says START FRESH, don't modify) |
| `dashboards/collections_project/collections_dashboard_v3.pbix` | Legacy |
| `dashboards/collections_project/collections_dashboard_v2.pbix` | Legacy (8.9 MB) |

### Testing Layer
| File | Content |
|---|---|
| `test/conftest.py` | Fixtures, METRIC_RANGES, GENERATOR_ROW_COUNTS, DB cursor |
| `test/qa_validation.py` | 66 tests (64 fast + 2 slow): data integrity, KPI views, metric ranges |
| `test/test_generator.py` | 10 tests: generator output, row counts, reproducibility, 4 invariant tests |

### Key Docs
| File | Content |
|---|---|
| `docs/kpi_definitions.md` | 319-line KPI reference with formulas |
| `docs/data_dictionary.md` | Full column-level dictionary |
| `docs/executive_summary.md` | 1-page leadership summary |
| `dashboards/assets/docs/execution_guide.md` | 2,499-line enterprise build guide (13 sections) |
| `dashboards/assets/docs/mis_collections_build_plan.md` | 5-phase Power BI build plan |
| `dashboards/assets/docs/reference_guide.html` | 1,555-line DAX + dashboard blueprint |
| `dashboards/assets/theme/Tema 1.json` | Power BI theme (blue primary #262A76, Calibri) |

## Key Facts
- DB: localhost:5433, user=[REDACTED], password=[REDACTED], db=MSI_CollectionsDB
- Star schema: 6 dim tables (Supervisors/Agents/Clients/Products/Accounts/Calendar), 5 fact tables (Interactions/PTP/Payments/AgentTime/EOMSnapshot), 9 KPI views
- Weekend bug FIXED: interactions Mon-Fri only, payments allowed on weekends
- 74 fast tests + 2 slow = 76 total passing (0 failures) — includes 4 Phase 6 invariant tests
- Config calibrated May 2026 — 11 param changes + 2 new params (see CONTEXT.md Session Notes)
- SQL view fixes: cure count uses COUNT(DISTINCT account_id), BB Conversion uses kept_pct * ptp_pct / 100
- Monthly drift: ±8% per-agent rate drift each month (RPC% swings 38–67%)
- Generator CSV row counts validated at ±5% tolerance (seed 42 baseline)
- Pipeline runs in ~157s end-to-end (3 months data)
- All 3 months (Oct-Dec 2025) loaded in PostgreSQL
- `.env` at project root (was database/.env)
- ETL at `etl/` (was database/etl/)
- **Phase 5** — Progressive severity (cure_count decay), other_pool restricted to ever-Mora accounts, utilization capped at 0.95
- **Phase 6** — 4 invariant tests: cure-flag completeness, PTP-payment consistency, grace-period integrity, re-entry rate bounds (10-25%)
- Dim_Calendar: 122 rows (Sep–Dec 2025 generated) / 365 rows (seed for full year)
- Generator seed 42 row counts: Interactions 342,996 / PTP 22,150 / Payments 19,504 / Agent Time 5,280 / EOM 46,701

## DAX v2 (207 measures → target 320)
- **Base (87)**: `collections_dax_v2.csv` — 5 tables (Outreach 20, Promise 13, Recovery 16, Portfolio 20, Time Intel 18)
- **Targets & Comparisons (120)**: `dax_targets_and_comparisons.md` — 29 goals/RAG measures + 91 time intel (MoM/WoW/DoD/YoY/OTC)
- **Goal targets**: PTP% 80%, KP% 80%, ACW RPC 120s, ACW Non-RPC 25s, Capped KP/RPC Arrears 37%, Cures/THT 2.4, Utilization 90%
- **RAG colors**: Green #00B050, Amber #FFC000, Red #FF0000
- **2 calculated tables**: Dim_Targets (7 goals with thresholds), Color Reference (3 RAG hex codes)
- **Pending**: 91 time intel measures not yet in CSV + 22 new dashboard-specific measures = +113 measures
- Legacy v1 preserved: `collections_dax.csv`, `docs/legacy/dax_measures_dictionary.md`
- CSV is **source of truth** — import into PBIX, do NOT author measures exclusively in PBIX

## Next Phase
- Phase 8.5: Generator + Schema enhancements (G1-G9, 12-month data, new columns/tables/views)
- Phase 9: Build Power BI dashboard (fresh PBIX, 9 pages, import mode, star schema, ~320 DAX measures, RLS by supervisor)
- Phase 10: Excel MIS report generator (openpyxl at `reports/generate_daily_mis.py`)
- Phase 11: Publish, user guide, handoff

## Reference
For full project context read: `CONTEXT.md`
