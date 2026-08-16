# Notebooks — Medium — Tasks

```
learning/
├── _reference/            ← READ FIRST (datasets.md, kpi_glossary.md, data_dictionary.md)
├── sql/  python/  excel/  powerbi/  git-cli/
├── notebooks/
│   ├── README.md
│   └── medium/            ← YOU ARE HERE
│       ├── tasks.md       ← current file
│       ├── results.md     ← guidance, peek AFTER attempting
│       └── work/          ← your .ipynb files live here
└── README.md
```

**Up from notebooks basic:** clean, reproducible, honest cells. Medium adds the two superpowers of notebooks: **talking to the live database** (SQL → DataFrame in one artifact) and **time-series storytelling** with charts that earn their place.

**Setup:** notebooks/README.md + DB running (datasets.md §5). Save each as `learning/notebooks/medium/work/attempt_*.ipynb`.

**Discipline:** attempt → commit → Restart & Run All → read `results.md`.

---

## Task 1 — SQL in a notebook (cursor in, DataFrame out)

The supervisor: *"In one artifact, pull January per-team RPC% from the live database and chart it. No CSV detour."*

**What you'll practice:** database access from a notebook — `psycopg`-style cursor (or the SQL magic your client offers), parameters, and the pipeline *query → DataFrame → chart* with no intermediate file.

Steps:
1. Read the connection params from the root `.env` (never hardcode — see _reference/datasets.md §5). Build one connection helper cell.
2. Run a parameterized query: team × RPC% for a month you pass in as a variable. (A *parameter* means re-running for another month changes one cell, not the query text.)
3. Load result into a DataFrame; chart it (bar, sorted, labeled — your basic skills).
4. Notebook end-state: a single Markdown cell stating the takeaway; provider the month-variable so a reader can flip it.

**Guiding questions:**
- Why round-trip through a DataFrame at all, instead of "query → chart"? What does a `pd.DataFrame` give you that a result grid doesn't (reuse, mixing with CSV data)?
- Parameters vs string-interpolation in the SQL — what does each risk (injection is a proxy for "string-wrecked query"; here the stakes are just correctness — but the *habit* matters)?

**Deliverable:** `work/attempt_1.ipynb` — env-sourced connection, parameterized query, chart, takeaway cell.

---

## Task 2 — Two sources, one notebook (DB + CSV, arguing together)

The supervisor: *"Cross-check RPC% by team: compute it from the live DB in one cell and from the raw CSVs in the next. Same artifact, same number."*

**What you'll practice:** the audit-pair — a DB figure and a file figure computed in adjacent cells, verified equal *inside the notebook* (not by eye at two separate windows).

Steps:
1. Cell A: DB-derived team RPC% (reuse Task 1's query, one month).
2. Cell B: CSV-derived team RPC% (reuse python basic Task 4 logic, read from `data_sources/raw/`).
3. Cell C: merge the two results on team; add a column that flags where the pair differs beyond a chosen tolerance; print only the flags (usually nothing — that's the point).
4. Markdown: one sentence on what this audit proves about the ETL and about *your own two code paths*.

**Guiding questions:**
- If DB and CSV disagreed, which one would you trust first, and what would you check (row counts, a filter, dtype truncation)?
- Why is the "flag differences" *column* better than eyeballing two result grids side by side?

**Deliverable:** `work/attempt_2.ipynb` — the audit-pair notebook with a zero-divergence verification cell.

---

## Task 3 — A trend story that earns its charts

The supervisor: *"Walk me through 12 months. I want the trend of RPC% AND average AHT — on the same page if the story supports it, separate if it fights. You decide."*

**What you'll practice:** multipanel storytelling with *justification* — when two metrics share a figure vs demand separate panes, and how to read drift across time.

Steps:
1. From the DB (or reassembled CSV — choose the source and say why), compute monthly RPC% and monthly mean AHT.
2. Draw both monthly series. Decide single vs dual-pane based on the read: do the two lines *move together*, or is a shared axis misleading given different units?
3. Add a horizon marker at a year boundary or a policy-ish vertical line if the story has one (read backs for the creator: "what changed").
4. Markdown: the trend story in ≤4 sentences (level, direction, one notable turn date).

**Guiding questions:**
- Twin-line chart with two y-axes: when is that tolerated and when is it dishonest (the basic track's "chart that takes a stand" lesson, in motion)?
- Monthly means hide within-month shape; do you need a daily/weekly sub-trace to claim a "turn"? (Bring evidence for a claim you make.)

**Deliverable:** `work/attempt_3.ipynb` — two metrics, chosen layout *with the reason in Markdown*, ≤4-sentence story.

---

## Task 4 — Buckets that become a picture

The supervisor: *"Delinquency profile of the portfolio: bucket accounts by DPD and show me accounts and arrears per bucket, and the mix changing across the latest 3 month-ends."*

**What you'll practice:** the bucketing + evolution pair — reuse `pd.cut` logic, then show *migration between bucket profiles* as charted shifts, not just a static table.

Steps:
1. Pull the EOM snapshots for the latest 3 month-ends from the DB (or CSVs — pick and defend).
2. Bucket DPD with the house standard (dictionary labels; reuse python medium Task 3).
3. Static: accounts + arrears per bucket for the latest month.
4. Evolution: per-bucket account *share* across the 3 months — a 100%-stacked bar or grouped line. Plus a Markdown note flagging the bucket whose share is *crawling* (each month a worse bucket gains share).

**Guiding questions:**
- Why show *share*, not counts, when comparing across months of different portfolio sizes?
- Stacked bars vs grouped lines for "share over months": which reads the *mix shift* better? Defend yours.

**Deliverable:** `work/attempt_4.ipynb` — static profile + evolution chart + the "share-crawl" takeaway note.

---

## Task 5 — Reproducibility check: the notebook that outlives you

The supervisor: *"Six months from now a stranger will re-run this. Make it survive: no manual edits, no package of a month in a literal string."*

**What you'll practice:** making *any* of your earlier medium notebooks parameter-driven and crash-gracefully.

Steps:
1. Take attempt_3 (trend story) and replace every hardcoded month with a *single* config cell at the top (`MONTHS = [...]`, `SOURCE = 'db'`) — the rest of the notebook must respond.
2. Add a guard cell early: if the DB isn't up *or* `SOURCE` says CSV, a clear message is printed and the notebook stops gracefully (`raise SystemExit`-class early exit from a notebook cell).
3. Restart & Run All twice — once with `SOURCE='db'`, once `SOURCE='csv'` — and confirm both run end-to-end with *identical final numbers*.
4. Markdown epilogue: "How to run me" (3 steps a stranger follows).

**Guiding questions:**
- What breaks first when the month literal is baked into five cells? How does one config cell localize it?
- Why is a *silent fallback* (DB down → silently use CSV) worse than a loud early stop?

**Deliverable:** `work/attempt_5.ipynb` — config-driven fork (db/csv) + guards + run-me epilogue.

---

### Finish

Attempt all five, then read `medium/results.md`. Add a one-line note per task recording what *survived* a Restart & Run All (and what didn't).

**Move up when:** you can wire SQL + CSV into one notebook, verify them equal, and hand it to a stranger who runs it cold and gets the same picture.