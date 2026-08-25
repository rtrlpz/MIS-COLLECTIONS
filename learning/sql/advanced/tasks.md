# SQL Advanced — Your Inbox (level 3 of 3)

```
You are here: learning/sql/advanced/
Assumed:      medium/ complete — CTEs and window functions are warm
Your answers: work/attempt_*.sql
Solutions:    advanced/results.md — after a serious attempt; then RUN and DIFF
Theme:        stop consuming the official v_* views — audit them
New tools:    LAG/LEAD state machines, cohort windows, view-vs-raw reconciliation,
              forecasting baselines, report governance queries
```

**What this level gives you.** The senior half of the job: proving — or breaking — the numbers leadership acts on. Every task ends with a reconciliation against a project view; divergence must be *explained*, never ignored.

---

## Task 1 — Roll rates: how accounts move between buckets
📥 **Inbox:** From Credit Risk Director · Tue 9:00 · "board pack closes Friday"

> "I need the month-over-month migration matrix for H2: from bucket × to bucket, account counts. Rank buckets by severity, not alphabet — Current, then 1-30, 31-60, 61-90, 90+. And I keep hearing some accounts 'exit' the book; tell me where they went."

**Background:** Roll rates are the earliest warning of portfolio deterioration. Each account has one row per month-end in `fact_eom_snapshot`; consecutive rows define transitions.

**Your job:**
1. Use `LAG` over each account's snapshot history to pair every month with its predecessor.
2. Join `dim_delinquency_bucket` twice (from/to) for severity ranks.
3. Aggregate the full H2 matrix; classify each cell improved / stable / worsened.
4. Investigate exits: accounts present in month N but absent in N+1.

**Guiding questions:** Why must the LAG partition be per-account? What does NULL previous bucket mean vs missing next row? Which cells would an alphabetical sort scatter?

**Data pointers:** `fact_eom_snapshot`, `dim_delinquency_bucket.sort_order`; cross-check: `v_dpd_migration_matrix`.

**Done when:**
- [ ] Full matrix, severity-ordered axes, direction labeled
- [ ] Exit behavior explained vs the view's handling
- [ ] One-sentence risk read: is H2 worsening or healing?

---

## Task 2 — Vintage curves: Mora % by account age
📥 **Inbox:** From Portfolio Analytics · Thu 11:00 · "new-business quality review"

> "Are newer vintages worse, or is it the same book aging? Build Mora% by months-on-book, one curve per open-date cohort month. If recent cohorts run hotter at the same age, underwriting needs to hear it."

**Background:** A vintage curve replaces calendar time with account age — the only fair comparison between cohorts. Open dates span ~2 years; snapshots cover 2025.

**Your job:**
1. Cohort = month of `open_date`.
2. Months-on-book = whole months between cohort and snapshot month.
3. Mora % per cohort × age.

**Guiding questions:** Which ages have thin data (right-edge censoring)? Why can two cohorts show opposite calendar trends yet identical curves?

**Data pointers:** `dim_accounts.open_date`, `fact_eom_snapshot.status`; glossary: vintage.

**Done when:**
- [ ] Cohort × months-on-book Mora% grid
- [ ] Edge-age caveat noted; verdict on new-cohort quality

---

## Task 3 — Re-entry: cured accounts coming back
📥 **Inbox:** From Collections Strategy Lead · Mon 3:00 · "the recycle-rate question, again"

> "Every strategy meeting someone claims our cures bounce straight back into arrears. Quantify it: of accounts cured between month-end M and M+1, what share sit in Mora again by M+2? Every window across 2025, chronologically."

**Background:** Cured = Mora at month-end N and Activo at N+1. Re-entry = that account Mora again by N+2. The project treats 5–25% as the plausible band for this engine.

**Your job:**
1. Monthly status sets per account from snapshots.
2. Per window (M, M+1, M+2): cured set, re-entered subset, rate.
3. All windows chronological; flag any outside the band.

