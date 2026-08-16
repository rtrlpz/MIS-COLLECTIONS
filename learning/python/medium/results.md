# Python — Medium — Results (Guidance)

```
learning/
├── _reference/            ← datasets.md, kpi_glossary.md, data_dictionary.md
├── sql/  notebooks/  excel/  powerbi/  git-cli/
├── python/
│   ├── README.md
│   └── medium/            ← YOU ARE HERE
│       ├── tasks.md
│       ├── results.md     ← current file
│       └── work/
└── README.md
```

**How to use this file:** attempt → commit → read one section. Guidance only: reasoning path, steps-with-why, verification strategy, traps. No full scripts, no computed values.

---

## Task 1 — Merges

**Thinking path:**
- Trace the key map first (product from `dim_accounts`; region — decide client-side vs employee-side). Then write the merges in the *same order* you laid out the map.
- On every `merge`, state the `how=` out loud. `how='left'` keeps all left-side rows (dims on the left = labels attach; fact on the left = facts preserved). `how='inner'` drops either side's orphans. The *why* of the choice is the deliverable, not the parameter.
- Row-count assertion: `assert len(merged) == len(fact)` after attaching *dimensions* — true only if the dim has one row per key. If the dim has duplicates on the key, pandas emits repeats → fan-out. Detect with `dim[key].value_counts().max() > 1` BEFORE merging.

**Verification strategy:**
- Product × region grid row total == January total (partition identity).
- Compare against SQL medium Task 1 *cells* — identical order/values = the ETL transition is proven.

**Traps & worth knowing:**
- Merge aligns on *columns* by default; index-alignment is a different animal and can't be assumed cross-frame.
- pandas 3 has a copy-on-write default — in-place edits on merged frames may warn; assign back explicitly (`df = df.assign(...)`).
- A column you "filtered" pre-merge can silently change what merges — e.g. dropping NULL `agent_id` rows before merging the team dim changes the population. Know which merge is the *population-defining* one.

---

## Task 2 — DateTime & resample

**Thinking path:**
- Parse dates with `pd.to_datetime` and confirm the dtype. Timestamps change `freq` behavior — `resample` needs a `DatetimeIndex`.
- Weekly bucketing: `resample('W-MON')` for ISO (Monday) start. `groupby(pd.Grouper(key=..., freq='W-MON'))` works on a column without moving the index. Knowing both is leveling-up; knowing when each applies is the mastery.
- Expected weekdays: this portfolio has no weekend interactions by design (glossary §6). Expected = Monday–Friday *for that ISO week* — count via `date_range(week_start, week_start + 6)` directly, or a weekday-count formula, and drop weekends. A missing *weekday* = flag.
- Running total: `groupby('team')['count'].cumsum()` — cumsum is group-aware after groupby.

**Verification strategy:**
- A week's distinct observed days ≤ 5 always (no weekends). Flag weeks where observed < expected #weekdays.
- The cumulative total's last value per team must equal that team's total count (cumsum sanity).

**Traps & worth knowing:**
- `resample` buckets anchor at the *end* of periods (`W-SUN`) by default — you want `W-MON` for ISO week names that match your SQL.
- Empty weeks at calendar edges: a `W-MON` bucket crossing a month break changes labels — include/exclude deliberately.
- Naive `.mean()` on an empty datetime group returns `NaT`, not an error — know what "empty" means for each metric.

---

## Task 3 — Bucketing

**Thinking path:**
- Read the canonical bucket labels from the dictionary (not your invention) so the house standard is reused — leadership reads case-normalized labels.
- `pd.cut(dpd, bins=edges, labels=names)` with explicit integer edges and *explicit* labels; boundary semantics: default `right=True` means bins are (left, right] — your buckets must state whether an exact boundary lands left or right. Cross-check against how the SQL views bucket.
- Write the equivalent with `np.select(conditions, choices)` — the pandas translation of `CASE WHEN …` — and *diff the two bucket columns*. Zero diff = you understand both tools well enough to trust them interchangeably.
- Status vs DPD: `Activo` accounts are a *status*, not a DPD value. Don't force them into the DPD ladder (a current-but-activo account has low DPD; squishing it as "current" conflates status with bucket). Keep a status flag separate; the house views treat them separately.

