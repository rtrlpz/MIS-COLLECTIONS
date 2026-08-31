# mis-collections — Collections Analytics Portfolio

**Stack:** Python 3, PostgreSQL 15 (Docker), SQL, Power BI, openpyxl
**Root:** `/home/rtrlpz/projects-portfolio/mis-collections` (cross-platform: was `C:\Users\Leand\Desktop\Portafolio-Projects\mis-collections`)
**Conda env:** `mis-collections`

## Commands
- Generate data: `python data_sources/data_generator_v7.py`
- Start DB: `docker compose --env-file .env -f database/docker-compose.yml up -d`
- Run pipeline: `./run_pipeline.sh` (Linux/macOS) or `./run_pipeline.bat` (Windows CMD)
- Run migrations: `bash migrate.sh` (or `bash migrate.sh --fresh` for full rebuild)
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
| `data_sources/data_generator_v7.py` | Generator (P3/P4 engine: 12-mo, ~1.9M rows, strategy arms/SCD2/recoveries) |
| `data_sources/config.py` | 45+ calibration params (CFG + PRODUCT_CFG) |
| `data_sources/schema/dictionary.md` | Column-level docs |
| `database/docker-compose.yml` | Postgres 15 + pgAdmin |
| `database/migrations/001_create_tables.sql` | DDL: 16 tables (8 dim + 7 fact + etl_load_log) |
| `database/migrations/002_kpi_views.sql` | 15 KPI views (contact, promise, recovery, productivity, handle time, daily_mis, monthly, dpd_migration, weekly_agent, etl, freshness, rls_supervisor_map, promise_timeline, monthend_portfolio, writeoff_recovery) |
| `database/migrations/003_constraints.sql` | 15 CHECK constraints |
| `database/migrations/004_agents_scorecards.sql` | v_agent_scorecards (composite weighted: RPC 25%, KP 25%, Cure 20%, Util 15%, AHT 15%) |
| `database/migrations/005_indexes.sql` | 27 indexes |
| `database/migrations/006_comments.sql` | 63 COMMENT ON |
| `database/migrations/007_remove_post_writeoff_snapshots.sql` | One-time repair: charged-off accounts exit the EOM book (idempotent) |
| `database/migrations/008_dim_delinquency_bucket.sql` | Apply bucket dimension to existing DBs (create+seed+backfill+FK, idempotent) |
| `database/migrations/009_strategy_scd2.sql` | Apply strategy dim + SCD2 to existing DBs (hash-backfill 60/25/15, idempotent) |
| `database/migrations/010_fact_recoveries.sql` | Create fact_recoveries on existing DBs (empty until regen, idempotent) |
| `database/seeds/001_dim_products.sql` | 3 products (Tarjeta, Prestamo, Hipoteca) |
| `database/seeds/002_dim_calendar.sql` | 396 calendar rows (Dec 2024 + full year 2025) |
| `database/seeds/003_dim_delinquency_bucket.sql` | 5 ordered delinquency buckets (Current→90+) |
| `database/seeds/004_dim_calendar_extension.sql` | Jan–Mar 2026 rows (I3: covers PTP spill-over dates) |
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
| `dashboards/dax/collections_dax_v2.csv` | **148 active measures** (5 measure tables; 118 legacy TI retired to `legacy/`). Source of truth. |
| `dashboards/dax/legacy/time_intelligence_legacy.csv` | Retired v3.2: the 118 per-metric TI measures (superseded by the Calculation Group). Keep for reference; do not import. |
| `dashboards/dax/calculation_group_ti.json` | **_Time Intelligence** Calculation Group (18 items). Replaces 118 legacy TI measures. |
| `dashboards/dax/dax_targets_and_comparisons.md` | Goals & Targets patterns (31 measures documented) |
| `dashboards/dax/generate_dax_reference.py` | Script to regenerate dax_measures_all.md from CSV |
| `docs/dashboards/dax_measures_all.md` | Complete DAX reference (all 148 + 18 CG items as code blocks) |
| `docs/dashboards/legacy/dax_measures_dictionary.md` | Legacy v1 docs |
| `docs/dashboards/legacy/metrics_catalog_v1_may2026.md` | Archived May-2026 visual catalog (~93 placements, 5-page/74-DAX era, superseded by blueprint) |
| `docs/dashboards/legacy/context_may24_notes.md` | Archived May-24 Power BI session notes (from deleted feature/powerbi-dashboard branch) |
| `docs/dashboards/dashboard_blueprint.md` | **Page-by-page wireframe** (9 dashboards, 1920x1080 canvas, visual specs, field wells, DAX refs) |
| `docs/dashboards/dashboard_blueprint.pdf` | **PDF export** of blueprint (printable) |
| `docs/dashboards/PLAN_DASHBOARDS.pdf` | **PDF export** of 9-dashboard implementation plan |
| `dashboards/scripts/md_to_pdf.py` | Markdown to PDF converter script |
| `docs/PLAN_DASHBOARDS.md` | **9-dashboard implementation plan** (DAX coverage analysis per dashboard) |

