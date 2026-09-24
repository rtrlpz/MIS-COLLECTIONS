# Excel Medium — Your Inbox (level 2 of 3)

```
You are here: learning/excel/medium/
Assumed:      basic/ complete — shell script, lookups, pivots all warm
Solutions:    medium/results.md — full openpyxl scripts + manual steps; run, OPEN, and diff against your attempt
Theme:        self-updating packs — formula-driven RAG, refreshable data, dashboard sheet,
               protection, and the change log that keeps versions honest
```

**How to work through this level.** Phase A (Tasks 1–5) is Excel-native: you build and manipulate the workbook **in Excel/LibreOffice** — pivot tables created by clicking, SUMIFS typed manually, conditional formatting rules set in dialogs, Power Query configured via the UI, slicers placed by hand. Phase B (Tasks 6–9) teaches you to automate everything with openpyxl and VBA.

---

## ═══ PHASE A — Excel-Native Skills ═══

*These tasks teach you to USE Excel for real MIS work. Every formula, every pivot, every rule is done with the mouse and keyboard.*

---

## Task 1 — One producer, many consumers (manual pivot from Data)

📥 **Inbox:** From MIS Manager · Mon 9:00 · "stop emailing six different files"

> "Restructure: a `Data` sheet holds the raw daily table (from your loader), consumer sheets reference it via structured formulas. When June's numbers correct themselves, every downstream sheet updates without touching them."

**Your job (Excel first):**
1. Create a `Data` sheet. Paste your daily × team aggregation (or import from CSV).
2. **Convert to an Excel Table:** select the range → **Insert → Table** (Ctrl+T). Name it `tblDaily`.
3. On a new sheet `Summary`, type `=SUM(tblDaily[Contacts])` — a structured reference.
4. **Create a PivotTable** from `tblDaily` on a third sheet. Rows = Month, Values = SUM of all KPIs.
5. Edit one Data cell → confirm Summary formulas and the PivotTable both update.
6. **Add rows** below the table → confirm the Table auto-expands and the Pivot picks them up.
7. *Then* read results.md for the openpyxl version.

**Done when:**
- [ ] Single Data table as the only place raw values live
- [ ] Consumer sheets use structured references (not copy-paste values)
- [ ] PivotTable auto-expands when data grows
- [ ] Edit one Data cell → consumers recalc

---

## Task 2 — Live formulas: manual SUMIFS rollup

📥 **Inbox:** From Operations Manager · Tue 2:00 · "the summary tab"

> "Summary sheet with SUMIFS-driven monthly totals per KPI from the Data sheet, plus month-over-month delta column. All FORMULAS in cells — python writes structure once, Excel keeps it alive."

**Your job (Excel first):**
1. On the Summary sheet, type month dates down column A (first of each month).
2. **Type the SUMIFS formula by hand** in cell B5:
   ```
   =SUMIFS(tblDaily[Contacts],tblDaily[Date],">="&A5,tblDaily[Date],"<"&EDATE(A5,1))
   ```
3. Repeat for all KPI columns (Connects, RPCs, Promises, Payments).
4. Add RPC% column: `=IFERROR(D5/C5,"")` (RPCs ÷ Connects).
5. Add MoM delta: `=TEXT(D5-D4,"+0;-0;±0")` in column F.
6. **Test it:** nudge one Data value ±100 → confirm month total and delta move.
7. *Then* read results.md for the openpyxl automation version.

**Done when:**
- [ ] SUMIFS/SUMPRODUCT rollup by month working (typed manually)
- [ ] Delta column flags direction
- [ ] Editing one daily value moves the month + delta

---

## Task 3 — RAG at scale: conditional formatting via Excel UI

📥 **Inbox:** From Site Director · Thu 4:00 PM · "ten-second read"

> "RPC% and KP% columns get RAG backgrounds from THRESHOLD FORMULAS (not manual fills). Thresholds live on Parameters so strategy can tune them without asking you."

**Your job (Excel first):**
1. On the Parameters sheet, create threshold cells:
   - E2: `35` (label in D2: "RPC% low amber")
   - E3: `45` (label in D3: "RPC% green")
2. On the Summary sheet, select the RPC% column range (e.g., F5:F20).
3. **Home → Conditional Formatting → New Rule → Format only cells that contain.**
4. Rule 1 (Green): `Cell Value >= $E$3` → fill #00B050
5. Rule 2 (Amber): `Cell Value between $E$2 and $E$3` → fill #FFC000
6. Rule 3 (Red): `Cell Value < $E$2` → fill #FF0000
7. **Test it:** change E3 to 90 → confirm nearly everything turns green/red. Change back → repaints instantly.
8. Note: these rules reference Parameter cells — strategy tunes thresholds ON the Parameters sheet, zero code changes.
9. *Then* read results.md for the openpyxl automation version.

**Done when:**
- [ ] Conditional formatting rules reference Parameter cells (set via Excel UI)
- [ ] Green #00B050 / amber #FFC000 / red #FF0000
- [ ] Moving a threshold repaints instantly

---

## Task 4 — PivotChart + slicer

📥 **Inbox:** From Site Director · Wed 3:00 · "the director wants a visual"

> "Create a visual summary of monthly RPC% trends. Not a static chart — something the director can filter by team and interact with."

