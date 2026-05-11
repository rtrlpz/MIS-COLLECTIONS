# Project Roadmap — Collections Analytics Portfolio

> **Current Completeness: ~82%** | Last updated: 2026-05-07
>
> Phases 1–7: **100% Complete** | Phase 8: **~50%** | Phase 9: **Plan Ready, Build Pending**

---

## Status Summary

| Phase | Description | Status | What's Left |
| :--- | :--- | :--- | :--- |
| **1** | Data Generation | ✅ 100% | Weekend bug fix (optional, creates 25K weekend rows) |
| **2** | ETL Pipeline | ✅ 100% | Maintenance only |
| **3/5** | DB Schema + KPI Views | ✅ 100% | Maintenance only |
| **4** | Analysis SQL (17 files) | ✅ 100% | None |
| **6** | Testing | ✅ 100% | None |
| **7** | Automation | ✅ 100% | None |
| **8** | Documentation | 🟡 ~50% | See Phase 8 below |
| **9** | BI / Reporting | 🔵 ~10% | Build dashboards + Excel script per build plan |

---

## PHASE 1 — Data Generation ✅ COMPLETE

- [x] `--output-dir` and `--months` CLI parameters
- [x] `--seed` flag for reproducibility
- [x] CSV headers with ISO 8601 dates, consistent decimals
- [x] Generator logging (console + file, timestamps, row counts, elapsed time, log-level arg)
- [x] Output validation post-generation (row counts ±5%, no null PKs, FK integrity)
- [x] `data_sources/__init__.py` (Python package)
- [x] `data_sources/generators/config.py` (centralized constants: CFG, PRODUCT_CFG)
- [x] Anomaly injection report (`anomaly_report.csv`, ~9,117 anomalies)
- [x] `requirements.txt` with pinned versions
- [x] `data_sources/generators/README.md`
- [x] Output: ~506K interactions, ~31K PTP events, ~21K payments across 3 months

> **Known issue:** `data_generator_v7.py` does not filter weekend dates, creating ~25,786 weekend interactions despite `Dim_Calendar.is_weekday = FALSE`. Fix exists in CONTEXT.md as a known bug — generator patch is optional since weekend rows don't break KPIs.

---

## PHASE 2 — ETL Pipeline ✅ COMPLETE

- [x] Logging (INFO/ERROR with timestamps, file + console handlers)
- [x] `validate_csv()` — PK validation, row count, headers
- [x] Transaction wrapping (single transaction with atomicity)
- [x] Idempotency (`TRUNCATE CASCADE` before full load)
- [x] `etl_load_log` metadata table (table_name, rows_loaded, loaded_at, status, csv_checksum)
- [x] CSV SHA256 checksum verification (stored in `etl_load_log`)
- [x] `--env-file` flag for environment variables
- [x] `--dry-run` flag (validate without DB connection, exit 0/1)
- [x] `--incremental` flag (skip already-loaded months via fact_interactions query)
- [x] Retry logic (3 connection attempts, 5-second sleep)
- [x] Error recovery (savepoints per table, writes `errors/<table>_errors.csv`)
- [x] Per-table and total elapsed time tracking
- [x] Pipeline orchestration via `run_pipeline.bat`

---

## PHASE 3/5 — Database Schema & KPI Views ✅ COMPLETE

### KPI Views (9 views in `002_kpi_views.sql`)
- [x] `v_contact_metrics` — RPC, RPC%, RPC/OpHr, RPC Arrears (agent/day, team/day, month)
- [x] `v_promise_metrics` — PTP count, PTP%, Kept/Broken count, KP% (agent/day, team/day, month)
- [x] `v_recovery_metrics` — Cures, cured amount, cure rate, agent vs self-cure (4 granularities)
- [x] `v_productivity_metrics` — Utilization%, contacts/agent/hour
- [x] `v_handle_time_metrics` — AHT-RPC, AHT-NonRPC, ACW-RPC, ACW-NonRPC
- [x] `v_daily_mis` — Consolidated daily view combining all 5 KPI categories
- [x] `v_monthly_summary` — Month-level rollup (agent, team, portfolio granularities)
- [x] `v_etl_load_summary` — Latest ETL load per table with data freshness
- [x] `v_data_freshness` — Days since each fact table was last updated

