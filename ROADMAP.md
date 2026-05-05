# Project Roadmap — Collections Analytics Portfolio
> Current Completeness: **28%** | Target: **100%**
> Estimated Total: ~18–22 days of focused work
> **See [EXECUTION_GUIDE.md](docs/execution_guide.md) for detailed task instructions, context, and verification steps.**

---

## How to Use This File
- Check off tasks as you complete them: change `- [ ]` to `- [x]`
- Commit after every task: `git commit -m "feat: complete daily_agent_activity.sql"`
- Work **one file at a time** — never leave a file half-done

---

## 🛠️ Execution Strategy: Corrected Priority Order

| Priority | Phase | Rationale (Why) |
| :--- | :--- | :--- |
| **1** | **Phase 1: Generator Fixes** | Seed/reproducibility is foundational. Data must be consistent. |
| **2** | **Phase 2: ETL Improvements** | Data must load reliably and catch errors before anything else can be built. |
| **3** | **Phase 3: DB Indexes & Constraints** | Schema hardening. Prepares the database for heavy querying. |
| **4** | **Phase 5: KPI Views** *(Merge with Phase 3)* | The single source of truth. Everything downstream queries these views. |
| **5** | **Phase 4: Analysis SQL** | The portfolio centerpiece. Fully unblocked once the schema and views are stable. |
| **6** | **Phase 6: Testing** | Prove it works. Validates the integrity of everything built in steps 1-5. |
| **7** | **Phase 9: BI / Reporting** | Dashboarding. Can be parallelized with Phases 5 and 6. |
| **8** | **Phase 7: Automation** | Wires the working, tested pipeline together into a single click/command. |
| **9** | **Phase 8: Documentation** | Ongoing throughout, but gets its final polish here for recruiters. |


## PHASE 1 — Data Generation (Current: 70% → Target: 95%)

- [X] Add `--output-dir` and `--months` CLI parameters
- [X] Add `--seed` flag for reproducibility (`python generator.py --seed 42`)
- [X] Generate CSVs with headers and explicit dtypes (ISO 8601 dates, consistent decimals)
- [X] Add generator logging (console + file with timestamps, row counts, elapsed time, anomalies injected, --log-level arg)
- [X] Add output validation post-generation (row counts ±5%, no nulls in PKs, FK integrity)
- [ ] Add `requirements.txt` with pinned hashes (`--require-hashes`)
- [ ] Create `data_sources/__init__.py` (make it a proper Python package)
- [ ] Add `data_sources/generators/config.py` (centralize constants)
- [ ] Add anomaly injection report (`anomaly_report.csv`)
- [ ] Add `data_sources/generators/README.md`

---

## PHASE 2 — ETL Pipeline (Current: 35% → Target: 90%)

- [ ] Add logging to `data_to_pg.py` (INFO/ERROR with timestamps)
- [ ] Add retry logic with backoff (3x retries, 5s intervals)
- [ ] Add data validation on ingest (file exists, has headers, row count > 0, PK not null)
- [ ] Add transaction wrapping (ROLLBACK all on any failure)
- [ ] Add idempotency (TRUNCATE before load or skip if exists)
- [ ] Add `etl_load_log` metadata table (table_name, rows_loaded, timestamp, status, checksum)
- [ ] Add CSV checksum verification (hash each CSV, store in `etl_load_log`)
- [ ] Add environment variable support (`python-dotenv` for DB credentials)
- [ ] Add `--dry-run` flag (validate files without loading)
- [ ] Add `--incremental` flag (load only new months)
- [ ] Add error recovery (write failed rows to `errors/<table>_errors.csv`)
- [ ] Add pipeline orchestration to `run_pipeline.bat`

---

## PHASE 3 — Database & Schema (Current: 60% → Target: 90%) - Merged with PHASE 5. 

- [ ] Add indexes on FK columns (`Dim_Agents.supervisor_id`, `Dim_Accounts.client_id`, `Dim_Accounts.product_id`, all fact FK columns)
- [ ] Add indexes on common query columns (`Dim_Calendar.date`, `Fact_Interactions.interaction_date`, `Fact_PTP_Log.ptp_date`)
- [ ] Add composite indexes (`(product_id, month)`, `(agent_id, interaction_date)`, `(supervisor_id, month)`)
- [ ] Populate `002_kpi_views.sql` (7 views: v_contact_metrics, v_promise_metrics, v_recovery_metrics, v_productivity_metrics, v_handle_time_metrics, v_daily_mis, v_monthly_summary)
- [ ] Populate `003_agents_scorecards.sql` (agent composite score view)
- [ ] Create seed SQL scripts (`seeds/001_dim_products.sql`, `seeds/002_dim_calendar.sql`)
- [ ] Add CHECK constraints (DPD >= 0, utilization BETWEEN 0 AND 100, call_duration > 0)
- [ ] Add COMMENT ON TABLE/COLUMN for all tables
- [ ] Create `v_etl_load_summary` view
- [ ] Add data freshness query
- [ ] `v_contact_metrics` — RPC, RPC%, RPC/OpHr, RPC Arrears by agent/day/team/month
- [ ] `v_promise_metrics` — PTP count, PTP%, kept/broken count, kept%, BB conversion
- [ ] `v_recovery_metrics` — cures, cured amount, cure rate, agent vs self-cure
- [ ] `v_productivity_metrics` — utilization%, No Touch Letter rate, contacts/agent/hour
- [ ] `v_handle_time_metrics` — AHT-RPC, AHT-NonRPC, ACW-RPC, ACW-NonRPC
- [ ] `v_daily_mis` — consolidated daily view for Excel MIS report
- [ ] `v_monthly_summary` — month-level rollup for dashboard trend lines

