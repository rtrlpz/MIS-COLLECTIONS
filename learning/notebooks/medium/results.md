# Notebooks — Medium — Results (Guidance)

```
learning/
├── _reference/            ← datasets.md, kpi_glossary.md, data_dictionary.md
├── sql/  python/  excel/  powerbi/  git-cli/
├── notebooks/
│   ├── README.md
│   └── medium/            ← YOU ARE HERE
│       ├── tasks.md
│       ├── results.md     ← current file
│       └── work/
└── README.md
```

**How to use this file:** attempt → commit → read one section. Guidance only — reasoning paths, steps-with-why, verification strategy, traps. No full code, no computed values.

---

## Task 1 — SQL in a notebook

**Thinking path:**
- Credentials from `.env`: read the file, parse host/port/user/db/password, set the connection. Never hardcode — the "never commit creds" rule is a state of *habit*, and a helper cell that reads `.env` is the habit embodied.
- A connection helper as one cell keeps it visible and idempotent (re-running shouldn't spawn 50 open cursors). Parameterized query: the month is a *variable* passed into the SQL (engine-side binds, or a well-scoped Python parametrization — avoid naive string-f-strings that break on quoting).
- Round-trip through a DataFrame is the point: it lets the next cell reuse the result for charting or for the Task 2 audit-pair. A raw cursor → print grid answers one question; a DataFrame answers one question *and* leaves the result available.

**Verification strategy:**
- Parameter change → rerun the query cell → chart shifts to the new month. If the query cell's text had the literal, you'd be *editing* the query (the anti-pattern).
- Restart & Run All: the connection cell must not leak state (close/finish the connection cleanly so repeated runs don't exhaust).

**Traps & worth knowing:**
- Forget the password when source-ing `.env` → a broken connection cell. Guard with a friendly print.
- In Jupyter, a cell that opens a connection and never closes leaves a lingering session; DB sessions are finite — read and close (or rely on the client's `with` context).

---

## Task 2 — Two sources, one notebook

**Thinking path:**
- The audit-pair: same metric, two engines, in *adjacent cells*. The zero-divergence check is a merge-then-flag column (tolerance chosen consciously — tiny float noise is expected; a real mismatch is a *filter or dtype* gap).
- Source choice honesty: DB = the pipelines' output; CSV = the generator's land. If they disagree, the blame chain is ETL (load skipped rows), generator (columns misnamed), or your own two code paths (one filters a channel). The notebook can only *flag*; the analyst explains.
- Why flag-column over eyeball: two grids side by side hide a single differing row; a merged frame with a `diff > tol` boolean reveals exactly the offending team(s) in one cell.

**Verification strategy:**
- Zero flags printed = a clean ETL statement in one cell (that *is* the deliverable).
- Re-run after changing tolerance to show the noise floor, then back to the honest tolerance.

**Traps & worth knowing:**
- The two paths can differ by *aggregation order* (rounding at different stages) — tolerance choice internalizes that, but state the tolerance's meaning in Markdown.
- If the DB path returns a team the CSV path lacks (or vice versa), a straight merge hides the mismatch — do an *outer* merge and flag nulls on either side.

---

## Task 3 — Trends that earn their charts

**Thinking path:**
- RPC% (rate) and AHT (time) have different units and different ranges — a shared single axis is meaningless; a twin-axis figure can mislead by superscaling. The *honest* default is separate panes sharing an x (time) — unless the story is *comparative timing* (both metrics turn in the same month), where twin-axis has a narrow, defended place.
- Monthly means flatten within-month shape — if you claim "the turn happened in March", bring the daily/weekly trace to prove the turn isn't a month-boundary artifact (basic Task 3's optical-illusion lesson, in a time series).
- A "year boundary" or "policy month" vertical line is evidence of an *event*, not decoration.

**Verification strategy:**
- The two monthly series match your python-basic/medium numbers (already proven — presentation only).
- Any marked "turn" in the story has a supporting sub-plot or data point; a story claim without evidence inside the same notebook fails its own pretense.

**Traps & worth knowing:**
- Same chart, two axes, one barely visible line: the eye reads what's big. Separate panes render that unmistakeable.
- A single anomalous month (holiday-heavy) will swing monthly AHT; note it rather than smooth it away.

---

## Task 4 — Buckets that become a picture

**Thinking path:**
- Source: EOM snapshots for the latest three month-ends (DB or CSVs — pick; if CSV, you reassemble months which is its own lesson). Bucket via `pd.cut` with house labels (python medium Task 3 — reuse, don't re-derive).
- Static profile: accounts + arrears per bucket — this is the *state* read.
- Evolution: each bucket's *share* of accounts across three months. Share (not counts) because the portfolio size can drift month-to-month; raw counts would disguise a relative mix-shift. A 100% stacked bar shows mix-shift at a glance; a grouped line shows *directional* movement (bucket X climbing). Pick by what claim you're making — the claim defines the idiom.
- The takeaway lands on *which bucket crawls* (e.g. accounts migrating from early to late in successive months) — that's the "crawl vs cure" reading managers care about.

**Verification strategy:**
- Shares sum to 100% per month-ends (or the mix is fully partitioned — margin identity).
- The bucket whose share crawled is *traceable* to a month-pair where the migration matrix (sql/python advanced) would confirm the same direction — cross-track consistency.

**Traps & worth knowing:**
- If you show *arrears* shares instead of account shares, the story can flip (few big arrears) — label clearly which share you chart, and say why it's the right one for the claim.
- NaNs in `pd.cut` (accounts outside defined edges) silently drop rows — keep an explicit "other" bucket so shares still partition.

---

## Task 5 — The notebook that outlives you

**Thinking path:**
- Config cell at top: `MONTHS`, `SOURCE` — everything downstream *reads* these. Localizing month literals into one cell means a stranger changes one value, not five cells (and never risks editing a query string).
- The early guard: if DB is the source and it's down, *loud early* — print a clear message and stop, rather than failing deep in cell 12 with a confusing traceback (or worse, silently falling back to CSV and producing a *different* number).
- A db/csv fork also forces you to *keep both engines in sync*: identical final numbers across runs is the master verification. Two runs, one config-variable flip, identical story.

**Verification strategy:**
- Restart & Run All with `SOURCE='db'`; then again `SOURCE='csv'`; final numbers equal, both complete without manual steps. That's the reproducibility bar.
- Kill the DB (or point at a wrong port) and confirm the guard fires with a readable message.

**Traps & worth knowing:**
- "Cell 5 sets sourced + cell 7 overrides it" is the state-leak trap; only the config cell may set `SOURCE`.
- A guard that stops execution must be *deliberate* — an exception that halts the kernel vs a clean `SystemExit` message differs in reviewer-friendliness; choose the readable one.