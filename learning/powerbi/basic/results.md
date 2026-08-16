# Power BI — Basic — Results (Guidance)

```
learning/
├── _reference/            ← datasets.md, kpi_glossary.md, data_dictionary.md
├── sql/  python/  notebooks/  excel/  git-cli/
├── powerbi/
│   ├── README.md
│   └── basic/             ← YOU ARE HERE
│       ├── tasks.md
│       ├── results.md     ← current file
│       └── work/
└── README.md
```

**How to use this file:** attempt → look → read one section. Guidance only — reasoning paths, steps-with-why, verification strategy, traps. No full DAX, no computed values.

---

## Task 1 — Model reflects schema

**Thinking path:**
- Import mode = the data is copied into the model (a snapshot); DirectQuery = the visual pings the source live. Import wins on responsiveness and enables the whole measure stack; DirectQuery wins on freshness. For a daily-load MIS portfolio, import is the sane default — picks the trade and states it (freshness vs latency).
- Star-schema cardinality sanity: facts many-to-one into dims, one row per dim key. This model is deliberately built so *no many-to-many* exists — if Power BI auto-detects one, an auto-detection guess is wrong, not a new truth.
- No fact-to-fact relationships: `fact_payments.ptp_id` is FK-less *by design* (dictionary note) — DAX filter propagation crosses *shared dims*, not raw fact links. A fact-to-fact relationship fertilizes cartesian behavior you'll fight forever. Drop it; filter through the account/calendar dims instead.

**Verification strategy:**
- Data-view row counts per table == the DB counts you've already verified (the model is only as correct as the import).
- Hover relationships: each active relationship shows correct cardinality + cross-filter direction.

**Traps & worth knowing:**
- Auto-detected relationships guess cardinality from your data; a *dirty* import (duplicate keys in a dim) can fool it into creating a vermin m2m. Clean the dims before modeling.
- `Bi-directional` cross-filtering is a power feature that disables itself when used carelessly — leave defaults one-directional unless you can justify bidirectional (measure-level reasons).

---

## Task 2 — Measure vs column

**Thinking path:**
- A measure is evaluated **in the filter context at render time** — slicing by month/team/channel re-evaluates it each time. A calculated column is evaluated **once at load** and stored per row — it can't know a later slicer. That single line is the whole "which one" decision.
- RPC% as a measure = ratio of sums inside the current context (the denominator from `kpi_glossary.md`) — the exact convention you proved in SQL. Sum-of-sums discipline carries; averaging per-row flags (or a column of precomputed daily rates) is the same trap in DAX (glossary §6).
- The column demo: a stored per-row 1/0 column supports row-level arithmetic but the *mean of flags ≠ rate of sums* — build both, present the difference as a note on the page.

**Verification strategy:**
- Your measure with a month slicer = your SQL/Python/Excel RPC% for that month (the cross-track identity, again).
- Formatting: percent format with a `0.0%` display — a measure that displays `0.35` as `35%` correctness check.

**Traps & worth knowing:**
- Implicit measures (drag a column → auto-sum) are traps: Power BI picks *sum/count* by guess; your ratio-of-sums has no implicit form. Always author the explicit measure.
- A measure that "staticly looks right" under no slicer can silently go wrong under a slicer if it references a bare column (implicit filter) instead of the context-correct expression — test under a slicer, always.

---

## Task 3 — One honest page

**Thinking path:**
- Visual choice per claim: line for trend (sequence), bar for categorical totals (channel volumes), bar for top-10 by arrears (ranked magnitudes), matrix for profile (bucks × counts). A chart chosen by habit (pie everywhere) is a chart that lies by idiom.
- As-of discipline: the top-10 arrears and the delinquency profile are *snapshot-state* claims — the page needs the snapshot month stated on-page, or the reader misreads a Dec figure as "now".
- Definitional alignment: the RPC% trend uses *RPC per connected* while the channel bar uses *total calls attempted* — different denominators by design (each matches its claim); the *note* must say so (the "same-number-looking-different-meaning" trap from the whole track).

**Verification strategy:**
- Each visual's number == the same slice you already proved elsewhere. Any visual that *looks* right but fails this check is the finding to chase, not to render around.
- The page reads in one glance with the as-of note: a stranger answers "what's the story" from the title + five numerals.

**Traps & worth knowing:**
- A hidden per-visual-level filter that silently changes a claim (e.g. only Manual channel) renders a different story under a slicer — no visual-level filters without an on-page mention.
- Sorting: a bar sorted by value ascending can reorder as the slice changes; default sorts alphabetically — choose the deliberate sort per visual.

---

## Task 4 — Slicers restate

**Thinking path:**
- A slicer changes the **filter context** for the whole page; measures recompute and row sets narrow. Every visual should honor it — that's the restate-check. The top-10 visual *effort* is the tell: it must recompute "top 10 **within the slice**", which it does naturally once context flows — if it doesn't, a visual-level filter holds it hostage (find and fix).
- The "all" option: a slicer that can't represent "everyone" makes the *default* state misleading; justify absence (a tiny dim with a mandatory active state is a legit reason) — but don't leave it casual.

**Verification strategy:**
- Under a chosen slice (team+month+product), every visual changes — including the cards **and** the top-10 (grain: distinct accounts within slice). Dead visuals are the deliverable-bug to document.
- The broken-visual hunt: which one ignored the slicer first, and what was holding it (a visual filter, a measure that filtered a column)? That note is your Task 4 finding.

**Traps & worth knowing:**
- Measures referring to a *bare column* (implicit context) vs to the context passed by slicers — the difference surfaces only under slicing; test every measure under a nontrivial combi.
- A numeric "month" slicer vs a calendar-based one — using the `Dim_Calendar`-style date for slicing keeps report periods aligned with the whole model.