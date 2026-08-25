# Power BI Advanced — Results (worked solutions)

Senior-level patterns — rebuild, then diff behavior under slicers and identities. No outputs; your screenshots and logs are the evidence.

---

## Task 1 — SVG sparkline card

```dax
RPC Trend Sparkline =
VAR Months =
    ADDCOLUMNS (
        VALUES ( dim_calendar[month_num] ),
        "v", [RPC %]
    )
VAR MaxV = MAXX ( Months, [v] )
VAR BarW = 18
VAR Gap = 4
VAR Bars =
    CONCATENATEX (
        FILTER ( Months, NOT ISBLANK ( [v] ) ),
        VAR i  = RANKX ( Months, [month_num], , ASC ) - 1
        VAR h  = ROUND ( DIVIDE ( [v], MaxV ) * 28, 0 )
        VAR x  = i * ( BarW + Gap )
        RETURN
            "<rect x='" & x & "' y='" & ( 30 - h )
            & "' width='" & BarW & "' height='" & h
            & "' fill='#262A76'/>"
        , "" )
RETURN
IF (
    COUNTROWS ( Months ) >= 2 && LEN ( Bars ) > 0,
    "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='"
        & ( COUNTROWS(Months) * (BarW + Gap) ) & "' height='32'><rect width='100%' height='100%' fill='white'/>"
        & Bars & "</svg>"
)
```

Set: Measure tools → Data category → **Image URL**. Place in a card visual (or HTML-capable custom visual if policy allows — this pattern needs none).

**Why each part:** `CONCATENATEX` builds the SVG body one `<rect>` per month; bar height scales against the max so the picture is relative, which is what trends mean. The `IF(COUNTROWS>=2)` guard keeps single-month contexts blank instead of a broken image.

**Verify yourself:** slice to one team then another — bars re-rank shape. Slice to a single month → blank (by design). Change a month's RPC% in SQL? Not possible here — instead cross-check two adjacent bars' relative heights against the medium-level monthly chart.

**Traps & alternatives:** SVG text needs single quotes inside the URL — mixing quote styles is the classic render-blank bug. Keep the palette hex from the theme so cards match Task 4's standard.

---

## Task 2 — Row-level security via the supervisor map

Model:
1. Import `v_rls_supervisor_map` as `RLS Map`. Power Query: add column `Email = Text.Lower([supervisor_id]) & "@collections.test"` (convention documented in the standard doc).
2. Relationship: `RLS Map[agent_id]` → `dim_employees[agent_id]`, single direction dim→dim is fine; enable **Apply security filter in both directions** on it so filters flow from map into employees and onward into facts.

Role creation (Modeling → Manage Roles):

```dax
-- Role: Supervisor
-- Filter on 'RLS Map':
[Email] = USERPRINCIPALNAME ()
```

Testing: View As → Other user → `sup01@collections.test`, role Supervisor. Walk every page INCLUDING drillthrough; screenshot each.

**Why each part:** mapping-table RLS survives staff changes — grant access by adding a row, not editing roles. Both-direction filter application is required because facts relate to `dim_employees`, not to the map.

**Verify yourself:** test log rows: identity × page × visible-teams expectation × pass/fail. Negative test matters most: sup01 must see ZERO rows of Team 5's agents anywhere, including the roll-rate matrix and drillthrough detail pages.

**Traps & alternatives:** hardcoding `[team_name] = "Team 3"` in roles breaks on reorgs and fails audits. LOOKUPVALUE-based dynamic RLS on `USERPRINCIPALNAME()` directly against `dim_employees` also works when email lives there — we route through the shipped view because that's the project's contract.

---

## Task 3 — Honest trend lines

Built-in: select line chart → Analytics pane → Trend line → Exponential smoothing. Document in the page note: it smooths seasonality away and extrapolates forward — assumptions belong on-screen per governance.

DAX-controlled linear trend:

```dax
RPC Linear Trend =
VAR Known =
    FILTER (
        ALLSELECTED ( dim_calendar[date] ),
        NOT ISBLANK ( CALCULATE ( [RPC %] ) )
    )
VAR SlopeIntercept =
    LINESTX ( Known, CALCULATE ( [RPC %] ), dim_calendar[date] )
VAR Slope    = SELECTCOLUMNS ( SlopeIntercept, [Slope] )
VAR Intercept= SELECTCOLUMNS ( SlopeIntercept, [Intercept] )
VAR CurrentDate = MAX ( dim_calendar[date] )
RETURN DIVIDE ( SUMX ( Known, Intercept + Slope * ( CurrentDate - MINX ( Known, dim_calendar[date] ) ) ),
                COUNTROWS ( Known ) )
```

