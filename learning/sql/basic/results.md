# SQL — Basic — Results (Guidance)

```
learning/
├── _reference/            ← READ FIRST (datasets.md, kpi_glossary.md, data_dictionary.md)
├── sql/
│   ├── README.md
│   └── basic/             ← YOU ARE HERE
│       ├── tasks.md
│       ├── results.md     ← current file
│       └── work/          ← your .sql files live here
├── python/  notebooks/  excel/  powerbi/  git-cli/
└── README.md              ← master guide
```

**How to use this file:** read a task → attempt it in `work/` → commit to your answer → *then* read only that task's section here. This file teaches the **reasoning path**, not a ready-made answer. It deliberately shows no full query and no computed values.

---

## Task 1 — Say hello to the star schema

**Goal of the task:** build a mental map of the database. Queries are just tools; the map is what makes you fast.

**Thinking path:**
- Start from the big list of tables. Group them by their *role*: which ones describe things (dimensions) and which ones record events/state (facts)? The naming convention `dim_` / `fact_` exists precisely so you can do this grouping at a glance.
- Facts are big. Dimensions are small. Try to explain *why* — it's the difference between "one row per thing" and "one row per event". This is the single most important structural insight in any data warehouse.
- For "how do two tables connect", look for shared key columns. A fact almost always carries the same key back to a dimension (look at the fact table's columns that end in `_id` or `_key`).
- When comparing to `_reference/data_dictionary.md`, don't grade yourself on getting every column right. Grade yourself on whether the *story* you told matches: 5 dims, 6 facts, at least 3 (or more) join paths, and a calendar that exists as its own dimension.

**Verification strategy:**
- Roll your table list up into "here are the 6 facts and what grain each row is" — if a fact has foreign keys to several dims, name them.
- Check whether your one-liner-per-table would let someone else join two tables without asking you.

**Common traps & worth knowing:**
- `schema` filtering: use `information_schema.tables` or `\dt` (psql) — not your memory.
- A "snapshot" fact (like `fact_eom_snapshot`) doesn't grow like event facts; one row per *account per month-end*. If you see 6 facts and think "why isn't the snapshot huge too?" you've found the mental model, not a bug.

---

## Task 2 — Count, filter, sort: the classic MIS question

**Goal of the task:** the `SELECT … WHERE … GROUP BY … ORDER BY` template — and what each clause is *for*.

**Thinking path:**
- Step 1 (total for the month): this is a filtered `COUNT(*)`. The filter is on the interaction date. The month is a range of dates, so your `WHERE` should express a *range*, not one day.
- Step 2 (per team): the team name lives in the employee dimension, not in the fact table (facts carry keys, not labels). That's the clue that a join is needed — and WHY: never trust a label to be denormalized into a fact unless the data dictionary says so. In this project, check `_reference/datasets.md`/`data_dictionary.md` for whether the interaction table carries `team_name` directly or only `agent_id`.
- Step 3 (per day): a daily count is a *finer grain* of the same aggregation. The insight in the glossary hint is about days where no calls happen (weekends) or where behavior spikes — a monthly total would hide that shape entirely. The lesson is *granularity choice*, not the specific spike.
- Step 4 (sort): sorting is presentation. The correct sort is the one that makes the *question* readable — if the question is "which team has the most", sort descending by the count. If it's "first day to last day", sort by date. Justify in words, don't guess.

**Verification strategy:**
- Cross-check: sum your per-team counts and compare to your total. They must agree — if not, you leaked rows through a join (a team with no employees, or an employee with no team). This is the classic join-blowup check.
- Try the same count with and without a `DISTINCT` and explain in words when the two would differ here.

**Common traps & worth knowing:**
- Filtering an aggregate in `WHERE` (`WHERE COUNT(*) > 5`) errors — that's what `HAVING` is for. The teaching moment: `WHERE` runs *before* grouping, `HAVING` *after*.
- Filtering with `BETWEEN` on a date is fine, but `>=` / `<` on the next-lower-granularity boundary is a habit worth building (you'll thank yourself with timestamps later).
- Aliases: if you order by an alias, Postgres lets you; but *never* filter on an alias in `WHERE` — it doesn't exist yet.

---

## Task 3 — Rate columns: what does RPC% really mean?

**Goal of the task:** compute a rate from two numerators *correctly*. This is the analysis move that separates "runs queries" from "answers questions".

**Thinking path:**
- A rate = a part over a whole. The whole (denominator) is the thing you *had a chance to do the thing on*. The part (numerator) is the subset that actually did it. Define both in words BEFORE writing SQL.
- In this project the glossary's goal is explicit about the denominator for RPC% — confirm it, don't assume. There is a correct, documented answer.
- Ratio-of-sums vs average-of-flags: if you average a per-row flag (`1`/`0`), every row weighs equally regardless of `calls_connected`. A channel with mostly tiny calls would skew the average. The ratio `SUM(rpc) / SUM(connected)` is a proper rate because it's weighted by effort. If a channel has almost no connected calls, its rate is near-data-scarce — decide whether it's even meaningful.
- Integer division: tables store counts as integers. `rpc / connected` in Postgres is integer division → truncates. Casting to `numeric` first gets fractions — hence the `::numeric` habit.

**Verification strategy:**
- Sanity: what's the biggest a rate can be? If your math returns numbers >1, numerator/denominator are misaligned (different filters, or a join inflating the numerator).
- Cross-check with the project's own KPI views: `v_contact_metrics` has **no channel grain** (agent/team/monthly only), so there is no per-channel view to match. Instead, compare your *overall* January RPC% (summed across channels) to the view's agent/monthly number. If you excluded FICO/SMS per the dialect while the view does not filter channels, the two differ **for a documented reason** — state that reason, don't force a match.
- Check FICO/SMS handling matches the documented convention — the glossary flags those channels as non-dialing, so they typically don't belong in a "contact rate" denominator at all.

**Common traps & worth knowing:**
- Averaging a column of already-computed rates (e.g., averaging daily RPC%s) introduces the same bias as averaging flags — the glossary's "averaging daily rates" trap. Sums first, divide last.
- `COUNT(*)` vs `COUNT(col)`: `COUNT(*)` counts rows; `COUNT(col)` counts non-null values of `col`. For flags the distinction usually doesn't matter, but it matters the day a flag is `NULL`.

---

## Task 4 — The unpaid question: who owes and how much?

**Goal of the task:** read **state** from a snapshot table, and understand a top-N list vs an aggregate-with-group — two different lenses on the same data.

**Thinking path:**
- "Who owes how much *at month end*" is a *snapshot* question (a point-in-time view), not a *transaction* question (what happened). That's the key table choice: `fact_eom_snapshot`, not an event/interactions table. Justify this in words: you want the state *at* a moment, not the history *around* it.
- For "latest snapshot", what's the largest snapshot date? Or equivalently, order by snapshot date descending and look at the top. Other snapshots exist (Jan–Dec), so `MAX(snapshot_date)` is the robust way to say "the latest one in the data".
- The `product_type` is denormalized onto the account dimension — so no snowflake hop to the product table is needed; you can go straight from account to label.
- The top-20 vs the product-type total are *different questions*. Top-20 answers "which individual accounts are the biggest problems" (risk at the account level). The product-type aggregate answers "which bucket has the most total exposure" (risk at the portfolio level). A few giant mortgages can dominate one lens while many small cards dominate the other — and that contrast is the actual lesson, not the specific winner.

**Verification strategy:**
- Confirm your filter set is exactly the Mora accounts at the *latest* snapshot — no double-counting a card across months (that would be mixing state across time).
- For the top-20, check your rows are distinct accounts. If the same account repeats, you've joined something that multiplied rows.
- For the aggregate, sum of your per-product totals must equal the total over ALL Mora accounts — same check as Task 2.

**Common traps & worth knowing:**
- `LIMIT` after `ORDER BY` cuts off ties silently. PostgreSQL doesn't guarantee *which* of two tied rows survives — that's usually fine for a "top 20" eyeball list but dangerous for anything official. A ties-safe alternative is ranking with a window function — filed under "advanced", but know it exists.
- Snapshot tables reward you for spelling out the "as-of" date explicitly. Every future report that uses this table will need the same discipline — get used to `status` + snapshot-date pairing now.
- Counting "Mora accounts" vs "accounts *with any* Mora row in history" is a different question again. Here you want the *current-state* one.

---

### Finish

Compare your files with this guidance:
- If your query shape matches the path above (right table, right filters, ratio-of-sums, right lens) but your *results* differ from what you expected — that's normal. The mock data is evidence, not a grading sheet. Document what you expected and why the data disagrees.
- If your query shape differs — find *where* in the reasoning path you diverged, and note it in your file as your progress log.

**Move up when:** you can write Task 2's query from memory. (Same rule that's in `tasks.md`.)