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

#### AgentLookup sheet:
1. A1: `AgentID`, B1: `Name`; paste the agent roster (one row per `EID-*`).
2. Keep it a plain range — lookups below point at `$A$2:$B$200`.

#### Daily sheet:
1. Paste the daily extract (agent-day rows from `v_daily_mis` joined to `fact_payments`, with `kept_count`/`broken_count`). Headers in row 4 (the CSV header row must match the table headers so the QueryTable refresh does not break structured references).
2. Columns A4:L4 = Date | Agent ID | Team | Contacts | Connects | RPCs | Promises | Payments | Kept | Broken | Name (XLOOKUP) | Name (VLOOKUP). **Type XLOOKUP by hand** in K5:
   `=IFNA(XLOOKUP(B5,AgentLookup!$A$2:$A$100,AgentLookup!$B$2:$B$100),"—")`
3. **Data → Data Validation → List** on the team column (C5:C...) → source = Parameters!$A$2:$A$100
4. Freeze panes at A5
5. Convert the data range to an **Excel Table** (Ctrl+T) — name it `tblDaily`

#### Summary sheet:
1. Month dates in A5:A16
2. **Type SUMIFS formulas** by hand for each KPI column: Month | Contacts | Connects | RPCs | RPC % | Promises | Payments | KP % | Promises Δ MoM
3. RPC% in E5: `=IFERROR(D5/C5,"")`
4. KP% in H5: `=IFERROR(SUMIFS(tblDaily[Kept],tblDaily[Date],">="&A5,tblDaily[Date],"<"&EDATE(A5,1))/(SUMIFS(tblDaily[Kept],tblDaily[Date],">="&A5,tblDaily[Date],"<"&EDATE(A5,1))+SUMIFS(tblDaily[Broken],tblDaily[Date],">="&A5,tblDaily[Date],"<"&EDATE(A5,1))),0)`
5. Promises Δ in I6: `=TEXT(F6-F5,"+0;-0;±0")`
6. **Conditional formatting** on H5:H16 (KP% is column H):
   - Green: `=H5>=Parameters!$E$3` → #00B050
   - Amber: `=AND(H5>=Parameters!$E$2,H5<Parameters!$E$3)` → #FFC000
   - Red: `=H5<Parameters!$E$2` → #FF0000
   Thresholds in Parameters!E2:E3 (0.68 / 0.80 = 85% of the 80% goal / goal)

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
2. Add a new row below the Daily table
3. **Right-click the pivot → Refresh** → confirm the new row appears
4. **PivotTable Analyze → Options → Data** → see the cache range
5. **Problem demonstration:** if the cache is hardcoded to `A4:L50` and you add row 51, the pivot ignores it

**Fix options tested:**
- **Option A — Excel Table:** convert data range to Table → cache auto-expands with table rows (best for openpyxl-generated files)
- **Option B — Manual cache range update:** right-click pivot → PivotTable Options → Data → change range (works but fragile)
- **Option C — Power Query source:** pivot sourced from Power Query connection → cache refreshes when the query refreshes (best enterprise practice)

**Enterprise recommendation:** Power Query as the pivot source. The pipeline generates the Daily sheet → Power Query loads it → pivot reads from the query. Adding data? Refresh the query, the pivot follows.

**Verify yourself:** add rows → refresh → confirm new data appears. Test all three options.

---

## ═══ PHASE B — Automation Solutions ═══

---

## Task 3 — Full generator script

**Build the extract first.** `v_daily_mis` has no `payment_count`; join `fact_payments` at agent-day grain (same pattern as basic Task 8). It already exposes `kept_count` and `broken_count`, so select them directly for the KP% RAG column.

