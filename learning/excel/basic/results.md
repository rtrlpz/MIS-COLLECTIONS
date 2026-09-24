# Excel Basic — Results (worked solutions)

**Philosophy:** Phase A tasks are solved FIRST in Excel/LibreOffice manually, then automated with openpyxl. The manual version is the primary skill; the automation version is the efficiency layer. Open the manual workbook and poke it — change values, refresh pivots, test validation.

---

## ═══ PHASE A — Excel-Native Solutions ═══

---

## Task 1 — Workbook anatomy (manual build)

### Manual steps (do these in Excel/LibreOffice first):
1. Open LibreOffice Calc or Excel → New workbook
2. Cell A1: type `Collections Daily MIS` — format: Font size 16, bold, color #262A76
3. Cell B2: type `2025-06-30` (a real date, formatted `yyyy-mm-dd`)
4. Cell A2: type formula `="Report for "&TEXT(B2,"yyyy-mm-dd")` — italic font
5. Row 4: headers `Date | Contacts | Connects | RPCs | Promises | Payments` — bold, fill #262A76, white text, centered
6. Freeze panes at A5 (View → Freeze Cells / Freeze Panes)
7. Column widths: A=10, B–G=14
8. Save as `work/daily_mis_manual.xlsx`

**Verify yourself:** reopen the file. Edit B2 → A2 subtitle must change. If it doesn't, LibreOffice/Excel may need a recalc (Ctrl+Shift+F9).

### Automation equivalent (openpyxl):
```python
from pathlib import Path
from openpyxl import Workbook
from openpyxl.styles import Font, Alignment
from openpyxl.utils import get_column_letter

OUT = Path("work/daily_mis.xlsx")
wb = Workbook()
ws = wb.active
ws.title = "Daily"

ws["A1"] = "Collections Daily MIS"
ws["A1"].font = Font(size=16, bold=True, color="262A76")

headers = ["Date", "Contacts", "Connects", "RPCs", "Promises", "Payments"]
for c, h in enumerate(headers, start=2):
    cell = ws.cell(row=4, column=c, value=h)
    cell.font = Font(bold=True, color="FFFFFF")
    cell.alignment = Alignment(horizontal="center")

ws["B2"] = "2025-06-30"
ws["A2"] = '="Report for "&TEXT(B2,"yyyy-mm-dd")'
ws["A2"].font = Font(italic=True)

ws.freeze_panes = "A5"
for c in range(2, 8):
    ws.column_dimensions[get_column_letter(c)].width = 14

wb.save(OUT)
```

**Why each part:** the manual build teaches you what "good" looks like — the openpyxl version just replicates it at scale. If you skip the manual step, you can't tell when the automation produces something wrong.

---

## Task 2 — Data rows (manual import)

### Manual steps:
1. Export one month's aggregated data as CSV from your pandas loader
2. In Excel: **Data → Get Data → From Text/CSV** → select the file
3. Confirm dates parse correctly (not as text like "2025-06-15" strings)
4. Apply `#,##0` number format to count columns
5. Sort by date ascending — confirm chronological order
6. Spot-check: pick one day, verify contacts/connects/RPCs against your SQL morning pack

### Automation equivalent:
```python
import pandas as pd
from openpyxl import load_workbook

inter = pd.read_csv("data_sources/raw/june_2025/Fact_Interactions.csv",
                     parse_dates=["interaction_date"])
ptp   = pd.read_csv("data_sources/raw/june_2025/Fact_PTP_Log.csv",
                     parse_dates=["ptp_date"])
pay   = pd.read_csv("data_sources/raw/june_2025/Fact_Payments.csv",
                     parse_dates=["payment_date"])

daily = pd.DataFrame({"Date": sorted(inter["interaction_date"].dt.normalize().unique())})
daily["Contacts"] = inter.groupby(inter["interaction_date"].dt.normalize()).size()
daily["Connects"] = inter.groupby(inter["interaction_date"].dt.normalize())["calls_connected"].sum()
daily["RPCs"]     = inter.groupby(inter["interaction_date"].dt.normalize())["rpc_flag"].sum()
daily["Promises"] = ptp.groupby(ptp["ptp_date"].dt.normalize()).size()
daily["Payments"] = pay.groupby(pay["payment_date"].dt.normalize()).size()
daily = daily.fillna(0).astype(int).reset_index()

wb = load_workbook(OUT)
ws = wb["Daily"]
for r, row in daily.iterrows():
    ws.cell(row=5 + r, column=2, value=row["Date"]).number_format = "yyyy-mm-dd"
    for c, col in enumerate(["Contacts", "Connects", "RPCs", "Promises", "Payments"], start=3):
        cell = ws.cell(row=5 + r, column=c, value=int(row[col]))
        cell.number_format = "#,##0"
wb.save(OUT)
```

