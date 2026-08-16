# Power BI — Medium — Results (Guidance)

```
learning/
├── _reference/            ← datasets.md, kpi_glossary.md, data_dictionary.md
├── sql/  python/  notebooks/  excel/  git-cli/
├── powerbi/
│   ├── README.md
│   └── medium/            ← YOU ARE HERE
│       ├── tasks.md
│       ├── results.md     ← current file
│       └── work/
└── README.md
```

**How to use this file:** attempt → commit → read one section. Guidance only — reasoning paths, steps-with-why, verification strategy, traps. No full DAX, no computed values.

---

## Task 1 — CALCULATE

**Thinking path:**
- DAX is *context*: a measure's numeric output is a function of the current filter context (row filters, slicers, page context). `CALCULATE` is the one function that **changes** that context for one expression — the surgeon's knife. The base measure (no CALCULATE) inherits whatever slicers exist; the Manual-only measure *narrows* the context (channel filter); the "genuine overall" measure *widens* it (removes the channel effect via a `REMOVEFILTERS`-class argument on that column) so it says "overall" even under a channel slicer.
- Inherit-vs-intend: the Manual measure inherits the month slicer (fine — you asked only channel to change); the overall measure must remove *only channel*, keeping the month slicer. The lesson: CALCULATE changes what you specify, and *only* what you specify; everything else inherits.

**Verification strategy:**
- Under a channel slicer → the overall card must NOT change (it overrides); the base card must change (it inherits); Manual stays Manual. All three behaviors on one screen *are* the proof.
- Cross-check: Manual's number matches a hand filter of the raw data for the same window.

**Traps & worth knowing:**
- `ALL`-class removers are *broad*: removing "all columns of channel" can over-remove if you intended only one column. State precisely what you mean to wipe.
- A measure text must compile with a trailing function-only body (no standalone `FILTER` in a measure body without `CALCULATE`); the rule "currently, filter functions live only inside ␁CALCULATE-adjacent" is the #1 newbie error in DAX.

---

## Task 2 — Time intelligence

**Thinking path:**
- Parallel-period functions (`PREVIOUSMONTH`-class) return the equiv-period **relative to the then-current context**, then connect to a lifted `DATE` context via `CALCULATE`. The honest edge: when a partial slice (e.g., a 3-month window from June) is active, the period-before measure computes against the *whole* prior period, and `DATEADD`-schemes can produce all-context or blank rows depending on the pattern. The professional move is to *observe* and *declare* the edge (blank for "no previous"), not to silently guess.
- Delta = current − previous as a *measure* (live, re-computes under any slice) — never a stored column (which freezes the slice it was computed under). Same theorem as measure-vs-column, restated in time.

**Verification strategy:**
- For a mid-series month, your previous-month measure == the same month's proven rate (cross-track). For the *first* month of data, it must blank (no previous) — show that blank as a designed fact, not an accident.
- Slice to a window: the previous-month measure returns the period-before *of the window*, and the trend line stays flattering-honest (no fabricated early rows).

**Traps & worth knowing:**
- Calendar continuity: month-end-30 vs 31-day months make `PREVIOUSMONTH` land on a distinct set of days — a "31-day vs 30-day" comparison bug that swims silently. State whether you compare *calendar months* or *days-in-window*.
- A measure that uses time-intel without a calendar table in the model (or with `date` not marked as date-table) quietly computes nothing — the `Dim_Calendar`-style table + marking is the precondition.

---

## Task 3 — Trend vs state pages

**Thinking path:**
- One model, two claims: Flows = time series over event facts (interactions/PTPs); State = point-in-time view of `fact_eom_snapshot` (buckets/arrears at a snapshot date). They belong on *separate pages* not because of aesthetics but because mixing them yields "a trend made of monthly snapshot deltas" — a claim that's neither a flow nor a state.
- As-of control: State page needs a *snapshot-period* slicer (or an explicit as-of caption) so December's profile isn't read as "current" — the Excel as-of discipline, carried into a live dashboard.
- Edit-interactions: Power BI lets you decide whether another page's slicer cross-filters a visual. Keep sync where two pages are *same-entity* (both about teams — a team sync is meaningful); break it where the combination is *semantically empty* (a team slicer dead-filtering a snapshot that's account-level and team-independent) — a "smoke screen" filter is worse than no filter.