### Database Hardening
- [x] `003_constraints.sql` — 15 CHECK constraints (idempotent DO blocks)
- [x] `004_agents_scorecards.sql` — `v_agent_scorecards` with composite weighted scoring
- [x] `005_indexes.sql` — 27 indexes (16 FK/date + 5 single-column + 6 composite)
- [x] `006_comments.sql` — 63 COMMENT ON statements for all 11 tables and columns
- [x] `seeds/001_dim_products.sql` — 3 product seed rows (`ON CONFLICT DO NOTHING`)
- [x] `seeds/002_dim_calendar.sql` — 92 calendar rows (Oct–Dec 2025)

---

## PHASE 4 — Analysis SQL ✅ COMPLETE (17 of 17 files)

### Agent Level — Operational / Supervisors (6 files)
- [x] `coaching_opportunities.sql` — WoW metric drops (RPC%, KP%, Utilization%)
- [x] `schedule_adherence.sql` — Hourly gap detection vs expected schedule
- [x] `eda_agents.sql` — Distribution analysis, histograms, team consistency ratings
- [x] `daily_agent_activity.sql` — Per-agent daily totals + 7-day moving averages
- [x] `agent_scorecard.sql` — Composite weighted score + rank within team
- [x] `agent_exception_report.sql` — Top/bottom 5% outliers (RPC%, AHT, PTP Kept%)

### Team Level — Tactical / Managers (6 files)
- [x] `team_comparison.sql` — Side-by-side monthly metrics + std dev from portfolio avg
- [x] `agent_leaderboard.sql` — Top/bottom 10 agents by composite score, MoM rank changes
- [x] `handle_time_benchmark.sql` — AHT by product/agent/region vs SLA targets (300s/60s)
- [x] `workload_distribution.sql` — Accounts/calls per agent, z-score from team mean (>2σ outlier)
- [x] `campaign_effectiveness.sql` — Contact frequency vs RPC% scatter prep + hourly PTP conversion
- [x] `eda_supervisors.sql` — Team performance, team size correlation, regional comparison

### Portfolio Level — Strategic / Directors (5 files)
- [x] `target_vs_actual.sql` — KPI targets vs actuals with gap analysis (RPC%≥65, PTP%≥70, KP%≥60, Cure≥25)
- [x] `portfolio_concentration.sql` — Top 10% balance concentration, product risk, segment proxy
- [x] `recovery_trend_mom.sql` — MoM cures, cure rates, cost-to-collect proxy, seasonal patterns
- [x] `roll_rate_analysis.sql` — DPD migration matrix (Current → 1-30 → 31-60 → 61-90 → 90+)
- [x] `portfolio_health.sql` — DPD bucket %, cure rate by product, arrears trend MoM

---

## PHASE 6 — Testing ✅ COMPLETE

### Test Files Created
- [x] `test/conftest.py` (141 lines) — Pytest fixtures: DB cursor, table metadata, PK/FK mappings, KPI views, custom `slow` mark
- [x] `test/qa_validation.py` (293 lines) — 11 data integrity tests
- [x] `test/test_generator.py` (136 lines) — Generator unit tests
- [x] `test/test_kpi_views.sql` (168 lines) — SQL validation queries for KPI views
- [x] `test/README.md` — Test documentation

### QA Validation Tests (9 fast + 2 slow)
| # | Test Class | Validates | Status |
| :--- | :--- | :--- | :--- |
| 1 | `TestRowCounts` | Dim_Agents=80, Dim_Clients=10000, Dim_Accounts~15575 ±5% | ✅ Pass |
| 2 | `TestNoNullPKs` | No nulls in PK columns across all 11 tables | ✅ Pass |
| 3 | `TestFKIntegrity` | 16 FK relationships have no orphans | ✅ Pass |
| 4 | `TestDateRanges` | Fact dates within Oct–Dec 2025, calendar covers full period | ✅ Pass |
| 5 | `TestWeekdayOnly` | No interactions on weekends | ⚠️ XFAIL (known bug) |
| 6 | `TestDPDLogic` | DPD >= 0 in fact_interactions, fact_payments, fact_eom_snapshot | ✅ Pass |
| 7 | `TestUtilizationBounds` | Utilization between 0 and 100 | ✅ Pass |
| 8 | `TestCallDuration` | AHT > 0s, max < 3600s | ✅ Pass |
| 9 | `TestKPIViewOutput` | All 9 views return rows, percentage columns in 0–100 | ✅ Pass |
| 10 | `TestETLIdempotency` | Running ETL twice = same row counts (slow) | ✅ Pass |
| 11 | `TestGeneratorSeed` | Same seed produces identical CSV checksums (slow) | ✅ Pass |

