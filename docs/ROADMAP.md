# Project Roadmap — Collections Analytics Portfolio

> **Current Completeness: ~90%** | Last updated: 2026-08-31
>
> Phases 1–7: **100% Complete** | Phase 8: **~85%** | Phase 8.5: **100% Complete** | Phase 9: **Blueprint Ready (9 dashboards)**

---

## Status Summary

| Phase | Description | Status | What's Left |
| :--- | :--- | :--- | :--- |
| **1** | Data Generation | ✅ 100% | None |
| **2** | ETL Pipeline | ✅ 100% | Maintenance only |
| **3/5** | DB Schema + KPI Views | ✅ 100% | Maintenance only |
| **4** | Analysis SQL (17 files) | ✅ 100% | None |
| **5** | Generator Enhancements | ✅ 100% | Progressive severity, monitoring pool, utilization cap |
| **6** | Testing | ✅ 100% | 4 invariant tests added (cure-flag, PTP, grace, re-entry) |
| **7** | Automation | ✅ 100% | None |
| **8** | Documentation | 🟡 ~85% | DAX v3 docs + PLAN_DASHBOARDS + CHANGELOG 1.6.0 done; execution_guide/reference_guide partially historical |
| **8.5** | Generator + Schema Enhancements | ✅ 100% | G1-G9 complete, 12-month data loaded, P1-P4 audit fixes regenerated (Aug 2026) |
| **9** | BI / Reporting (9 dashboards) | 🔵 Ready to Build | 148 active DAX measures + TI calc group ready, dashboard build pending |

---

## PHASE 1 — Data Generation ✅ COMPLETE

- [x] `--output-dir` and `--months` CLI parameters
- [x] `--seed` flag for reproducibility
- [x] CSV headers with ISO 8601 dates, consistent decimals
- [x] Generator logging (console + file, timestamps, row counts, elapsed time, log-level arg)
- [x] Output validation post-generation (row counts ±5%, no null PKs, FK integrity)
- [x] `data_sources/__init__.py` (Python package)
- [x] `data_sources/config.py` (centralized constants: CFG, PRODUCT_CFG)

- [x] `data_sources/README.md`
- [x] Output (3 months): ~344K interactions, ~28K PTP events, ~23K payments
- [x] Output (12 months): ~1.34M interactions, ~106K PTPs, ~121K payments, ~21K agent time, ~183K EOM snapshots, ~441 writeoffs, ~323 recoveries

> **Enhancements post-v7**: See Phase 5 section for progressive severity, monitoring pool, and utilization cap.

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

### KPI Views (15 views in `002_kpi_views.sql` + 1 in `004_agents_scorecards.sql` = 16 total)
- [x] `v_contact_metrics` — RPC, RPC%, RPC/OpHr, RPC Arrears (agent/day, team/day, month)
- [x] `v_promise_metrics` — PTP count, PTP%, Kept/Broken count, KP% (agent/day, team/day, month)
- [x] `v_recovery_metrics` — Cures, cured amount, cure rate, agent vs self-cure (4 granularities)
- [x] `v_productivity_metrics` — Utilization%, contacts/agent/hour
- [x] `v_handle_time_metrics` — AHT-RPC, AHT-NonRPC, ACW-RPC, ACW-NonRPC
- [x] `v_daily_mis` — Consolidated daily view combining all 5 KPI categories
- [x] `v_monthly_summary` — Month-level rollup (agent, team, portfolio granularities)
- [x] `v_etl_load_summary` — Latest ETL load per table with data freshness
- [x] `v_data_freshness` — Days since each fact table was last updated
- [x] `v_dpd_migration_matrix` — DPD bucket transitions between months (P2)
- [x] `v_weekly_agent_summary` — Weekly performance aggregation (P2)
- [x] `v_rls_supervisor_map` — Supervisor↔agent mapping for RLS (P2)
- [x] `v_promise_timeline` — Promise lifecycle with calendar roles (P2)
- [x] `v_monthend_portfolio` — Month-end portfolio rollup (P4)
- [x] `v_writeoff_recovery` — Recovery curve by write-off cohort (P4)
- [x] `v_agent_scorecards` — Composite weighted score (004_agents_scorecards.sql)

