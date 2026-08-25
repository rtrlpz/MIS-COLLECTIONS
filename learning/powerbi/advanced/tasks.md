# Power BI Advanced — Your Inbox (level 3 of 3)

```
You are here: learning/powerbi/advanced/
Assumed:      medium/ complete — TI measures, RAG-by-measure, drillthrough all warm
Solutions:    advanced/results.md — after a serious attempt; then REBUILD and DIFF
Theme:        the senior layer — custom visuals in DAX, security, forecasting,
              governance, and model performance
```

**What this level gives you.** The capabilities that separate a report builder from the MIS analyst who owns the platform: DAX-drawn visuals, row-level security that survives an audit, honest trend lines, and the standards doc that keeps the next ten reports consistent.

---

## Task 1 — SVG indicator cards drawn in DAX
📥 **Inbox:** From Head of MIS · Tue 10:00 · "make the exec page feel designed"

> "Our KPI cards are flat numbers. I've seen dashboards where the trend sparkline is DRAWN BY A MEASURE — no extra visuals, scales with filters. Build one for monthly RPC%: mini bars per month inside a single card visual."

**Your job:**
1. Write a measure returning an SVG data URL: one bar per month, height ∝ RPC%.
2. Set the measure's Data category to Image URL; drop it into a card/image-capable visual.
3. Keep it blank-safe when fewer than two months are in context.

**Done when:**
- [ ] Sparkline renders and CHANGES with slicers
- [ ] No external images or custom visuals installed
- [ ] Code commented well enough that a colleague can change bar count

---

## Task 2 — Row-level security supervisors can't peek past
📥 **Inbox:** From Security Officer · Wed 9:00 · "go-live blocker, non-negotiable"

> "Each supervisor sees ONLY their teams' data. The project ships `v_rls_supervisor_map` for exactly this. Design the role(s), wire the mapping, TEST as each supervisor identity, and hand me a one-page test log. If any supervisor can see another team's agents anywhere in the model — including drillthrough — it fails."

**Your job:**
1. Import the mapping view; add an email convention column (e.g., supervisor_id → sup01@collections.test).
2. Create role(s) with filter expressions; ensure filters flow to EVERY fact-bearing path.
3. View As each test identity; document results per page.

**Done when:**
- [ ] Role expressions use the mapping table, not hardcoded names
- [ ] View-As screenshots for ≥2 identities across all pages
- [ ] Test log covers drillthrough + hidden pages

---

## Task 3 — Honest trend lines & forecasts
📥 **Inbox:** From Portfolio Manager · Thu 1:00 · "is RPC% really improving or is it noise?"

> "Add a trend line to the monthly RPC% chart — either the built-in analytics pane done RIGHT (explain its assumptions) or a DAX regression line you fully control. Then tell me what January's forecast would have said, and how much you'd trust it."

**Your job:**
1. Implement BOTH: analytics-pane exponential smoothing AND a DAX linear-trend measure.
2. Compare their stories on the same chart.
3. Written verdict: which goes in the exec pack and why.

**Done when:**
- [ ] Both lines coexist on the monthly chart
- [ ] One-paragraph methodology note (assumptions + limits)
- [ ] Forecast-vs-actual backtest comment

---

## Task 4 — Report governance: make the next ten reports consistent
📥 **Inbox:** From Head of MIS · Mon 8:30 · "governance initiative phase 2 — yours"

> "Standardize: one theme file, one measure-naming convention, one rule for where measures live, descriptions mandatory. Deliver the theme JSON wired into a template PBIX plus a written standard a new analyst follows without asking questions."

**Your job:**
1. Author/curate a theme JSON (project palette: primary #262A76 family) — fonts, data colors, card styles.
2. Template PBIX: `_Measures` table, hidden keys, naming conventions baked into example measures.
3. One-page standard doc: naming pattern, description requirement, RAG thresholds source-of-truth pointer.

**Done when:**
- [ ] Theme applies cleanly to any page
- [ ] Template contains exemplar measures meeting the standard
- [ ] Standard doc ≤1 page and actually specific

---

## Task 5 — Model performance: make refresh and slicing fast
📥 **Inbox:** From MIS Manager · Fri 3:00 · "the file is getting heavy"

> "Before this grows: disable everything Power BI silently generates that we don't need, prune unused columns from the big fact, document before/after size. I want the hygiene checklist we run on EVERY new model from now on."

**Your job:**
1. Kill auto date/time artifacts (file level); remove built-in date hierarchies.
2. In Power Query: drop columns no measure/relationship uses from `fact_interactions`; correct data types at source.
3. Measure .pbix size + a subjective slicer-speed note before/after; write the reusable checklist.

**Done when:**
- [ ] Before/after sizes recorded
- [ ] Checklist doc exists and names every step
- [ ] Nothing user-facing broke (visual spot-check list)

---

## Finish

You now own the senior toolkit: DAX-drawn visuals, auditable security, defensible trends, enforceable standards, and models that stay fast. The production dashboard (Phase 9 of the main project) is this track at scale — go read its blueprint and recognize everything.
