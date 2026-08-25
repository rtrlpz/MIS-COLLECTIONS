# Excel Advanced — Results (worked solutions)

Two artifacts per task where relevant: python script sections and full VBA listings. VBA lives in `.bas` modules you IMPORT into the workbook's VBE (Alt+F11 → File → Import File) — openpyxl cannot author VBA, only preserve it.

---

## Task 1 — The MIS generator

`generate_daily_mis.py` skeleton (assembling everything from basic+medium):

```python
"""generate_daily_mis.py — one-command Collections Daily MIS pack.
Usage: python generate_daily_mis.py --input daily_extract.csv --out work/daily_mis.xlsx
Input: CSV export of v_daily_mis (date, team_name, contacts, connects, rpcs, ...)
"""
import argparse
from pathlib import Path
import pandas as pd
from openpyxl import Workbook
# ... NamedStyles, build_cover(), build_data(), build_summary(),
#     build_agent_lookup(), build_parameters(), build_changelog(),
#     apply_print_setup(ws), attach_rag_rules(ws_s), save()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--out", default="work/daily_mis.xlsx")
    args = ap.parse_args()

    df = pd.read_csv(args.input, parse_dates=["date"])
    wb = Workbook()
    build_cover(wb); build_data(wb, df); build_summary(wb, df)
    build_agent_lookup(wb); build_parameters(wb); build_changelog(wb)
    for ws in wb.worksheets:
        apply_print_setup(ws)
    wb.save(args.out)

if __name__ == "__main__":
    main()
```

**Why each part:** builder-per-sheet functions keep the 300-line generator reviewable; CLI args make it schedulable (Task 5 depends on this). Byte-stable reruns except timestamps = your regression test.

