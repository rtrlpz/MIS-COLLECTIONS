# Changelog

## [1.6.0] — 2026-08-25

### P3/P4 — REGENERATED & VERIFIED
- Pipeline run materialized the P3/P4 engine; full test gate green (**84 passed, 0 failures**). DB spot-checks confirm every audit item live:
  - **I5**: strategy split 58.9/26.2/14.9; efficacy multipliers bite (RPC by arm 37.7/32.2/28.0, connect 64.8/55.5/61.8 — no longer flat ~36%)
  - **N4**: `fact_recoveries` 323 rows, $39,949 recovered (Feb–Dec)
  - **N5**: 27.9% of kept promise plans settle in ≥2 installments
  - **I4**: 6 mid-year team transfers with clean SCD2 segments (`valid_to=2025-06-30` → new team `2025-07-01`)
  - **I1**: `portfolio_cure_rate` 56.4%→76.2% vs prior month-end Mora stock (view stores %)
  - **W4**: Exited transitions = 413 in migration matrix (scales with 441 write-offs)

### Hybrid C — test suite speedup (~8× less generator work)
- Fast tests share ONE session-scoped 3-month generation (`conftest.small_generated_data`, `--months 1,2,3` seed 42 → `data_sources/raw_test_session/`). Was: 8 separate FULL 12-month generations per suite run (~7–9 min of pure regeneration).
- Slow gates keep full fidelity: canonical 12-month baseline validation (`test_canonical_12mo_row_counts`, ±10%), seed reproducibility (fixture vs ONE extra small run), ETL idempotency.
- `TestGeneratorRowCounts` split into fast structural check (vs new `GENERATOR_ROW_COUNTS_SMALL`) + slow canonical gate (vs `GENERATOR_ROW_COUNTS`); baselines single-sourced in conftest.
- Duplicate `TestGeneratorSeed` removed from qa_validation (was two MORE full runs for identical coverage).

### Bug fixes surfaced by the regen gate
- **Re-entry invariant measured garbage windows since Phase 6**: month dirs were sorted ALPHABETICALLY (`february` < `january` < `march`) — arbitrary/backwards month pairs. Now chronological (`%B_%Y` parse); true P3/P4 band is a stable 10.4–14.3% across all ten 12-month windows (Q1: 11.6%), well inside the 5–25% bound (kept unchanged).
- **Metric-range bounds were hardcoded inline** in `TestMetricRanges`, ignoring conftest's recalibration (kp_pct floor 65→60, cures_per_tht ceiling 0.15→0.20) — now read `METRIC_RANGES` (single source of truth). Observed medians: KP% 60.0, Cures/THT 0.163.
- **Latent `from conftest import` breakage**: package layout (`test/__init__.py`) makes plain conftest unimportable at module level; both test files now insert their dir into `sys.path`.
- ETL loads sparse header-only CSVs legitimately (Fact_Recoveries pre-first-write-off months); COPY switched to `copy_expert` with quoted identifiers.

### Ops note
- Live DB was found still on the PRE-regen load when today's gate started (user's last pipeline run predated the Aug 24 23:30 regeneration) — first-run "failures" were this stale state; `TestETLIdempotency`'s reload brought it current and everything passed after. Rule stands: re-run the pipeline after pulling engine changes before trusting QA results.

## [1.5.0] — 2026-08-24

### P4 — Semantics & Extras (audit I1/N4/N5/N6/W4) — CODE COMPLETE, REGEN PENDING

**I1 — Industry-correct portfolio cure rate**
- `v_monthend_portfolio` gains `cured_accounts`, `mora_stock_entering` (prior month-end Mora), and `portfolio_cure_rate` = cures ÷ delinquent stock entering the month — the definition the audit demanded. Feb sample: 2,572 stock → 60.50%
- The legacy cures÷payments ratio stays in `v_recovery_metrics` under its honest meaning; agent scorecards keep their conversion component by design

**N5 — Multi-payment promise plans**
- ~35% of will-pay clients now settle in two installments; promises resolve on **cumulative paid ≥95% within grace**, staying Pending between parts (was: first payment alone decided Kept/Broken)
- Invariant `test_ptp_payment_consistency` updated to per-plan sums (per-row check was installment-hostile)

