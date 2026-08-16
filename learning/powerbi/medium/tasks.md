# Power BI — Medium — Tasks

```
learning/
├── _reference/            ← READ FIRST (datasets.md, kpi_glossary.md, data_dictionary.md)
├── sql/  python/  notebooks/  excel/  git-cli/
├── powerbi/
│   ├── README.md
│   └── medium/            ← YOU ARE HERE
│       ├── tasks.md       ← current file
│       ├── results.md     ← guidance, peek AFTER attempting
│       └── work/          ← your .pbix + screenshots live here
└── README.md
```

**Up from powerbi basic:** model, explicit measures, one honest page, slicers that restate. Medium is where DAX stops being "a formula" and becomes **a language of context** — CALCULATE, time intelligence, interaction between visuals, and the discipline of a *measure library*.

**Setup:** Power BI Desktop + the model page from basic (extend it). Save each as `learning/powerbi/medium/work/attempt_*.pbix` + screenshots.

**Discipline:** attempt → commit → read as a viewer → read `results.md`.

---

## Task 1 — CALCULATE: the context surgeon

The supervisor: *"I want RPC% overall, AND RPC% for Manual channel only — as two separate measures, side by side. One must literally say 'overall excluding nothing'."*

**What you'll practice:** `CALCULATE` (changing filter context) vs a default measure — the language's heart — and writing an *explicit overall* that survives slicers.

