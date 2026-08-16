# Power BI — Basic — Tasks

```
learning/
├── _reference/            ← READ FIRST (datasets.md, kpi_glossary.md, data_dictionary.md)
├── sql/  python/  notebooks/  excel/  git-cli/
├── powerbi/
│   ├── README.md
│   └── basic/             ← YOU ARE HERE
│       ├── tasks.md       ← current file
│       ├── results.md     ← guidance, peek AFTER attempting
│       └── work/          ← your .pbix + screenshots live here
└── README.md
```

**Up from excel medium/advanced:** you can build a printable pack with live formulas. Power BI basic is the first step of the same story in a *visual-first* tool: model → measure → one honest page.

**Setup:** Power BI Desktop (see `powerbi/README.md`). Save each as `learning/powerbi/basic/work/attempt_*.pbix` + a screenshot per task into `work/`.

**Discipline:** attempt → commit → **look at the visual as a reader** → read `results.md`.

---

## Task 1 — The model reflects the schema (import mode)

The supervisor: *"Power BI is only as good as its model. Import the star schema and prove the relationships behave."*

**What you'll practice:** the Import-mode model — connecting to the DB (or importing reassembled CSVs — pick and say why), naming tables, and *validating* relationships, not just clicking them.

Steps:
1. Get the data into Power BI: connect (Import mode) to the DB **or** import your `work/` reassembled CSVs. State the trade-off you just made (live-connects vs import freshness).
2. Check the auto-detected relationships: rename to `Dim_*`/`Fact_*` for readability, delete bogus ones, add the *intentional* ones on the keys you know from the dictionary.
3. Prove cardinality: `fact_interactions` → `dim_accounts` is many-to-one; `dim_accounts` → `dim_clients` is many-to-one. Verify in the relationships pane and note any many-to-many (there shouldn't be any by design here).
4. Sanity count on the MODEL (not SQL): row counts in the Data view vs the DB counts you already know. If they differ, find why *before* building anything.

**Guiding questions:**
- Why does a *fact-to-fact* relationship (e.g., anything through `ptp_id`) not belong in this model — what breaks in DAX filter propagation when facts join facts?
- Import mode means the data is a *snapshot* — when is that the right call vs DirectQuery? (Freshness vs performance latency.)

**Deliverable:** `work/attempt_1.pbix` + screenshot of the relationships pane with your cardinalities annotated.

---

## Task 2 — The first measure: RPC% (and measure vs column)

The supervisor: *"Build RPC% by channel so the number is a measure — say why it must be a measure, and what a calculated column would '-do' to it."*

**What you'll practice:** the measure-vs-column distinction — the single most important DAX decision — plus implicit vs explicit measures.

Steps:
1. Create an **explicit measure** inside the interactions table: RPC% = ratio of sums (the denominator from `_reference/kpi_glossary.md`, exactly as you proved it).
2. Add a card visual with period/channel context; verify the number against your SQL/Excel RPC% for the same slice.
3. Now create a *calculated column* that stores per-row `rpc_flag` as 1/0 — and show why a sum/mean over that column yields a **different population** statement than your measure (state the reason in a static text/comment on the page).
4. Format it as a percent, sorted, on a clean one-channel-years page.

**Guiding questions:**
- A measure is computed *in filter context at render*; a column is computed *once at load*. Which one re-answers when a slicer changes? That's the whole difference in one line.
- Why does the visual show the *denominator's* your-chosen meaning only if the measure encodes it? What happens if you average a column of already-computed daily rates (the glossary trap, now in DAX)?

**Deliverable:** `work/attempt_2.pbix` + screenshot: clean page with the measure card + your measure-vs-column note.

---

## Task 3 — One honest page: the story board

The supervisor: *"Give me a first real page: RPC% trend, a channel breakdown, a top-10 accounts bar, and the snapshot delinquency profile. All on one screen, readable standing up."*

**What you'll practice:** layout as communication — visual *choice* per claim (nobody plots a histogram for a rate), sorting, labels, and restraint (five-not-fifty, from Excel advanced).

Steps:
1. Line visual: RPC% over months (the trend claim — the monthly series you've proven three ways).
2. Bar visual: channel volumes (categorical totals) — pick total (not rate) to match the claim.
3. Bar visual: top-10 accounts by arrears (from the latest snapshot) — *state which snapshot month the page is as-of* in a clear label.
4. Matrix/table: delinquency buckets × counts (the profile).
5. One title, one as-of note, one page-claims sentence in a text box. No second debris.

**Guiding questions:**
- Which of the four visuals is an *as-of-snapshot* claim and which is a *flow* claim — and why must the as-of note be on the page, not in your head?
- If the channel bar uses total calls attempted, does the RPC% trend's denominator match? Cross-visual definitional alignment = the check.

**Deliverable:** `work/attempt_3.pbix` + screenshot: the one-page story with as-of note.

---

## Task 4 — Everyone can filter, few can slice-restate

The supervisor: *"Add a slicer for team, month, and product type. Then prove the whole page *re-answers* — not just dims, but the measures too."*

**What you'll practice:** slicers + filter context in action, and the *restate-check*: does every visual honor the slicer (or is one secretly ignoring it)?

Steps:
1. Add three slicers: team, month, product type.
2. Verify the "re-answer" claim: pick a team+month+product and your four visuals must move *together* — including the top-10 accounts (which must now be top-10 *within the slice*).
3. Check for a *broken* visual: find one that ignores a slicer and fix it (a measure or a visual-level filter is holding it hostage).
4. Add a trailing "all" option where meaningful (a team slicer that can't show "everyone" is a footgun — justify its absence if you leave it out).

**Guiding questions:**
- Which slicer changes *filter context* for every measure, and which just changes what rows are plotted? (Answer: all of them — if a visual disagrees, that's the bug.)
- Why does the top-10 visual "reset" under a slicer need effort, while cards don't? (The distinction between row-level and measure-context filtering.)

**Deliverable:** `work/attempt_4.pbix` + screenshot of the page under a nontrivial slice + your note on which visual initially broke and why.

---

### Finish

Attempt all four, then read `basic/results.md`. Write one line per task on what you saw as a *reader* of your own page.

**Move up when:** the model, the measure is explicit, and the page answers — and you can say in one sentence why that RPC% must be a measure, not a column.