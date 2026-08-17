# MIS-COLLECTIONS — Collections Analytics Portfolio

**Stack:** Python 3, PostgreSQL 15 (Docker), SQL, Power BI, openpyxl
**Root:** `C:\Users\Leand\Desktop\Portafolio-Projects\MIS-COLLECTIONS`
**Conda env:** `mis-collections`

## Commands
- Generate data: `python data_sources/data_generator_v7.py`
- Start DB: `docker-compose -f database/docker-compose.yml up -d`
- Run pipeline: `./run_pipeline.bat` (Windows CMD)
- Run migrations: `bash database/migrate.sh`
- Run tests (fast): `python -m pytest test/ -v -m "not slow"`
- Run all tests: `python -m pytest test/ -v`

## Critical Rules (must follow)
- NEVER commit .env files, credentials, or secrets
- NEVER modify generated CSVs (data_sources/raw/)
- Table naming: Dim_ prefix for dimensions, Fact_ prefix for facts
- All SQL follows PostgreSQL dialect
- Tests use pytest with conftest.py fixtures
- DAX measures in CSV, NOT .pbix-first: CSV is source of truth, import into PBIX
- ANY file in `dashboards/dax/` is editable (defines all measures)

## Project File Map (key paths only)

### Data Layer
| File | Purpose |
|---|---|
| `data_sources/data_generator_v7.py` | Generator (11 tables, 500K+ rows, weekend-bug-fixed) |
| `data_sources/config.py` | 45+ calibration params (CFG + PRODUCT_CFG) |
| `data_sources/schema/dictionary.md` | Column-level docs |
| `database/docker-compose.yml` | Postgres 15 + pgAdmin |
| `database/migrations/001_create_tables.sql` | DDL: 11 tables (star schema) |
| `database/migrations/002_kpi_views.sql` | 12 KPI views (contact, promise, recovery, productivity, handle time, daily_mis, monthly, dpd_migration, weekly_agent, etl, freshness, rls_supervisor_map) |
| `database/migrations/003_constraints.sql` | 15 CHECK constraints |
| `database/migrations/004_agents_scorecards.sql` | v_agent_scorecards (composite weighted: RPC 25%, KP 25%, Cure 20%, Util 15%, AHT 15%) |
| `database/migrations/005_indexes.sql` | 27 indexes |
| `database/migrations/006_comments.sql` | 63 COMMENT ON |
| `database/seeds/001_dim_products.sql` | 3 products (Tarjeta, Prestamo, Hipoteca) |
| `database/seeds/002_dim_calendar.sql` | 365 calendar rows (full year 2025) |
| `etl/data_to_pg.py` | CSV → PostgreSQL (idempotent, incremental, transactional) |

### Analysis Layer (17 SQL files in `analysis/`)
| Directory | Files |
|---|---|
| `agent_level_operational_supervisors/` | agent_scorecard, agent_exception_report, coaching_opportunities, daily_agent_activity, eda_agents, schedule_adherence |
| `team_level_tactical_managers/` | team_comparison, agent_leaderboard, handle_time_benchmark, workload_distribution, campaign_effectiveness, eda_supervisors |
| `portfolio_level_strategic_directors/` | target_vs_actual, portfolio_concentration, recovery_trend_mom, roll_rate_analysis, portfolio_health |

### DAX Layer
| File | Content |
|---|---|---|
| `dashboards/dax/collections_dax_v2.csv` | **252 measures** (6 tables). Source of truth. Import into PBIX. |
| `dashboards/dax/calculation_group_ti.json` | **_Time Intelligence** Calculation Group (18 items). Replaces 118 legacy TI measures. |
| `dashboards/dax/dax_targets_and_comparisons.md` | Goals & Targets patterns (31 measures documented) |
| `dashboards/dax/generate_dax_reference.py` | Script to regenerate dax_measures_all.md from CSV |
| `docs/dashboards/dax_measures_all.md` | Complete DAX reference (all 252 + 18 CG items as code blocks) |
| `docs/dashboards/legacy/dax_measures_dictionary.md` | Legacy v1 docs |
| `docs/dashboards/dashboard_blueprint.md` | **Page-by-page wireframe** (9 dashboards, 1920x1080 canvas, visual specs, field wells, DAX refs) |
| `docs/dashboards/dashboard_blueprint.pdf` | **PDF export** of blueprint (printable) |
| `docs/dashboards/PLAN_DASHBOARDS.pdf` | **PDF export** of 9-dashboard implementation plan |
| `dashboards/scripts/md_to_pdf.py` | Markdown to PDF converter script |
| `docs/PLAN_DASHBOARDS.md` | **9-dashboard implementation plan** (DAX coverage analysis per dashboard) |

