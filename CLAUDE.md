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
| `dashboards/assets/dax/collections_dax_v2.csv` | **256 measures** (13 tables). Source of truth. Import into PBIX. |
| `dashboards/assets/dax/dax_targets_and_comparisons.md` | Goals & Targets patterns (31 measures documented) |
| `dashboards/assets/dax/collections_dax.csv` | Legacy v1 (73 measures, preserved as backup) |
| `dashboards/assets/dax/generate_dax_reference.py` | Script to regenerate dax_measures_all.md from CSV |
| `dashboards/assets/docs/dax_measures_dictionary_v2.md` | v2.2 full documentation (formulas, formats, dependencies) |
| `dashboards/assets/docs/dax_measures_all.md` | Complete DAX reference (all 256 as code blocks) |
| `dashboards/assets/docs/legacy/dax_measures_dictionary.md` | Legacy v1 docs |
| `dashboards/assets/docs/dashboard_blueprint.md` | **Page-by-page wireframe** (9 dashboards, 1920x1080 canvas, visual specs, field wells, DAX refs) |
| `dashboards/assets/docs/dashboard_blueprint.pdf` | **PDF export** of blueprint (printable) |
| `dashboards/assets/docs/PLAN_DASHBOARDS.pdf` | **PDF export** of 9-dashboard implementation plan |
| `dashboards/assets/docs/md_to_pdf.py` | Markdown to PDF converter script |
| `PLAN_DASHBOARDS.md` | **9-dashboard implementation plan** (DAX coverage analysis per dashboard) |

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
| `dashboards/assets/docs/dashboard_blueprint.pdf` | Printable PDF of page-by-page wireframes (1920x1080) |
| `dashboards/assets/docs/PLAN_DASHBOARDS.pdf` | Printable PDF of 9-dashboard implementation plan |
| `dashboards/assets/theme/Tema 1.json` | Power BI theme (blue primary #262A76, Calibri) |

## Key Facts
- DB: localhost:5433, user=[REDACTED], password=[REDACTED], db=MSI_CollectionsDB
- Star schema: 5 dim tables (Employees/Clients/Products/Accounts/Calendar), 6 fact tables (Interactions/PTP/Payments/AgentTime/EOMSnapshot/Writeoffs), 12 KPI views
- Dim_Employees: unified table (8 supervisors + 80 agents), self-ref FK, denormalized team/region/skills
- Dim_Accounts: includes denormalized `product_type` (avoids snowflake join to Dim_Products)
- Fact_Payments: `ptp_id` has no FK constraint (avoids fact-to-fact chain)
- Weekend bug FIXED: interactions Mon-Fri only, payments allowed on weekends
- 74 fast tests + 2 slow = 76 total passing (0 failures) — includes 4 Phase 6 invariant tests
- Config calibrated May 2026 — 11 param changes + 2 new params (see CONTEXT.md Session Notes)
- SQL view fixes: cure count uses COUNT(DISTINCT account_id), BB Conversion uses kept_pct * ptp_pct / 100
- Monthly drift: ±8% per-agent rate drift each month (RPC% swings 38–67%)
- Generator CSV row counts validated at ±5% tolerance (seed 42 baseline)
- Pipeline runs in ~157s end-to-end (12 months data)
- All 12 months (Jan-Dec 2025) loaded in PostgreSQL (1.8M rows)
- `.env` at project root (was database/.env)
- ETL at `etl/` (was database/etl/)
- **Phase 5** — Progressive severity (cure_count decay), other_pool restricted to ever-Mora accounts, utilization capped at 0.95
- **Phase 6** — 4 invariant tests: cure-flag completeness, PTP-payment consistency, grace-period integrity, re-entry rate bounds (10-25%)
- **Phase 8.5** — G1-G9 complete: open_date spread, experience tiers, credit limits, income brackets, channel mix, write-offs, 12-month data, hire dates, agent cost model
- Dim_Calendar: 365 rows (full year 2025)
- Generator seed 42 row counts (12mo): Interactions ~1.36M / PTP ~58K / Payments ~49K / Agent Time ~21K / EOM ~186K / Writeoffs ~222

## DAX v2.2 (256 measures across 13 tables)
- **Base (89)**: `_Outreach & Activity` (20), `_Promise & Conversion` (13), `_Recovery & Collection` (16), `_Portfolio Health` (23), `_Goals & Targets` (31 including 2 calc tables + 1 selected goal + 7 goals + 7 gaps + 7 status + 7 color)
- **Time Intelligence (120)**: MoM (36) + WoW (21) + DoD (21) + YoY (21) + OTC (21)
- **Dashboard-Specific (47)**: `_Executive` (3), `_Agent Performance` (6), `_Dialer Performance` (4), `_Portfolio Management` (3), `_Financial Recovery` (9), `_Vintage Analysis` (3), `_Roll Rate Analysis` (5)
- **Goal targets**: PTP% 80%, KP% 80%, ACW RPC 120s, ACW Non-RPC 25s, Capped KP/RPC Arrears 37%, Cures/THT 2.4, Utilization 90%
- **RAG colors**: Green #00B050, Amber #FFC000, Red #FF0000
- **2 calculated tables**: Dim_Targets (7 goals with thresholds), Color Reference (3 RAG hex codes)
- Legacy v1 preserved: `collections_dax.csv`, `docs/legacy/dax_measures_dictionary.md`
- CSV is **source of truth** — import into PBIX, do NOT author measures exclusively in PBIX
- **DAX coverage per dashboard**: Exec 95%, Agent 95%, Dialer 80%, Portfolio 95%, Ops 55%, Credit 80%, Financial 95%, Vintage 85%, Roll Rate 90%
- **Blueprint ready**: `dashboards/assets/docs/dashboard_blueprint.md` — page-by-page wireframes, visual specs, field wells, formatting
- **Blueprint PDF**: `dashboards/assets/docs/dashboard_blueprint.pdf` — printable PDF export
- **Plan PDF**: `dashboards/assets/docs/PLAN_DASHBOARDS.pdf` — printable implementation plan
- **4 schema gaps** (campaign, occupancy, login/logout, answered calls) — deferred

## Next Phase
- Phase 9: Build Power BI dashboard (fresh PBIX, 9 pages, import mode, star schema, 256 DAX measures, RLS by supervisor) — **Blueprint ready**
- Phase 10: Excel MIS report generator (openpyxl at `reports/generate_daily_mis.py`)
- Phase 11: Publish, user guide, handoff

## Reference
For full project context read: `CONTEXT.md`
