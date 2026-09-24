# Excel Advanced — Results (worked solutions)

**Philosophy:** Phase A tasks are solved FIRST in Excel/LibreOffice manually — you build the reference dashboard. Phase B tasks automate it. The manual workbook IS the spec; the automation must reproduce it. VBA modules are authored as `.bas` files and imported into the VBE.

---

## ═══ PHASE A — Excel-Native Solutions ═══

---

## Task 1 — Build the complete dashboard manually

### Manual steps (do this entirely in Excel/LibreOffice):

#### Cover sheet:
1. Cell A1: `Collections Daily MIS` — Font size 16, bold, color #262A76
2. Cell A3: `Owner:` | Cell B3: `MIS Analyst — Collections`
3. Cell A4: `Generated:` | Cell B4: `="Snapshot "&TEXT(TODAY(),"yyyy-mm-dd")&" · refreshed "&TEXT(NOW(),"yyyy-mm-dd hh:mm")`
4. Cell A6–A12: Navigation lines — one sentence per tab
5. Sheet tab color: `808080` (governance)

#### Daily sheet:
1. Paste the daily data. Headers in row 4.
2. Add Agent ID column. **Type XLOOKUP by hand** in the name column:
   `=IFNA(XLOOKUP(A5,AgentLookup!$A$2:$A$100,AgentLookup!$B$2:$B$100,"—"),"")`
3. **Data → Data Validation → List** on the team column → source = Parameters!$A$2:$A$100
4. Freeze panes at A5
5. Convert the data range to an **Excel Table** (Ctrl+T) — name it `tblDaily`

#### Summary sheet:
1. Month dates in A5:A16
2. **Type SUMIFS formulas** by hand for each KPI column
3. RPC% in E5: `=IFERROR(D5/C5,"")`
4. MoM delta in F6: `=TEXT(D6-D5,"+0;-0;±0")`
5. **Conditional formatting** on E5:E16 (RPC%):
   - Green: `=$E$3<=E5` → #00B050
   - Amber: `=AND(E5>=$E$2,E5<$E$3)` → #FFC000
   - Red: `=$E$2>E5` → #FF0000
   Thresholds in Parameters!E2:E3

#### PivotDaily sheet:
1. Select tblDaily → **Insert → PivotTable** → new sheet
2. Rows = Team, Values = SUM(Contacts), SUM(Connects), SUM(RPCS), SUM(Promises), SUM(Payments)
3. Filter = Month
4. **Insert → PivotChart** → line chart of RPC% by month
5. **Insert Slicer** → Team

#### Power Query:
1. **Data → Get Data → From CSV** → daily extract
2. Transform: promote headers, set date/number types
3. Close & Load To → Only Create Connection + Add to Data Model
4. Pivot from the Data Model → Refresh on open configured

#### ChangeLog:
1. Columns: Date · Author · Sheet/Range · What changed · Why
2. Pre-populate 3+ entries (including one fix)

#### Print setup:
- Every sheet: landscape, fit-to-width=1, print_title_rows="4:4"
- File → Print preview → screenshot

**Verify yourself:** this IS the reference. The automation must reproduce every formula, pivot, chart, slicer, and RAG rule. Open it as a reader — does it look like a report a director would trust?

---

## Task 2 — Understand the pivot cache

### Manual steps:
1. Open `work/daily_mis_manual.xlsx`
2. Add a new row to the Data sheet below the table
3. **Right-click the pivot → Refresh** → confirm the new row appears
4. **PivotTable Analyze → Options → Data** → see the cache range
5. **Problem demonstration:** if the cache is hardcoded to `A4:G50` and you add row 51, the pivot ignores it

**Fix options tested:**
- **Option A — Excel Table:** convert data range to Table → cache auto-expands with table rows (best for openpyxl-generated files)
- **Option B — Manual cache range update:** right-click pivot → PivotTable Options → Data → change range (works but fragile)
- **Option C — Power Query source:** pivot sourced from Power Query connection → cache refreshes when the query refreshes (best enterprise practice)

**Enterprise recommendation:** Power Query as the pivot source. The pipeline generates the Data sheet → Power Query loads it → pivot reads from the query. Adding data? Refresh the query, the pivot follows.

**Verify yourself:** add rows → refresh → confirm new data appears. Test all three options.

---

## ═══ PHASE B — Automation Solutions ═══

---

## Task 3 — Full generator script