### Database Hardening
- [x] `003_constraints.sql` — 15 CHECK constraints (idempotent DO blocks)
- [x] `004_agents_scorecards.sql` — `v_agent_scorecards` with composite weighted scoring
- [x] `005_indexes.sql` — 27 indexes (16 FK/date + 5 single-column + 6 composite)
- [x] `006_comments.sql` — 63 COMMENT ON statements for all 16 tables and columns
- [x] `seeds/001_dim_products.sql` — 3 product seed rows (`ON CONFLICT DO NOTHING`)
- [x] `seeds/002_dim_calendar.sql` — 396 calendar rows (Dec 2024 + full year 2025)
- [x] `seeds/004_dim_calendar_extension.sql` — +90 rows (Jan–Mar 2026, total 486)
- [x] **View formula fixes**: Cure count uses `COUNT(DISTINCT account_id)` instead of `SUM(is_cured)` — eliminates double-counting. BB Conversion uses `kept_pct * ptp_pct / 100` matching DAX `[PTP%] * [KP%]`. Removed misnamed "no-touch rate" from `v_productivity_metrics` comment.

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

## PHASE 5 — Generator Enhancements ✅ COMPLETE

### Progressive Severity (cure_count Decay)
- [x] Accounts track `cure_count` — incremented each time an account transitions from Mora to Activo
- [x] Self-cure rate decays by `0.5^cure_count` (min 0.1) — repeat offenders less likely to self-cure
- [x] Agent connection rate penalized by `1.0 - 0.2*cure_count` (min 0.4) — evasive accounts harder to reach
- [x] AHT/ACW boosted by `1.0 + 0.15*cure_count` — escalated collection stages take longer

### Monitoring Pool Restriction
- [x] `other_pool` limited to accounts that have ever been in Mora (`ever_mora` tracking set)
- [x] `ever_mora` initialized with all starting Mora accounts
- [x] Accounts entering Mora via replenishment are added to `ever_mora`
- [x] Clean Activo accounts no longer receive collections calls

### Utilization Cap
- [x] Utilization clamped at 0.95 (was 1.0) to reflect unavoidable idle/wrap-up time

---

## PHASE 6 — Testing ✅ COMPLETE

### Test Files Created
- [x] `test/conftest.py` — Pytest fixtures: DB cursor, table metadata, PK/FK mappings, KPI views, GENERATOR_ROW_COUNTS(+_SMALL), METRIC_RANGES, `small_generated_data` session fixture (Hybrid C), custom `slow` mark
- [x] `test/test_qa_validation.py` — Data integrity + metric percentile test classes (73 tests: 72 fast + 1 slow)
- [x] `test/test_generator.py` — Generator unit tests + dual-fidelity row counts + Phase 6 invariant tests (11 tests: 9 fast + 2 slow)
- [x] `test/test_kpi_views.sql` (168 lines) — SQL validation queries for KPI views
- [x] `test/README.md` — Test documentation

> **Hybrid C (Aug 2026):** fast generator tests share ONE session-scoped 3-month generation; slow gates carry full fidelity (canonical 12-month baseline vs conftest ±10%, seed reproducibility, ETL idempotency). Total suite: **84 passed** (81 fast + 3 slow).

### QA Validation Tests (72 fast + 1 slow)
| # | Test Class | Validates | Status |
| :--- | :--- | :--- | :--- |
| 1 | `TestRowCounts` | dim_employees=88, dim_clients=10000, dim_accounts~15,480 | ✅ Pass |
| 2 | `TestNoNullPKs` | No nulls in PK columns across all 16 tables | ✅ Pass |
| 3 | `TestFKIntegrity` | All FK relationships have no orphans (incl. bucket/strategy/history) | ✅ Pass |
| 4 | `TestDateRanges` | Fact dates within Jan–Dec 2025, calendar covers full period | ✅ Pass |
| 5 | `TestWeekdayOnly` | No interactions on weekends | ✅ Pass |
| 6 | `TestDPDLogic` | DPD >= 0 in fact_interactions, fact_payments, fact_eom_snapshot | ✅ Pass |
| 7 | `TestUtilizationBounds` | Utilization between 0 and 1 (decimal) | ✅ Pass |
| 8 | `TestCallDuration` | AHT > 0s, max < 3600s | ✅ Pass |
| 9 | `TestKPIViewOutput` | All views return rows, percentage columns in 0–100 | ✅ Pass |
| 10 | `TestMetricRanges` | Bounds from conftest.METRIC_RANGES (RPC% 35-60, PTP% 5-40, KP% 60-90, Util% 30-60, Cures/THT 0.02-0.20, ACW RPC 80-180) | ✅ Pass |
| 11 | `TestCappedKPPositive` | SUM(capped_kp) > 0 | ✅ Pass |
| 12 | `TestBBConversionPositive` | median(bucket_conversion) > 0 | ✅ Pass |
| 13 | `TestETLIdempotency` | Running ETL twice = same row counts (slow) | ✅ Pass |

