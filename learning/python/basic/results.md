# Python — Basic — Results (Guidance)

```
learning/
├── _reference/            ← datasets.md, kpi_glossary.md, data_dictionary.md
├── sql/  notebooks/  excel/  powerbi/  git-cli/
├── python/
│   ├── README.md
│   └── basic/             ← YOU ARE HERE
│       ├── tasks.md
│       ├── results.md     ← current file
│       └── work/
└── README.md
```

**How to use this file:** attempt → commit → read one section. Guidance only — reasoning paths, steps-with-why, verification strategy, traps. No full scripts, no computed values.

---

## Task 1 — Meet the raw files

**Thinking path:**
- `pd.read_csv` the dim and the fact. `df.shape` / `df.columns` / `df.dtypes` / `df.head()` / `df.describe()` are the orientation toolkit. The *why* of each: shape = inhabitants, dtypes = habitat, describe = temperament.
- Look for dtype lies. A date column read as `object` is a lie waiting to bite; an `account_id` read as `int64` is convenient but semantically a *code*, not a number to add. The lesson is to *notice* the dtype, not necessarily to fix it now — Task 2/medium will punish you where it matters.
- Sparseness: columns that are mostly zero/NaN on a fact table tell you the generator was told to leave fields empty for some call channels — that's a *design signal*, e.g. `aht_seconds` absent for non-RPC rows. Noting it now will explain weird aggregation in later tasks.
- Row-count sanity vs `_reference/datasets.md`: the doc gives year totals; that's for Task 2's exact check, but grabbing the *per-month* fact count here and roughly dividing is a good "does this smell right" moment.

**Verification strategy:**
- `df.info()` gives missing + dtype in one place — read it before and after you "fix" dtypes.
- `describe()` skips object columns by default; run `describe(include='object')` too.

**Traps & worth knowing:**
- pandas infers `int64` for ID columns — `account_id` 01548 becomes the integer 1548; if any later merge key depends on leading zeros, you've lost information. (Check whether this dataset's IDs carry zeros that matter.)
- A blank in a numeric column → `NaN`; pandas silently makes the whole column `float64`. Sums still "work" — and that's exactly how rates sneak off.

---

## Task 2 — Recombine the year

**Thinking path:**
- The pattern: `frames = [pd.read_csv(path) for path in sorted_paths]; df = pd.concat(frames)`. Sorting the paths is the hidden requirement — "folders may arrive in any order" is a real-world promise that breaks `concat` order-insensitive downstream groups only if you rely on it.
- Reassembly check: your total rows must equal the reference year total (datasets.md §3). A mismatch = a folder double-read, a skipped folder, or a filtered read. Fix the *loop*, never the number.
- Add month: deriving from the *path or folder* name is explicit and immune to date-parse quirks; deriving from `interaction_date` is content-driven and survives renames. Note which you chose and why.
- Save assembled data under `work/` (parquet keeps dtypes; CSV is human-eyeable). `work/` is git-ignored — perfect for derived artifacts.

**Verification strategy:**
- Count unique months in your assembled table == 12.
- `df.groupby(month).size()` sums to the exact reassembled total — the partition identity.

**Traps & worth knowing:**
- `concat` without `ignore_index=True` keeps each file's own index → duplicate indices across months. Subsequent `reset_index` or indexing gets confusing. Decide one convention and re-use it.
- Reading a folder that turns out to be `anomaly_report.csv`-style junk (see §2 of datasets.md) into your concat would poison the totals — filter to `Fact_*.csv` by name.

---

## Task 3 — The SQL-basic question, in pandas

**Thinking path:**
- The translation table is the point: SQL `WHERE month` → pandas boolean mask; `GROUP BY team` → `groupby('team')`; `COUNT` of rows → `.size()` (returns per-group row count) vs `.count()` (returns non-null of one column — a different animal); `ORDER BY` → `.sort_values(ascending=False)`.
- Team location: if `fact_interactions` carries `agent_id` but not team, the merge via `dim_employees` is the *same* join you proved in SQL. After `merge`, re-run `.shape` and compare to the pre-merge row count — a jump = join blowup, this time in pandas.
- The cross-track check is the whole point: two tools + same data = same answer. Print both, eyeball, and match. If they disagree, the culprit is usually filter text (channel, status) or a silent row loss on merge (`how='left'` vs `'inner'`).

**Verification strategy:**
- The per-team counts should sum to your January total (partition identity again).
- Filtering January: `df['interaction_date'].dt.month == 1` needs the date parsed first; comparing against a *string* column only "works" if the file format cooperates — parse dates, it's safer.

**Traps & worth knowing:**
- `.size()` returns a Series named 0; rename it. `.value_counts()` on a column sorts descending by default and counts the grouping column — convenient, but it's `groupby().size()`, not a general aggregate.
- After filtering an index-altered frame, `sort_values` by the count column; don't accidentally sort by the index label.

---

## Task 4 — RPC%: ratio of sums

**Thinking path:**
- Correct: `groupby('channel').agg(num=('rpc_flag','sum'), den=('calls_connected','sum'))` then `num/den`. This weights by effort — a channel with big connected volumes drives the rate proportionally. This is the exact ratio-of-sums argument from SQL basic.
- Wrong-but-tempting: `groupby('channel')['rpc_flag'].mean()` — averages the flags per *row*, so a channel with 2 calls and 1 RPC scores the same as another with 2000 calls, 1000 RPCs. Same data, two credible-looking numbers — the diff print is your teaching moment.
- Channel policy: FICO/SMS (or whichever the glossary marks non-dialing) shouldn't sit in a *contact* rate. Keep the row visible but flag it rather than silently dropping — that's the field-honest version of the SQL `WHERE channel IN (...)` decision.

**Verification strategy:**
- Sum numerator over all channels == your SQL numerator in the same window (the invariant).
- Your pandas table vs your SQL basic Task 3: same channel order, same ratios. Any mismatch is a definitional statement you get to *find*.
- Division by an all-zero denominator: pandas gives `NaN` + a warning; that `NaN` IS the honest answer for "no connected calls", not an error to chase.

**Traps & worth knowing:**
- In pandas/NumPy, int/int division returns a float in NumPy ≥2, but policy differs by version and dtype — verify rather than assume; `df['num'] / df['den']` on int columns may produce int truncation under some paths, so `.astype(float)` is the explicit, version-proof move.
- A boolean column summed with `sum()` == count of Trues; `mean()` of the same column == % true — they're *different metrics*, keep the labels clear.