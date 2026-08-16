# Python — Basic — Tasks

```
learning/
├── _reference/            ← READ FIRST (datasets.md, kpi_glossary.md, data_dictionary.md)
├── sql/  notebooks/  excel/  powerbi/  git-cli/
├── python/
│   ├── README.md
│   └── basic/             ← YOU ARE HERE
│       ├── tasks.md       ← current file
│       ├── results.md     ← guidance, peek AFTER attempting
│       └── work/          ← your .py scripts live here
└── README.md
```

**Up from SQL basic:** you can filter, group, and compute a rate in SQL. Now do the same in pandas — and learn the field's #1 trick: **the raw CSVs arrive one folder per month, and the first thing you do is put the year back together.**

**Setup:** conda env `mis-collections` (see `python/README.md`). Create `work/attempt_*.py` per task. Read from `data_sources/raw/` — never write there.

**Discipline:** attempt → commit → then read `results.md`. Where a task mirrors a SQL-basic task, **compare your Python answer to your SQL answer** — they must agree.

---

## Task 1 — Meet the raw files

The supervisor: *"We keep data one month per folder. Before analyzing, show me you actually know what's inside."*

**What you'll practice:** the *orientation move* — load, peek, shape, dtypes, and the honesty of `info()` on a wide fact table.

Steps:
1. Pick one shared dimension (e.g. `Dim_Accounts.csv`) and one month folder's fact (e.g. `january_2025/Fact_Interactions.csv`).
2. Load both with pandas. For each: print shape, column names, dtypes, first rows, and a numerical summary.
3. Look at the fact's *sparseness*: which columns are mostly missing/zero? Which are dense? Write one sentence on what that suggests about the data-generation designers' intent.
4. Sanity: does the fact's row count match what `_reference/datasets.md` implies per month? (Record the count; don't just nod at it.)

**Guiding questions:**
- Which dtypes did pandas guess, and which are *lying* (e.g. an ID column read as integer when it's really a code, a date read as object)?
- Why are the dims in `shared/` while the facts are per-month? What does that tell you about how the generator writes disk?

**Deliverable:** `work/attempt_1.py` — script printing all of the above, plus your one-sentence per-file note as a comment.

---

## Task 2 — Recombine the year (the ETL's job, your hands)

The supervisor: *"Our ETL loads all 12 months into Postgres. Reproduce that: one DataFrame of the whole year of interactions."*

**What you'll practice:** the loop-over-files concat — the single most repeated gesture in file-based data work — and total-row verification against the known year total.

Steps:
1. List all 12 month folders, read their `Fact_Interactions.csv` into a growing list of DataFrames, then `pd.concat` once.
2. Verify: your combined shape must equal the year total in `_reference/datasets.md` (§3 row estimate, or the DB smoke-test count from §5). They must match — this is the *reassembly correctness check*.
3. Add a `month` column (derive from folder name or dates — decide which is less error-prone).
4. Write the combined frame to `work/` as CSV or parquet for reuse in later tasks. Note the dtype of the new month column.

**Guiding questions:**
- Concat with `ignore_index=True` or not — what breaks between the two? How does the index behave when you concatenate twice?
- If month folders later arrive out of order (e.g. `march` then `january`), does your script survive? What assumption should your loop not make?

**Deliverable:** `work/attempt_2.py` — the reassembly + a printed verification line + the saved `work/all_interactions.parquet`.

---

## Task 3 — The SQL-basic question, in pandas

The supervisor: *"January interactions, per team, sorted by count. You did this in SQL — do it here. They should agree."*

**What you'll practice:** translate `WHERE → GROUP BY → ORDER BY` into pandas — filtering, groupby-aggregate, sort — and the cross-track consistency check with your own SQL output.

Steps:
1. Reuse your Task 2 table (or `Dim_Employees` merge if team is not on the fact — check the dictionary for where `team_name` lives).
2. Filter to January. Group by team; count interactions. Sort descending by count.
3. Run the same query in your SQL client; print **both** results side by side and confirm agreement.
4. Add the per-day count for one team and compare its *shape* (weekends visible?) with what you found in SQL basic Task 2.

**Guiding questions:**
- `value_counts` vs `groupby(...).size()` vs `groupby(...).count()` — when does each differ?
- If team lives on the employee dimension, `merge` brings it in — but double-check you didn't *multiply* rows (the pandas merge blowup is the SQL join blowup's twin).

**Deliverable:** `work/attempt_3.py` — January-per-team table + a printed agreement check against your saved SQL result.

---

## Task 4 — RPC% in pandas: ratio of sums, not mean of flags

The supervisor: *"RPC% by channel for January. Use the same definition you proved in SQL."*

**What you'll practice:** the #1 pandas mistake — computing a rate as `groupby.mean()` of a boolean flag instead of **sum over sum** — and the discipline of reusing the SQL-proven definition.

Steps:
1. Compute RPC% by channel: numerator `sum(rpc_flag)`, denominator `sum(calls_connected)`; ratio per group. (Don't skip to `mean()` — try both and *diff them*.)
2. State, in a comment, the denominator convention you're committing to (from `_reference/kpi_glossary.md`), exactly as you did in SQL.
3. Compare your channel numbers to your SQL basic Task 3 output — same table, same order.
4. Handle the "almost no connected calls" channels explicitly: keep the group, but mark it as unreliable rather than silently excluding (see glossary's FICO/SMS note).

**Guiding questions:**
- Why does `groupby.mean()` on a 0/1 flag *always* lean wrong for rates — restate the weighted-average-of-sums argument from SQL basic.
- Integer division: in pure Python `1/2 == 0.5`, but what happens if both columns are integers and you do `numerator / denominator` in pandas 3 / NumPy 2? When do you need `.astype(float)`?

**Deliverable:** `work/attempt_4.py` — channel × RPC% table + a `mean()`-vs-`sum()` diff + agreement check with your SQL result.

---

### Finish

Attempt all four, then read `basic/results.md`. Note in each file how your pandas answer compared to your SQL answer — that cross-track note is your progress proof.

**Move up when:** you can reassemble the year and answer a groupby-rate question without opening your SQL notes.