---

## PHASE 4 — Analysis SQL (Current: 8% → Target: 100%)

### Supervisor-Level (6 files)
- [ ] `daily_agent_activity.sql` — per-agent daily totals + running window totals
- [ ] `agent_scorecard.sql` — composite weighted score + rank within team
- [ ] `coaching_opportunities.sql` — flag agents with WoW metric drops
- [ ] `agent_exception_report.sql` — outliers: top/bottom 5 by RPC%, AHT, PTP kept%
- [ ] `schedule_adherence.sql` — hourly activity vs expected, gap detection
- [ ] `eda_agents.sql` — distribution analysis, tenure vs RPC% correlation

### Manager-Level (6 files)
- [ ] `team_comparison.sql` — side-by-side team metrics + t-test approximation
- [ ] `agent_leaderboard.sql` — top/bottom 10, trend columns, WoW position changes
- [ ] `campaign_effectiveness.sql` — contact frequency vs RPC%, PTP set rate by time of day
- [ ] `handle_time_benchmark.sql` — AHT by product/agent/region vs SLA targets
- [ ] `workload_distribution.sql` — accounts/calls per agent, deviation from team avg
- [ ] `eda_supervisors.sql` — validate existing 464 lines + add supervisor tenure correlation

### Director-Level (5 files)
- [ ] `portfolio_health.sql` — % accounts per DPD bucket, cure rate by product, arrears trend
- [ ] `roll_rate_analysis.sql` — 30→60→90→120+ DPD migration matrix, MoM roll rates
- [ ] `recovery_trend_mom.sql` — MoM cures, cure rate, cost-to-collect, seasonal patterns
- [ ] `portfolio_concentration.sql` — top 10% by balance, geographic/product mix risk
- [ ] `target_vs_actual.sql` — KPI targets vs actuals, gap analysis, trend to target

---

## PHASE 6 — Testing (Current: 5% → Target: 100%)

- [ ] `test_row_counts()` — Dim_Agents=80, Dim_Clients=10000, Dim_Accounts≈20000
- [ ] `test_no_null_pks()` — zero nulls in all PK columns
- [ ] `test_fk_integrity()` — every FK value exists in referenced dimension
- [ ] `test_date_ranges()` — all fact dates within Oct–Dec 2025, calendar covers full year
- [ ] `test_weekday_only()` — no interactions on weekends
- [ ] `test_ptp_state_machine()` — no invalid PTP state transitions
- [ ] `test_dpd_logic()` — DPD >= 0, consistent with billing cycle
- [ ] `test_utilization_bounds()` — utilization between 0 and 100
- [ ] `test_call_duration()` — all durations > 0s, max < 3600s
- [ ] `test_kpi_view_output()` — each view returns rows, no nulls, percentages 0–100
- [ ] `test_etl_idempotency()` — running ETL twice = same row counts, no duplicates
- [ ] `test_generator_seed()` — same seed produces identical output

---

## PHASE 9 — BI & Reporting (Current: 40% → Target: 90%)

- [ ] Validate DAX formulas in `dax_measures_dictionary.md` against KPI definitions
- [ ] Document Power BI data model (relationships, cardinality, cross-filter direction)
- [ ] Add dashboard screenshot (`dashboards/assets/screenshots/dashboard_preview.png`)
- [ ] Add sample Excel report generation script (Python → `daily_mis.xlsx`)
- [ ] Add automated report scheduling simulation (generate reports for Oct–Dec 2025)
- [ ] Validate DAX measures match SQL view outputs

---

## PHASE 7 — Automation & Operations (Current: 15% → Target: 90%)

- [ ] Rewrite `run_pipeline.bat` (check docker → generate → validate → ETL → views → tests → report)
- [ ] Add exit codes and clear error messages
- [ ] Add pipeline log file (`logs/pipeline_YYYYMMDD_HHMMSS.log`)
- [ ] Add `test/validate_data.py` — data validation script with pass/fail report
- [ ] Add Docker health check in `docker-compose.yml`
- [ ] Add `.dockerignore`
- [ ] Add `docker-compose.test.yml` for CI ephemeral DB
- [ ] Add Makefile (`make generate`, `make db-up`, `make etl`, `make test`, `make full-pipeline`)

---

## PHASE 8 — Documentation (Current: 65% → Target: 95%)

- [ ] Add `QUICKSTART.md` (5-minute setup: prerequisites + 3 commands)
- [ ] Add `TROUBLESHOOTING.md` (Docker errors, port conflicts, ETL failures, DB reset)
- [ ] Add data lineage diagram (generator → CSV → ETL → PostgreSQL → views → BI)
- [ ] Add `CHANGELOG.md`
- [ ] Add runbooks for each phase (generator alone, ETL alone, analysis alone)
- [ ] Add KPI view documentation (what it calculates, source tables, example query)
- [ ] Add test documentation (how to run, what validates, how to add new tests)
- [ ] Update README with status badges (Build, Tests, Last Updated)

---

*Last updated: 2026-05-04 | Next milestone: Phase 1 complete*