### PBIX Files
| File | Status |
|---|---|
| `dashboards/pbix/collections_dashboard_v3.pbix` | Working dashboard (gitignored). v1.1: 25 tables (11 base + 6 measure + 2 calc `Dim_Targets`/`Color Reference` + 5 hidden date + 1 CG), 132 measures + 18-item CG, 0 measure errors. No RLS yet. |

### Dashboards Support
| File | Purpose |
|---|---|
| `dashboards/scripts/import_measures.cs` | C# script to bulk-import DAX measures into PBIX |
| `dashboards/scripts/prefix_removal.cs` | C# script for measure prefix cleanup |
| `dashboards/scripts/csv_to_tsv.py` | Utility to convert DAX CSV to TSV format |

### Testing Layer
| File | Content |
|---|---|
| `test/conftest.py` | Fixtures, METRIC_RANGES, GENERATOR_ROW_COUNTS(+_SMALL), `small_generated_data` session fixture, DB cursor |
| `test/test_qa_validation.py` | 73 tests (72 fast + 1 slow): data integrity, KPI views, metric ranges (bounds from conftest), migration-matrix regression |
| `test/test_generator.py` | 11 tests (9 fast + 2 slow): output, dual-fidelity row counts (3-mo fast / 12-mo canonical gate), reproducibility, 4 invariants (chronological month sort) |
### Key Docs
| File | Content |
|---|---|
| `docs/QUICKSTART.md` | 5-minute setup guide |
| `docs/TROUBLESHOOTING.md` | Docker/ETL error resolution |
| `docs/CHANGELOG.md` | Version history (0.1.0 → 1.6.3) |
| `docs/CONTEXT.md` | Full project context |
| `docs/KPI_VIEWS.md` | 13 of 16 KPI views documented (gap noted at top of file) |
| `docs/kpi_definitions.md` | 319-line KPI reference with formulas |
| `docs/data_dictionary.md` | Full column-level dictionary (16 tables) |
| `docs/executive_summary.md` | 1-page leadership summary |
| `CHANGELOG.md` | Version history (0.1.0 → 1.6.0) — see `docs/CHANGELOG.md` (canonical path) |
| `docs/README.md` | Documentation index (single entry point) |
| `docs/dashboards/execution_guide.md` | 2,499-line enterprise build guide (13 sections) |
| `docs/dashboards/mis_collections_build_plan.md` | 5-phase Power BI build plan |
| `docs/dashboards/reference_guide.html` | 1,555-line DAX + dashboard blueprint |
| `docs/dashboards/dashboard_blueprint.pdf` | Printable PDF of page-by-page wireframes (1920x1080) |
| `docs/dashboards/PLAN_DASHBOARDS.pdf` | Printable PDF of 9-dashboard implementation plan |
| `dashboards/theme/Tema 1.json` | Power BI theme (blue primary #262A76, Calibri) |

## Key Facts
- DB: localhost:5433, user=[REDACTED], password=[REDACTED], db=MIS_CollectionsDB
- Star schema: 8 dim tables (Employees/Clients/Products/Accounts/Calendar/DelinquencyBucket/Strategy/EmployeeHistory), 7 fact tables (Interactions/PTP/Payments/AgentTime/EOMSnapshot/Writeoffs/Recoveries) = 15 base tables + etl_load_log; 16 KPI views (15 in 002 incl. v_promise_timeline/v_monthend_portfolio/v_writeoff_recovery/v_dpd_migration_matrix/v_weekly_agent_summary/v_rls_supervisor_map, + v_agent_scorecards in 004)
- Dim_Employees: unified table (8 supervisors + 80 agents), self-ref FK, denormalized team/region/skills
- Dim_Accounts: includes denormalized `product_type` (avoids snowflake join to Dim_Products)
- Fact_Payments: `ptp_id` has no FK constraint (avoids fact-to-fact chain)
- Weekend bug FIXED: interactions Mon-Fri only, payments allowed on weekends
- **84 tests passing (81 fast + 3 slow, 0 failures)** — Hybrid C suite: ONE shared 3-month session generation (`--months 1,2,3` seed 42) feeds all fast generator tests; slow gates = canonical 12-month baseline validation, seed reproducibility (one extra small run), ETL idempotency
- **P1 audit hotfix (Aug 2026)**: v_agent_scorecards restored (migrate.sh now asserts view count post-run — 16 as of P4); written-off accounts exit the EOM book (generator skip + migration 007, −1,574 zombie rows); team/portfolio rollups are ratio-of-sums (util=ΣTHT/Σop-hrs, cure=Σcures/Σpayments, AHT/ACW from Σsecs/Σn — no AVG-of-rates); self-cure payments record true dpd_at_payment
- **P3 regenerated & verified (Aug 25, 2026)**: replenishment 0.0042 equilibrium holds (re-entry band 10.4–14.3%), G7 seasonality wired, strategy split 58.9/26.2/14.9 with efficacy multipliers biting (RPC by arm 37.7/32.2/28.0 — no longer flat), SCD2 history + 6 Jul-1 transfers live, calendar → Mar 2026 (486 rows)
- **P4 regenerated & verified (Aug 25, 2026)**: portfolio_cure_rate 56–76% vs prior Mora stock (view stores %), installment plans = 27.9% of kept promises multi-part, fact_recoveries live (323 rows, $39,949 recovered), Exited transitions = 413 in matrix. Targeted pytest runs MUST pair -k with -m "not slow" — name-only filters once matched the ETL idempotency test and reloaded old CSVs over repaired state
- migrate.sh runs with ON_ERROR_STOP + set -e and FAILS if view count ≠ 16 (prevents silent drift like the scorecard outage)
- Config calibrated May 2026 — 11 param changes + 2 new params (see CONTEXT.md Session Notes)
- SQL view fixes: cure count uses COUNT(DISTINCT account_id), BB Conversion uses kept_pct * ptp_pct / 100
- Monthly drift: ±8% per-agent rate drift each month (RPC% swings 38–67%)
- Generator CSV row counts validated at ±10% tolerance (seed 42 baseline, conftest single source of truth)
- Pipeline runs in ~157s end-to-end (12 months data)
- All 12 months (Jan-Dec 2025) loaded in PostgreSQL (1.8M rows)
- `.env` at project root (was database/.env)
- ETL at `etl/` (was database/etl/)
- **Phase 5** — Progressive severity (cure_count decay), other_pool restricted to ever-Mora accounts, utilization capped at 0.95
- **Phase 6** — 4 invariant tests: cure-flag completeness, PTP-payment consistency (per-plan, installment-aware), grace-period integrity, re-entry rate bounds (5-25%, chronological windows)
- **Phase 8.5** — G1-G9 complete: open_date spread, experience tiers, credit limits, income brackets, channel mix, write-offs, 12-month data, hire dates, agent cost model
- Dim_Calendar: 486 rows (Dec 2024 → Mar 2026, FK-ready for promise/grace spill-over)
- Generator seed 42 row counts (12mo): Interactions ~1.34M / PTP ~106K / Payments ~121K / Agent Time ~21K / EOM ~183K / Writeoffs ~441 / Recoveries ~323

## Learning Environment (`learning/`)
If asked about a task/skill material at `learning/`, follow these contracts (see `learning/README.md`; execution plan in `learning/_reference/REFACTOR_PLAN.md`):
- **Purpose:** practice lab aligned to the Collections MIS Analyst JD (`docs/unused/general_docs/mis analyst.docx`) — JD→track coverage map lives in REFACTOR_PLAN.md
- **Tracks:** `sql/` `python/` `notebooks/` `excel/` `powerbi/` × `basic/medium/advanced` (tasks.md + results.md + work/) + single-level `git-cli/`
- **tasks.md:** workplace-inbox scenario (sender/day/time/urgency), background, steps-with-why, guiding questions, data pointers into `_reference/`, explicit Done-When checklist. **NO code, NO expected numbers** — tasks must teach method, never expected results (lesson learned: a "Tarjeta dominates" hint contradicted real data)
- **results.md:** full worked approach + **complete executable code** (SQL/pandas/DAX/VBA) + verification recipe + traps/alternatives. **NO computed outputs or result tables** — give the code that should be written, not the numbers it prints
- **Answer-key discipline:** learner attempts in `work/`, then reads results.md; keep early attempts — the trail IS the progress log
- **Language:** English workplace voice throughout
- **Reference:** `_reference/` is copied (self-contained) per user choice; DB queries are a QA gate only, never a content source
- **Reproduce-from-scratch ethos:** learners re-derive the project's `v_*` KPI views in SQL/Python and audit against them; divergence = finding, not failure
- **House rules practiced in the track:** never commit `.env`/credentials, never edit generated CSVs, DAX measures CSV-first, RAG/targets from `_reference/kpi_glossary.md`
- **Ignored:** `learning/**/work/*` (keeps `.gitkeep`), `**/.ipynb_checkpoints/`; all `.md` tracked
- **Refactor (Aug 2026):** 7-phase rewrite per REFACTOR_PLAN.md (~95 JD-aligned tasks); phases land track-by-track with one commit each

## DAX v3.2 (148 active measures across 5 measure tables + 1 CG; 118 legacy TI retired)
- **Base measures (117)**: `_Outreach & Activity` (22), `_Promise & Recovery` (30), `_Portfolio Health` (34), `_Goals & Targets` (31)
- **Composites (31)**: `_Composites & Strategy` — scores, tiers, efficiency, credit risk, vintage + P3 strategy-arm attribution
- **Total: 148 active measures** (5 measure tables) + `_Time Intelligence` Calculation Group (18 items)
- **v3.1 corrections (Aug 2026)**: Agent Quality Score realigned to v_agent_scorecards weights (RPC25/KP25/Cure20/Util15/AHT15, AHT inverted vs 300s); Portfolio Health Score → renamed Portfolio Goal Achievement Index (goal-relative normalization vs Dim_Targets — old version had dead cure weight from /3 scaling); Coaching Alert now DATEADD(-7,DAY) (iso_week−1 broke on year boundary); Dialer Abandon Rate → Dialer Non-RPC Share % (old name measured connected-non-RPC, not abandonment); Cure Rate by Vintage denominator no longer ALL(Dim_Calendar)
- **v3.1 additions (Aug 2026, P3/P4 coverage)**: Cure Rate % base (parity with v_recovery_metrics); Strategy Arm Interactions/Mix %/Connect+RPC Lift vs Champion %; Recovered Amount/Recovery Events/Recovery Rate %/Net Write-off Position/Recoverable Outstanding (parity v_writeoff_recovery); Roll Rate Worsened/Improved % + Worst Active Bucket via Dim_Delinquency_Bucket severity (replaces hardcoded dpd_bucket labels); Portfolio Cure Rate % (mirrors v_monthend_portfolio: is_cured payments ÷ prior month-end Mora stock)
- **Time Intelligence**: legacy 118 TI measures RETIRED to `dashboards/dax/legacy/time_intelligence_legacy.csv` (v3.2); the `_Time Intelligence` Calculation Group (18 items) is the single TI mechanism — apply as slicer
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
> **Session note (2026-08-31):** Retired the stale `feature/powerbi-dashboard` branch — it was **48 commits behind `main`** with only one unique commit (May 2026: root `CONTEXT.md` + 5-page-era Spanish visual catalog). Archived both under `docs/dashboards/legacy/` (`metrics_catalog_v1_may2026.md`, `context_may24_notes.md`, DB creds stripped) and deleted the remote branch; repo is single-branch `main`. Rewrote root `README.md` into an interview-ready showcase (CHANGELOG 1.6.3): agent count **88 (8 supervisors + 80 agents)**, `docs/CHANGELOG.md` path, `docker compose --env-file .env`, real tree, and a "What Makes This Stand Out" section (12-mo/~1.8M-row, SCD2/strategy arms, 84-test Hybrid-C, 148 DAX + TI CG with RLS, three-tier analysis, governance). Docs only. **CI remains deliberately skipped** (meaningful pytest needs the full loaded-DB pipeline, ~20 min; the documented 84-test suite is the quality proof).
- Phase 9: Build Power BI dashboard (fresh PBIX, 9 pages, import mode, star schema, 148 DAX measures + TI calc group, RLS by supervisor) — **Blueprint ready** · guided execution plan saved at `docs/dashboards/PHASE9_EXECUTION_PLAN.md` (M0 prep pack builds when kickoff starts)
  - Import order: `_Outreach & Activity` → `_Promise & Recovery` → `_Portfolio Health` → `_Goals & Targets` → `_Composites & Strategy`; TI comes from `create_calc_group.cs` (legacy per-metric TI measures are retired — do NOT import them)
  - Run `create_calc_group.cs` in Tabular Editor after importing all measures
- Phase 10: Excel MIS report generator (openpyxl at `reports/generate_daily_mis.py`) — needs real MIS report layout study first
- Phase 11: Publish, user guide, handoff

## Reference
For full project context read: `docs/CONTEXT.md`