**Verify yourself:** run twice; diff via unzip of the xlsx (it's a zip): only timestamp-bearing parts differ. Spot-check three Summary cells against SQL `v_daily_mis`.

---

## Task 2 — Refresh-on-open VBA

Save as `work/RefreshOnOpen.bas`, import into the .xlsm's VBE:

```vb
' Module: modRefresh
Option Explicit

Private Sub Workbook_Open()   ' lives in ThisWorkbook, not a .bas module
    Dim ws As Worksheet
    Set ws = ThisWorkbook.Worksheets("Cover")
    On Error Resume Next
    ws.Range("C8").Value = "Last refreshed: " & Format(Now, "yyyy-mm-dd hh:nn:ss")
    Application.CalculateFullRebuild
    On Error GoTo 0
End Sub
```

Note: `Workbook_Open` belongs in **ThisWorkbook**, not a standard module — the .bas you import is any helper code; event stubs are pasted into ThisWorkbook. Convert first: File → Save As → *Excel Macro-Enabled Workbook (.xlsm)*.

**Why each part:** `CalculateFullRebuild` guarantees formula freshness on stale-looking opens; error-guard keeps a broken calc from blocking the file opening entirely.

**Verify yourself:** close & reopen → timestamp changes to now; F9-recalc state visibly refreshed. Document honestly: users must click "Enable Content" — that prompt IS the security tradeoff; mention signing/cert options in your note.

---

## Task 3 — One-button pack

```vb
' Module: modPackPipeline
Option Explicit

Const DROP_PATH As String = "C:\collections\drops\"
Const DATA_SHEET As String = "Data"

Public Sub RefreshPack()
    Dim fDialog As FileDialog, csvPath As String
    Dim latest As String, f As String
    latest = Dir(DROP_PATH & "daily_*.csv")
    Do While latest <> ""
        If f = "" Or FileDateTime(DROP_PATH & latest) > FileDateTime(DROP_PATH & f) Then f = latest
        latest = Dir()
    Loop
    If f = "" Then
        MsgBox "No daily_*.csv found in " & DROP_PATH, vbExclamation, "Refresh Pack"
        Exit Sub
    End If
    csvPath = DROP_PATH & f

    Application.ScreenUpdating = False
    LoadCsvIntoData csvPath
    ThisWorkbook.Application.CalculateFullRebuild

    Dim outPdf As String
    outPdf = ThisWorkbook.Path & "\daily_mis_" & Format(Date, "yyyy-mm-dd") & ".pdf"
    ThisWorkbook.Worksheets("Daily").ExportAsFixedFormat Type:=xlTypePDF, Filename:=outPdf
    ThisWorkbook.Worksheets("Summary").ExportAsFixedFormat Type:=xlTypePDF, Filename:=Replace(outPdf, ".pdf", "_summary.pdf")
    Application.ScreenUpdating = True
    MsgBox "Pack refreshed and exported:" & vbCrLf & outPdf, vbInformation
End Sub

Private Sub LoadCsvIntoData(ByVal csvPath As String)
    Dim wsD As Worksheet, qt As QueryTable
    Set wsD = ThisWorkbook.Worksheets(DATA_SHEET)
    wsD.Range("A4").CurrentRegion.Offset(1).ClearContents   ' keep headers
    Set qt = wsD.QueryTables.Add( _
        Connection:="TEXT;" & csvPath, _
        Destination:=wsD.Range("A5"))
    With qt
        .TextFileParseType = xlDelimited
        .TextFileCommaDelimiter = True
        .RefreshStyle = xlOverwriteCells
        .Refresh BackgroundQuery:=False
    End With
    qt.SavePassword = False
End Sub
```

Cover button: Insert → Shapes → rectangle → Assign Macro → `RefreshPack`.

**Why each part:** newest-file pick means the analyst never renames anything at 8:40; ClearContents keeps header row + table structure so medium-level formulas survive; PDF names embed the DATE (the JD deliverable pattern). Failure path exits BEFORE touching sheets.

**Verify yourself:** drop two CSVs with different timestamps — correct one loads. Remove all CSVs — message box, no partial write. Formulas on Summary intact after refresh (spot-check).

---

## Task 4 — Generating .xlsm safely from python

The honest flow (documented in your script header):

```text
1. Build template ONCE manually: pack.xlsm containing the VBA project
   (ThisWorkbook stub + imported .bas modules).
2. Generator flow:
   - openpyxl.load_workbook("pack_template.xlsm", keep_vba=True)
   - rebuild/refresh sheet CONTENTS (values, styles, tables)
   - wb.save("daily_mis.xlsm")
3. LIMITS (write these down):
   - You cannot CREATE or EDIT VBA from python — only preserve it.
   - Sheet-level code (event handlers on renamed/deleted sheets) can orphan.
   - Keep sheet NAMES stable so ThisWorkbook/module references survive.
```

```python
wb = load_workbook("work/pack_template.xlsm", keep_vba=True)
rebuild_data(wb["Data"], df_daily)          # values/styles only — same sheet names
wb.save("work/daily_mis.xlsm")
```

**Verify yourself:** open generated file → Alt+F11 shows modules intact → Workbook_Open fires → button works. Break test deliberately: rename Data sheet in a copy → observe what orphans; document.

---

## Task 5 — Scheduling + governance wrap-up

Task Scheduler run-of-show (documented in `work/scheduling.md`):

```text
Trigger : Weekly  weekdays 08:15
Action  : "C:\...\mis-collections\python.exe"
          args: generate_daily_mis.py --input C:\collections\drops\<latest handled by script>
          Start in: C:\Users\you\MIS-COLLECTIONS
Failure : email via task history + fallback manual run
Then    : duty analyst opens daily_mis.xlsm → Enable Content → RefreshPack → mail PDF
```

Final checklist doc (`work/pack_governance_checklist.md`):
- [ ] RAG thresholds live ONLY on Parameters (strategy-editable)
- [ ] reconcile step ran (python track reconcile.py PASS) before send
- [ ] ChangeLog row exists for every change since last send
- [ ] Macro policy stated on Cover (signed/enable-click)
- [ ] PDF filename carries report date; archive folder per month

**Verify yourself:** dry-run one full morning: scheduler fires (or manual invoke), button pressed, PDF attached, log rows written. That rehearsal IS the deliverable.