Simpler equivalent many models ship:

```dax
RPC Trend Line =
VAR Known = FILTER ( ALLSELECTED ( dim_calendar[month_num] ), NOT ISBLANK ( [RPC %] ) )
VAR sx = SUMX ( Known, dim_calendar[month_num] )
VAR sy = SUMX ( Known, [RPC %] )
VAR sxx = SUMX ( Known, dim_calendar[month_num] ^ 2 )
VAR sxy = SUMX ( Known, dim_calendar[month_num] * [RPC %] )
VAR n   = COUNTROWS ( Known )
VAR slope = DIVIDE ( n * sxy - sx * sy, n * sxx - sx ^ 2 )
VAR intercept = DIVIDE ( sy - slope * sx, n )
RETURN intercept + slope * MAX ( dim_calendar[month_num] )
```

Plot both measures plus actuals as lines on the same chart.

**Why each part:** least-squares over the SELECTED window only (`ALLSELECTED`) — slicing to H2 retrends honestly within that scope. The analytics pane is faster but opaque; shipping both with a note is the transparency standard.

**Verify yourself:** backtest comment — hide the last month from Known conceptually by slicing to earlier months, read each method's implied next value, compare to what actually happened; write one sentence on trust. Direction of slopes must agree between methods; magnitude may not.

**Traps & alternatives:** LINESTX returns a TABLE — wrap columns out via SELECTCOLUMNS (as shown). Never let a trend measure silently include blank months: the `FILTER(NOT ISBLANK)` guard is the honesty clause.

---

## Task 4 — Report governance: theme + template + standard

Theme (`collections_theme.json`, based on project palette #262A76):

```json
{
  "name": "Collections MIS Theme",
  "dataColors": ["#262A76", "#1A60B0", "#00B050", "#FFC000", "#FF0000", "#7F7F7F"],
  "background": "#FFFFFF",
  "foreground": "#262A76",
  "tableAccent": "#262A76",
  "visualStyles": {
    "*": { "*": {
      "title": [{ "fontSize": 12, "bold": true, "fontColor": "#262A76" }],
      "labels": [{ "fontSize": 10 }]
    }},
    "card": { "*": { "labels": [{ "fontSize": 24 }] } }
  }
}
```

Template PBIX checklist (bake in once):
- `_Measures` table exists and is EMPTY by convention (measures never live on fact tables)
- All key columns hidden; `dim_calendar` marked as date table; auto date/time OFF
- Exemplar measures included meeting the naming standard: `[<Metric>]`, `[<Metric> PM]`, `[<Metric> Color]`
- Every measure has a description; RAG bounds referenced from `Dim_Targets`, never inline literals beyond the color hexes

Standard doc skeleton (≤1 page): measure naming pattern · description mandatory · thresholds live in Dim_Targets · RAG hexes fixed (#00B050/#FFC000/#FF0000) · every page footer states filter behavior · drillthrough tested per release.

**Verify yourself:** apply theme to a messy test page — fonts/colors snap everywhere without manual edits. Hand the standard to a colleague cold: if they ask a question the doc should have answered, the doc isn't done.

---

## Task 5 — Model performance hygiene

Checklist (becomes the reusable doc):

1. File options → Data Load → Auto date/time OFF (before importing anything).
2. Power Query on each fact: remove columns no measure, relationship, or axis uses (e.g., free-text descriptions); set data types explicitly at source step.
3. Dimensions: hide keys; verify no unused attributes linger in report view.
4. Refresh: Import scheduled via gateway/service — document cadence matching MIS deadlines (the JD's automation requirement).
5. Re-measure after changes: file size before vs after; subjective slicer latency note.

Typical wins on this model: auto date/time artifacts removal is often the single biggest shrink; dropping unused wide-text columns from the 1.3M-row fact follows.

**Verify yourself:** before/after numbers recorded in `work/performance_notes.md`. Spot-check list executed: headline cards, one matrix, drillthrough, RLS View-As — nothing user-facing changed.

**Traps & alternatives:** don't prune a column just because today's report ignores it — prune against the DASHBOARD SPEC (blueprint), not current visuals; note borderline calls in the doc. Performance work without a written before/after is opinion, not governance.