### Generator Unit Tests (test_generator.py)
| # | Test Class | Validates |
| :--- | :--- | :--- |
| 1 | `TestGeneratorOutput` | Generator exists, `--help` works, produces CSVs with correct structure |
| 2 | `TestGeneratorReproducibility` | Seed 42 produces identical output across two runs |
| 3 | `TestGeneratorDataQuality` | No null PKs in generated CSVs across all dimension tables |

### Run Tests
```bash
# Fast tests only (excludes ETL idempotency + generator seed reproducibility)
/c/Users/Leand/.conda/envs/mis-collections/python -m pytest test/ -v -m "not slow"

# All tests (includes ~2 min slow tests)
/c/Users/Leand/.conda/envs/mis-collections/python -m pytest test/ -v
```

---

## PHASE 7 — Automation ✅ COMPLETE

- [x] `run_pipeline.bat` (125 lines) — Docker check → start containers → wait for PostgreSQL → migrations → generate data → ETL → colored output → timing per stage
- [x] COLOR bug fixed (trailing colons removed)
- [x] Pipeline runs end-to-end in ~83 seconds
- [x] `migrate.sh` (47 lines) — Runs all SQL migrations via `cat file.sql | docker exec -i psql`
- [x] Exit codes per stage for error propagation

---

## PHASE 8 — Documentation 🟡 ~50% Complete

- [x] `CONTEXT.md` — Single-source project overview for AI-assisted development
- [x] `README.md` — Project overview & interview pitch
- [x] `docs/executive_summary.md` — One-page leadership summary
- [x] `docs/kpi_definitions.md` — 319-line comprehensive KPI reference
- [x] `docs/data_dictionary.md` — Full data dictionary (10 tables)
- [x] `docs/execution_guide.md` — Granular task instructions
- [x] `data_sources/schema/dictionary.md` — Column-level docs for all tables
- [x] `dashboards/assets/reference_guide.html` — 994-line DAX + dashboard blueprint reference
- [x] `dashboards/assets/dax_measures_dictionary.md` — 73 DAX measures (type-safe, Cured Amounts added)
- [x] `dashboards/assets/mis_collections_build_plan.md` — 396-line build plan for Phases 8–9

- [ ] `QUICKSTART.md` — 5-minute setup (prerequisites + 3 commands)
- [ ] `TROUBLESHOOTING.md` — Docker errors, port conflicts, ETL failures, DB reset
- [ ] `CHANGELOG.md` — Version history
- [ ] Readme status badges (Build, Tests, Last Updated)
- [ ] KPI view documentation (what each view calculates, source tables, example queries)
- [ ] Data lineage diagram (generator → CSV → ETL → PostgreSQL → views → BI)

---

## PHASE 9 — BI / Reporting 🔵 Plan Ready, Build Pending

### Build Plan Complete
- [x] `dashboards/assets/mis_collections_build_plan.md` — 10-day build plan with phases, designs, requirements
- [x] Architecture defined: single .pbix, 5 pages, 3 Excel sheets
- [x] 73 DAX measures documented in `dax_measures_dictionary.md` (type-safe, Cured Amounts added)
- [x] 5 dashboard page designs with visual-by-visual layout specs
- [x] Excel report design (3-sheet workbook, Python openpyxl)

### Build — Pending
- [ ] Import data model into Power BI (star schema, 11 tables)
- [ ] Implement all DAX measures in 3 measure tables
- [ ] Build Page 1 — Executive Overview (KPI cards, trend lines, waterfall, treemap)
- [ ] Build Page 2 — Agent Scorecard (conditional table, gauges, coaching alerts)
- [ ] Build Page 3 — Team Leaderboard (scatter, box plot, z-score table)
- [ ] Build Page 4 — Portfolio Health (arrears line, Sankey, concentration treemap)
- [ ] Build Page 5 — Promise Intelligence (KP% by DPD, PTP%/KP% matrix, heatmap)
- [ ] Add RLS by supervisor_id
- [ ] Publish to Power BI Service
- [ ] `reports/generate_daily_mis.py` — Python script for Excel generation
- [ ] Generate sample Excel reports for Oct–Dec 2025
- [ ] Validate DAX measures match SQL view outputs
- [ ] Dashboard screenshots for documentation

---

*Last updated: 2026-05-07*