*(legacy `TestGeneratorSeed` removed — duplicate coverage now lives in test_generator.py)*

### Generator Unit Tests (test_generator.py — 11 tests)
| # | Test Class | Validates |
| :--- | :--- | :--- |
| 1 | `TestGeneratorOutput` | Generator exists, `--help` works, produces CSVs with correct structure (incl. Fact_Recoveries) |
| 2 | `TestGeneratorRowCounts` | Fast: 3-mo structure vs GENERATOR_ROW_COUNTS_SMALL · Slow (canonical): 12-mo run vs GENERATOR_ROW_COUNTS ±10% |
| 3 | `TestGeneratorReproducibility` | Seed 42 produces identical checksums (fixture vs one extra small run, slow) |
| 4 | `TestGeneratorDataQuality` | No null PKs in generated CSVs across all dimension tables |
| 5 | `TestGeneratorPostFixInvariants` (4 tests) | Cure-flag completeness, per-plan PTP-payment consistency (installment-aware), grace-period integrity, re-entry rate bounds (5-25%, chronological windows) |

### Run Tests
```bash
# Fast tests only (~5-6 min incl. DB percentile queries)
/c/Users/Leand/.conda/envs/mis-collections/python -m pytest test/ -v -m "not slow"

# Full gate (~15 min: adds canonical 12-mo generation, seed repro, ETL idempotency)
/c/Users/Leand/.conda/envs/mis-collections/python -m pytest test/ -v
```

---

## PHASE 7 — Automation ✅ COMPLETE

- [x] `run_pipeline.bat` (125 lines) — Docker check → start containers → wait for PostgreSQL → migrations → generate data → ETL → colored output → timing per stage
- [x] COLOR bug fixed (trailing colons removed)
- [x] Pipeline runs end-to-end in ~157s (12 months) / ~126s (3 months calibrated)
- [x] `database/migrate.sh` (47 lines) — Runs all SQL migrations via `cat file.sql | docker exec -i psql`
- [x] Exit codes per stage for error propagation

---

## PHASE 8 — Documentation 🟡 ~85% Complete

- [x] `CONTEXT.md` — Single-source project overview for AI-assisted development
- [x] `README.md` — Project overview & interview pitch
- [x] `docs/executive_summary.md` — One-page leadership summary
- [x] `docs/kpi_definitions.md` — 319-line comprehensive KPI reference
- [x] `docs/data_dictionary.md` — Full data dictionary (16 tables, current schema)
- [x] `docs/execution_guide.md` — Granular task instructions (historical snapshot noted)
- [x] `data_sources/schema/dictionary.md` — Column-level docs for all tables
- [x] `docs/dashboards/reference_guide.html` — DAX + dashboard blueprint reference
- [x] `docs/dashboards/legacy/dax_measures_dictionary.md` — 73 DAX measures (v1 backup)
- [x] `docs/dashboards/mis_collections_build_plan.md` — 396-line build plan for Phases 8–9
- [x] `dashboards/dax/collections_dax_v2.csv` — **148 active measures** (5 measure tables, source of truth; v3.2)
- [x] `docs/dashboards/dax_measures_dictionary_v2.md` — Full documentation with formulas, formats, dependencies (v2.2, legacy)
- [x] `PLAN_DASHBOARDS.md` — 9-dashboard implementation plan (generator G1-G9, schema, DAX coverage analysis)
- [x] `QUICKSTART.md` — 5-minute setup (prerequisites + 3 commands)
- [x] `TROUBLESHOOTING.md` — Docker errors, port conflicts, ETL failures, DB reset
- [x] `CHANGELOG.md` — Version history (0.1.0 → 1.6.3)
- [x] `docs/KPI_VIEWS.md` — 13 of 16 KPI views documented (3 added in P2/P4)