```python
"""generate_daily_mis.py — one-command Collections Daily MIS pack.
Reproduces the Phase A manual dashboard programmatically.
"""
import argparse
from pathlib import Path
import pandas as pd
from openpyxl import Workbook
from openpyxl.worksheet.table import Table, TableStyleInfo
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.styles import Font, Alignment, NamedStyle, PatternFill, Border, Side
from openpyxl.formatting.rule import CellIsRule, FormulaRule
from openpyxl.utils import get_column_letter

def build_pack(input_csv: str, output_path: Path):
    df = pd.read_csv(input_csv, parse_dates=["date"])
    wb = Workbook()

    # Daily sheet with Excel Table
    ws_d = wb.active
    ws_d.title = "Daily"
    ws_d.append(["Date", "Team", "Contacts", "Connects", "RPCs", "Promises", "Payments"])
    for _, r in df.iterrows():
        ws_d.append([r["date"].date(), r["team"], int(r["contacts"]), int(r["connects"]),
                      int(r["rpcs"]), int(r["promises"]), int(r["payments"])])
    tbl = Table(displayName="tblDaily", ref=f"A4:G{4+len(df)}")
    tbl.tableStyleInfo = TableStyleInfo(name="TableStyleMedium2", showRowStripes=True)
    ws_d.add_table(tbl)

    # Summary sheet with SUMIFS formulas
    ws_s = wb.create_sheet("Summary")
    ws_s["A1"] = "Monthly rollup"
    ws_s.append(["Month", "Contacts", "Connects", "RPCs", "RPC %", "Δ vs prior month"])
    for r, mrow in enumerate(month_rows, start=5):
        ws_s.cell(row=r, column=2, value=f'=SUMIFS(tblDaily[Contacts],tblDaily[Date],">="&A{r},tblDaily[Date],"<"&EDATE(A{r},1))')
        # ... repeat per KPI ...
        ws_s.cell(row=r, column=5, value=f'=IFERROR(D{r}/C{r},"")')
        if r > 5:
            ws_s.cell(row=r, column=6, value=f'=TEXT(D{r}-D{r-1},"+0;-0;±0")')

    # RAG conditional formatting on Summary RPC% column
    rng = f"F5:F{4+len(month_rows)}"
    ws_s.conditional_formatting.add(rng, CellIsRule(operator="greaterThanOrEqual", formula=["$E$3"], fill=PatternFill("solid", fgColor="00B050")))
    ws_s.conditional_formatting.add(rng, CellIsRule(operator="between", formula=["$E$2", "$E$3"], fill=PatternFill("solid", fgColor="FFC000")))
    ws_s.conditional_formatting.add(rng, CellIsRule(operator="lessThan", formula=["$E$2"], fill=PatternFill("solid", fgColor="FF0000")))

    # AgentLookup, Parameters, ChangeLog sheets
    # ... (as in Basic/Medium tasks) ...

    # Print setup
    for ws in wb.worksheets:
        ws.page_setup.orientation = "landscape"
        ws.page_setup.fitToWidth = 1
        ws.sheet_properties.pageSetUpPr.fitToPage = True
        ws.print_title_rows = "4:4"

    wb.save(output_path)

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--out", default="work/daily_mis.xlsx")
    args = ap.parse_args()
    build_pack(args.input, Path(args.out))
```

**Verify yourself:** run twice → diff via unzip → only timestamp parts differ. Compare Summary cells against SQL `v_daily_mis`.

---

## Task 4 — Refresh-on-open VBA

### VBA module: `work/RefreshOnOpen.bas`

```vb
' Module: modRefresh
Option Explicit

Private Sub Workbook_Open()
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Worksheets("Cover")
    On Error Resume Next
    ws.Range("B4").Value = "Last refreshed: " & Format(Now, "yyyy-mm-dd hh:nn:ss")
    Application.CalculateFullRebuild
    On Error GoTo 0
End Sub
```

**Note:** `Workbook_Open` belongs in **ThisWorkbook**, not a `.bas` module. The `.bas` file holds helper code; event stubs are pasted into ThisWorkbook via Alt+F11 → Double-click ThisWorkbook.

**Convert first:** File → Save As → *Excel Macro-Enabled Workbook (.xlsm)*.

**Why each part:** `CalculateFullRebuild` guarantees formula freshness on stale-looking opens; error-guard keeps a broken calc from blocking the file opening entirely.

**Verify yourself:** close & reopen → timestamp changes to now. Document honestly: users must click "Enable Content."

---

## Task 5 — One-button pack

### VBA module: `work/modPackPipeline.bas`

