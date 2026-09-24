# Excel Medium — Results (worked solutions)

**Philosophy:** Phase A tasks are solved FIRST in Excel/LibreOffice manually, then automated with openpyxl. The manual version is the primary skill; the automation version is the efficiency layer.

---

## ═══ PHASE A — Excel-Native Solutions ═══

---

## Task 1 — One producer, many consumers (manual)

### Manual steps (do these in Excel):
1. Create sheet `Data`. Select the daily × team data range.
2. **Insert → Table** (Ctrl+T). In the Table Design ribbon, name it `tblDaily`.
3. On a new sheet `Summary`:
   - Type `=SUM(tblDaily[Contacts])` in B5
   - Type `=SUM(tblDaily[RPCs])` in E5
   - Type `=SUM(tblDaily[Promises])` in F5
4. Create a PivotTable from `tblDaily` on a third sheet `PivotView`:
   - Rows = Month, Values = SUM(Contacts), SUM(RPCs), SUM(Promises)
5. **Add rows below the table** in Data → confirm Table auto-expands → confirm Pivot picks up new rows.
6. **Edit one Data cell** → confirm Summary formulas and Pivot both update.

**Why each step:** a real Excel Table gives structured references (`tblDaily[RPCs]`) that survive row growth — consumer formulas never need range surgery. Pivots give the interactive summary that formulas can't match for exploration.

**Verify yourself:** add a dummy row under the table in Excel → it auto-joins and downstream moves. Delete the dummy → re-verify.

### Automation equivalent (openpyxl):
```python
from openpyxl.worksheet.table import Table, TableStyleInfo

ws_d = wb.create_sheet("Data")
ws_d.append(["Date", "Team", "Contacts", "Connects", "RPCs", "Promises", "Payments"])
for _, r in data_df.iterrows():
    ws_d.append(list(r))
tbl = Table(displayName="tblDaily", ref=f"A4:G{4+len(data_df)}")
tbl.tableStyleInfo = TableStyleInfo(name="TableStyleMedium2", showRowStripes=True)
ws_d.add_table(tbl)
```

---

## Task 2 — Manual SUMIFS rollup

### Manual steps (do this in Excel):
1. On Summary sheet, type month dates in A5:A16 (first of each month, as real dates).
2. **Type this formula in B5** (contacts):
   ```
   =SUMIFS(tblDaily[Contacts],tblDaily[Date],">="&A5,tblDaily[Date],"<"&EDATE(A5,1))
   ```
3. Copy across for all KPI columns (Connects, RPCs, Promises, Payments).
4. RPC% in E5: `=IFERROR(D5/C5,"")`
5. MoM delta in F6: `=TEXT(D6-D5,"+0;-0;±0")`
6. **Test:** nudge one Data value → confirm month total and delta move.

**Why each part:** SUMIFS bounded by `EDATE` month windows reads naturally AND handles partial months. The Δ uses TEXT's "+0;-0;±0" format for sign-aware display without helper columns.

**Verify yourself:** nudge one Data value ±100 → month total and delta move; check against a hand count.

### Automation equivalent (openpyxl):
```python
ws_s = wb.create_sheet("Summary")
for r, mrow in enumerate(month_rows, start=5):
    ws_s.cell(row=r, column=2,
        value=f'=SUMIFS(tblDaily[Contacts],tblDaily[Date],">="&A{r},tblDaily[Date],"<"&EDATE(A{r},1))')
    # ...repeat per KPI column...
    ws_s.cell(row=r, column=5, value=f'=IFERROR(D{r}/C{r},"")')
    if r > 5:
        ws_s.cell(row=r, column=6, value=f'=TEXT(D{r}-D{r-1},"+0;-0;±0")')
```

---

## Task 3 — RAG via Excel UI conditional formatting

### Manual steps (do this in Excel):
1. On Parameters sheet: E2 = `35`, D2 = "RPC% low amber"; E3 = `45`, D3 = "RPC% green"
2. On Summary sheet, select F5:F20 (RPC% column)
3. **Home → Conditional Formatting → New Rule → Use a formula**
4. Green rule: formula `=$E$3>=F5` → fill #00B050, font white
5. Amber rule: formula `=AND(F5>=$E$2,F5<$E$3)` → fill #FFC000
6. Red rule: formula `=F5<$E$2` → fill #FF0000
7. **Test:** change E3 to 90 → confirm repaints instantly. Change E2 to 80 → confirm red shifts.

