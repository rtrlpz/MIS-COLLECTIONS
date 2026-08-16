# SQL — Medium — Tasks

```
learning/
├── _reference/            ← READ FIRST (datasets.md, kpi_glossary.md, data_dictionary.md)
├── sql/
│   ├── README.md
│   └── medium/            ← YOU ARE HERE
│       ├── tasks.md       ← current file
│       ├── results.md     ← guidance, peek AFTER attempting
│       └── work/          ← your .sql files live here
├── python/  notebooks/  excel/  powerbi/  git-cli/
└── README.md
```

**Up from basic:** you can count, filter, group, sort, and compute a rate from two sums. Now we make queries *answer why* — joins, conditional logic, date math, CTEs, and window functions.

**Setup:** DB running (see `_reference/datasets.md` §5). Create `work/attempt_*.sql` per task.

**Discipline:** attempt → commit → then read `results.md`.

---

## Task 1 — Joining a fact to two dimensions (and surviving the blowup)

The supervisor: *"Break down January interactions by product type and by region. I want to see real usage by our customers, not by internal teams."*

**What you'll practice:** the diamond join — a fact in the middle, two dimensions on the sides — and the JOIN BLOWUP, the #1 silent bug in SQL.

Steps:
1. Map the path: `fact_interactions` → `dim_accounts` (for product) → and where does region come from? The account's client, or the agent? Trace it before writing a line.
2. Build the join, aggregating by `product_type` and `region`.
3. Sanity-check the total rows *before* aggregating: does `COUNT(*)` stay equal to the raw fact count for the month, or did it multiply? If it multiplied, you've hit a fan-out — find it and fix it.
4. Re-read the data dictionary for whether the needed labels are already denormalized (this project occasionally denormalizes — know when you're *supposed* to skip a join).

**Guiding questions:**
- Which dimension in this model is at "many accounts per client"? Which is "many accounts per employee"? If either relationship is one-to-many, what does that do to a `COUNT` on the fact?
- Would aggregating by *agent's* region answer a different question than aggregating by *account's* region? Which one did the supervisor actually ask for?

**Deliverable:** `work/attempt_1.sql` — product × region grid for January, plus a comment explaining why your row counts did (or didn't) stay exact.

---

## Task 2 — CASE buckets, or "every accent in my data is now a palette"

The supervisor: *"Give me a delinquency profile of the current portfolio: bucket accounts by their DPD — current, early, mid, late, and severe — and show how many accounts and how much arrears sit in each bucket."*

**What you'll practice:** turning continuous DPD into meaningful bands with `CASE`, then aggregating over the buckets. Buckets are where *analysis* happens — nobody reads a 200-row DPD histogram.

Steps:
1. Look at the DPD column in the latest `fact_eom_snapshot`. Also look at the project's own bucket terminology in `_reference/data_dictionary.md` (there's a predefined bucket set used everywhere — reuse it so your bands match the house standard).
2. Express the bands in `CASE`, making sure literals and boundary semantics (inclusive/exclusive) are explicit.
3. Aggregate accounts and arrears per bucket. Also report per product type × bucket — one bucketed table is the profile; the cross-tab is the *story*.
4. Verify the special statuses: this table mixes `Activo` and `Mora` accounts — decide where non-Mora/current accounts belong in the band ladder, or where `is_cured`-type flags appear.

**Guiding questions:**
- Why does `CASE` give you *both* a new dimension column *and* a filter condition depending on whether it's in `SELECT` or `WHERE`? Try putting your status check directly in `WHERE` vs. encoding it in `CASE`.
- If you bucket by DPD but leave out the accounts with `NULL` or unusual DPD, where do they go? What does "missing" as a bucket tell you?

**Deliverable:** `work/attempt_2.sql` — DPD bucket profile + per-product cross-tab for the latest snapshot.

---

## Task 3 — Date math, or "same question last month"

The supervisor: *"Show me weekly interaction volumes for the team, with each week's average connected per agent-day, and flag the weeks where a weekday was skipped."*

**What you'll practice:** date arithmetic and window-aligned trimming — the workhorse of longitudinal reporting: `date_trunc`, interval math, and the discipline of "same-sized periods". Also two important habits: day-of-week frequency to spot skipped days, and the weekend gap — this portfolio has *no* weekend interactions, so a "week with a skipped day" is a real event to find.

Steps:
1. Truncate each interaction date to the ISO week ("week starting which day?"), then aggregate counts per week.
2. For "average connected per agent-day", decide the denominator: actual agent-days that appear in the time log, or calendar weekdays? These differ — justify the choice.
3. Detecting a skipped weekday: compare a per-week count of distinct interaction dates against the expected weekday count for that ISO week.
4. Layer the weekend filter correctly — is it a `WHERE` or something you must account for in the expected-day count? (Glossary §6 has a note about weekend behavior in this portfolio.)

**Guiding questions:**
- Why `date_trunc('week', …)` instead of `GROUP BY` on a date string? What changes on the boundaries between weeks, and why is ISO important?
- A week is Monday–Sunday. If you compare against a naive 7-day expectation, will you misfire *every* week here? What's the *right* expected day count?

**Deliverable:** `work/attempt_3.sql` — weekly table (week start date, count, avg connected per agent-day, distinct-days-used, flag for skipped weekdays), with a comment defending the expected-count logic.

---

## Task 4 — CTEs: from one giant query to a readable pipeline

The supervisor: *"Genuinely I need the ≥90-days-past-due accounts plus their last interaction's date and outcome. Accounts without any interaction should still appear, with a NULL for that last interaction."*

**What you'll practice:** building a *query pipeline* with CTEs — the `WITH` stage that turns a wall of SQL into named, reviewable layers — plus keeping the *left* side even when the right side has no match.

Steps:
1. Split the question into stages: (a) which accounts are severely delinquent as of latest snapshot, (b) per account *their most recent* interaction, (c) combine.
2. For stage (b), think about selecting the "latest row per account" before you join — you'll reach for a window/RANK approach, but for this task, a CTE with a row-numbered pass gets you there too. Which do you prefer and why?
3. Combine with the join flavor that keeps every severe account even if it has zero interactions. Explain in a comment what happens to a right-side NULL.
4. Final projection: account, status, DPD bucket, last-interaction-date, last-outcome.

**Guiding questions:**
- Why is a CTE better than a subquery for reviewing someone else's (or your own, next-week) SQL?
- "Latest interaction per account" needs an ordering key. When two interactions share a date, what's the tiebreaker, and does it matter for a report like this?
- Why `LEFT JOIN` (vs `INNER`) here, and where would a `LEFT JOIN` *hide* rows rather than preserve them (the head-scratch day you'll thank me for)?

**Deliverable:** `work/attempt_4.sql` — pipeline with ≥2 CTEs producing the severe-accounts + last-interaction view (must include the NULL cases).

---

## Task 5 — Window functions: the previous month's number, in the same row

The supervisor: *"Give me monthly interactions per team, and next to each month the previous month's count, plus the delta. I want month-over-month movement without re-jointing the table to itself."*

**What you'll practice:** window functions — `LAG`/`LEAD`, `PARTITION BY`, `ORDER BY` inside the window — the difference between "aggregate, then look" and "look inside each group".

Steps:
1. Aggregate monthly counts per team first (a plain GROUP BY of interactions).
2. Now bring in the previous month's value with `LAG` partitioned by team and ordered by month. Compute the delta and the % change.
3. Add cumulative (running) total per team with a second window — show you can *reuse the same partition* in one query.
4. Note what happens to the first row of each team partition (no previous value) and decide how to present it.

**Guiding questions:**
- What's the difference between a plain `GROUP BY` sum and a window sum over a `PARTITION`? When would you ever want *both* in one query?
- Why is `LAG` safer than a self-join for previous-month? What silent bug can a self-join introduce on months with zero activity (a month that exists in the calendar but has no interactions)?
- Do you specify the frame (`ROWS BETWEEN …`) in your running total? What's the default for `ORDER BY` present, and does it matter here?

**Deliverable:** `work/attempt_5.sql` — per team: month, count, previous count, delta, % change, running total; with a comment on the first-row edge case.

---

### Finish

Attempt all five (right or wrong), then read `medium/results.md` and compare. Note divergences in your files — that's your log.

**Move up when:** you can explain, out loud, the difference between `LAG(… OVER (PARTITION BY …))` and a self-join, and when you'd pick each.