**Verify yourself:** pick any row; compare its six numbers against your python morning pack for that date — exact match required.

---

## Task 3 — VLOOKUP + XLOOKUP typed by hand

### Manual steps (do these in Excel):
1. Create sheet `AgentLookup`. Column A: agent IDs. Column B: agent names (paste from CSV).
2. On Daily sheet, column A (below headers): type agent IDs manually.
3. **Type the XLOOKUP formula** in cell I5 (name column):
   ```
   =IFNA(XLOOKUP(A5,AgentLookup!$A$2:$A$100,AgentLookup!$B$2:$B$100,"—"),"")
   ```
4. **Type the VLOOKUP formula** in cell J5:
   ```
   =IFNA(VLOOKUP(A5,AgentLookup!$A$2:$B$100,2,FALSE),"")
   ```
5. Change A5 to a valid different ID → both names update.
6. Change A5 to garbage → both show `—`.
7. **Test column insertion:** insert a column between ID and Name in AgentLookup. XLOOKUP still works (direction-based). VLOOKUP now returns wrong data (column index shifted). This is why XLOOKUP is preferred — but VLOOKUP still ships with older Excel versions.

### Automation equivalent (openpyxl writes the same formulas):
```python
ws_lu = wb.create_sheet("AgentLookup")
emps = pd.read_csv("data_sources/raw/shared/Dim_Employees.csv", dtype="string")[["agent_id","agent_name"]]
ws_lu.append(["AgentID", "Name"])
for _, r in emps.iterrows():
    ws_lu.append([r.agent_id, r.agent_name])
n_rows = len(emps) + 1

for r in range(5, 5 + len(daily)):
    ws.cell(row=r, column=9,
            value=f'=IFNA(XLOOKUP(A{r},AgentLookup!$A$2:$A${n_rows},AgentLookup!$B$2:$B${n_rows}),"—")')
    ws.cell(row=r, column=10,
            value=f'=IFNA(VLOOKUP(A{r},AgentLookup!$A$2:$B${n_rows},2,FALSE),"")')
```

**Why each part:** the FORMULA lives in the cell — python never pre-fills names. `IFNA` turns misses into an em-dash. `XLOOKUP` is direction-safe; `VLOOKUP` requires the lookup column to be leftmost.

**Verify yourself:** change one ID to garbage → shows `—`. Change to valid other ID → name updates. Insert a column in AgentLookup → XLOOKUP survives, VLOOKUP breaks.

---

## Task 4 — Pivot Table basics (manual creation)

### Manual steps (do these in Excel — NO openpyxl pivot creation):
1. On the Data sheet, select the entire data range (A4:G{last_row}).
2. Go to **Insert → PivotTable**. Choose "New Worksheet." Name the sheet `PivotDaily`.
3. In the PivotTable Fields pane:
   - Drag `Team` to **Rows**
   - Drag `Promises` to **Values** (default: Sum)
   - Drag `Payments` to **Values**
4. Add a filter: drag `Month` to **Filters** area.
5. **Refresh test:** change one value in the Data sheet → right-click pivot → **Refresh**. Confirm the sum changes.
6. **Explore:** drag `Team` to Columns instead of Rows. Notice how the layout flips. This is the interactive advantage of pivots — no formula rewriting needed.

**Manual pivot notes:**
- Pivots are Excel's interactive analysis tool — they recalculate on refresh, don't store formulas
- openpyxl **cannot create** pivot tables from scratch (it can only read/preserve existing ones)
- For automation, the Data sheet is structured so a pre-built pivot cache can refresh

**Verify yourself:** change one team name in Data → refresh pivot → confirm counts shift. Filter to one month → confirm sums match Task 1's manual check.

---

## Task 5 — Validation dropdowns (manual setup)

### Manual steps (do these in Excel):
1. Create sheet `Parameters`. Column A: list valid team names (from CSV extract).
2. Go to the Data sheet. Select the team cell range (e.g., J5:J100).
3. **Data → Data Validation → List.**
4. Source: `=Parameters!$A$2:$A$100`
5. Check: "Show error message after invalid data is entered"
6. Error Title: `Invalid team` | Error message: `Pick from the list.`
7. **Try to type "Free Texxt"** in J5 → Excel refuses with your error message.
8. Also set date validation on the report-date cell (B2): **Data → Data Validation → Date** → between `2024-01-01` and `2026-12-31`.

**Note on free-type cells:** Notes/comment columns deliberately left unvalidated — document which and why.

