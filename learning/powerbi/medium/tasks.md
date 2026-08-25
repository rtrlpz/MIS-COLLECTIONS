# Power BI Medium — Your Inbox (level 2 of 3)

```
You are here: learning/powerbi/medium/
Assumed:      basic/ complete — marked date table, _Measures table, safe-divide habits
Solutions:    medium/results.md — after attempting; then REBUILD and DIFF against your attempt
New tools:    TOTALMTD/YTD family, CALCULATE modifiers, field-value conditional formatting,
              matrix visuals that read like a migration matrix, drillthrough
```

**What this level gives you.** The middle of the analyst's dashboard work: numbers that move correctly through time, targets with RAG colors a director reads in two seconds, a roll-rate matrix risk teams actually use, and a drillthrough page for the "why is THIS agent red?" conversation.

---

## Task 1 — Time intelligence: MTD, YTD, previous month
📥 **Inbox:** From MIS Manager · Mon 9:00 · "the exec pack needs running totals"

> "Add interactions and RPC% as month-to-date, year-to-date, and versus-previous-month. Our production model uses a calculation group for this — build the explicit measures first so you understand what the calc group automates."

**Your job:**
1. `Interactions MTD`, `Interactions YTD` using the TOTAL* family on the marked date table.
2. `RPC % PM` (previous calendar month) with the standard time-shift pattern.
3. Comment each: what happens if someone drops a visual on a non-date axis?

**Done when:**
- [ ] Three measures working off the marked date table only
- [ ] A line chart shows MTD resetting each month
- [ ] Note written: where the `_Time Intelligence` calculation group replaces these

---

## Task 2 — Targets vs actuals
📥 **Inbox:** From Operations Manager · Wed 11:00 · "board asks 'against target' constantly"

> "Give me actual RPC% next to its target with the gap, driven by ONE target table — when strategy changes the number, I edit a row, not twelve measures."

**Your job:**
1. Build a small targets table (goal name, target value) via Enter Data or DAX `DATATABLE`.
2. Measures: selected goal's target, actual-vs-target gap.
3. Table visual: metric name, actual, target, gap — one row per KPI.

**Done when:**
- [ ] Target lives in data, not hardcoded inside measures
- [ ] Changing a target row flows through without touching DAX

---

## Task 3 — RAG colors managers can scan
📥 **Inbox:** From Site Director · Thu 4:00 PM · "I read this page in ten seconds"

> "Color-code the KPI table: green/amber/red per our thresholds. Colors must come from MEASURES, not manual formatting rules — the thresholds will move."

**Your job:**
1. Per-KPI color measure returning hex codes (green #00B050 / amber #FFC000 / red #FF0000).
2. Apply via conditional formatting → Background color → Field value.
3. Thresholds documented in measure comments.

**Done when:**
- [ ] Colors change when data changes (tested by slicing)
- [ ] No manual cell-by-cell rules anywhere
- [ ] Hex values match project RAG standards

---

## Task 4 — The roll-rate matrix risk teams actually read
📥 **Inbox:** From Credit Risk Director · Tue 2:00 · "board pack page"

> "Month-over-month bucket migrations as a matrix: from-bucket rows, to-bucket columns, account counts in cells, buckets ordered by severity — Current down to 90+. Worsening moves should jump out visually."

**Your job:**
1. Import `v_dpd_migration_matrix` output (or rebuild equivalent in Power Query from snapshots).
2. Add a bucket-order dimension so rows/columns sort Current→90+, never alphabetically.
3. Matrix: from × to × count; conditional formatting emphasizing below-diagonal (worsened) cells.

**Done when:**
- [ ] Severity ordering on both axes
- [ ] Diagonal = stable reads instantly; worsening cells pop
- [ ] Counts reconcile against SQL `v_dpd_migration_matrix`

---

## Task 5 — Drillthrough: the "why is this agent red" page
📥 **Inbox:** From Supervisor, Team 3 · Fri 10:30 · "coaching prep"

> "On any agent row I want to right-click → drill through to a detail page: that agent's monthly trend, channel split, and promise outcomes. It must respect whatever filters I drilled with."

**Your job:**
1. Build the detail page; add agent to drillthrough well.
2. Include a back button; verify filters carry.
3. Test from every source visual.

**Done when:**
- [ ] Right-click → Drill through works from all agent-level visuals
- [ ] Page shows ONLY the drilled agent
- [ ] Back button returns intact

---

## Task 6 — Titles that update themselves
📥 **Inbox:** From MIS Manager · Mon 3:30 · "screenshots keep lying about scope"

> "Page titles must reflect active slicers — 'RPC% by Team — March 2025' when March is picked, generic otherwise. SELECTEDVALUE, not concatenated chaos."

**Your job:**
1. Title measures returning dynamic strings for month/team context.
2. Wire into card/chart titles via Field value.
3. Handle the nothing-selected case gracefully.

**Done when:**
- [ ] Titles change with slicer state
- [ ] No-selection default text is sensible
- [ ] No title shows '(Blank)'

---

## Finish

Six patterns saved — time, targets, color, matrix, drillthrough, titles. These are the building blocks of the production dashboard's pages. [`../advanced/tasks.md`](../advanced/tasks.md): SVG cards, real RLS, and governance.