**N4 — Post-charge-off recoveries**
- New `fact_recoveries` (001 DDL + live via idempotent `010`); generator §3H2 emits daily partial collections draining a per-account recoverable balance set at write-off (`RECOVERY_CFG`: p=0.004/day, 10–35% of remainder)
- New `v_writeoff_recovery`: recovery-curve KPI by write-off cohort month for the Financial Recovery page

**W4 — `Exited` transitions finally reachable**
- Migration matrix previously dropped every account's final-month row; post-C2 that hid real book exits. WHERE now admits pre-end finals → **Exited = 203** (222 write-offs − 19 December cohorts with no following month); rank-invariant tests exclude exits (no destination bucket ≠ severity transition)
- Calendar test updated to the extended span (Dec 2024 → Mar 2026, 486 rows)

**N6 — Housekeeping**
- Dead `CFG["utilization"]` removed (THT-normalized utilization made it unused); client segments renamed to non-product-colliding values (`Retail/Mass Affluent/Affluent/Small Business/Corporate`) — materializes at regen
- `etl_load_log` self-heals on next pipeline run (each load writes rows); manual back-dating deliberately avoided

### Ops incident (resolved same day)
A targeted pytest run using `-k "...row_counts..."` accidentally matched slow-marked `TestETLIdempotency` (name match bypassed the marker), which reloaded old CSVs over the live DB and reverted P1/P3 label repairs. **Recovered by re-running idempotent seeds/007/008/009**; verified baseline restored (184,210 snapshots · 0 NULL bucket_keys · 60.0/24.9/15.1 strategy split · calendar→2026-03-31 · Exited=203). Rule going forward: targeted runs always pair `-k` with `-m "not slow"`.

## [1.4.0] — 2026-08-24

### P3 — Realism Engine Upgrades (audit I4/I5/I7/I8) — CODE COMPLETE, REGEN PENDING

> **All changes below are implemented but NOT yet materialized**: current CSVs
> and loaded data predate this phase except where a migration backfills labels.
> Full regeneration + reload + complete test gate (incl. generator suites)
> is the explicit next step.

**I7 — Delinquency equilibrium**
- `mora_replenishment_rate` 0.0018 → **0.0042/day**: old value couldn't offset cure outflow (Mora decayed 16.6%→7.2% monotonically); new rate × seasonal multipliers targets a stable ~12–15% book

**I8 — G7 seasonality actually wired** (was dead config)
- Daily workload scales by `seasonal_volume[m]`; Mora replenishment scales by `seasonal_mora[m]`

**I5 — Treatment/strategy dimension (champion-challenger)**
- New `dim_strategy`: STG-01 Champion_Dialer 60% · STG-02 Challenger_SMS_First 25% (conn ×0.88) · STG-03 Challenger_FICO_Priority 15% (conn ×1.06, rpc ×1.12)
- Accounts get ONE stable arm; arm drives channel mix **and** efficacy multipliers — fixes cosmetic channels AND enables strategy→outcome attribution
- `fact_interactions.strategy_id` added; **live DB backfilled deterministically** (hash of account_id, exact 60.0/24.9/15.1 split verified). RPC-by-arm flat (~36%) in today's data — expected: multipliers bite only at regen

**I4 — SCD Type 2 for employee org attributes**
- `dim_employees` gains valid_from/valid_to/is_current (current-state rows; keeps all fact joins intact)
- New `dim_employee_history` versioning team/supervisor segments; generator emits **6 mid-year team transfers on Jul 1**
- Live DB baseline-populated (88 current segments)

**I3 completion path — Calendar extended**
- Generator CAL_RANGE now END+90d; SQL seed extended Jan–Mar 2026 (+90 rows, live DB verified 486 through 2026-03-31) — unblocks physical promised/grace-date FKs at regeneration

### Tests & ops
- conftest registers `dim_delinquency_bucket`, `dim_strategy`, `dim_employee_history` + their FKs (incl. snapshot→bucket from P2, previously unregistered)
- Structural QA re-run: **37 passed, 0 failures** (tables/PKs/FKs/view outputs)
- migrate.sh wires seeds/004 + migration 009; assertion remains 15 views

## [1.3.0] — 2026-08-24

### P2 — Kimball Dimensional Upgrades (audit items I2/I3/N2/N3)

