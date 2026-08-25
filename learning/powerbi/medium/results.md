# Power BI Medium — Results (worked solutions)

Rebuild each pattern in your attempt .pbix, then diff behavior — slicer states are your test suite. No outputs shown; screenshots verify.

---

## Task 1 — Time intelligence

```dax
Interactions MTD =
TOTALMTD ( [Total Interactions], dim_calendar[date] )

Interactions YTD =
TOTALYTD ( [Total Interactions], dim_calendar[date] )

RPC % PM =
CALCULATE ( [RPC %], PREVIOUSMONTH ( dim_calendar[date] ) )
```

**Why each part:** the TOTAL* family requires the MARKED date table (basic Task 5) — that's why the prerequisite exists. `PREVIOUSMONTH` inside `CALCULATE` shifts filter context one calendar month; `[RPC %]` re-computes in shifted context because measures are context-aware by design.

**Verify yourself:** MTD line resets at each month boundary; YTD climbs within year and resets at January; `RPC % PM` on a March visual equals plain `[RPC %]` filtered to February (cross-check against SQL for both months). Note for the file: 2025-only data means SAMEPERIODLASTYEAR returns blank — previous-month is the honest comparison here.

**Traps & alternatives:** using the fact's own date column instead of `dim_calendar[date]` silently breaks MTD at month edges. Production replaces all of these with the `_Time Intelligence` calculation group applied as a slicer — you built them explicitly once so the CG is a tool, not magic.

---

## Task 2 — Targets vs actuals

Modeling → New table:

```dax
Dim_Targets =
DATATABLE (
    "Goal", STRING, "Target", DOUBLE,
    {
        { "RPC %", 45 },
        { "PTP %", 80 },
        { "KP %", 80 }
    }
)
```

Measures:

```dax
Selected Target =
VAR g = SELECTEDVALUE ( Dim_Targets[Goal] )
RETURN SWITCH ( g,
    "RPC %", 45,
    "PTP %", 80,
    "KP %", 80,
    BLANK ()
)
```

Simpler, data-driven version (preferred):

```dax
Selected Target = SELECTEDVALUE ( Dim_Targets[Target] )

Actual for Goal =
VAR g = SELECTEDVALUE ( Dim_Targets[Goal] )
RETURN SWITCH ( g,
    "RPC %", [RPC %],
    "PTP %", [PTP %],
    "KP %",  [KP %],
    BLANK ()
)

Gap to Target =
DIVIDE ( [Actual for Goal] - [Selected Target], [Selected Target] )
```

**Why each part:** targets live in a TABLE so a strategy change edits a row, not DAX. `SWITCH` maps goal name → its actual measure; the table visual lists goals with actual/target/gap columns driven purely by selection.

**Verify yourself:** change KP target from 80 to 75 in the table — every gap recomputes with zero DAX edits. Cross-check one month's actuals against SQL views.

**Traps & alternatives:** hardcoding `IF(goal="KP %",[KP %]>=0.80,…)` inside color measures scatters thresholds across five measures — governance violation you'll fix properly in Task 3.

---

## Task 3 — RAG colors

```dax
-- Project RAG standard: Green #00B050 · Amber #FFC000 · Red #FF0000
KP % Color =
VAR kp = [KP %]
RETURN IF ( ISBLANK ( kp ), BLANK (),
    IF ( kp >= 0.80, "#00B050",
        IF ( kp >= 0.60, "#FFC000", "#FF0000" ) ) )

RPC % Color =
VAR r = [RPC %]
RETURN IF ( ISBLANK ( r ), BLANK (),
    IF ( r >= 0.45, "#00B050",
        IF ( r >= 0.35, "#FFC000", "#FF0000" ) ) )
```

Apply: visual → conditional formatting → Background color → Format style **Field value** → pick the measure.

**Why each part:** colors as MEASURES mean thresholds live in reviewed code (with comments), survive refresh, and can later read their bounds FROM `Dim_Targets` — the full governance loop.

**Verify yourself:** slice to a team/month with weak RPC% — cell flips amber/red without touching format rules. Blank-safe: an empty slice shows no fill, not red.

---

## Task 4 — The roll-rate matrix

1. Model: import `v_dpd_migration_matrix` (from/to bucket labels + counts) AND create the ordering dimension via Enter Data:

| Bucket | SortOrder |
|---|---|
| Current | 1 |
| 1-30 | 2 |
| 31-60 | 3 |
| 61-90 | 4 |
| 90+ | 5 |

Relate it to BOTH from_bucket and to_bucket? Power BI allows one active relationship per pair — practical route: keep the view's own label columns for the matrix and set **Sort by column** on each label column using duplicated order columns created in Power Query (merge against the order table twice).

2. Matrix: Rows `from_bucket`, Columns `to_bucket`, Values `SUM(accounts)`.
3. Conditional formatting → Background → Rules: highlight cells where from-rank < to-rank (worsened) — implement rank columns in Power Query so rules compare numbers, not text.

**Why each part:** alphabetical sorting is THE classic migration-matrix failure — severity order must be structural (sort-by columns), never left to default. Below-diagonal highlighting makes deterioration pre-attentive: directors see red before reading numbers.

**Verify yourself:** reconcile total account count against SQL `v_dpd_migration_matrix` for the same months; diagonal should dominate (stability is normal).

---

## Task 5 — Drillthrough page

Build `Agent Detail` page: monthly trend line (`month_name` × `[RPC %]`), channel bar, promise outcomes (kept/broken counts). Visual pane → Drag `dim_employees[agent_name]` into **Add drillthrough fields**. Insert → Buttons → Back.

**Why each part:** the drillthrough well auto-applies the clicked agent as a page filter; the Back button ships free navigation users expect.

**Verify yourself:** right-click any agent bar/table row → Drill through → Agent Detail shows ONLY that agent (check a card); test from every source visual; Back returns with selections intact.

**Traps & alternatives:** forgetting "Maintain filters" options changes what carries over — choose deliberately and note it in the page footer like Task basic-6 taught.

---

## Task 6 — Titles that update themselves

```dax
Page Title RPC =
VAR m = SELECTEDVALUE ( dim_calendar[month_name], "All Months" )
VAR t = SELECTEDVALUE ( dim_employees[team_name], "All Teams" )
RETURN "RPC % by Team — " & t & " — " & m
```

Wire: select visual → Title → fx (Field value) → the measure. Turn OFF auto title.

**Why each part:** `SELECTEDVALUE`'s second argument is the graceful nothing-selected default — no "(Blank)" leaks. Concatenation stays minimal: grain first, scope after.

**Verify yourself:** click March + Team 3 → title updates; clear slicers → falls back cleanly. Screenshot pairs saved.