**Why each part:** rules point at `$E$2/$E$3` — strategy tunes thresholds ON the Parameters sheet; zero code changes, instant repaint. Hexes match the project RAG standard.

**Verify yourself:** set E3 to 90 → nearly everything shifts; restore. Screenshot before/after saved.

### Automation equivalent (openpyxl):
```python
from openpyxl.formatting.rule import CellIsRule
from openpyxl.styles import PatternFill

rng = f"F5:F{4+len(data_df)}"
ws_s.conditional_formatting.add(rng, CellIsRule(
    operator="greaterThanOrEqual", formula=["$E$3"],
    fill=PatternFill("solid", fgColor="00B050")))
ws_s.conditional_formatting.add(rng, CellIsRule(
    operator="between", formula=["$E$2", "$E$3"],
    fill=PatternFill("solid", fgColor="FFC000")))
ws_s.conditional_formatting.add(rng, CellIsRule(
    operator="lessThan", formula=["$E$2"],
    fill=PatternFill("solid", fgColor="FF0000")))
```

---

## Task 4 — PivotChart + slicer (manual)

### Manual steps (do this in Excel):
1. Select `tblDaily` range → **Insert → PivotTable** → new sheet `PivotChart`.
2. Rows = Month, Values = RPC%, Filters = Team.
3. Click inside the PivotTable → **Insert → Line Chart** (or PivotChart).
4. **PivotTable Analyze → Insert Slicer** → select `Team`.
5. Position PivotTable, Chart, and Slicer on the `Dashboard` sheet.
6. Click different teams in the slicer → confirm chart updates.

**Why each part:** the PivotChart + Slicer combination gives the director an interactive view that no Python-generated static chart can match. The slicer filters multiple pivots/charts simultaneously if they share the same pivot cache.

**Verify yourself:** select a team in the slicer → confirm chart reflects only that team. Resize — confirm layout holds.

---

## Task 5 — Power Query refresh (manual)

### Manual steps (do this in Excel):
1. **Data → Get Data → From File → From CSV** → select the daily extract CSV.
2. In Power Query Editor:
   - Promote first row to headers
   - Select date column → Transform → Data Type → Date
   - Select count columns → Data Type → Whole Number
   - Click **Close & Load To → Only Create Connection** → check "Add to Data Model"
3. Create a PivotTable: **Insert → PivotTable** → choose "Use this workbook's Data Model"
4. Build the pivot from the Power Query connection.
5. **Test refresh:** replace the CSV → **Data → Refresh All** → confirm pivot updates.
6. Configure auto-refresh: **Data → Queries & Connections** → right-click query → Properties → "Refresh every time the file opens"

**Why each part:** Power Query handles data transformation *before* it hits the sheet — type casting, filtering, merging. This is fundamentally different from importing CSV into cells. The "Refresh on open" setting means the analyst never touches raw data again.

**Verify yourself:** replace the CSV with updated data → Refresh All → pivot should show new numbers. Check "Refresh on open" works by closing and reopening.

### Automation equivalent (openpyxl):
openpyxl **cannot create or manage Power Query connections**. The automation approach generates the output file that the Power Query refresh runs on. Document the flow: generator produces the Data sheet → Power Query reads it → refresh updates pivots.

---

## ═══ PHASE B — Automation Solutions ═══

---

## Task 6 — Print polish + PDF export

```python
# All sheets page setup
for ws in wb.worksheets:
    ws.page_setup.orientation = "landscape"
    ws.page_setup.fitToWidth = 1
    ws.page_setup.fitToHeight = 0
    ws.sheet_properties.pageSetUpPr.fitToPage = True
    ws.print_title_rows = "4:4"

# PDF export via LibreOffice
import subprocess
subprocess.run(["soffice", "--headless", "--convert-to", "pdf", "--outdir", "work/", "work/daily_mis.xlsx"])
```

