# Python — Advanced — Tasks

```
learning/
├── _reference/            ← READ FIRST (datasets.md, kpi_glossary.md, data_dictionary.md)
├── sql/  notebooks/  excel/  powerbi/  git-cli/
├── python/
│   ├── README.md
│   └── advanced/          ← YOU ARE HERE
│       ├── tasks.md       ← current file
│       ├── results.md     ← guidance, peek AFTER attempting
│       └── work/          ← your .py scripts live here
└── README.md
```

**Up from python medium:** merges, datetimes, buckets, group-transforms, pivots — all yours. Advanced is the finish line: **rebuild the project's KPI logic in pandas without a database**, and do it on the full ~1.36M-row scale without blowing up memory.

**Setup:** conda env `mis-collections`. Create `work/attempt_*.py`. Read raw CSVs from `data_sources/raw/`. Reuse your saved `work/` tables.

**Discipline:** attempt → commit to your numbers → cross-check against the SQL-track answers → then read `results.md`.

> **The advanced rule (borrowed from SQL):** a number that differs from the reference view is a *finding*, not a failure. State the semantic divergence and prove it with a targeted computation.

---

## Task 1 — Rebuild `v_contact_metrics` in pandas (no DB)

The supervisor: *"The SQL view says RPC% by team. Reproduce it here — this time the numbers must travel without a database between you and the file."*

**What you'll practice:** porting the SQL derivation into pandas and auditing yourself — the metric travel test.

Steps:
1. State the RPC% definition you'll use (glossary §1) *before* coding — same convention you defended in SQL basic Task 3.
2. From raw CSVs: dissolve the year, attach team via the employee dim, and compute per team: connections, RPCs, RPC%, and RPCs-per-operational-hour (operational hours come from the time-log fact — decide the merge grain carefully).
3. Compare against your SQL advanced Task 1 output (or the `v_contact_metrics` reference). Same table, same order, same values.
4. For any divergence: write one hypothesis sentence, prove it with a targeted `groupby` diff, and leave the finding as a comment.

**Guiding questions:**
- Cross-fact metrics (interactions × time log) risk *row explosion* in pandas too — how do you attach operational hours without `merge`-fan-out? (Pre-aggregate is the classic answer.)
- If the view filters channels and your raw port doesn't, where does the difference *appear* — every team, or only specific ones?

**Deliverable:** `work/attempt_1.py` — pandas port + a printed/side-by-side comparison with your SQL result + divergence notes.

---

## Task 2 — The promise chain: PTP% and KP% from CSVs

The supervisor: *"RPCs become promises, promises become kept payments. Give me the chain per team — PTP%, KP%, and BB conversion — the way `v_promise_metrics` does, but from files."*

**What you'll practice:** the three-fact chain in pandas — interaction RPCs → PTP log → payments keyed by `ptp_id` (FK-less, so *you* define the contract).

Steps:
1. Draw the chain and keys: RPCs (interactions, `rpc_flag`), promises (`fact_ptp_log`), kept payments (`fact_payments`, `ptp_id`). Note the payment table's `ptp_id` intentionally has no FK (dictionary §3) — what does that *mean* for your merge?
2. PTP% = promises ÷ RPCs per team (review the denominator from glossary before coding).
3. KP%: define "kept" and the *evaluable* set explicitly (the SQL advanced Task 2 lesson — target-date-passed vs all).
4. BB = product of the two rates (the glossary's documented fix). Compare all three with `v_promise_metrics` and your SQL advanced Task 2.

**Guiding questions:**
- A fact-to-fact merge (`payments` × promise-ish rows) has no natural grain anchor — is a payment in a PTP due to *that* promise, or just *associated*? How do you keep the count from quietly multi-counting?
- If `is_cured`/`cure_flag` sits on payments, is a cure the same thing as a kept promise? (Read glossary — they're cousins, not twins.)

**Deliverable:** `work/attempt_2.py` — per-team chain + comparison vs SQL/`v_promise_metrics` + your stated merge contract.

---

## Task 3 — The DPD migration matrix in pandas

The supervisor: *"The matrix: bucket last month × bucket this month, accounts and arrears, computed from two snapshots. Files this time."*

**What you'll practice:** the self-merge of two month-populations and `crosstab` — reproducing `v_dpd_migration_matrix` from CSVs.

Steps:
1. Load `fact_eom_snapshot` for two *consecutive* months (the latest adjacent pair available).
2. Merge the two months on `account_id` so each account has last-month and this-month bucket + arrears. `how='inner'` = accounts present in BOTH (the transition population); keep a side-view of accounts that appear only once and compare counts.
3. Build the buckets-from-`dpd` (reuse python medium Task 3's cut logic) and `crosstab` to the matrix: rows last-month bucket, columns this-month bucket.
4. Percentages as a fraction of the *row* total (where did last month's bucket go?) — and compare cell-for-cell with `v_dpd_migration_matrix` and your SQL advanced Task 3.

**Guiding questions:**
- Self-merge via `merge(df_m1, df_m2, on='account_id', suffixes=...)` — where do the suffix collisions bite (two `arrears` columns)?
- Row-percentaged matrix: is a row total of zero possible, and what does it *mean* (a bucket that had no accounts last month)?

**Deliverable:** `work/attempt_3.py` — paired population + raw and percentage matrices + comparison note vs the view.

---

## Task 4 — Scale discipline: ~1.36M rows without melting RAM

The supervisor: *"The full year is big. Show me you can work at that size deliberately: right dtypes, one read-pass to reassemble, and a memory number written down — not a mystery."*

**What you'll practice:** the high-leverage habits analysts reach for when data stops being polite — explicit dtypes, parquet I/O, chunked or filtered reads, memory measurement, and *lazy vs eager* thinking.

Steps:
1. Load the full year's interactions with *declared dtypes* (int64/int32/float32/category where the cardinality is low) and measure memory (`df.info(memory_usage='deep')` before/after dtypes). Note the delta as a comment.
2. Reassemble without holding twelve separate frames in memory: iterate and `concat` incrementally (or read parquet files if you converted — either way, measure peak).
3. Show one aggregation that would be painful if dtypes are wrong: e.g. computing per-channel RPC% on the reassembled frame with float division — prove it runs in-place and fast.
4. Save the final intermediate to `work/` as parquet with `engine`, then reload and assert schema equality.
5. (Optional stretch) Compare a single chosen metric with the equivalent PostgreSQL query result — one line in one tool, tens of millions in another: note how long each *took* (record rough wall-times; don't fuss over exact ms).

**Guiding questions:**
- Why does `category` help (and when does it not — high-cardinality strings)?
- `memory_usage='deep'` vs the default — which one lies less about object columns?
- If you had 100 month folders instead of 12, which part of your loop becomes first to break — and what's the lazy fix?

**Deliverable:** `work/attempt_4.py` — reassembly with declared dtypes + a printed before/after memory delta + parquet round-trip assertion + a short scale-habit note.

---

### Finish

Attempt all four, then read `advanced/results.md`. For each task, close your file with a short "finding log": what you ported, what matched, what diverged, and the root cause.

**Graduate when:** you can rebuild a reference KPI from raw files under time pressure *and* explain the one deliberate convention choice each metric embeds.