```vb
' Module: modPackPipeline
Option Explicit

Const DROP_PATH As String = "C:\collections\drops\"
Const DATA_SHEET As String = "Data"

Public Sub RefreshPack()
    Dim csvPath As String
    csvPath = FindNewestCSV(DROP_PATH)
    If csvPath = "" Then
        MsgBox "No daily_*.csv found in " & DROP_PATH, vbExclamation, "Refresh Pack"
        Exit Sub
    End If

    Application.ScreenUpdating = False
    LoadCsvIntoData csvPath
    ThisWorkbook.Application.CalculateFullRebuild

    Dim outPdf As String
    outPdf = ThisWorkbook.Path & "\daily_mis_" & Format(Date, "yyyy-mm-dd") & ".pdf"
    ThisWorkbook.Worksheets("Daily").ExportAsFixedFormat Type:=xlTypePDF, Filename:=outPdf
    ThisWorkbook.Worksheets("Summary").ExportAsFixedFormat Type:=xlTypePDF, _
        Filename=Replace(outPdf, ".pdf", "_summary.pdf")
    Application.ScreenUpdating = True
    MsgBox "Pack refreshed and exported:" & vbCrLf & outPdf, vbInformation
End Sub

Private Function FindNewestCSV(dropPath As String) As String
    Dim latest As String, f As String
    latest = Dir(dropPath & "daily_*.csv")
    Do While latest <> ""
        If f = "" Or FileDateTime(dropPath & latest) > FileDateTime(dropPath & f) Then f = latest
        latest = Dir()
    Loop
    FindNewestCSV = f
End Function

Private Sub LoadCsvIntoData(ByVal csvPath As String)
    Dim wsD As Worksheet, qt As QueryTable
    Set wsD = ThisWorkbook.Worksheets(DATA_SHEET)
    wsD.Range("A4").CurrentRegion.Offset(1).ClearContents
    Set qt = wsD.QueryTables.Add(Connection:="TEXT;" & csvPath, Destination:=wsD.Range("A5"))
    With qt
        .TextFileParseType = xlDelimited
        .TextFileCommaDelimiter = True
        .RefreshStyle = xlOverwriteCells
        .Refresh BackgroundQuery:=False
    End With
End Sub
```

**Cover button:** Insert → Shapes → rectangle → Assign Macro → `RefreshPack`.

**Why each part:** newest-file pick means the analyst never renames anything at 8:40; ClearContents keeps headers and table structure so formulas survive; PDF names embed the date.

**Verify yourself:** drop two CSVs — correct one loads. Remove all CSVs — message box. Formulas on Summary intact after refresh.

---

## Task 6 — Generating .xlsm safely from python

**Documented flow:**
```text
1. Build template ONCE manually: pack_template.xlsm containing the VBA project
   (ThisWorkbook stub + imported .bas modules).
2. Generator flow:
   - wb = load_workbook("pack_template.xlsm", keep_vba=True)
   - rebuild/refresh sheet CONTENTS (values, styles, tables)
   - wb.save("daily_mis.xlsm")
3. LIMITS:
   - Cannot CREATE or EDIT VBA from python — only preserve it.
   - Sheet-level code (event handlers on renamed/deleted sheets) can orphan.
   - Keep sheet NAMES stable so ThisWorkbook/module references survive.
```

```python
from openpyxl import load_workbook

wb = load_workbook("work/pack_template.xlsm", keep_vba=True)
rebuild_data(wb["Data"], df_daily)   # values/styles only — same sheet names
wb.save("work/daily_mis.xlsm")
```

**Verify yourself:** open generated file → Alt+F11 shows modules intact → Workbook_Open fires → button works. Break test: rename Data sheet in a copy → observe what orphans; document.

---

## Task 7 — Scheduling + governance

**Task Scheduler documentation (`work/scheduling.md`):**
```text
Trigger : Weekdays 08:15
Action  : "C:\...\python.exe" generate_daily_mis.py --input C:\collections\drops\daily_*.csv --out C:\collections\output\daily_mis.xlsx
Start in: C:\Users\you\mis-collections
Failure : email via task history + fallback manual run
Then    : duty analyst opens daily_mis.xlsm → Enable Content → RefreshPack → mail PDF
```

**Final governance checklist (`work/pack_governance_checklist.md`):**
- [ ] RAG thresholds live ONLY on Parameters (strategy-editable)
- [ ] Reconcile step ran before send
- [ ] ChangeLog row for every change since last send
- [ ] Macro policy stated on Cover (signed/enable-click)
- [ ] PDF filename carries report date; archive folder per month
- [ ] Pivot cache understood — refresh confirmed (Phase A Task 2)
- [ ] Power Query source verified (Phase A Task 1)

**Verify yourself:** dry-run one full morning — scheduler fires, button pressed, PDF attached, log rows written. That rehearsal IS the deliverable.