**Verification strategy:**
- An auditor flicks the snapshot period on the State page: profile + top-10 re-answer to that month-end; the Flow page is unaffected (or deliberately linked) — the divergence is *expected and labeled*.
- Cross-track: State page top-10 arrears == Excel advanced top-10 arrears (same as-of). Flow RPC% trend == the line you've drawn three times.

**Traps & worth knowing:**
- Snapshot table *without* an as-of slicer silently shows ALL months stacked (a "current profile" that's actually a year of stacks) — the #1 state-page bug; always pin the as-of.
- `ALL`-style page baselines on the Flow page can inject "this visual ignores all your slicers" weirdness — prefer page-level default filters over buried all-context measures for the normal user story.

---

## Task 4 — Measure library

**Thinking path:**
- The `_Measures` table is an empty (display-only) table that exists to *house* measures — so measures live in a dedicated container rather than inside a model table's field list. It must never hold data (a data-bearing `_Measures` is a fact table wearing a disguise — breaks cardinality hopes and confuses the model reader).
- Display folders = the taxonomy the reference deck already uses (Contact / Promise / Recovery / Time Intelligence — mirror naming for scale). A measure without a folder in a 252-measure library is needle-in-haystack.
- Comments/descriptions on measures = the source-of-truth habit: definition, denominator, and the "people misread this because…" line. This is the CSV-measure philosophy (measures documented *at authoring time*, reviewable outside the PBIX) in embryo.
- The manifest (`work/measure_manifest.md`) = your own mini version of the CSV measure documentation: pattern, taxonomy, comment policy.

**Verification strategy:**
- Stranger-test the library: given "pull MoM RPC%", can they find it by folder+name in under a minute without reading bodies? That's the taxonomy test.
- Comment audit: every measure in your PBIX has a description or comment explaining its denominator — none leave the reader guessing.

**Traps & worth knowing:**
- Three measures named `RPC%`, `RPC % YoY`, `RPC% (py)` read as siblings — the *naming rule* (e.g. prefix family + horizon: `Contact_RPC%`, `Contact_RPC%_MoM`, `Contact_RPC%_PY`) must be stated in the manifest or the CSV replaces nothing.
- Deferred-editing measures in the field list right pane (a "measure" you only rename) — name your measures at *creation* time; renaming later breaks existing visuals without a widespread replace.

---

## Task 5 — Multi-page report stands a review

**Thinking path:**
- Navigation buttons (a button strip or a nav page) over the raw tab bar: hierarchy + call-to-action + guardrail (a reader lands on a *reset/no-filter* state, not a deep-filtered one). Tab bars encourage dead-ends; buttons *walk* your narrative.
- The slicer shelf with a "applies to…" caption sets scope; a page with slicers that whisper their application area is a page that produces misreadings.
- The stranger-filters test is the guts of Task 5 — a measure that *silently blanks* or returns a grotesque value under an unexpected combination is either a real context bug or a design statement (the combination is meaningless). The professional frame: *decide* which, then *show* the decision (blank + caption, a "no data for this combination" text), never ship an unexplained surrogate.
- The ≤3-clicks cold-read test is the report's acceptance criterion — measure it with a real stranger, don't pretend to.

**Verification strategy:**
- Reset → stranger walk: channel-who-volume-and-trend in three clicks; note the click-path that failed (navigation order, slicer placement) and fix it — the fix is the deliverable.
- Cross-filter the stranger state: no measure breaks; the "no data" states are labeled. Screenshot everything, because the report *state* at that moment is part of the record.

**Traps & worth knowing:**
- Deep-linking into a filtered PBIX state on open (a page loaded with last-session filters) can confuse the cold-read test — reset the report's default filter state so first open = neutral.
- A measure that depends on *which* slicer is on (rather than reacting to its values) is the sign of an over-engineered context — simplify until it's a simple function of the context.