- [x] Readme status badges (Python, PostgreSQL, Tests, DAX, Data, Branch)
- [x] Data lineage diagram (generator → CSV → ETL → PostgreSQL → views → BI; mermaid in README)

*Doc sweep (2026-08-31): standardized DAX counts to 148 + 18-item CG, KPI views to 13 of 16, account count to ~15,480 across all docs; cross-platform branch consolidated onto `main` (see CHANGELOG 1.6.1); retired `feature/powerbi-dashboard` and archived its May-2026 artifacts under `docs/dashboards/legacy/`; rewrote README into an interview-ready showcase with badges + lineage diagram (CHANGELOG 1.6.2–1.6.3), closing the two previously-pending items here.*

---

## PHASE 8.5 — Generator + Schema Enhancements ✅ COMPLETE

### Generator Enhancements (G1-G9)
- [x] G1 — `open_date` spread: Dim_Accounts open_date uses `CFG["open_date_spread_months"]` (12-24 months)
- [x] G2 — `cost_per_hour`: Dim_Agents gets cost_per_hour column (senior $38, mid $32, junior $26)
- [x] G3 — `credit_limit`: Dim_Accounts gets credit_limit from PRODUCT_CFG (lognormal distribution)
- [x] G4 — `income_bracket`: Dim_Clients gets income_bracket (5 segments with weighted distribution)
- [x] G5 — `channel`: Fact_Interactions gets channel (65% Dialer, 15% Manual, 10% FICO, 10% SMS)
- [x] G6 — `write-offs`: New Fact_Writeoffs table (5% rate at 91+ DPD)
- [x] G7 — `12 months`: Dim_Calendar expanded to 396 rows (Dec 2024 + Jan–Dec 2025) + 90-row extension to Mar 2026 (total 486)
- [x] G8 — `hire_date`: Dim_Supervisors gets hire_date (5-year span)
- [x] G9 — `hire_date`: Dim_Agents gets hire_date + experience_tier (senior/mid/junior)

### Schema Changes
- [x] +9 new columns across existing tables
- [x] +1 new table: fact_writeoffs
- [x] +3 new views: v_dpd_migration_matrix, v_weekly_agent_summary, v_rls_supervisor_map
- [x] +8 new CHECK constraints
- [x] +6 new indexes
- [x] Dim_calendar seed expanded to full year

### Config Updates
- [x] +9 new config dictionaries (VINTAGE_CFG, AGENT_HIRE_CFG, CREDIT_LIMIT_CFG, etc.)
- [x] Modified PRODUCT_CFG for credit_limit ranges
- [x] Income bracket distribution added
- [x] Monthly drift std (0.08), self-cure payday boost (2.5), utilization cap (0.95)

### Data Generation & Loading
- [x] 12 months generated (Jan-Dec 2025)
- [x] 1.8M rows loaded into PostgreSQL
- [x] All tests passing (**84 total: 81 fast + 3 slow**, Hybrid C suite)

### DAX Updates (v2.2 → v3.2 superseded)
- [x] **v2.2 (legacy):** 256 measures across 13 tables with per-metric time intelligence
- [x] **v3.2 (current):** 148 active measures (5 measure tables) + `_Time Intelligence` Calculation Group (18 items)
- [x] 118 legacy TI measures retired to `dashboards/dax/legacy/time_intelligence_legacy.csv`
- [x] `dax_measures_all.md` generated (complete DAX reference: 148 + 18 CG items as code blocks)
- [x] `dax_measures_dictionary_v2.md` v2.2 preserved as legacy reference

---

## PHASE 9 — BI / Reporting 🔵 Blueprint Ready (9 Dashboards)