```python
"""generate_daily_mis.py — one-command Collections Daily MIS pack.

Usage:
  python generate_daily_mis.py --input daily_extract.csv --out work/daily_mis.xlsx
  python generate_daily_mis.py --latest C:\\collections\\drops --out work/daily_mis.xlsx
Input CSV is an agent-day extract: v_daily_mis joined to fact_payments
(see basic Task 8) with kept_count / broken_count included.
"""
import argparse
from pathlib import Path

import pandas as pd
from openpyxl import Workbook
from openpyxl.formatting.rule import CellIsRule
from openpyxl.styles import Font, PatternFill
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.worksheet.table import Table, TableStyleInfo

REQUIRED = {"date", "agent_id", "team_name", "total_calls",
            "connected_calls", "rpc_count", "ptp_count", "payment_count",
            "kept_count", "broken_count"}


def pick_latest(folder: Path) -> Path:
    files = sorted(folder.glob("daily_*.csv"), key=lambda f: f.stat().st_mtime)
    if not files:
        raise FileNotFoundError(f"no daily_*.csv in {folder}")
    return files[-1]


def build_pack(input_csv: Path, output_path: Path):
    df = pd.read_csv(input_csv)
    df.columns = [str(c).strip().lower().replace(" ", "_") for c in df.columns]
    missing = REQUIRED - set(df.columns)
    if missing:
        raise ValueError(f"input is missing columns: {sorted(missing)}")
    df["date"] = pd.to_datetime(df["date"])

    wb = Workbook()
    ws_c = wb.active
    ws_c.title = "Cover"
    ws_c["A1"] = "Collections Daily MIS"
    ws_c["A1"].font = Font(size=16, bold=True, color="262A76")
    ws_c["A3"], ws_c["B3"] = "Owner:", "MIS Analyst — Collections"
    ws_c["A4"], ws_c["B4"] = "Generated:", '="Snapshot "&TEXT(TODAY(),"yyyy-mm-dd")&" · refreshed "&TEXT(NOW(),"yyyy-mm-dd hh:mm")'
    for i, line in enumerate([
            "Daily — agent-day extract from v_daily_mis",
            "Summary — monthly SUMIFS rollup with RAG KP%",
            "AgentLookup — agent id to name",
            "Parameters — RAG thresholds and team list",
            "ChangeLog — dated record of every change"], start=6):
        ws_c.cell(row=i, column=1, value=line)

    ws_d = wb.create_sheet("Daily")
    headers = ["Date", "Agent ID", "Team", "Contacts", "Connects",
               "RPCs", "Promises", "Payments", "Kept", "Broken",
               "Name (XLOOKUP)", "Name (VLOOKUP)"]
    for c, h in enumerate(headers, start=1):          # header row 4, table starts A4
        ws_d.cell(row=4, column=c, value=h).font = Font(bold=True, color="FFFFFF")
        ws_d.cell(row=4, column=c).fill = PatternFill("solid", fgColor="262A76")

    for r, row in enumerate(df.itertuples(index=False), start=5):
        ws_d.cell(row=r, column=1, value=row.date.to_pydatetime()).number_format = "yyyy-mm-dd"
        ws_d.cell(row=r, column=2, value=row.agent_id)
        ws_d.cell(row=r, column=3, value=row.team_name)
        for c, value in enumerate([row.total_calls, row.connected_calls, row.rpc_count,
                                   row.ptp_count, row.payment_count,
                                   row.kept_count, row.broken_count], start=4):
            ws_d.cell(row=r, column=c, value=int(value)).number_format = "#,##0"
        ws_d.cell(row=r, column=11, value=f'=IFNA(_xlfn.XLOOKUP(B{r},AgentLookup!$A$2:$A$200,AgentLookup!$B$2:$B$200),"—")')
        ws_d.cell(row=r, column=12, value=f'=IFNA(VLOOKUP(B{r},AgentLookup!$A$2:$B$200,2,FALSE),"")')

    last = 4 + len(df)
    tbl = Table(displayName="tblDaily", ref=f"A4:L{last}")
    tbl.tableStyleInfo = TableStyleInfo(name="TableStyleMedium2", showRowStripes=True)
    ws_d.add_table(tbl)
    ws_d.freeze_panes = "A5"

    # AgentLookup
    emps = pd.read_csv("data_sources/raw/shared/Dim_Employees.csv", dtype="string")
    emps = emps[emps["employee_type"] == "Agent"]
    ws_l = wb.create_sheet("AgentLookup")
    ws_l.append(["AgentID", "Name"])
    for row in emps[["agent_id", "agent_name"]].itertuples(index=False):
        ws_l.append([row.agent_id, row.agent_name])

    # Parameters: RAG thresholds in E2:E3, teams in A
    ws_p = wb.create_sheet("Parameters")
    ws_p["E1"] = "KP% RAG thresholds"
    ws_p["E2"] = 0.68
    ws_p["E3"] = 0.80
    ws_p["A1"] = "Teams"
    teams = sorted(df["team_name"].dropna().unique())
    for i, team in enumerate(teams, start=2):
        ws_p.cell(row=i, column=1, value=team)

    dv = DataValidation(type="list", formula1=f"=Parameters!$A$2:$A${len(teams) + 1}",
                        allow_blank=True, showErrorMessage=True,
                        errorTitle="Invalid team", error="Pick from the list.")
    ws_d.add_data_validation(dv)
    dv.add(f"C5:C{last}")

    # Summary: one row per month, SUMIFS over the table
    ws_s = wb.create_sheet("Summary")
    ws_s["A1"] = "Monthly rollup"
    ws_s["A1"].font = Font(size=16, bold=True, color="262A76")
    for c, h in enumerate(["Month", "Contacts", "Connects", "RPCs", "RPC %",
                           "Promises", "Payments", "KP %", "Promises Δ MoM"], start=1):
        ws_s.cell(row=4, column=c, value=h).font = Font(bold=True, color="FFFFFF")
        ws_s.cell(row=4, column=c).fill = PatternFill("solid", fgColor="262A76")

    months = pd.Series(df["date"].dt.to_period("M").unique()).sort_values()
    for i, period in enumerate(months, start=5):
        ws_s.cell(row=i, column=1, value=period.to_timestamp()).number_format = "yyyy-mm"
        ws_s.cell(row=i, column=2, value=(f'=SUMIFS(tblDaily[Contacts],tblDaily[Date],">="&A{i},'
                                          f'tblDaily[Date],"<"&EDATE(A{i},1))'))
        ws_s.cell(row=i, column=3, value=(f'=SUMIFS(tblDaily[Connects],tblDaily[Date],">="&A{i},'
                                          f'tblDaily[Date],"<"&EDATE(A{i},1))'))
        ws_s.cell(row=i, column=4, value=(f'=SUMIFS(tblDaily[RPCs],tblDaily[Date],">="&A{i},'
                                          f'tblDaily[Date],"<"&EDATE(A{i},1))'))
        ws_s.cell(row=i, column=5, value=f'=IFERROR(D{i}/C{i},"")').number_format = "0.0%"
        ws_s.cell(row=i, column=6, value=(f'=SUMIFS(tblDaily[Promises],tblDaily[Date],">="&A{i},'
                                          f'tblDaily[Date],"<"&EDATE(A{i},1))'))
        ws_s.cell(row=i, column=7, value=(f'=SUMIFS(tblDaily[Payments],tblDaily[Date],">="&A{i},'
                                          f'tblDaily[Date],"<"&EDATE(A{i},1))'))
        ws_s.cell(row=i, column=8, value=(
            f'=IFERROR(SUMIFS(tblDaily[Kept],tblDaily[Date],">="&A{i},'
            f'tblDaily[Date],"<"&EDATE(A{i},1))/'
            f'(SUMIFS(tblDaily[Kept],tblDaily[Date],">="&A{i},'
            f'tblDaily[Date],"<"&EDATE(A{i},1))+'
            f'SUMIFS(tblDaily[Broken],tblDaily[Date],">="&A{i},'
            f'tblDaily[Date],"<"&EDATE(A{i},1))),0)')).number_format = "0.0%"
        if i > 5:
            ws_s.cell(row=i, column=9, value=f'=TEXT(F{i}-F{i-1},"+0;-0;±0")')

    rag = f"H5:H{4 + len(months)}"
    ws_s.conditional_formatting.add(rag, CellIsRule(
        operator="greaterThanOrEqual", formula=["Parameters!$E$3"],
        fill=PatternFill("solid", fgColor="00B050")))
    ws_s.conditional_formatting.add(rag, CellIsRule(
        operator="between", formula=["Parameters!$E$2", "Parameters!$E$3"],
        fill=PatternFill("solid", fgColor="FFC000")))
    ws_s.conditional_formatting.add(rag, CellIsRule(
        operator="lessThan", formula=["Parameters!$E$2"],
        fill=PatternFill("solid", fgColor="FF0000")))

    ch = wb.create_sheet("ChangeLog")
    ch.append(["Date", "Author", "Sheet/Range", "What changed", "Why"])

    for ws in wb.worksheets:
        ws.page_setup.orientation = "landscape"
        ws.page_setup.fitToWidth = 1
        ws.page_setup.fitToHeight = 0
        ws.sheet_properties.pageSetUpPr.fitToPage = True
        ws.print_title_rows = "4:4"

    wb.save(output_path)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    group = ap.add_mutually_exclusive_group(required=True)
    group.add_argument("--input", help="one CSV file")
    group.add_argument("--latest", help="folder containing daily_*.csv")
    ap.add_argument("--out", default="work/daily_mis.xlsx")
    args = ap.parse_args()
    src = Path(args.input) if args.input else pick_latest(Path(args.latest))
    build_pack(src, Path(args.out))
```