**Guiding questions:** Why three-month windows instead of two? What would a near-zero rate reveal about your join logic?

**Data pointers:** `_reference/kpi_glossary.md` → re-entry; band documented in project test suite.

**Done when:**
- [ ] Window table: cured_n, reentered_n, rate_pct
- [ ] Band verdict + note on any breaching window

---

## Task 4 — Audit the agent scorecard from raw tables
📥 **Inbox:** From MIS Manager · Wed 10:00 · "HR wants the formula defended"

> "Composite scorecards feed coaching and pay conversations. Before HR signs off, prove we can rebuild `v_agent_scorecards.composite_score` from raw tables — weights RPC 25%, KP 25%, Cure 20%, Utilization 15%, AHT 15%, AHT inverted against a 300-second scale. Wherever your rebuild disagrees with the view, explain or escalate."

**Background:** The view builds on `v_monthly_summary` (agent grain). Read `database/migrations/004_agents_scorecards.sql` FIRST — reproducing documented definitions is allowed; inventing them is not.

**Your job:**
1. Rebuild the five components per agent-month from raw facts.
2. Apply normalization exactly as 004 does (including the AHT inversion cap).
3. Composite; diff against the view; classify mismatches: rounding vs definitional.
4. Try BOTH monthly aggregation styles (average-of-daily-rates vs ratio-of-sums); report which matches the view.

**Guiding questions:** Which component is most sensitive to aggregation choice? Any agent-month missing from your rebuild — why?

**Data pointers:** `004_agents_scorecards.sql` (read first), `v_monthly_summary`, `v_agent_scorecards`.

**Done when:**
- [ ] Raw rebuild + diff query, mismatch counts by component
- [ ] Aggregation-style verdict documented
- [ ] Sign-off paragraph you'd hand HR

---

## Task 5 — Reconcile portfolio cure rate (the industry definition)
📥 **Inbox:** From Portfolio Manager · Fri 1:00 PM · "regulators ask, we answer"

> "Our month-end view reports portfolio cure rate against prior month-end delinquent stock. Rebuild it from raw: cured accounts this month divided by Mora stock entering the month. Show both series for the full year and certify they agree — or tell me precisely why they don't."

**Background:** This definition was fixed in a past audit: cures ÷ prior Mora stock, NOT cures ÷ payments. `v_monthend_portfolio` implements it with `LAG`. Use only its OUTPUT for comparison, not its internals.

**Your job:**
1. Month-end Mora counts from snapshots, chronological.
2. Cured-this-month = accounts flipping Mora→Activo between consecutive month-ends.
3. Rate = cured ÷ prior-month Mora; join against the view; quantify gaps.

**Guiding questions:** Why is prior stock the right denominator while same-month payments are wrong? What happens in month one with no prior?

**Data pointers:** cross-check: `v_monthend_portfolio.portfolio_cure_rate`; glossary → cure.

**Done when:**
- [ ] 12-row series: rebuilt vs view rate + gap column
- [ ] Certification sentence or precise defect report

---

## Task 6 — Post-write-off recovery curve by cohort
📥 **Inbox:** From Recovery Operations · Tue 2:30 · "is the recovery desk paying for itself?"

> "Write-offs aren't the end — we chase balances afterward. Group write-offs into cohorts by month; show recovered dollars by months-since-write-off. I want to know whether cash keeps trickling after month one or dies immediately."

**Background:** `fact_writeoffs` marks charge-off; `fact_recoveries` records partial collections draining a recoverable balance. Sparse early data is legitimate — nothing to recover before write-offs exist.

**Your job:**
1. Attach each recovery to its account's write-off date.
2. Months-since = whole months between events.
3. Recovered $ per cohort × months-since + cumulative share per cohort.

**Guiding questions:** Can one account have several recoveries — does your grain handle it? Which cohort collects steepest early, and why might that be?

