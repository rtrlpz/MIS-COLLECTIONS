# SQL — Advanced — Tasks

```
learning/
├── _reference/            ← READ FIRST (datasets.md, kpi_glossary.md, data_dictionary.md)
├── sql/
│   ├── README.md
│   └── advanced/          ← YOU ARE HERE
│       ├── tasks.md       ← current file
│       ├── results.md     ← guidance, peek AFTER attempting
│       └── work/          ← your .sql files live here
├── python/  notebooks/  excel/  powerbi/  git-cli/
└── README.md
```

**Up from medium:** you join, bucketed, did date math, pipelined with CTEs, and windowed. Now the final move: **reproduce the project's own KPI views from raw tables** and hold your number against theirs. This is the closest SQL can get to "defend your work in front of the department".

**Setup:** DB running (see `_reference/datasets.md` §5). Create `work/attempt_*.sql`. Read the views themselves in `database/migrations/002_kpi_views.sql` as *second* resort.

**Discipline:** attempt → commit to your own numbers → compare against `v_` views → then read `results.md` to diagnose.

> **The advanced rule:** a number that differs from the reference view is **not a failure** — it's a *finding*. Find the semantic gap (denominator? filter window? dedupe? bucketing?) and write it down. That is the skill.

---

## Task 1 — Rebuild `v_contact_metrics` from scratch

The supervisor: *"We publish RPC% by team to ops every month. Before you trust our view, reproduce the number from the raw interaction table yourself."*

**What you'll practice:** reverse-engineering a reference implementation — reading intent from column names, and hunting the exact denominator convention.

Steps:
1. Read `_reference/kpi_glossary.md` §1 for the RPC% definition this project *commits to*. State it in one line before querying.
2. Build team × RPC%, connections-per-team, and RPCs-per-operational-hour from `fact_interactions` — join through employees for the team label. Check glossary for what "operational hour" means and whether it comes from a different table.
3. Compare your output against `v_contact_metrics` **column by column**.
4. For any column that diverges, hypothesize *why* (different denominator, extra filter like channel, or metric defined over a different population), then prove your hypothesis with one targeted query.

**Guiding questions:**
- Is the rate `SUM(rpc) / SUM(connected)`, or over *operational hours*? The glossary names a primary convention — but the view may legitimately expose several.
- Does the view restrict channels? Does your raw version need to, to match?

**Deliverable:** `work/attempt_1.sql` — your derivation + a written diff note (which columns matched, which didn't, and the semantic reason).

---

## Task 2 — Rebuild the promise-and-kept chain, `v_promise_metrics`

The supervisor: *"PTP% and KP% drive our targets. Show me the promise chain by team: how many RPCs → promises (PTP) → kept promises (KP), and the conversion."*

**What you'll practice:** three facts and one logic chain — RPCs (interactions) → PTPs (promise log) → KPs (payments honoring promises) — plus understanding what "evaluated" means in a kept-promise rate.

Steps:
1. Draw the chain on paper first: which table has RPCs, which has promises, which has payments, and on what key does each hop connect? (Note: `fact_payments` carries a `ptp_id` but the FK is intentionally loose — read why in the dictionary.)
2. Build the PTP side: per team, count RPCs (reuse Task 1), count promises, derive PTP%.
3. Build the KP side: of *evaluable* promises, how many were kept? Decide what "kept" means (a payment? a payment arriving on time? cure-related?) from the glossary — then decide which promises are "evaluable" at all.
4. Derive BB conversion (PTP × KP) and compare all columns against `v_promise_metrics`.

**Guiding questions:**
- The glossary notes a specific fix history: *BB conversion uses a product of two rates* — which rates, and why is the *product* semantically right?
- "Evaluable promises" — promises whose target date has passed, or all promises ever? Your choice changes the rate; the view has an answer.

**Deliverable:** `work/attempt_2.sql` — the chain per team with PTP%, KP%, BB, plus a diff note vs the view.

---

## Task 3 — The DPD migration matrix `v_dpd_migration_matrix`

The supervisor: *"Last month's 30-days-past-due accounts — where did they go this month? I want a matrix: bucket-last-month × bucket-this-month, with counts."*

**What you'll practice:** a state-transition matrix from two snapshots of the same table — the pairing problem that powers roll-rate analysis and "cure vs crawl" thinking.

Steps:
1. From `fact_eom_snapshot`, pick two consecutive months (the most recent available pair).
2. Pair accounts across the two months on `account_id`, bringing each month's `dpd_bucket` into the same row. Choose the join flavor so you only get accounts present in BOTH snapshots (the matrix population) — but also build the version that keeps pre- or post-only accounts as a displaced row, and note which you'd report.
3. Pivot/aggregate to a matrix: rows = last-month bucket, columns = this-month bucket, cells = account counts (and optionally total arrears).
4. Compare against `v_dpd_migration_matrix`. Check whether their population definition matches yours, or whether they include partial/new accounts.

**Guiding questions:**
- Why is the migration matrix computed from **snapshots** and not from event data? What assumption does that make about an account appearing in exactly one row per month?
- If an account's bucket is "Current" last month and "31-60" now, what does the diagonal (roll-to-same) vs off-diagonal imply operationally?

**Deliverable:** `work/attempt_3.sql` — paired pop + matrix, plus a diff note on population handling vs the view.

---

## Task 4 — The composite scorecard, `v_agent_scorecards`, and an audit

The supervisor: *"Numbers meet people only in the scorecard: five metrics weighted into one score per agent. Reproduce it, and then — audit it."*

**What you'll practice:** assembling five different KPI views into one composite (the real "last mile" of analytics), then *verifying a published artifact by rebuilding it*. Weighted scoring, normalization, and the honesty of checking the house's own output.

Steps:
1. Read the scorecard weights from `_reference/kpi_glossary.md` (they're fixed and documented: five components with specific weights — find them). Also read `004_agents_scorecards.sql`'s *comment* if available.
2. Re-derive each component per agent from the raw facts (which you can now do): RPC-based, KP-based, cure-based, utilization-based, handle-time-based. Be explicit about each component's denominator.
3. Combine into a single weighted score, exactly as the view does (same weights, same NULL policy — what happens to an agent missing one component?).
4. Diff your scorecard against `v_agent_scorecards`. For top-3 diverging agents, isolate *which component* caused it and why (a component definition difference is common). Write up the audit as a comment.

**Guiding questions:**
- Should an agent with all a perfect metric but one failing one get the failing score, or "no data" (NULL)? The view has a policy — find it.
- A weighted composite mixes rates with different denominators (RPC% vs utilization%). What does that do to comparability? Is the score even *normalized*?

**Deliverable:** `work/attempt_4.sql` — weighted scorecard derivation + written audit of the top divergences against the shipped view.

---

### Finish

Run all four. For each, update your file with a short "diff log": matched, diverged, root cause. That log is your deliverable to the supervisor.

**Graduate when:** you can rebuild a project view from raw tables under time pressure, and — more importantly — you can *explain any one-number difference* between yours and the house's.