**Reconciliation:** reuse the `reconcile()` function from Excel Basic Task 9 — compare each month's Contacts/RPCs/Promises/Payments/Kept/Broken totals against the CSV extract (itself audited against `v_daily_mis` + `fact_payments`) before sending.

**Verify yourself:** run twice → compare sheet names, table refs and every formula (openpyxl read-back); Excel writes fresh zip timestamps, so byte equality is the wrong test. Compare Summary totals against SQL `v_daily_mis` for the same month.

---

## Task 4 — Refresh-on-open VBA

### VBA module: `work/RefreshOnOpen.bas`

```vb
' Module: modRefresh (.bas) — helper only, callable from ThisWorkbook
Option Explicit

Public Sub StampAndRecalculate()
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Worksheets("Cover")
    On Error Resume Next
    ws.Range("B4").Value = "Last refreshed: " & Format(Now, "yyyy-mm-dd hh:nn:ss")
    Application.CalculateFullRebuild
    On Error GoTo 0
End Sub
```

**ThisWorkbook** (paste into the ThisWorkbook object, not a .bas module):
```vb
Private Sub Workbook_Open()
    modRefresh.StampAndRecalculate
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
Const DATA_SHEET As String = "Daily"

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
    wsD.Range("A5:L100000").ClearContents   ' keep the header/table at A4'
    Set qt = wsD.QueryTables.Add(Connection:="TEXT;" & csvPath, Destination:=wsD.Range("A4"))
    With qt
        .TextFileParseType = xlDelimited
        .TextFileCommaDelimiter = True
        .RefreshStyle = xlOverwriteCells
        .Refresh BackgroundQuery:=False
    End With
End Sub
```