### PBIX Files
| File | Status |
|---|---|
| `dashboards/pbix/collections_dashboard_v3.pbix` | Working dashboard (gitignored) |

### Dashboards Support
| File | Purpose |
|---|---|
| `dashboards/scripts/import_measures.cs` | C# script to bulk-import DAX measures into PBIX |
| `dashboards/scripts/prefix_removal.cs` | C# script for measure prefix cleanup |
| `dashboards/scripts/csv_to_tsv.py` | Utility to convert DAX CSV to TSV format |

### Testing Layer
| File | Content |
|---|---|
| `test/conftest.py` | Fixtures, METRIC_RANGES, GENERATOR_ROW_COUNTS, DB cursor |
| `test/test_qa_validation.py` | 68 tests (66 fast + 2 slow): data integrity, KPI views, metric ranges, migration-matrix regression |
| `test/test_generator.py` | 10 tests: generator output, row counts, reproducibility, 4 invariant tests |

### Key Docs
| File | Content |
|---|---|
| `docs/QUICKSTART.md` | 5-minute setup guide |
| `docs/TROUBLESHOOTING.md` | Docker/ETL error resolution |
| `docs/CHANGELOG.md` | Version history (0.1.0 → 1.0.0) |
| `docs/CONTEXT.md` | Full project context |
| `docs/KPI_VIEWS.md` | All 13 KPI views documented |
| `docs/kpi_definitions.md` | 319-line KPI reference with formulas |
| `docs/data_dictionary.md` | Full column-level dictionary |
| `docs/executive_summary.md` | 1-page leadership summary |
| `CHANGELOG.md` | Version history (0.1.0 → 1.0.0) |
| `docs/README.md` | Documentation index (single entry point) |
| `docs/dashboards/execution_guide.md` | 2,499-line enterprise build guide (13 sections) |
| `docs/dashboards/mis_collections_build_plan.md` | 5-phase Power BI build plan |
| `docs/dashboards/reference_guide.html` | 1,555-line DAX + dashboard blueprint |
| `docs/dashboards/dashboard_blueprint.pdf` | Printable PDF of page-by-page wireframes (1920x1080) |
| `docs/dashboards/PLAN_DASHBOARDS.pdf` | Printable PDF of 9-dashboard implementation plan |
| `dashboards/theme/Tema 1.json` | Power BI theme (blue primary #262A76, Calibri) |

## Key Facts
- DB: localhost:5433, user=[REDACTED], password=[REDACTED], db=MSI_CollectionsDB
- Star schema: 5 dim tables (Employees/Clients/Products/Accounts/Calendar), 6 fact tables (Interactions/PTP/Payments/AgentTime/EOMSnapshot/Writeoffs), 13 KPI views (12 in 002_kpi_views.sql incl. v_rls_supervisor_map, + v_agent_scorecards in 004)
- Dim_Employees: unified table (8 supervisors + 80 agents), self-ref FK, denormalized team/region/skills
- Dim_Accounts: includes denormalized `product_type` (avoids snowflake join to Dim_Products)
- Fact_Payments: `ptp_id` has no FK constraint (avoids fact-to-fact chain)
- Weekend bug FIXED: interactions Mon-Fri only, payments allowed on weekends
- 76 fast tests + 2 slow = 78 total passing (0 failures) — includes 4 Phase 6 invariant tests + 3 migration-matrix regression tests
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

## Learning Environment (`learning/`)
If asked about a task/skill material at `learning/`, follow these contracts (see `learning/README.md`):
- **Tracks:** `sql/` `python/` `notebooks/` `excel/` `powerbi/` × `basic/medium/advanced` (tasks.md + results.md + work/) + single-level `git-cli/`
- **tasks.md:** scenario + steps-with-why + guiding questions + conceptual checks. **NO code, NO numbers** — tasks must teach method, never expected results (lesson learned: a "Tarjeta dominates" hint contradicted real data)
- **results.md:** guidance-only — reasoning path, steps-with-why, verification strategy, traps/alternatives. No full runnable solutions, no computed outputs. Syntax fragments ONLY where syntax is the lesson
- **Answer-key discipline:** learner attempts in `work/`, then peeks at results.md
- **Reference:** `_reference/` is copied (self-contained) per user choice; DB queries are a QA gate only, never a content source
- **Reproduce-from-scratch ethos:** learners re-derive the project's `v_*` KPI views in SQL/Python and audit against them; divergence = finding, not failure
- **House rules practiced in the track:** never commit `.env`/credentials, never edit generated CSVs, DAX measures CSV-first, RAG/targets from `_reference/kpi_glossary.md`
- **Ignored:** `learning/**/work/*` (keeps `.gitkeep`), `**/.ipynb_checkpoints/`; all `.md` tracked

## DAX v3.0 (252 measures across 6 tables + 1 CG)
- **Base (107)**: `_Outreach & Activity` (22), `_Promise & Recovery` (29), `_Portfolio Health` (25), `_Goals & Targets` (31)
- **Composites (27)**: `_Composites & Strategy` — all unique composites (scores, tiers, efficiency, credit risk, vintage)
- **Time Intelligence (118 legacy + 1 CG)**: `_Time Intelligence` table (118 measures for backward compatibility) + `_Time Intelligence` Calculation Group (18 items — replaces all 118)
- **Deduplicated**: 6 exact duplicates removed (Agent RPC per Hour, Agent KP Rate, Dialer Connection Rate, Mora Balance Rate, Agent-Assisted Cure Rate, Monthly Recovery Rate)
- **Expression fixes**: 47 triple-quote expressions cleaned, AHT/ACW column reference bug fixed, Income Segment VALUES→SELECTEDVALUE
- **Goal targets**: PTP% 80%, KP% 80%, ACW RPC 120s, ACW Non-RPC 25s, Capped KP/RPC Arrears 37%, Cures/THT 2.4, Utilization 90%
- **RAG colors**: Green #00B050, Amber #FFC000, Red #FF0000
- **2 calculated tables**: Dim_Targets (7 goals with thresholds), Color Reference (3 RAG hex codes)
- Legacy v1 preserved: `docs/dashboards/legacy/dax_measures_dictionary.md`
- CSV is **source of truth** — import into PBIX, do NOT author measures exclusively in PBIX
- **DAX coverage per dashboard**: Exec 95%, Agent 95%, Dialer 80%, Portfolio 95%, Ops 55%, Credit 80%, Financial 95%, Vintage 85%, Roll Rate 90%
- **Blueprint ready**: `docs/dashboards/dashboard_blueprint.md` — page-by-page wireframes, visual specs, field wells, DAX refs
- **4 schema gaps** (campaign, occupancy, login/logout, answered calls) — deferred
- **Calculation Group**: `_Time Intelligence` CG defined in `calculation_group_ti.json` — apply as slicer to any base measure. Creates via `create_calc_group.cs` in Tabular Editor.

## Next Phase
- Phase 9: Build Power BI dashboard (fresh PBIX, 9 pages, import mode, star schema, 252 DAX measures + CG, RLS by supervisor) — **Blueprint ready**
  - Import order: `_Outreach & Activity` → `_Promise & Recovery` → `_Portfolio Health` → `_Goals & Targets` → `_Composites & Strategy` → `_Time Intelligence` (legacy, then delete after CG verified)
  - Run `create_calc_group.cs` in Tabular Editor after importing all measures
- Phase 10: Excel MIS report generator (openpyxl at `reports/generate_daily_mis.py`) — needs real MIS report layout study first
- Phase 11: Publish, user guide, handoff

## Reference
For full project context read: `docs/CONTEXT.md`