**I2 — Delinquency buckets are now a real ordered dimension**
- New `dim_delinquency_bucket` (bucket_key, label, sort_order, days_from/to) seeded with the 5 canonical buckets
- `fact_eom_snapshot.bucket_key` added + backfilled from labels (**184,210 rows, 0 NULLs**) with validated FK
- `v_dpd_migration_matrix` rewritten: severity ranking joins `sort_order` instead of inline CASE maps — output verified **byte-identical** to pre-change distribution (Same 146,380 / Deteriorated 13,128 / Improved 6,797 / Cured 2,423)
- Fresh builds: table+column in `001`; existing DBs: idempotent migration `008`; seed in `seeds/003_dim_delinquency_bucket.sql`

**I3 (view layer) — Role-played promise dates + lifecycle milestones**
- New `v_promise_timeline`: one row per promise exposing made/due/grace-end dates as aliased calendar roles (`dc_made`/`dc_due`), promised lead days, grace days, first-payment date, days-to-pay, on-time flag
- Physical FKs from `promised_date`/`grace_until_date` to calendar **deferred to P3**: late-December promises spill into Jan 2026, outside the current calendar range — extending `Dim_Calendar.csv` + generator CAL_RANGE + conftest counts belongs with regeneration
- Sanity: timeline rows = 58,811 (= PTP count); `on_time`=37,835 exactly equals Kept promises

**N3 — Semi-additive-safe portfolio API**
- New `v_monthend_portfolio`: per-month-end rollup (accounts in book, Mora %, Σbalance, Σarrears, per-bucket counts) making the safe aggregation the default; Dec shows 15,279 accounts / 7.28% Mora / 222 in 90+

**N2 — Grain declarations**
- Every table in `001_create_tables.sql` now carries an explicit GRAIN comment (one row = …), including the semi-additive warning on the snapshot fact

### Tests & ops
- View-count assertion raised to **15**; both new views registered in `TestKPIViewOutput`
- Targeted QA re-run: **60 passed, 0 failures** (structure, integrity, ranges, matrix regressions)

## [1.2.1] — 2026-08-24

### P1 Audit Hotfix — Correctness (Kimball audit, Critical items)

**C1 — `v_agent_scorecards` restored**
- Live DB had 12 views; migration run had historically died at 004 (005/006 never applied). Re-applied 004/005/006 → **13 views**, scorecard live (960 agent-months, avg composite 35.8)
- `database/migrate.sh` hardened: post-run assertion fails (`exit 1`) if view count ≠ 13 — prevents silent drift recurring

**C2 — Written-off accounts exit the EOM book**
- Root cause: after write-off, accounts kept being re-snapshotted monthly as `90+` with residual principal → contaminated roll-rate matrices, 90+-stock trends and portfolio aggregates
- Generator (§3H): skips `WrittenOff` accounts in snapshot loop; final row = write-off month-end (consistent with `fact_writeoffs.balance_before`)
- New `007_remove_post_writeoff_snapshots.sql`: idempotent DELETE of post-writeoff snapshots; applied live → **−1,574 zombie rows** (185,784→184,210); Dec-90+ 425→222 (203 live + 19 Dec write-off finals)

**C3 — Ratio-of-sums rollups (kills remaining AVG-of-rates bias)**
- `v_productivity_metrics`: team/monthly utilization = ΣTHT/Σop-hours (was AVG of daily ratios); view now also exposes `operational_hours`, `tht_hours`
- `v_handle_time_metrics`: exposes per-bucket Σseconds + counts; averages derived by division
- `v_monthly_summary` team/portfolio grains: util, cure_rate, AHT×2, ACW×2 all SUM(numerator)/SUM(denominator) (cure uses Σcures/Σpayments — redefinition vs snapshot stock deferred to P4/I1); existing columns preserved, additions appended (CREATE OR REPLACE-safe)
- Portfolio before→after spot: Jan cure 13.24→14.96, Feb AHT 264.5→266.5, util stable at 2dp

**I6 — Self-cure DPD integrity**
- Generator §3C: `dpd_at_payment` now records true pre-cure DPD (was hardcoded 0), restoring the DPD-at-cure distribution for ~20% of cures