**Cover button:** Insert → Shapes → rectangle → Assign Macro → `RefreshPack`.

**Why each part:** newest-file pick means the analyst never renames anything at 8:40; clearing below the header keeps the table and formulas alive; PDF names embed the date. The QueryTable destination is A4 so the CSV header lands on the header row, not in the first data row.

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


def rebuild_data(ws, df, first_row=5):
    """Replace values below the header without touching styles or sheet names."""
    if ws.max_row >= first_row:
        ws.delete_rows(first_row, ws.max_row - first_row + 1)
    for row in df.itertuples(index=False):
        ws.append(list(row))


wb = load_workbook("work/pack_template.xlsm", keep_vba=True)
rebuild_data(wb["Daily"], df_daily)   # values only — same sheet names
wb.save("work/daily_mis.xlsm")
```

**Verify yourself:** open generated file → Alt+F11 shows modules intact → Workbook_Open fires → button works. Break test: rename Daily sheet in a copy → observe what orphans; document.

---

## Task 7 — Scheduling + governance

**Task Scheduler documentation (`work/scheduling.md`):**
```text
Trigger : Weekdays 08:15
Action  : "C:\...\python.exe" generate_daily_mis.py --latest C:\collections\drops --out C:\collections\output\daily_mis.xlsx
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
