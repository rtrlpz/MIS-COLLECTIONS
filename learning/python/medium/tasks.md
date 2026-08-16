# Python — Medium — Tasks

```
learning/
├── _reference/            ← READ FIRST (datasets.md, kpi_glossary.md, data_dictionary.md)
├── sql/  notebooks/  excel/  powerbi/  git-cli/
├── python/
│   ├── README.md
│   └── medium/            ← YOU ARE HERE
│       ├── tasks.md       ← current file
│       ├── results.md     ← guidance, peek AFTER attempting
│       └── work/          ← your .py scripts live here
└── README.md
```

**Up from python basic:** you can orient, reassemble the year, filter/group, and computing a ratio-of-sums rate. Medium is where pandas stops being "SQL with different brackets" and becomes its own tool: merges, datetimes, bucketing, group-transforms, and pivots.

**Setup:** conda env `mis-collections`. Create `work/attempt_*.py`. Read from `data_sources/raw/` and any `work/` tables you saved in basic.

**Discipline:** attempt → commit → cross-check vs SQL where indicated → then read `results.md`.

---

## Task 1 — Merges: the pandas join

The supervisor: *"I want January interactions with product type and region attached — same question as SQL medium Task 1. Reuse your assembled table."*

**What you'll practice:** `pd.merge` semantics — `how=`, `on=`, and the join-blowup in pandas clothing.

Steps:
1. Merge your interactions table with the account dimension (for product) and figure out where region actually lives (client? employee? — same map you drew in SQL).
2. Use explicit `how=` on every merge and write a comment stating what each `how` means for *this* question (left vs inner).
3. After each merge, assert your row count didn't change (or understand exactly why it did).
4. Build the product × region grid for January, same as SQL medium Task 1, and compare to your SQL output.

**Guiding questions:**
- What's the difference between `merge` on columns (`on=`) and aligning on the *index*? Which is safer here and why?
- When one side has duplicates on the join key, pandas *emits* those repeats — how would you detect fan-out programmatically (`.shape` diff, `value_counts` on key)?

**Deliverable:** `work/attempt_1.py` — merged table + grid + row-count assertion + SQL comparison note.

---

## Task 2 — DateTime & resample: the weekly pulse

The supervisor: *"Weekly interaction volume with a running total per team — and on the weeks where a Monday or Friday vanished, flag it."*

**What you'll practice:** real datetime handling — `pd.to_datetime`, `.dt.`, `resample`, and comparing against expected weekdays (the pandas twin of SQL medium Task 3).

Steps:
1. Parse `interaction_date` (+`interaction_time` if you want timestamps). Confirm the parsed dtype with a test on a known weekday.
2. Resample by week (which anchor, Monday or Sunday?) and aggregate counts per team. Compare the approach vs `groupby(pd.Grouper(freq='W'...))`.
3. Expected-weekday count per ISO week: this portfolio has *no* weekend interactions (glossary §6), so the expected count is Monday–Friday weekdays, and a missing *weekday* is the flag.
4. Add the running total per team with `.cumsum()` inside a `groupby`.

**Guiding questions:**
- `resample` works on a *DatetimeIndex*; `groupby(pd.Grouper(...))` works on a column. What breaks on the rule "resample needs the index"?
- Weekend-only weeks: with zero weekend data, a `freq='W'` bucket that lands on Sunday may appear empty or shift — how do you make the week boundaries match ISO (Mon start) instead?

**Deliverable:** `work/attempt_2.py` — weekly table with counts, cumsum, expected-vs-observed weekdays, flag column + a comment on the ISO anchor.

---

## Task 3 — Bucketing the portfolio (cut & case)

The supervisor: *"Current-address the delinquency profile: bucket DPD like we do in SQL, one row per bucket, accounts and arrears. Same bands as the house standard."*

