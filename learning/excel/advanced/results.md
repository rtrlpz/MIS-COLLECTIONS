# Excel — Advanced — Results (Guidance)

```
learning/
├── _reference/            ← datasets.md, kpi_glossary.md, data_dictionary.md
├── sql/  python/  notebooks/  powerbi/  git-cli/
├── excel/
│   ├── README.md
│   └── advanced/          ← YOU ARE HERE
│       ├── tasks.md
│       ├── results.md     ← current file
│       └── work/
└── README.md
```

**How to use this file:** attempt → open → read one section. Guidance only — reasoning paths, steps-with-why, verification strategy, traps. No full code, no computed values.

---

## Task 1 — Charts that earn their ink

**Thinking path:**
- The chart API (`BarChart`/`LineChart`, `Reference` for categories/values, titles, axis titles, legend) draws from the workbook's cell ranges, not from literal values — so a chart is a *derived object*, regenerated when data refreshes. That's the anchor-by-reference point: series from cells = the chart can never silently disagree with the sheet.
- Claim-idiom match: a *categorical* comparison (channels) → bar; a *time sequence* claim → line. A bar chart of categorical data implying order, or a line over categories implying continuity, are both lies by idiom.
- Growth-proof anchoring: a monthly series that gains a month next period will not auto-extend a `Reference`; design the data range to cover a generous span (or rebuild ranges on regeneration). Silent range-death is the #1 "chart died after refresh" incident.

**Verification strategy:**
- Edit an underlying data cell → the chart re-plots (openpyxl regeneration; in a viewer, a manual F9/refresh matches).
- Label audit: title + axis titles + legend all present; a chart readable with the sheet hidden.

**Traps & worth knowing:**
- Chart engine differences between Excel and LibreOffice (Task 4's acceptance) — simple charts travel better than exotic ones.
- A "screenshot of a chart" pasted as an image is not a chart — it's a fossil. Refuse it in deliverables.

---

## Task 2 — The dashboard cover

**Thinking path:**
- Five-not-fifty is a *decision* filter: a number earns the cover if a change in it **moves an ops decision** that day (RPC%, PTP%, cure, utilization, one portfolio state view). The "so what" line under the worst number is the pivot between "reporting" and "decision support".
- The period selector is a single defining cell; every headline is a *formula* that reads off it (via the pack's data sheet, indirectly). A sheet that hardcodes a period silently falls out of sync — same producer/consumer law from medium, now at the *whole-pack* scale.
- RAG treatment from the documented targets: a cover that lands all-green is a boring good day; the amber/red cell is the one the exec asks about first — annotate it.

**Verification strategy:**
- Change the period selector → all five headline cells move together; none stays stale (the pack-wide live check).
- The cover reads in ≤10 seconds: title, period, five big numbers, legend/target line, one "so what".

**Traps & worth knowing:**
- Merged multi-row title blocks can break a clean selection-copy; keep the skyline cells simple and individually selectable.
- A formula chain too deep (period → 4 hops → headline) becomes un-debuggable; cap hops and put the chain in a named range for auditability.

---

## Task 3 — The self-auditing pack

**Thinking path:**
- The checks tab builds the audit table: | metric | workbook | view | delta | tolerance | PASS/FAIL |. The view values come from the DB (`v_daily_mis` etc.) — the same cross-track audit you've been running in SQL/Python, now *materialized inside the deliverable*.
- Tolerance is a *contract*: rates get a percentage tolerance, counts exact-or-tight; printed per row, every row. A bare PASS without a stated tolerance is theater; a FAIL with a root-cause line is an audit.
- A FAIL's root cause is the real product: definitional (denominator), filter (channel/status), or formatting (a `0.35` displayed as `35%` won't read as equal to an integer-pct view with naive delta). Diagnose, don't silence.

**Verification strategy:**
- Every headline cell has a Checks row; every row sums to a verdict; the verdict column reads top-to-bottom.
- Re-running the pack (fresh DB pull) leaves the same verdicts — the audit is *reproducible*, not editorial.

**Traps & worth knowing:**
- Comparing a formatted cell (display) vs its raw value (reality) is a classic delta surprise — always delta on raw values, present the formatted display separately.
- A view whose filter (month window) differs from your workbook's period is a *definition mismatch*, not a bug — still a root-cause line.

---

## Task 4 — Validation, polish, hardened

**Thinking path:**
- Data validation (a dropdown of the 12 real month-values) bounds *inputs*; an error dialog that explains itself is a UX nicety that prevents week-of-lost-period mistakes. Restrict *stable selectors*, not free-text notes (restriction is ergonomics, not straitjacketing).
- The red-triangle sweep: reopen and find every `#REF!`, `#DIV/0!`, `#N/A`, or stale style clash; fix or justify in a note. A pack promising self-audit can't ship with diagnostic cannons still smoking.
- Two-reader acceptance (Excel + LibreOffice) tests *format dialect* (some conditional-formatting or chart features render differently), *font fallbacks*, and chart parity. Tolerate cosmetic differences you can name (e.g., a CF rule shading) — but *not* semantic ones (a formula that computes differently is a pack bug).

**Verification strategy:**
- Open in both readers: no formula shows `#VALUE!`/`#NAME?` (a function one reader lacks or names differently is the #1 cross-dialect casualty), chart categories match, RAG still colors.
- Re-run the hard fixes (validation rule, dried-up formulas) through the generator — resetting is part of the pipeline, not an exception.

**Traps & worth knowing:**
- Font fallback silently swaps a font a reader lacks — a file designed around a company-font can render off-brand elsewhere; weigh the trade-off consciously.
- Validation added only in the *writer* run won't survive a pandas `to_excel` overwrite of the same range — re-apply validation in the regeneration script, not by hand.