**Data pointers:** cross-check: `v_writeoff_recovery`; dictionary → recoveries.

**Done when:**
- [ ] Cohort × months-since grid + cumulative %
- [ ] Verdict: does recovery cash persist past month 1?

---

## Task 7 — Delinquency forecast baseline → capacity planning
📥 **Inbox:** From Site Director · Thu 4:00 · "budget pre-work — rough is fine, indefensible isn't"

> "Starting point for January staffing: project Mora stock forward with something simple and honest, translate it into collector-hours, document every assumption on the page. No data science needed — arithmetic I can defend."

**Background:** Capacity = delinquent accounts × attempts per account ÷ collector productivity per day. A naive forecast is acceptable when its assumptions are explicit.

**Your job:**
1. Monthly Mora stock series from snapshots.
2. Projection: trailing 3-month moving average (note alternatives you rejected).
3. Convert projected accounts to collector-hours using attempts/day and accounts-per-collector/day assumptions quoted from project config, stated inline.
4. Deliver: projected stock, required hours, FTE-equivalents.

**Guiding questions:** What does the naive method ignore (seasonality? trend?)? Which assumption breaks first under questioning?

**Data pointers:** `_reference/kpi_glossary.md`; config values quoted in your comments.

**Done when:**
- [ ] Stock series + projection table
- [ ] Hours & FTE math with visible assumptions
- [ ] Caveat list a director could read aloud

---

## Task 8 — Report governance audit: same metric, three definitions?
📥 **Inbox:** From Head of MIS · Mon 8:00 · "governance initiative starts today — you're first"

> "We suspect KP% and RPC% live in several views with subtly different math. Inventory every view exposing them, then COMPARE outputs for a sample period. Two deliverables: the inventory, and a discrepancy report saying which view disagrees with which, by how much, and which source should be canonical."

**Background:** Governance means one metric, one definition, one home. This project ships ~16 views built over time — ideal audit terrain.

**Your job:**
1. Catalog query: every view + column matching rpc/kept percentage metrics.
2. Pull one fixed agent-month sample through each candidate view.
3. Pairwise diff; classify rounding vs real definitional drift.
4. Recommend canonical sources per metric.

**Guiding questions:** Is every difference a bug — when is granularity the explanation? Which view gets nominated and why?

**Data pointers:** `information_schema.columns` over views; candidates: `v_contact_metrics`, `v_daily_mis`, `v_promise_metrics`, `v_agent_scorecards`.

**Done when:**
- [ ] Metric inventory saved
- [ ] Pairwise discrepancy table for the sample
- [ ] Canonical-source recommendation memo

---

## Task 9 — Point-in-time team attribution (SCD2)
📥 **Inbox:** From Workforce Analyst · Wed 12:30 · "July transfer fairness question"

> "Six collectors switched teams on July 1. Their July calls must credit the RECEIVING team; June calls stay with the old one. The employee table is 'current state' only — build point-in-time attribution from history and show which teams' July numbers move versus the naive current-state join."

**Background:** `dim_employee_history` versions org attributes (`valid_from`, `valid_to`, `is_current`). Naive joins silently rewrite history.

**Your job:**
1. Join July interactions to the history version valid ON each interaction date.
2. Repeat with current-state `dim_employees.team_name`.
3. Team-level July totals both ways; highlight mover teams and shift size.

**Guiding questions:** How do you handle the open-ended row (`valid_to = 9999-12-31`)? Which business questions legitimately want current-state instead?

**Data pointers:** dictionary → dim_employee_history; confirm six transfers effective Jul 1.

**Done when:**
- [ ] History-driven attribution query
- [ ] Both attributions compared; movers quantified
- [ ] One-line guidance: when to use which

---

## Finish

Nine audits deep, you can now defend — or correct — every number this pipeline ships. Close the loop without a database in [`../../python/basic/tasks.md`](../../python/basic/tasks.md).
