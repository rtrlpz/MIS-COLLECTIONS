# SQL — Medium — Results (Guidance)

```
learning/
├── _reference/            ← datasets.md, kpi_glossary.md, data_dictionary.md
├── sql/
│   ├── README.md
│   └── medium/            ← YOU ARE HERE
│       ├── tasks.md
│       ├── results.md     ← current file
│       └── work/
├── python/  notebooks/  excel/  powerbi/  git-cli/
└── README.md
```

**How to use this file:** attempt → commit → read one section. Guidance only: reasoning path, steps-with-why, verification, traps. No full queries, no computed values.

---

## Task 1 — Joining a fact to two dimensions (and surviving the blowup)

**Thinking path:**
- Trace the path BEFORE writing SQL. Interactions carry `account_id` (→ product) and `agent_id`. Region can come from two places — the *account's* region doesn't exist directly; the *agent* has a region, and the account's *client* may have one too. Read the dictionary: which of those is real for this model? The supervisor asked for "our customers", which strongly implies *client/account* side, not internal team side.
- The diamond join check: join the fact to each dimension and aggregate. The cardinality of the relationship determines whether counts stay exact:
  - one account → one product: safe, no multiplier.
  - one account → many clients, or many accounts → one client: if a dimension has *multiple rows per key*, the join **fans out** and `COUNT(*)` on the fact balloons. That's the JOIN BLOWUP.
- This project denormalizes `product_type` onto the account dimension — a hint that sometimes the *right* design is to skip the extra hop. But `region` is likely still a "join to employee/client" situation. The skill: know which labels are safe to trust and which require the join.

**Verification strategy:**
- Compare `COUNT(*)` with and without each join. Stable = good. Changed = fan-out or NULL-drop from an inner join.
- Cross-tab: sum your product×region cells; it must equal your January total from Basic Task 2.

**Traps & worth knowing:**
- The most common fan-out in this model: joining a fact through a dimension that has multiple related rows (e.g., employee with multiple accounts, or client with multiple accounts). Diagnose by `COUNT(DISTINCT <pk>)` before and after.
- `INNER` join silently drops facts whose key is missing. For "how many interactions" that's a bug with a smile on it.

---

## Task 2 — CASE buckets

**Thinking path:**
- Reuse the project's bucket vocabulary (see dictionary) so your "current/early/mid/late/severe" bands match what the house views already produce. The dictionary lists the actual bucket labels used in this data.
- Decide boundary semantics explicitly. "DPD between X and Y inclusive?" — the off-by-one is invisible yet ruining every downstream comparison.
- `CASE` appears both as a column (adding a bucket dimension inside `SELECT`, then `GROUP BY` the alias/expression) and as a filter (`WHERE`), and they serve different purposes. Doing both forces you to feel the difference.
- The snapshot also has non-delinquent statuses. Decide where `Activo` accounts sit — usually their own "current" band or bucket — and make the status handling part of the CASE, not a separate `WHERE`. Watch out for the cure flag semantics if present.

**Verification strategy:**
- Every account in the snapshot appears in exactly one bucket: your per-bucket account counts must partition the total (no overlap, no leakage).
- Sum of arrears across buckets = arrears for the whole latest snapshot's Mora set (when restricted to them).

**Traps & worth knowing:**
- Two rows at the exact boundary can be double counted if two `WHEN` conditions both match — ordering and AND conditions matter.
- `NULL` and oddball DPD values: an explicit tall `ELSE` bucket ("other") is honest analysis, not a cheat.

---

## Task 3 — Date math

**Thinking path:**
- `date_trunc('week', date)` collapses to the ISO week's start (Monday). Doing this in `GROUP BY` is the "same bin" trick for weeks. ISO matters: weeks start on Monday, year-boundary weeks don't belong to the year you expect.
- Denominator choice: avg connected per *agent-day*. "Agent-day" should mean days an agent actually logged time (`fact_agent_time_log`), not calendar weekdays. If you use calendar days you're mixing "potential" with "actual"; justify the choice in words.
- Skipped-day detection: count distinct interaction dates per week, compare to the expected number of interaction-enabled weekdays in that ISO week (Monday–Friday). This portfolio has no weekend interactions by design — so a weekend-looking gap is expected and **not** a skipped day; a *weekday* hole is the event worth flagging.