### Tests
- `test_percentage_columns_in_range` now asserts identical ranges in ONE filtered pass per view (was one full-view scan per column; a single scan of stacked `v_monthly_summary` costs ~80s)
- Fast QA suite green: 52 checks through `v_daily_mis` + 17 targeted (monthly_summary ranges, metric medians vs new formulas, CappedKP, BB conversion, migration-matrix regression) = **69 passed, 0 failures**
- **Deferred:** generator-spawning suites (`test_generator.py`, 2 slow tests) gated to P3 regeneration — they validate regenerated output, not today's stale CSVs

## [1.2.0] — 2026-08-24

### Learning Environment — Plain-Language Overhaul (Phase A)
- Rewrote `learning/README.md`: plain-language master guide — track map with real work-request examples, session routine, "a normal week as a collections BI analyst" vignettes mapped to tasks, simplified house rules, one-time setup steps
- Rewrote all 6 track READMEs (`sql`, `python`, `notebooks`, `excel`, `powerbi`, `git-cli`): each now opens with "At work, you reach for this when…" scenarios, plain level tables with move-up criteria, minimal trees
- Rewrote `learning/sql/basic/tasks.md` (entry point): added inline mini-glossary (fact/dimension/grain/snapshot), realistic supervisor-request framing, concrete "Done when" checks per task; contracts preserved (no code, no numbers)
- Contracts unchanged: tasks.md still scenario + steps-with-why + guiding questions; results.md still guidance-only. Remaining 15 task files keep original style pending user feedback on new tone

## [1.1.0] — 2026-08-17

### Power BI Model — PBIX Live Fixes (collections_dashboard_v3.pbix)
- **Created `Dim_Targets`** calculated table (7 goals: PTP% 80%, KP% 80%, ACW RPC 120s, ACW Non-RPC 25s, Capped KP/RPC Arrears 37%, Cures/THT 2.4, Utilization 90%; amber/green thresholds, direction, sort order) — resolves 29 `_Goals & Targets` measures in `SemanticError` state (`Cannot find table 'Dim_Targets'`)
- **Created `Color Reference`** calculated table (3 RAG rows: Green `#00B050`, Amber `#FFC000`, Red `#FF0000`) and replaced the misplaced DATATABLE partition inside `_Goals & Targets` with standard `{BLANK()}` — resolves `* Color` measures referencing `'Color Reference'`
- **Fixed `Income Segment`** syntax error (`SELECTEDVALUE(..., Multiple")` → `"Multiple")` per CSV row 133)
- **Validated:** all 29 Goals measures + `Income Segment` now `Ready`; live DAX sweep confirms Goal values, Status (Red/Amber), Color hexes, `Dim_Targets`=7 rows, `Color Reference`=3 rows
- **Model now:** 25 tables (11 base + 6 measure + 2 calc + 5 hidden date + 1 CG), 132 measures + 18-item CG, zero measure errors
- **Note:** No RLS roles yet (Phase 9 pending); `Monthly Recovery Rate` legacy measure not present in v3 — use `[Net Recovery]`/`[Collection Efficiency]`

### Blueprint — Executive Page v3 Alignment
- `dashboard_blueprint.md` §2.8 updated: legacy table names (`_Executive`, `_Promise & Conversion`, `_Recovery & Collection`) → live v3 tables (`_Composites & Strategy`, `_Promise & Recovery`), added `Dim_Targets`/`Color Reference`/`_Time Intelligence` CG rows, CG-vs-snapshot caveat documented

## [1.0.0] — 2026-07-25

### Phase 3 — DAX Cleanup & Gap Analysis
- Added `Avg AHT (sec)` and `Avg ACW (sec)` overall measures matching real ScotiaBank metric set
- DAX count: 258 measures across 15 tables

### Phase 2 — Critical Bug Fixes
- **Product ID**: Aligned `PRD_001` → `PRD-01` in seed to match generator format
- **Duplicate table**: Removed `etl_load_log` from `002_kpi_views.sql` (was defined in `001_create_tables.sql`)
- **Cartesian join**: Removed product grouping from `v_recovery_metrics.agent_daily` — was double-counting in `v_daily_mis`
- **Unweighted averages**: Replaced `AVG(rpc/ptp/kept_pct)` with weighted `SUM/SUM` in `v_monthly_summary`
- **Dead config**: Removed unused `rpc_rate_by_channel` from `config.py`
- **DAX columns**: Fixed `Fact_EOM_Snapshot[product_id]` → `Dim_Accounts[product_type]` and `Fact_EOM_Snapshot[open_date]` → `Dim_Accounts[open_date]`

