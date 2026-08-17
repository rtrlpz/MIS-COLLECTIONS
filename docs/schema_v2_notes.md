# Schema v2 — Audited Findings (post-learning redesign backlog)

**Status:** Living backlog. Parked by decision during the learning tracks; revisit after Power BI / Excel tracks finish.
**Source:** Schema audit performed while working `learning/sql/basic` (verifying first rows of every table against the live DB).
**Rule applied:** a number/semantic that differs from the reference (`v_*`) or from common sense is a **finding**, not a failure.

---

## Confirmed bug — FIXED

### Roll rate / DPD migration direction compared bucket *text*, not severity order

- `v_dpd_migration_matrix` (002_kpi_views.sql) used `next_bucket::text > dpd_bucket::text`.
- `roll_rate_analysis.sql` §3's `pct_rolled_forward` used `dpd_bucket > prev_bucket`.
- Root cause: `'Current'` sorts **above** all digit buckets (`'1-30'`…`'90+'`) in ASCII, so moving *into* Current from any delinquent bucket was classified `Deteriorated` (and 90+→Current was only correct via a special case).
- Fix: introduced an explicit severity `rank` (Current=0, 1-30=1, 31-60=2, 61-90=3, 90+=4) via a `bucket_ranks` CTE and ordered comparisons on rank. Applied to the live DB and verified:
  - `1-30/31-60/61-90 → Current` → now `Improved` ✔
  - `90+ → Current` → `Cured` (preserved) ✔
- **Lesson for learners:** this bug lives in the answer-key view itself — a textbook reason to *audit* reference views, never blindly trust them.

---

## Verified findings (parked — do not build until after learning)

### A. Semantics / definitions to standardize

| # | Finding | What the repo does today | Verdict | Fix direction |
|---|---|---|---|---|
| 1 | **Cure vocabulary is loose** | `is_cured=True` when a payment brings `arrears<=0`; `cure_flag` = Agent_Cure / Self_Cure / None. "Cured Amount" = `SUM(amount_paid WHERE is_cured)` which can exceed arrears cleared by overshoot. | Defines cure now, but "collected / cured / recovery" are not one canon | Agree once: *cleared arrears* vs *collected* vs *recovery*; add a canonical glossary + optional view columns (`arrears_cleared`, `net_recovery`) |
| 2 | **Client `segment` muddles product + tier** | Values: `Retail / Premium / Tarjeta / Prestamo / Hipoteca` — three product names, two client tiers, plus separate `income_bracket` | Semantics unclear | Split client tier from product affinity; or drop `segment` and keep `income_bracket` + product role |
| 3 | **Min payment rule is display-only** | `dim_products.min_payment_rule` VARCHAR (`'2% of Balance'`, `'Fixed Monthly Installment'`); the *value* is precomputed in `dim_accounts.min_payment` | Fine while non-computational | Only promote to a rule table if it needs to drive math (v2) |

### B. State vs events (the "account is affected" theme)

| # | Finding | What the repo does today | Verdict | Fix direction |
|---|---|---|---|---|
| 4 | **No current account state** | `dim_accounts` has no balance/status; `fact_payments` keeps `balance_before/after` per payment; `fact_eom_snapshot` freezes state monthly | Biggest structural gap. The generator *maintains* in-memory state (Mora↔Activo, arrears, dpd) but only serializes month-end | Add a current-state table (SCD2 status/balance/dpd) refreshed by ingestion, or an account-day ledger |
| 5 | **Payments don't "transact" on the account** | Effect exists only as before/after columns + monthly snapshot; no intra-month status row | Same root as #4 | Covered by #4 |
| 6 | **PTP status is pre-written, not derived** | `fact_ptp_log.status` (Kept/Broken) authored by the generator; `ptp_id` deliberately has no FK (no fact-to-fact) | Event-driven status is cleaner | Derive status via a view: Kept = payment ≥95% of promised within grace. Great **advanced learning task** |
| 7 | **EOM snapshot asked "is it necessary?"** | Monthly all-account freeze: balance/arrears/dpd/bucket. Powers migration matrix, roll rates, portfolio health, vintage, monthly rollups | **Necessary — keep.** It is the "current state" frozen monthly; complement, don't remove | See #4 |

### C. Metric definitions / naming mismatches

| # | Finding | What the repo does today | Verdict | Fix direction |
|---|---|---|---|---|
| 8 | **Utilization expects ≥90%, repo measures talk-share** | Repo `utilization` = actual THT seconds ÷ operational seconds (cap 0.95); healthy 30–60%. A hidden `CFG["utilization"]=(0.85,0.97)` sizes `operational_hours = schedule × utilization` | Definitional: the ~90% number exists but is never exposed as a KPI | Add an **occupancy/adherence** metric (~70–90% target) alongside talk-share; or rename to avoid collision |
| 9 | **THT↑ ⇒ more cure/collected (hypothesis)** | n/a — not a bug | Treat as **analytics exercise**, not schema change | EDA: correlation + directionality + non-linearity (learning task) |

### D. Missing context (the "model the bank" ideas)

| # | Finding | What the repo does today | Verdict | Fix direction |
|---|---|---|---|---|
| 10 | **No funding source / banking relationship** | Payments have `payment_method` string only; clients have static `risk_score` gauss(650,80) | Fully valid critique | v2: deposit accounts + payment-source link + ability-to-pay snapshot |
| 11 | **MOR has no term/LTV/collateral** | `dim_products` = 3-row type catalog (rate/grace/min); `dim_accounts` = limit, due_day, min_payment | Valid | v2: `dim_loan_contract` (instance terms: term, apr, installment, LTV, collateral, maturity) + `dim_billing_cycle` |
| 12 | **No behavioral risk tier** | `dim_clients.risk_score` is static decoration, unrelated to behavior | Strongest *add* idea | Compute tier from balance, DPD, missed payments in 12mo → `v_client_risk_tier` (advanced learning task first) |
| 13 | **Write-off early + nothing after** | Criteria: 5% of 91+ DPD per month; amount = arrears × pct; `balance −= amt`, `status → WrittenOff` | 91+ is early vs industry (120–180d); post-write-off recovery (agency/legal) unmodeled | v2: align criteria per product/stage; model collateral recovery + net shortfall |
| 14 | **Org hierarchy is denormalized strings** | `team_name`, `region` on `dim_employees` only | Valid for org analytics | v2: promote to `dim_region` / `dim_team` (FK-additive; keep columns for view compatibility) |

---

## How to use this doc
- **Do not build any of A–D until the learning tracks and Phase 9/11 are done.**
- Items marked "learning task" should land in `learning/` track material first (SQL/python advanced audits), *then* become schema features.
- When v2 work starts: address #4 (state table) first — it unlocks #5/#6/#12; then #10/#11; org + glossary (A) are low-risk cleanup.

## Change log
- 2026-08-16 · Roll-rate bucket-rank bug **fixed** in `002_kpi_views.sql` + `roll_rate_analysis.sql`, applied & verified on live DB.