**Your job (Excel first):**
1. Create a PivotTable from `tblDaily`: Rows = Month, Values = RPC%, Filters = Team.
2. **Insert → PivotChart** → choose a line chart.
3. Add a **Slicer**: PivotTable Analyze → Insert Slicer → select `Team`.
4. Click different teams in the slicer → the chart updates.
5. Resize and position the pivot, chart, and slicer on a `Dashboard` sheet.
6. **Test:** filter by team → confirm chart reflects only that team's data.
7. Note: how does this compare to a Python-generated chart? Interactive filtering is the key advantage.
8. *Then* read results.md for the openpyxl automation version.

**Done when:**
- [ ] PivotTable + PivotChart created via Excel UI
- [ ] Slicer on Team works and updates chart
- [ ] Dashboard sheet layout clean and navigable

---

## Task 5 — Power Query refresh

📥 **Inbox:** From Ops Lead · Fri 8:30 · "refresh the pack from CSV"

> "The daily pack pulls from a CSV export. Set it up so the analyst just clicks Refresh — no manual import needed."

**Your job (Excel first):**
1. **Data → Get Data → From File → From CSV** → select the daily extract CSV.
2. In the Power Query Editor: promote headers, change date column to Date type, set number formats.
3. Click **Close & Load To → Only Create Connection** → check "Add to Data Model" (for pivots).
4. Create a PivotTable that references the Power Query connection.
5. **Test the refresh:** replace the CSV with updated data → **Data → Refresh All** → confirm pivot updates.
6. Configure automatic refresh on file open (Query Options → Properties → "Refresh every time the file opens").
7. Note: Power Query handles data transformation *before* it hits the sheet — this is different from importing CSV into cells.
8. *Then* read results.md for the openpyxl automation version.

**Done when:**
- [ ] CSV loaded via Power Query (not manual paste)
- [ ] Refresh works and updates the pivot
- [ ] Refresh-on-open configured
- [ ] Notes on Power Query vs manual import written

---

## ═══ PHASE B — Automate with Python & VBA ═══

*These tasks teach you to generate everything you built manually in Phase A using openpyxl, and to automate the workflow with VBA.*

---

## Task 6 — The printed daily: freeze, fit, repeat

📥 **Inbox:** From Ops Lead · Fri 8:30 · "print run at 8:45 sharp"

> "Full pack polish: freeze panes everywhere sensible, print areas set per sheet, fit-to-width, headers repeat. Then export the Daily sheet to PDF programmatically — the 8:45 email attaches it."

**Your job:**
1. Apply page setup to every sheet via openpyxl (as in Basic Task 7).
2. Export to PDF — document the tool used (LibreOffice or COM automation).
3. Print preview screenshots saved.

**Done when:**
- [ ] Every sheet's page setup deliberate
- [ ] PDF exported by script
- [ ] Print preview screenshots saved

---

## Task 7 — Multi-sheet discipline: the small MIS pack

📥 **Inbox:** From MIS Manager · Wed 10:00 · "the weekly shape of things"

> "Formalize the pack: Cover (title/date/owner), Daily, Summary, AgentLookup, Parameters, ChangeLog. Sheet order fixed, tab colors coded (data=blue, governance=gray). A stranger navigates it unaided."

**Your job:**
1. Build the six-sheet structure via openpyxl.
2. Tab colors: `ws.sheet_properties.tabColor = "262A76"` (data), `"808080"` (governance).
3. Cover states owner + generation timestamp (formula off a cell).
4. Navigation note on Cover explaining each tab in one line.

**Done when:**
- [ ] Six sheets in order with color coding
- [ ] Cover has formula-driven timestamp
- [ ] Navigation note present

---

## Task 8 — The change log that saves careers

📥 **Inbox:** From Head of MIS · Fri 3:00 · "audit found three 'versions' of last month's pack"

> "ChangeLog sheet: Date · Author · What changed · Why · Cell range affected. Pre-populate this workbook's history honestly, including mistakes. Going forward NO edit ships without a row here."

**Your job:**
1. Create ChangeLog sheet with columns: Date · Author · Sheet/Range · What changed · Why.
2. Pre-populate with ≥3 real entries (including one fix).
3. Convention documented on Cover.
4. Actually use it for this task's own edits.

**Done when:**
- [ ] Log sheet with ≥3 real entries (including one fix)
- [ ] Convention on Cover
- [ ] Used for this task's edits

---

## Task 9 — The full generator: automated pack

📥 **Inbox:** From Head of MIS · Mon 9:00 · "the flagship deliverable"

> "Write `generate_daily_mis.py`: reads the daily KPI extract (CSV export of `v_daily_mis`), builds the FULL pack — Cover, Daily, Summary, AgentLookup, Parameters, ChangeLog — with every style, SUMIFS formula, RAG rule, pivot-ready data layout, Power Query connection, and print setting applied. One command, zero manual steps."

**Your job:**
1. Assemble everything from Phase A + basic tasks into a single CLI script.
2. Input: CSV path + output xlsx path.
3. All sheets built with Phase A behaviors intact.
4. Fresh run reproduces the workbook byte-stable except timestamps.
5. Add the reconciliation step from Basic Task 9.

**Done when:**
- [ ] Single CLI script: input CSV path + output xlsx path
- [ ] All sheets built with Phase A + basic behaviors
- [ ] Byte-stable reruns except timestamps
- [ ] Reconciliation step included

---

## Finish

The pack now maintains itself and its own history. Phase A taught you to build interactive MIS tools in Excel (pivots, SUMIFS, conditional formatting, Power Query, slicers). Phase B taught you to automate them. Advanced level adds the VBA automation layer: [`../advanced/tasks.md`](../advanced/tasks.md).