### Build Plan Complete
- [x] `docs/dashboards/mis_collections_build_plan.md` — 5-phase build plan
- [x] Architecture defined: single .pbix, 9 pages, 3 Excel sheets
- [x] **DAX v3.2 complete**: **148 active measures** (5 measure tables) + `_Time Intelligence` calculation group (18 items) — `dashboards/dax/collections_dax_v2.csv` (source of truth); 118 legacy TI measures retired to `dashboards/dax/legacy/time_intelligence_legacy.csv`
- [x] `dashboards/dax/dax_targets_and_comparisons.md` — Goals & Targets patterns
- [x] `docs/dashboards/dax_measures_dictionary_v2.md` — v2.2 documentation (legacy)
- [x] `docs/dashboards/dax_measures_all.md` — Complete DAX reference (all measures as code blocks)
- [x] 2 calculated tables: `Dim_Targets` (7 goal definitions), `Color Reference` (RAG hex codes)
- [x] Legacy v1 files preserved as backups (`collections_dax.csv`, `legacy/dax_measures_dictionary.md`)
- [x] `PLAN_DASHBOARDS.md` — Full implementation plan with DAX coverage analysis per dashboard
- [x] **`docs/dashboards/dashboard_blueprint.md`** — Page-by-page wireframes (1920x1080 canvas), visual specs, field wells, formatting
- [x] **`docs/dashboards/dashboard_blueprint.pdf`** — Printable PDF export of blueprint
- [x] **`docs/dashboards/PLAN_DASHBOARDS.pdf`** — Printable PDF export of implementation plan, DAX references

### Dashboard Pages (9 consolidated from original 10)
- [ ] Page 1 — Executive Collections (merged with Scorecard: operational + risk + cost per account) — **95% DAX ready**
- [ ] Page 2 — Agent Performance (RPC%, KP%, Cure, Util, AHT, Composite Score, WoW trends) — **95% DAX ready**
- [ ] Page 3 — Dialer Performance (Call volume, answer rate, RPC dialer-only, AHT by channel) — **80% DAX, limited by schema**
- [ ] Page 4 — Portfolio Management (Arrears waterfall, delinquency bands, DPD migration Sankey) — **95% DAX ready**
- [ ] Page 5 — Operations Command Center (limited: Calls Offered/Answered, AHT, Occupancy) — **55% DAX, most limited**
- [ ] Page 6 — Credit Risk (Delinquency by segment, Roll rates, Credit utilization) — **80% DAX ready**
- [ ] Page 7 — Financial Recovery (Recovery vs cost, Write-offs, Cost-to-collect, Net recovery) — **95% DAX ready**
- [ ] Page 8 — Vintage Analysis (DPD by account age, Vintage curves, Cure by vintage month) — **85% DAX ready**
- [ ] Page 9 — Roll Rate Analysis (Migration matrix, Skip/deteriorate rates, Stuck 90+) — **90% DAX ready**

**Excluded dashboards (6):** Executive Scorecard (merged), WFM, QA, Compliance, Customer Experience, Recovery Forecast

### DAX Coverage Summary
| Category | Count | Status |
|----------|-------|--------|
| In CSV (148) | 148 | ✅ Complete (+ `_Time Intelligence` CG is the single TI mechanism; 118 legacy TI retired to `dashboards/dax/legacy/`) |
| Requires schema changes | 4 | ❌ Deferred (campaign, occupancy, login/logout) |
| Visual-only gaps | 3 | ⚠️ Layout, not DAX (Risk Heat Map, Arrears Waterfall, Vintage Distribution) |

### Build — Pending
- [ ] Import data model into Power BI (star schema, 15 base tables + etl_load_log; PBIX v3 predates P3/P4 schema — fresh import required)
- [ ] Import 148 DAX measures from `collections_dax_v2.csv`, then run `create_calc_group.cs` for the CG
- [ ] Create 2 calculated tables: Dim_Targets, Color Reference
- [ ] Build all 9 dashboard pages (follow `dashboard_blueprint.md`)
- [ ] Add RLS by supervisor_id on dim_employees
- [ ] Publish to Power BI Service
- [ ] `reports/generate_daily_mis.py` — Python script for Excel generation
- [ ] Generate sample Excel reports for Jan-Dec 2025
- [ ] Validate DAX measures match SQL view outputs
- [ ] Dashboard screenshots for documentation

---

*Last updated: 2026-07-22*