Steps:
1. Base measure: the RPC% you proved (basic Task 2).
2. Manual-only measure: `CALCULATE` on the base measure with a `FILTER`/equivalence for channel = Manual. (State the syntax's meaning in a comment: what context you changed and why.)
3. "Overall, genuinely": a measure computing base RPC% while *removing* the active channel context (or a page-level slicer) — so "overall" means overall even under a channel slicer.
4. Page: three cards — overall, Manual, overall-undoes-slicer — and a slicer that proves card 3 is the honest "overall".

**Guiding questions:**
- What does "changing the filter context" mean — does your Manual measure *inherit* other slicers it shouldn't (e.g., a month slicer staying on)? Which context change should be intentional, which inherited?
- Why is an explicit "remove channel" (`ALL`-class) measure fragile if you later want to filter by team too? What's the general rule (remove only what you intend)?

**Deliverable:** `work/attempt_1.pbix` + screenshot under a slicer proving the three cards behave correctly.

---

## Task 2 — Time intelligence you understand (not paste)

The supervisor: *"The month-over-month RPC% — previous month's rate, month-on-month delta, and a 12-month horizon. Build the measures; know what each does under a partial date range."*

**What you'll practice:** time functions (`PREVIOUSMONTH`-class parallel-period + `CALCULATE`), and the *partial-range pitfall* — what the previous-month function returns when the data doesn't start at Jan 1 (or the filter is sliced to a week).

Steps:
1. Month-on-month measures: current-month rate, previous-month rate (`CALCULATE(base, <parallel period>)`), delta (current − previous), and a textual cue for "no previous" rows.
2. A 12-month trend visual from the monthly measures (the line you've drawn before — now measure-driven).
3. Test partial-range honesty: slice to a subrange (e.g., a 3-month window) and confirm the previous-month measure handles the *edge* (returns blank / shown as blank, not a wrong number). Note what you observe.
4. Add a card showing the delta with a `+/-` and percent format (presenter-grade, and correct under slicers).

**Guiding questions:**
- `PREVIOUSMONTH` returns the parallel period *relative to the current filter context* — so under a sliced range what does it return? (All?) Why is that a feature, and when does it become a misleading-answer trap?
- Why must the delta be live (a measure) rather than a stored column? (Same lesson as measure-vs-column, now in time-space.)

**Deliverable:** `work/attempt_2.pbix` + screenshot of the edge case (partial slice) with your note.

---

## Task 3 — Trend vs state: two pages, one model

The supervisor: *"Two audiences: ops wants movement (flows), credit wants the state of the book (snapshot). One model, two pages, no duplicated data."*

**What you'll practice:** multi-page reports from ONE model + visual *interaction* control (`edit interactions`) so pages slice independently without data duplication.

Steps:
1. Page A ("Flows"): monthly RPC%/PTP% trends + per-channel volumes (facts over time).
2. Page B ("State"): the latest snapshot's delinquency profile (buckets × counts × arrears) + top-10 accounts.
3. CRITICAL: Page B's profile must be **as-of the latest snapshot** — add a snapshot-period slicer, or paginate the as-of month, so a reader can't silently mix months. Show your choice and why.
4. Use `edit interactions`: while Page A slicers can cross-filter its own visuals, make the Page B profile *ignore* Page A's team slicer only where that physically means something (mixed-entity slicing is a smoke screen — decide, don't rubber-stamp).

**Guiding questions:**
- A trend (flow) claim and a snapshot (state) claim on the same model — what breaks if a page mixes them (a "this month's trend" line built from monthly snapshot deltas)? Which families must never co-plot without a defensive label?
- Edit-interactions: when is cross-page sync genuinely useful vs a liability? Name one case you'd *keep* synced and one you *break*.

**Deliverable:** `work/attempt_3.pbix` + screenshots: Flow page, State page with as-of control + your interaction decisions noted.

---

## Task 4 — The measure library: naming, folders, comments

The supervisor: *"You have 6 measures now. In production you'll have 252. Build the discipline NOW: a measure table, folder structure, and a comment/name so future-you can find 'that RPC thing'."*

**What you'll practice:** measure-housekeeping — a dedicated measure table (an empty `_Measures` table), display folders, deliberate naming (prefixes), and comments on every measure (the CSV source-of-truth habit, before the full 252).

Steps:
1. Create a `_Measures` (display-only) table; move your measures into it with clear names (`RPC%` vs `[Measure] Count` style — adopt a pattern and state it).
2. Assign display folders by *family* (Contact / Promise / Recovery / Time Intelligence) — mirroring the reference layering so it scales.
3. Add a comment (or a description field) on every measure: definition, denominator, and the *why* someone might misread it (e.g. "this is per RPC-counted call, not per connected").
4. Write a one-page `work/measure_manifest.md` describing: naming pattern, folder taxonomy, comment policy — the mini version of the CSV-measure documentation habit.

**Guiding questions:**
- Why does a measure table exist, and why must it be *display-only* (empty, no loads)? What breaks if a fact lands in it?
- Prefixes/folders: three measures that "look like the same thing" (YTD RPC%, MoM RPC%, PY RPC%) — what naming rule disambiguates them without reading bodies?

**Deliverable:** `work/attempt_4.pbix` + `work/measure_manifest.md` + screenshot of the field list showing folders.

---

## Task 5 — The multi-page report stands a review

The supervisor: *"Ship pages: a reader (not you) should reach the finding in three clicks: a nav page or button strip, a slicer shelf that makes sense, and measures that survive being cross-filtered by a stranger."*

**What you'll practice:** navigation affordances (buttons/page-navigation + a slicers shelf), measure robustness under *stranger* filtering, and the final *cold-read test*.

Steps:
1. Add navigation: a small button strip (Flows / State / Nav) on each page, or a nav page with click-through. In Power BI this means button actions.
2. Organize a shared slicer shelf per page (team, month, product — where meaningful) with a visual header: "slicers apply to…" so readers know the scope.
3. The stranger-filters test: sit one slice across everything and confirm *every* measure responds correctly (no measure that breaks, blanks silently, or returns an implausible value).
4. Cold-read: with all filters reset, a stranger finds "which channel drives volume and how it's trending" in ≤3 clicks. Note the fail if it took them more.

**Guiding questions:**
- Navigation buttons vs relying on the tab bar: what does a *button* add that a tab doesn't (hierarchy, call-to-action, guardrail against deep-linking into a filtered state)?
- A measure that breaks under an unexpected combination (blank / 0 / absurd) — is that a DAX bug or a *design* statement (the combination itself is meaningless)? How do you decide which and how do you show it (not silently)?

**Deliverable:** `work/attempt_5.pbix` + screenshots of nav, the slicer shelf, and the stranger-filtered state (with your verdict).

---

### Finish

Attempt all five, then read `medium/results.md`. Add one line per task on the moment DAX "clicked" (storage-less context, parallel period, interactions — whichever landed).

**Move up when:** you can write a CALCULATE that only touches the context it means, reason about previous-period under a partial slice, and navigate a 5-page report in your sleep.