**What you'll practice:** turning continuous DPD into the project's bucket ladder — `pd.cut` (with explicit bins *and labels*) vs `np.select` for hand-rolled conditions (the pandas twins of SQL `CASE`).

Steps:
1. From the latest EOM snapshot, take `dpd` and map to the project's bucket labels (read `_reference/data_dictionary.md` for the canonical labels — reuse them).
2. Use `pd.cut` with explicit bin edges and *explicit labels*; then write the same using `np.select` with conditions. Run both; diff the two bucket columns — they must produce identical buckets (that diff **is** the test).
3. Aggregate accounts and arrears per bucket, and per product × bucket.
4. Decide where the non-Mora/Activo population sits: does it fall into a "current" band, or is it a separate status dimension you must keep apart (not squish into the DPD ladder)?

**Guiding questions:**
- `pd.cut`'s boundary semantics: `right=True` by default — is your band "DPD <= X" or "DPD < X"? The house standard has an answer.
- What does `NaN` in a `cut` result mean — and what does an explicit `IntervalIndex` vs labels change?

**Deliverable:** `work/attempt_3.py` — profile table + product cross-tab + the cut/select equality diff.

---

## Task 4 — "Latest row per account" in pandas

The supervisor: *"For every severely delinquent account, give me its most recent interaction date and outcome — NULL if there are none."*

**What you'll practice:** the pandas way to "row 1 per group" — `sort_values` by date then `groupby().first()`/`nth(0)` (the twin of SQL `ROW_NUMBER … = 1`), plus keeping the no-match accounts alive.

Steps:
1. Determine the severe-account population (same latest-snapshot logic as SQL medium Task 4).
2. For interactions: sort by `interaction_date` (with a tiebreaker) and take the first row per account via `groupby(f'{group}, as_index=False').first()` or `drop_duplicates(subset, keep='first')`.
3. Merge back **from** accounts (the LEFT side) `how='left'` so accounts with zero interactions stay with `NaN`.
4. State in a comment: what does a `NaN` interaction mean here — and would an `INNER` merge silently kill those accounts?

**Guiding questions:**
- `sort_values(...).groupby().first()` vs `drop_duplicates(subset=..., keep='first')`: same result for "most recent per account", different costs/edge-behaviors. Which one do you trust when dates tie on both?
- Why is it *safer* to merge "accounts LEFT JOIN interactions" than "interactions" then filter?

**Deliverable:** `work/attempt_4.py` — severe accounts + last interaction (with NULLs present) + a comment on left-join-safety.

---

## Task 5 — Pivot/crosstab: from long to wide

The supervisor: *"A product × region grid was nice. Now make me the version the director likes: accounts counted in a matrix, cures and arrears as separate panes — long to wide, and back."*

**What you'll practice:** `pivot_table` (with multiple aggfuncs/values), `crosstab`, and the discipline of **round-tripping** (unpivot back = `melt`) to prove you lost nothing.

Steps:
1. On the latest snapshot, build a `pivot_table` of accounts by product (rows) × region (columns), with `aggfunc='count'`.
2. Add a second pane: arrears sum in the same pivot (multiple `values`).
3. Verify the wide table: the *marginals* (row/column totals) must equal the long-form grouped counts.
4. Round-trip: `melt` the wide table back to long and compare with your original grouped frame — identical = you exercised a real analytical round trip.

**Guiding questions:**
- `pivot_table` vs `pivot` vs `crosstab`: which handles duplicate index/column combinations, and what happens if yours has them?
- Marginals: `pivot_table(... margins=True)` adds totals — why are those the natural verification anchor for the whole task?

**Deliverable:** `work/attempt_5.py` — the two panes + margin check + a successful melt round-trip printout.

---

### Finish

Attempt all five, then read `medium/results.md`. Add a one-line diff note per task (what you expected vs what the guidance emphasizes).

**Move up when:** you can decide *without looking up* whether a given shape change is a `merge`, `groupby`, `pivot`, or `melt` — with a clear "why".