### Phase 8.5 — G1-G9 Generator Enhancements
- Vintage `open_date` spread (23 months, weighted)
- Agent hire dates + experience tiers (senior/mid/junior)
- Credit limit lognormal distribution per product
- Client income brackets (5 segments)
- Interaction channel mix (Dialer/FICO/SMS/Manual)
- `Fact_Writeoffs` table (5% write-off rate at 91+ DPD)
- 12-month data expansion (Jan-Dec 2025, seasonal patterns)
- Supervisor hire dates (5-year span)
- Agent cost model (hourly rates by tier + overhead)
- 256 DAX measures across all tables
- Dashboard blueprints for 9 pages
- Schema: 6 new columns + 3 new tables + 12 views
- Tests: 76 total (74 fast + 2 slow)

## [0.9.0] — 2026-07-16

### Enhanced
- Consolidated 10 dashboards to 9
- Added PLAN_DASHBOARDS.md with G1-G9 plan
- DAX v2 expansion to 256 measures
- Full documentation refresh (CONTEXT.md, CLAUDE.md redacted)

## [0.8.0] — 2026-05-26

### Fixed
- Cure misclassification: payments marked as Non-Cured when arrears reached 0
- Payment excess loss: amounts beyond arrears now applied correctly
- DPD capture at interaction and payment time
- Added audit columns, CHECK constraints, indexes on `fact_payments`

## [0.7.0] — 2026-05-10

### Enhanced
- Calibrated generator parameters against real historic data distributions
- Decoupled agent skill into 3 dimensions (contact, negotiation, efficiency)
- Added monthly performance drift (±8%) for realistic variance
- Computed THT from actual interaction handle times (not Op Hr)
- Clustered 60% of self-cures on payday weeks

### Fixed
- DAX type safety for all measures
- Corrected Cured Amounts measure

## [0.6.0] — 2026-05-01

### Added
- 17 analytical SQL queries across 3 tiers (agent, team, portfolio)
- ETL monitoring views: `v_etl_load_summary`, `v_data_freshness`
- Test suite: 66 QA validation tests + 10 generator tests

### Fixed
- Payment processing dates now allowed on weekends (was weekday-only bug)
- Flattened `dim_supervisor` into `dim_employees` (self-ref FK) for Power BI
- Corrected KP%, cure count, BB Conversion, Capped KP in SQL views
- Refactored `v_monthly_summary` to single-pass design
- Fixed portfolio-level Cartesian bug

## [0.5.0] — 2026-04-20

### Added
- All 9 KPI views (contact, promise, recovery, productivity, handle time, daily_mis, monthly, ETL summary, freshness)
- Agent scorecard view (`v_agent_scorecards`) with composite weighted scoring
- Seed scripts for `dim_products` and `dim_calendar`
- CHECK constraints (15) and indexes (27) for data integrity
- COMMENT ON for all tables and columns

### Pipeline
- Full pipeline orchestration via `run_pipeline.bat`
- ETL with transactions, idempotency (TRUNCATE + reload), retry logic
- Dry-run mode for pre-flight CSV validation
- Incremental mode to skip already-loaded months

## [0.4.0] — 2026-04-10

### Added
- Anomaly tracking with anomaly_report.csv export
- Extracted CFG and PRODUCT_CFG into `config.py`
- Post-generation validation (row counts, PK/FK checks)
- Structured logging with file + console handlers
- CLI arguments: `--output-dir`, `--months`, `--seed`
- Execution guide with granular task instructions
- Consistent CSV formatting with ISO dates and fixed decimals

## [0.3.0] — 2026-04-01

### Added
- V7 folder architecture with automated tests
- Issue templates for consistent contributions
- ROADMAP.md for project planning
- `__init__.py` files for package structure

## [0.2.0] — 2026-03-15

### Added
- Dockerized PostgreSQL + pgAdmin
- ETL pipeline with psycopg2
- First Power BI dashboard
- Initial DDL with 11 tables (star schema)

## [0.1.0] — 2026-03-01

### Added
- Project folder structure
- Initial data generator scripts
- Database DDL for tables
