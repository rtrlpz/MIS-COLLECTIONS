# Python — Advanced — Results (Guidance)

```
learning/
├── _reference/            ← datasets.md, kpi_glossary.md, data_dictionary.md
├── sql/  notebooks/  excel/  powerbi/  git-cli/
├── python/
│   ├── README.md
│   └── advanced/          ← YOU ARE HERE
│       ├── tasks.md
│       ├── results.md     ← current file
│       └── work/
└── README.md
```

**How to use this file:** attempt → commit → compare → read one section. Guidance only — reasoning paths, steps-with-why, verification strategy, traps. No full scripts, no computed values.

---

## Task 1 — `v_contact_metrics` in pandas

**Thinking path:**
- Definition-first discipline: write "RPC% = RPCs ÷ <denominator>" from the glossary before `groupby`. This is the same commitment you made in SQL — the port should be a *straight* translation, not a re-deciding.
- Team attach: fact carries `agent_id`; merge the employee dim for `team_name` (`how='left'` — every interaction keeps a team even if the agent moved).
- Operational hours live in `fact_agent_time_log` (different grain: agent-day). Merging hours into an interactions frame at *interaction* grain fans out. The clean move: aggregate hours per team-days first, then join the *already-aggregated* hours at team level. Pre-aggregation is the pandas twin of the SQL "aggregate each fact separately" lesson.
- Compare vs `v_contact_metrics` or your SQL advanced Task 1. Divergence has two classic holdouts: (a) view filters channels; (b) view computes the rate per *operational hour* denominator you skipped. Prove one with a targeted groupby diff (add filter → does the gap close?).

**Verification strategy:**
- Per-team RPC totals sum to the portfolio total within the same window.
- The channel-restricted version should bring your numbers in line with the view if (a) was the cause — that targeted test is your evidence.

**Traps & worth knowing:**
- Merging hours at interaction grain is the blowup you'll see as a sudden row-count explosion; always `assert len == len(fact)` after any dim attach.
- Float division policy differs across pandas/NumPy versions — `.astype(float)` before dividing keeps the port version-proof (the same callout from python basic Task 4).

---

## Task 2 — Promise chain

**Thinking path:**
- Draw the three-fact chain; the key contract is counting (RPC → PTP → kept payment) without multi-counting. `fact_payments.ptp_id` has no FK — so association is *your* logical choice: one payment ↔ one promise? multiple payments per promise (promise kept once, paid in parts)? Decide and state it, because it changes KP%.
- `PTP% = promises ÷ RPCs` per team — denominator from glossary, not commonsense. "RPC" here means the *evaluable RPC population* for a window; decide window alignment (promise date vs RPC date) explicitly.
- KP%: define *kept* (payment satisfying promise? on time? full amount?) and *evaluable* (target date passed within window) — the two knobs that silently swing the rate. The glossary's documented fix — **BB = kept-rate × promise-rate** — exists because the chain is compound probability: a promise only *means* something if it was made (PTP%) *and* honored (KP%). Product, not some naive ratio.
- Cure and kept-promise are cousins: `is_cured` on payments reflects an account brought current; a kept promise is a promise pipeline outcome. Don't let them fuse by `merge` accident.

**Verification strategy:**
- Chain equality: your PTP count vs a distinct count of PTP rows in the window; KP vs the payments in that window keyed to evaluable promises.
- BB product: it's a [0,1]×[0,1] product each term in range — verify term bounds (matching the glossary's documented ranges for this portfolio).

**Traps & worth knowing:**
- Fact-to-fact merges have no grain anchor — unless one side is pre-deduplicated (one row per promise), the merge emits repeats and your "kept" count junk-vacuum blows up. Dedupe by key before merging.
- A payment's `ptp_id` may reference a promise that got *cancelled* — decide whether cancelled promises count as evaluable, and note it (the view has an answer).

---

## Task 3 — DPD migration matrix

**Thinking path:**
- Two-month population: `merge(df_m1, df_m2, on='account_id', suffixes=('_last','_this'), how='inner')` = accounts in both snapshots (the transition set). Compare against an `outer`-flavored merge to *see* the displaced/new accounts and count them — the view's population rule is discoverable by matching its total.
- Buckets: reuse `pd.cut` from python medium Task 3 (`include_lowest=True`, explicit labels). Columns collide as `dpd_bucket_last` / `dpd_bucket_this` via suffixes.
- `crosstab(index='dpd_bucket_last', columns='dpd_bucket_this', values='account_id', aggfunc='count')`, then percentaged by *row* total (row-normalized): each row answers "where did last month's [bucket] go?" — the roll/crawl/cure optics of the matrix.
- Row total of 0 (a bucket absent last month) → NaN row percentages: present it as the honest "no population" rather than a 0 that reads as "all cured".

**Verification strategy:**
- Marginal identity: `matrix.sum(axis=1).sum() == len(pair population)`.
- Cell sums per row == paired total (the transition-completeness check).
- Compare cell orientation vs the view: rows = last month = `m1`, columns = this month = `m2`. Transposed is the classic silent bug — same totals, flipped story.

**Traps & worth knowing:**
- The *latest adjacent pair* matters: December→January is the natural end-of-year transition; don't compare January to December *as if* consecutive unless they actually are in snapshot order.
- Suffixes + two `arrears` columns: rename before analysis — `sum_arrears` per cell needs an explicit column pick.
- Snapshot months come split per month-folder file; read the two files directly rather than slicing one big concat (fewer rows in memory, exact pair).

---

## Task 4 — Scale discipline

**Thinking path:**
- Explicit dtypes are the whole game: int that fits → smaller int (`account_id` in int32 can halve the frame), low-cardinality strings (`channel`, `product`, `status`) → `category`; floats at float32 where precision allows. Measure with `df.info(memory_usage='deep')` (object columns count *string objects*, default `info` lies low).
- One-read-pass reassembly: loop months, `read_csv` with the dtype map once, `concat` at the end — avoids twelve full copies burning peak memory. Parquet preserves the dtype+statistics story and reloads fast; CSV is portable. Assert schema equality on reload (`df.parquet.dtypes == reload.dtypes`).
- Aggression check: run a rate computation (per-channel RPC%) on the reassembled frame — float division, no warnings. Wrong dtypes (int/int truncation) show up *here*.
- The Database cross-check (optional stretch): pick one metric, get it from PostgreSQL in one line; time both. The lesson isn't the ms — it's that two engines reach the same number through different paths, and knowing the *order of magnitude* of each is professional judgment.

**Verification strategy:**
- Memory delta printed before/after dtype pass — the number is your written evidence (should be a *reduction*; if not, your dtype map missed the wide object columns).
- Parquet round-trip asserts schema equality — no silent dtype drift on reload.
- Cross-engine metric equality: matches your SQL answer or your finding note (advanced rule).

**Traps & worth knowing:**
- `category` on high-cardinality strings (free-text names) can *cost* more, not less — reserve it for `channel`/`status`-like small sets.
- floor of float32 on balance/arrear sums can drift pennies on a 1.8M-row sum — use float64 for money unless you've proved otherwise.
- `read_csv` dtype inference on a 350MB file happens *twice* if you don't declare it (once to sniff, once to fill) — declaring dtypes shortens the first pass.

---

### Finish

Each file should end with a finding log: **ported / matched / diverged / root cause**. A complete set of honest finding logs — not perfect matches — is the graduate certificate.

**Graduate when:** you can rebuild a reference KPI from raw files on demand and explain the one deliberate convention each metric embeds.