### Automation equivalent:
```python
from openpyxl.worksheet.datavalidation import DataValidation

ws_p = wb.create_sheet("Parameters")
teams = sorted(emps["team_name"].unique())
ws_p["A1"] = "Teams"
for i, t in enumerate(teams, start=2):
    ws_p.cell(row=i, column=1, value=t)

dv = DataValidation(type="list",
                    formula1=f"=Parameters!$A$2:$A${len(teams)+1}",
                    allow_blank=True, showErrorMessage=True,
                    errorTitle="Invalid team", error="Pick from the list.")
ws.add_data_validation(dv)
dv.add("J5:J100")
```

**Verify yourself:** type "Free Texxt" in J5 → refused. Check that the Parameters list drives the dropdown (add a team to Parameters → it should appear in dropdowns without code changes).

---

## ═══ PHASE B — Automation Solutions ═══

---

## Task 6 — NamedStyles polish

```python
from openpyxl.styles import NamedStyle, Border, Side, PatternFill

title   = NamedStyle("title", font=Font(size=16, bold=True, color="262A76"))
header  = NamedStyle("header", font=Font(bold=True, color="FFFFFF"),
                      fill=PatternFill("solid", fgColor="262A76"),
                      border=Border(bottom=Side(style="thin")),
                      alignment=Alignment(horizontal="center"))
grid    = NamedStyle("grid", border=Border(
             left=Side(style="hair"), right=Side(style="hair"),
             top=Side(style="hair"), bottom=Side(style="hair")),
             alignment=Alignment(horizontal="right"))
date_st = NamedStyle("datecell", number_format="yyyy-mm-dd", border=grid.border)
num_st  = NamedStyle("numcell", number_format="#,##0", border=grid.border)
```

**Why:** NamedStyles are the workbook's design system — change `header` once, every sheet inherits. Two-color discipline: palette blue for identity, white space elsewhere. Borders do the separating.

**Verify yourself:** screenshot after opening; hairline grid reads professional, rainbow reads amateur.

---

## Task 7 — Print setup + PDF

```python
ws.print_area = f"A1:H{5 + len(daily)}"
ws.page_setup.orientation = "landscape"
ws.page_setup.fitToWidth  = 1
ws.page_setup.fitToHeight = 0
ws.sheet_properties.pageSetUpPr.fitToPage = True
ws.print_title_rows = "4:4"
```

**PDF export (LibreOffice):**
```bash
soffice --headless --convert-to pdf work/daily_mis.xlsx --outdir work/
```

**Why each part:** `fitToWidth=1` guarantees columns never split across pages; `print_title_rows` re-prints your styled header — the two settings people always forget until the boardroom print fails.

**Verify yourself:** PDF opens, header repeats on page breaks, one page wide.

---

## Task 8 — Full generator script

```python
"""generate_daily_mis.py — one-command Collections Daily MIS pack.
Usage: python generate_daily_mis.py --input daily_extract.csv --out work/daily_mis.xlsx
Combines all Phase A behaviors into a single CLI tool.
"""
import argparse
from pathlib import Path
import pandas as pd
from openpyxl import Workbook
from openpyxl.styles import Font, Alignment, NamedStyle, Border, Side, PatternFill
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation

OUT = Path("work/daily_mis.xlsx")

def build_pack(input_csv: str, output_path: Path):
    df = pd.read_csv(input_csv, parse_dates=["date"])
    wb = Workbook()
    ws = wb.active
    ws.title = "Daily"
    # ... all Phase A behaviors: title, headers, formulas, validation, styles, print setup
    wb.save(output_path)

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--out", default=str(OUT))
    args = ap.parse_args()
    build_pack(args.input, Path(args.out))
```

**Verify yourself:** run twice; diff via unzip of the xlsx (it's a zip): only timestamp-bearing parts differ. Spot-check three Summary cells against SQL `v_daily_mis`.

---

## Task 9 — Reconciliation

```python
# Reconciliation check in the generator:
import subprocess

def reconcile(date: str):
    # Run the SQL query for this date
    sql_result = subprocess.run(
        ["psql", "-c", f"SELECT contacts, connects, rpcs, promises FROM v_daily_mis WHERE date = '{date}'"],
        capture_output=True, text=True
    )
    # Read back the generated workbook
    wb = load_workbook(OUT)
    ws = wb["Daily"]
    excel_result = [ws.cell(row=5, column=c).value for c in range(2, 7)]
    # Compare
    if sql_result != excel_result:
        raise ValueError(f"Reconciliation failure for {date}: SQL={sql_result}, Excel={excel_result}")
```

**Why:** anything exported must agree with the official SQL view (`v_daily_mis`). If it doesn't, that's a finding to explain — not something to eyeball away.

**Verify yourself:** run the generator for a known date, compare against a manual SQL query. Any mismatch = a finding to investigate before shipping.
