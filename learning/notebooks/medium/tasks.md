# Notebooks Medium — Your Inbox (level 2 of 3)

```
You are here: learning/notebooks/medium/
Assumed:      basic/ + python/medium — loaders, pivots, reconciliation all exist
Solutions:    medium/results.md — cell-by-cell; Run All and compare narratives
Theme:        notebooks that ANALYZE, not just display: targets on charts,
              reconciliation stories, heatmaps, parameterization
```

---

## Task 1 — The year in one notebook, honestly loaded
📥 **Inbox:** From MIS Manager · Mon 9:00 · "single-file year analysis"

> "One notebook that builds the full-year interactions frame from monthly folders with your typed loader, prints the memory footprint, and asserts the row-count contract. This becomes the standard first section of every analysis notebook we ship."

**Done when:**
- [ ] Loader cell reusable (function, not inline loop)
- [ ] Memory footprint printed
- [ ] Row-count assert + reference comment

---

## Task 2 — KPI chart with a target line
📥 **Inbox:** From Operations Manager · Wed 3:00 · "managers ask 'against target' in every review"

> "Monthly RPC% line chart with the 45% target drawn as a horizontal reference line; color the below-target markers amber. One glance answers 'who's under'."

**Done when:**
- [ ] Reference line labeled 'target 45%'
- [ ] Below-target points visually distinct
- [ ] Takeaway cell naming the under-target months

---

## Task 3 — Reconciliation story: kept promises
📥 **Inbox:** From Collections Strategy Lead · Thu 10:00 · "walk finance through it"

> "The installment KP% rule confuses everyone. Build a notebook that EXPLAINS it: pick one multi-installment plan as a worked example, show its payment rows accumulating toward the threshold, then show the aggregate invariant (zero kept plans under 95%). Narrative first, code second."

**Done when:**
- [ ] Worked example traced row by row with commentary
- [ ] Aggregate invariant asserted at the end
- [ ] A non-analyst could follow it

---

## Task 4 — Heatmap: channel mix by arm
📥 **Inbox:** From Strategy Analyst · Tue 1:00 PM · "the grid, visualized"

> "Arm × channel share-of-arm as a seaborn heatmap with annotations. Arms ordered Champion → SMS_First → FICO_Priority; cells annotated as percentages."

**Done when:**
- [ ] Severity/program ordering on axes
- [ ] Percent annotations inside cells
- [ ] Takeaway: does each arm's wiring match intent?

---

## Task 5 — Parameterize the notebook
📥 **Inbox:** From MIS Manager · Fri 2:00 · "one notebook, any month"

> "Refactor your best medium notebook so MONTH and TEAM are variables set in ONE tagged parameters cell at top. Changing them reruns the whole story for any slice — this is how we'll automate notebook delivery later."

**Done when:**
- [ ] Single parameters cell drives everything downstream
- [ ] No hardcoded month/team strings anywhere else (grep yourself)
- [ ] Documented how papermill-style execution would consume it

---

## Finish

Five analytical documents. Advanced level turns them into teaching artifacts and forecasts: [`../advanced/tasks.md`](../advanced/tasks.md).