**Verification strategy:**
- Sum of buckets' account counts == snapshot total for the chosen population (with the status partition explained).
- The cut/select diff table: any mismatch is a boundary-semantics bug — resolve it, don't ignore it.

**Traps & worth knowing:**
- `pd.cut` with an edge outside the data range produces `NaN` for out-of-range values — that NaN is "other", and an honest dashboard keeps an "other" bin.
- `include_lowest=True` copies the left-most edge from `right=True` semantics; get this wrong and the lowest bucket loses its boundary account.

---

## Task 4 — Latest row per account

**Thinking path:**
- Severe population from the latest snapshot (reuse SQL medium Task 4's lens).
- Two idioms that look identical: `sort_values('interaction_date').groupby('account_id').first()` and `drop_duplicates(subset='account_id', keep='first')`. Both give "first row per account" — `drop_duplicates` is leaner when you only need the dedup; `groupby().first()` scales when you later need per-group aggregations too. Date ties: sort by a secondary key (`interaction_time` or outcome) to make the "latest" deterministic.
- The left side is *accounts*: merge `accounts` with the deduped interactions `how='left'`. NULL last-interaction == "no interaction recorded" and that is a *finding* (an account never contacted this quarter), not an error.
- Which join would *hide* those accounts? An `INNER` — that's the danger case: the filter "severe AND contacted" silently narrows your population.

**Verification strategy:**
- RESULTS: severe count == severe∩contacted + severe∩uncontacted. `len(result) == len(severe)` (the left side is authoritative).
- Spot-check one severest account's last interaction date against the raw table.

**Traps & worth knowing:**
- If interactions has an account with duplicate `interaction_date` (same-day multi-calls), naive sort+first returns *one arbitrary row*; the tiebreaker makes it reviewer-defensible.
- `groupby().first()` on a non-sorted frame returns the first *encountered*, which for unsorted input is random-ish — always sort first.
- Merging the *deduped* (1-row-per-account) interactions back avoids re-inflating; merging the full interactions table back would fan-out again.

---

## Task 5 — Pivot/crosstab

**Thinking path:**
- `pivot_table(index='product', columns='region', values='account_id', aggfunc='count')` — crosstab-style counts. Add arrears as a second `values` entry → `columns` stacking or multi-level; the two panes are "accounts" and "sum of arrears".
- `pivot_table` (with aggfunc) handles duplicate (product, region) pairs; a plain `pivot` errors on duplicates. Test both to feel the difference — this dataset has duplicate pairs by construction.
- Marginals: `margins=True` adds totals. The margin check is the verification anchor: row-total == long-form grouped count for that product; grand total == snapshot population.

**Verification strategy:**
- Round-trip: `melt` the wide pane(s) back to long, drop the margins rows (or rebuild without them), compare to the original `groupby` frame — identical after dtype/order normalization proves no information was lost in the reshape.

**Traps & worth knowing:**
- Margins rows/cols are aggregate rows — a naive `melt` round-trip will treat "All" as a real region; slice them off before comparing.
- `aggfunc='count'` counts *non-null* `values`; if `account_id` is dense it equals row count, but swap in a sparse column and the pancake flops — prefer `'size'`-style counting where you mean "rows".
- Column MultiIndex from two `values` is fine, but flatten with `.columns = […, …]` before writing to Excel later — Excel track will thank you.

---

### Finish

Compare your shapes to the guidance. One-line diff note per task = your log. If you can articulate *why* each reshape tool was right, medium is done.

**Move up when:** you pick `merge` / `groupby` / `pivot` / `melt` from intent, not from memory.