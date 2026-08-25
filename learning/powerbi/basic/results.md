# Power BI Basic — Results (worked solutions)

Rebuild each solution in your own attempt file — muscle memory is the deliverable. No outputs are shown; your screenshots ARE the check.

---

## Task 1 — The model mirrors the schema

**Model steps:**
1. Get Data → PostgreSQL database → `localhost:5433`, database `MSI_CollectionsDB`, Import mode, Database credentials from `.env` (never saved into the file's data source cloud settings).
2. Select only the six tables named in the task (navigator checkboxes) — resist importing everything on day one.
3. Model view: confirm Power BI auto-detected one-to-many from each dim key to `fact_interactions`. Fix any many-to-many or "guessed" relationship by deleting it and dragging the correct key pair:
   - `dim_employees[agent_id]` → `fact_interactions[agent_id]`
   - `dim_accounts[account_id]` → `fact_interactions[account_id]`
   - `dim_calendar[date]` → `fact_interactions[interaction_date]`
   - `dim_clients[client_id]` → `dim_accounts[client_id]`
   - `dim_products[product_id]` → `dim_accounts[product_id]`
4. Right-click every `_id`/`_key` column → Hide in report view.

**Why:** import mode mirrors the project's production model; single-direction dim→fact keeps filters flowing the way SQL joins think. Hiding keys stops report authors building nonsense on raw IDs.

**Verify yourself:** Model view screenshot shows a clean star. Cross-filter any dim slicer — row counts change, no relationship warnings appear.

**Traps & alternatives:** Power BI sometimes proposes a relationship on name-similar columns (`product_type` vs `product_id`) — delete and rebuild deliberately.

---

## Task 2 — First measures

Create an empty table first: Enter Data → name it `_Measures` → Load (it exists only to house measures).

```dax
Total Interactions = COUNTROWS ( fact_interactions )

Connected Calls =
SUM ( fact_interactions[calls_connected] )

RPC Count =
CALCULATE ( COUNTROWS ( fact_interactions ), fact_interactions[rpc_flag] = TRUE () )

RPC % =
DIVIDE ( [RPC Count], [Connected Calls] )
```

Format: `RPC %` as percent, 1 decimal. Descriptions: e.g., RPC % → "Right-party contacts ÷ connected calls. Matches v_contact_metrics."

**Why each part:** `COUNTROWS` beats `COUNT(column)` for PK grain truth. The boolean filter with `TRUE()` literal matches the project's DAX house style. `DIVIDE` is the safe-divide pattern — blank denominator yields BLANK, never an error or infinity.

**Verify yourself:** drop a card per measure with NO slicers; then slice by a quiet team/month combo where connects ≈ 0 — `RPC %` must show blank, not an error glyph. Final gate: compare against SQL `v_contact_metrics` for one month — equal within rounding.

**Traps & alternatives:** a calculated column `rpc_pct = rpc/connected` per ROW then averaging it anywhere is the average-of-averages trap from your SQL track — measures compute at query time over the filtered model, which is why they survive slicing.

---

## Task 3 — One honest page

- Cards: `[Total Interactions]`, `[Connected Calls]`, `[RPC Count]`.
- Line chart: X `dim_calendar[month_name]` (sorted by month_num — Task 5 fixes this if you skipped ahead), Y `[Total Interactions]`.
- Bar: Y axis team names, X `[RPC %]`, sort descending by value.

**Titles that state the claim:** "Monthly Interactions", "RPC % by Team (2025)".

**Verify yourself:** the read-aloud test — point at each visual and say its one sentence out loud. If a sentence needs "and also", split the visual.

---

## Task 4 — Formatting pass

Set once, reuse: View ribbon → Themes are coming in advanced; for now set per visual: display units Thousands/Auto, decimals consistent (0 for counts, 1 for %), font sizes Title 12 / labels 10 minimum. Alignment: Format → General → Position/X,Y snapped to a grid you keep for all pages.

**Verify yourself:** export → PNG at 1920 width. If you squint at row two, increase size — projector test passed means readable at 55-inch distance.

---

## Task 5 — Mark the date table

1. File → Options → Current File → Data Load → **uncheck** Auto date/time (kills hidden calendar tables bloat).
2. Table tools → Mark as date table → `dim_calendar[date]`.

Month ordering: select `month_name` column → Column tools → Sort by column → `month_num`. Same for weekday names by their number.

**Why:** without marking, TOTALMTD/YTD in medium level silently misbehave; auto date/time quietly builds hidden date tables per date column and doubles model size.

**Verify yourself:** matrix of `month_name` + any measure lists Jan…Dec in order. Options dialog screenshot saved showing auto date/time off.

---

## Task 6 — Slicer hygiene

Slicers: year (dropdown), month (dropdown, **Single select** ON in format pane → Selection), team (list). Edit interactions: cards ← month slicer ON, team slicer OFF (headline numbers stay whole-company); trend ← both ON.

Footer note text box: "Team slicer does not affect headline cards by design."

**Verify yourself:** multi-click months — impossible now; click a team — cards unchanged, bar highlights itself. That asymmetry is the documented choice, not a bug.