**Why each part:** openpyxl deliberately doesn't render/print; delegating to LibreOffice keeps fidelity. COM automation (pywin32) is the Windows alternative documented in the results.

**Verify yourself:** PDF opens, header repeats on page breaks, one page wide.

---

## Task 7 — Pack structure

```python
# Sheet order and tab colors
sheet_order = ["Cover", "Daily", "Summary", "AgentLookup", "Parameters", "ChangeLog"]
tab_colors = {"Cover": "808080", "Daily": "262A76", "Summary": "262A76",
              "AgentLookup": "262A76", "Parameters": "808080", "ChangeLog": "808080"}
for name in sheet_order:
    wb[name].sheet_properties.tabColor = tab_colors[name]

# Cover timestamp
ws_c["C7"] = '="Snapshot "&TEXT(Data!A5,"yyyy-mm-dd")&" · refreshed "&TEXT(NOW(),"yyyy-mm-dd hh:mm")'
```

**Verify yourself:** stranger test — colleague finds the current RPC% in <30 seconds using only the Cover text.

---

## Task 8 — Change log

```python
ws_log.append(["2025-08-25", "Analyst", "Summary!F5:F16",
               "Added MoM delta column", "Ops asked direction-at-a-glance"])
ws_log.append(["2025-08-25", "Analyst", "Parameters!E2:E3",
               "Raised RPC% amber floor 33→35", "Strategy recalibration memo 2025-08"])
ws_log.append(["2025-08-26", "Analyst", "Daily!B9",
               "Fixed June-09 double count", "Caught by reconcile vs v_daily_mis — my paste error"])
```

**Why each part:** the third entry is the important one — logging MISTAKES is what makes the log trustworthy. Convention note goes on the Cover: "No edit ships without a ChangeLog row."

**Verify yourself:** you actually added these rows while doing Tasks 1–7 — retro-fabricated logs defeat themselves.

---

## Task 9 — Full automated pack

```python
"""generate_daily_mis.py — one-command Collections Daily MIS pack.
Combines all Phase A behaviors (pivot-ready Data sheet, structured references,
RAG rules, SUMIFS formulas, Power Query-ready connections) into a single CLI tool.
"""
import argparse
from pathlib import Path
import pandas as pd
from openpyxl import Workbook
from openpyxl.worksheet.table import Table, TableStyleInfo
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.styles import Font, Alignment, NamedStyle, PatternFill, Border, Side
from openpyxl.formatting.rule import CellIsRule
from openpyxl.utils import get_column_letter

def build_pack(input_csv: str, output_path: Path):
    df = pd.read_csv(input_csv, parse_dates=["date"])
    wb = Workbook()

    # Build Data sheet with Excel Table
    ws_d = wb.active
    ws_d.title = "Data"
    ws_d.append(["Date", "Team", "Contacts", "Connects", "RPCs", "Promises", "Payments"])
    for _, r in df.iterrows():
        ws_d.append([r["date"].date(), r["team"], r["contacts"], r["connects"],
                      r["rpcs"], r["promises"], r["payments"]])
    tbl = Table(displayName="tblDaily", ref=f"A4:G{4+len(df)}")
    tbl.tableStyleInfo = TableStyleInfo(name="TableStyleMedium2", showRowStripes=True)
    ws_d.add_table(tbl)

    # Build Summary sheet with SUMIFS formulas
    ws_s = wb.create_sheet("Summary")
    # ... SUMIFS formulas, RAG conditional formatting ...

    # Add AgentLookup, Parameters, ChangeLog sheets
    # ... validation dropdowns, lookup formulas ...

    # Apply print setup to all sheets
    for ws in wb.worksheets:
        ws.page_setup.orientation = "landscape"
        ws.page_setup.fitToWidth = 1
        ws.sheet_properties.pageSetUpPr.fitToPage = True

    wb.save(output_path)

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--out", default="work/daily_mis.xlsx")
    args = ap.parse_args()
    build_pack(args.input, Path(args.out))
```

**Verify yourself:** run twice; diff via unzip of the xlsx (it's a zip): only timestamp-bearing parts differ. Spot-check three Summary cells against SQL `v_daily_mis`.