**Verification strategy:**
- The expected-weekday count should vary only at month/year boundaries — if you see variance mid-run, your "expected" logic is wrong.
- Pick one week you flagged and spot-check the raw dates by hand.

**Traps & worth knowing:**
- Naive `GROUP BY date` gives raw days; aggregation order matters. Truncate first, aggregate second.
- `date_trunc` on a date column returns a timestamp; cast/comparison types must line up (`date_trunc('week', d)::date`).
- Boundary bug: a Friday in February and a Monday in March land in the "same week number" but different months — join with quarter/year in mind.

---

## Task 4 — CTEs and keeping the no-match rows

**Thinking path:**
- Stage the problem: (a) severe accounts = from the *latest* `fact_eom_snapshot` where DPD is high; (b) last interaction per account; (c) combine.
- Stage (b) "latest row per account" — the classic is `ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY interaction_date DESC)` then filter the rank-=1 layer. Whether you put that in a CTE or use a lateral approach, the *intent* is "the most recent row for each account".
- Combine with the join that *preserves the left side* — that's the `LEFT JOIN`. Every severe account shows even with NULL on the interaction columns. Explain what NULL means there (no interaction recorded — itself a signal!).
- Tiebreaker on identical dates: an outcome value or interaction time ordering keeps it deterministic; for a "last date" report it often doesn't change the story, but the *decision you state* matters.

**Verification strategy:**
- Severe accounts with NULL last-interaction should all be accounts that verifiably have no interaction rows at all — cross-check with an anti-join (`NOT EXISTS`).
- The row count of the final result must equal the count of severe accounts (the LEFT side is authoritative).

**Traps & worth knowing:**
- `LEFT JOIN` *hides* rows when the left table isn't distinct by key — if your left side suddenly has duplicates (from an earlier stage), the join will *inflate*, not drop. Distinct-on-left before joining.
- A subquery in `SELECT` re-executes per row and can't share a filter — CTEs make the pipeline readable and once-computed.
- The "most recent" selection without a row number can grab *all* of an account's rows if you forget to restrict — always ask "does this layer output one row per account?"

---

## Task 5 — Window functions

**Thinking path:**
- Two steps that are easy to conflate: (1) plain `GROUP BY` month, team → a *reduced* result set; (2) a window function **over** that aggregation for the peer rows. You can even do both in one query: `GROUP BY` the month/team, then `LAG(...) OVER (PARTITION BY team ORDER BY month)` computed on the aggregate — a window over grouped output.
- `LAG(m, 1)` = the previous month in the partition's ordering. First row of each team has no previous → NULL. Decide the presentation (show NULL, or a "start of series" note) — it's a deliberate choice, not an accident.
- Reuse the same partition for a running total — but notice the frame: with `ORDER BY` present, the default frame grows from the partition start to the current row. That's exactly what a running total needs — until you change the frame accidentally.
- Why `LAG` beats self-join: months with zero interactions exist *in the calendar but not in the aggregated output*; a naive self-join on month−1 would simply **lose** those rows or pair them with nothing. A window partition over the aggregated rows sees only existing rows and marks "no previous" as NULL without dropping the row.

**Verification strategy:**
- Recompute one team's running total by hand for 3 months. If yours differs, it's a frame problem.
- The first row per team shows the "no previous" marker — that's evidence the window ordering worked.

**Traps & worth knowing:**
- Window functions can't go in `WHERE` or `GROUP BY` — you'll get an error; the fix is wrapping in a CTE/subquery. That pattern (wrap + filter on the window output) shows up constantly.
- `ORDER BY` direction inside the window controls *which* neighbor `LAG` returns; flip it and "previous" becomes "next".
- Default frames are subtle across versions — when the running total doesn't look cumulative, spell out `ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW`.

---

### Finish

Compare your queries to the reasoning here. Where you diverged, write one line on *what* and *why* — that line is your progress. If every task's shape matches, medium is done.

**Move up when:** you can explain out loud the `LAG` vs self-join difference and when to pick each.