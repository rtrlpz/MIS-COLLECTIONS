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
for c, h in enumerate(headers, start=1):
    cell = ws.cell(row=4, column=c, value=h)
    cell.font = Font(bold=True, color="FFFFFF")
    cell.alignment = Alignment(horizontal="center")

ws["B2"] = "2025-06-30"
ws["A2"] = '="Report for "&TEXT(B2,"yyyy-mm-dd")'
ws["A2"].font = Font(italic=True)

ws.freeze_panes = "A5"
for c in range(1, 7):
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

d = inter["interaction_date"].dt.normalize()
daily = (inter.groupby(d)
              .agg(Contacts=("interaction_id", "count"),
                   Connects=("calls_connected", "sum"),
                   RPCs=("rpc_flag", "sum")))
daily["Promises"] = ptp.groupby(ptp["ptp_date"].dt.normalize()).size()
daily["Payments"] = pay.groupby(pay["payment_date"].dt.normalize()).size()
daily = (daily.fillna(0).astype(int)
              .reset_index()
              .rename(columns={"interaction_date": "Date"})
              .sort_values("Date"))

wb = load_workbook(OUT)
ws = wb["Daily"]
for r, row in daily.iterrows():
    ws.cell(row=5 + r, column=1, value=row["Date"]).number_format = "yyyy-mm-dd"
    for c, col in enumerate(["Contacts", "Connects", "RPCs", "Promises", "Payments"], start=2):
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
emps = pd.read_csv("data_sources/raw/shared/Dim_Employees.csv", dtype="string")
emps = emps[emps["employee_type"] == "Agent"][["agent_id", "agent_name", "team_name"]]
ws_lu.append(["AgentID", "Name"])
for _, r in emps.iterrows():
    ws_lu.append([r.agent_id, r.agent_name])
n_rows = len(emps) + 1

# One row per agent-day, from the same June extract
ad = (inter.assign(day=inter["interaction_date"].dt.normalize())
           .groupby(["day", "agent_id"])
           .agg(Contacts=("interaction_id", "count"),
                Connects=("calls_connected", "sum"),
                RPCs=("rpc_flag", "sum"))
           .reset_index()
           .merge(emps[["agent_id", "team_name"]], on="agent_id", how="left"))
p = ptp.assign(day=ptp["ptp_date"].dt.normalize()).groupby(["day", "agent_id"]).size().rename("Promises")
q = pay.assign(day=pay["payment_date"].dt.normalize()).groupby(["day", "agent_id"]).size().rename("Payments")
ad = ad.merge(p, on=["day", "agent_id"], how="left").merge(q, on=["day", "agent_id"], how="left")
ad[["Promises", "Payments"]] = ad[["Promises", "Payments"]].fillna(0).astype(int)

ws_ad = wb.create_sheet("AgentDaily")
for col, h in enumerate(["Agent ID", "Team", "Agent Name (XLOOKUP)",
                         "Agent Name (VLOOKUP)", "Promises", "Payments"], start=1):
    ws_ad.cell(row=4, column=col, value=h).font = Font(bold=True)

for i, row in enumerate(ad.itertuples(index=False), start=5):
    ws_ad.cell(row=i, column=1, value=row.agent_id)
    ws_ad.cell(row=i, column=2, value=row.team_name)
    ws_ad.cell(row=i, column=3,
               value=f'=IFNA(_xlfn.XLOOKUP(A{i},AgentLookup!$A$2:$A${n_rows},AgentLookup!$B$2:$B${n_rows}),"—")')
    ws_ad.cell(row=i, column=4,
               value=f'=IFNA(VLOOKUP(A{i},AgentLookup!$A$2:$B${n_rows},2,FALSE),"")')
    ws_ad.cell(row=i, column=5, value=int(row.Promises))
    ws_ad.cell(row=i, column=6, value=int(row.Payments))
```

**Why each part:** the FORMULA lives in the cell — python never pre-fills names. `IFNA` turns misses into an em-dash. `XLOOKUP` is direction-safe; `VLOOKUP` requires the lookup column to be leftmost. openpyxl must write the future function as `_xlfn.XLOOKUP`; LibreOffice may still show `#NAME?` for it — test the VLOOKUP path there.

**Verify yourself:** change one ID to garbage → shows `—`. Change to valid other ID → name updates. Insert a column in AgentLookup → XLOOKUP survives, VLOOKUP breaks.

---

## Task 4 — Pivot Table basics (manual creation)

### Manual steps (do these in Excel — NO openpyxl pivot creation):
1. On the `AgentDaily` sheet, select the entire data range (A4:F{last_row}).
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
2. Go to the `AgentDaily` sheet. Select the team cell range (e.g., B5:B100).
3. **Data → Data Validation → List.**
4. Source: `=Parameters!$A$2:$A$100`
5. Check: "Show error message after invalid data is entered"
6. Error Title: `Invalid team` | Error message: `Pick from the list.`
7. **Try to type "Free Texxt"** in B5 → Excel refuses with your error message.
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
dv.add("B5:B100")
```

**Verify yourself:** type "Free Texxt" in J5 → refused. Check that the Parameters list drives the dropdown (add a team to Parameters → it should appear in dropdowns without code changes).

---

## ═══ PHASE B — Automation Solutions ═══

---

## Task 6 — NamedStyles polish

```python
from openpyxl.styles import Alignment, Border, Font, NamedStyle, PatternFill, Side

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

for st in (title, header, grid, date_st, num_st):
    wb.add_named_style(st)

ws["A1"].style = "title"
for cell in ws[4]:
    cell.style = "header"
for row in ws.iter_rows(min_row=5, max_col=6):
    for cell in row:
        cell.style = "grid"
wb.save(OUT)
```

**Why:** NamedStyles are the workbook's design system — change `header` once, every sheet inherits. Two-color discipline: palette blue for identity, white space elsewhere. Borders do the separating.

**Verify yourself:** screenshot after opening; hairline grid reads professional, rainbow reads amateur.

---

## Task 7 — Print setup + PDF

```python
ws.print_area = f"A1:F{5 + len(daily)}"
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
"""daily_mis_auto.py — one-command Collections Daily MIS pack.

Usage: python daily_mis_auto.py --input daily_extract.csv --out work/daily_mis.xlsx
Input: CSV export of v_daily_mis (agent-day grain).
"""
import argparse
from pathlib import Path

import pandas as pd
from openpyxl import Workbook
from openpyxl.styles import Alignment, Border, Font, NamedStyle, PatternFill, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation

OUT = Path("work/daily_mis.xlsx")
RAW = Path("data_sources/raw")
REQUIRED = {"date", "agent_id", "team_name", "total_calls",
            "connected_calls", "rpc_count", "ptp_count", "payment_count"}


def styles(wb):
    if "title" not in wb.named_styles:
        wb.add_named_style(NamedStyle("title", font=Font(size=16, bold=True, color="262A76")))
    if "header" not in wb.named_styles:
        wb.add_named_style(NamedStyle(
            "header", font=Font(bold=True, color="FFFFFF"),
            fill=PatternFill("solid", fgColor="262A76"),
            alignment=Alignment(horizontal="center"),
            border=Border(bottom=Side(style="thin"))))
    if "grid" not in wb.named_styles:
        wb.add_named_style(NamedStyle(
            "grid", border=Border(left=Side(style="hair"), right=Side(style="hair"),
                                  top=Side(style="hair"), bottom=Side(style="hair"))))


def build_pack(input_csv: str, output_path: Path):
    df = pd.read_csv(input_csv, parse_dates=["date"])
    missing = REQUIRED - set(df.columns)
    if missing:
        raise ValueError(f"input is missing columns: {sorted(missing)}")

    daily = (df.groupby("date")
               .agg(Contacts=("total_calls", "sum"),
                    Connects=("connected_calls", "sum"),
                    RPCs=("rpc_count", "sum"),
                    Promises=("ptp_count", "sum"),
                    Payments=("payment_count", "sum"))
               .reset_index().sort_values("date"))

    wb = Workbook()
    styles(wb)
    ws_c = wb.active
    ws_c.title = "Cover"
    ws_c["A1"] = "Collections Daily MIS"
    ws_c["A1"].style = "title"
    ws_c["A3"], ws_c["B3"] = "Owner:", "MIS Analyst — Collections"
    ws_c["A4"], ws_c["B4"] = "Generated:", '="Refreshed "&TEXT(NOW(),"yyyy-mm-dd hh:mm")'
    for i, line in enumerate([
            "Daily — daily rollup with agent-day detail",
            "Summary — monthly rollup",
            "AgentLookup — agent id to name",
            "Parameters — validation lists",
            "AgentDaily — per-agent promises and payments"], start=6):
        ws_c.cell(row=i, column=1, value=line)
    ws_c.column_dimensions["A"].width = 42

    ws = wb.create_sheet("Daily")
    ws["A1"] = "Collections Daily MIS"
    ws["A1"].style = "title"
    ws["B2"] = daily["date"].max().to_pydatetime()
    ws["B2"].number_format = "yyyy-mm-dd"
    ws["A2"] = '="Report for "&TEXT(B2,"yyyy-mm-dd")'
    headers = ["Date", "Contacts", "Connects", "RPCs", "Promises", "Payments"]
    for c, h in enumerate(headers, start=1):
        ws.cell(row=4, column=c, value=h).style = "header"
    for r, row in enumerate(daily.itertuples(index=False), start=5):
        ws.cell(row=r, column=1, value=row.date.to_pydatetime()).number_format = "yyyy-mm-dd"
        for c, value in enumerate(row[1:], start=2):
            ws.cell(row=r, column=c, value=int(value)).number_format = "#,##0"
    for c in range(1, 7):
        ws.column_dimensions[get_column_letter(c)].width = 14
    ws.freeze_panes = "A5"
    ws.print_area = f"A1:F{4 + len(daily)}"
    ws.page_setup.orientation = "landscape"
    ws.page_setup.fitToWidth = 1
    ws.page_setup.fitToHeight = 0
    ws.sheet_properties.pageSetUpPr.fitToPage = True
    ws.print_title_rows = "4:4"

    emps = pd.read_csv(RAW / "shared" / "Dim_Employees.csv", dtype="string")
    emps = emps[emps["employee_type"] == "Agent"][["agent_id", "agent_name", "team_name"]]
    lu = wb.create_sheet("AgentLookup")
    lu.append(["AgentID", "Name"])
    for r in emps.itertuples(index=False):
        lu.append([r.agent_id, r.agent_name])
    last_lu = len(emps) + 1

    ad = (df.groupby(["date", "agent_id", "team_name"], as_index=False)
            .agg(Promises=("ptp_count", "sum"), Payments=("payment_count", "sum")))
    ws_ad = wb.create_sheet("AgentDaily")
    ad_headers = ["Agent ID", "Team", "Agent Name (XLOOKUP)",
                  "Agent Name (VLOOKUP)", "Promises", "Payments"]
    for c, h in enumerate(ad_headers, start=1):
        ws_ad.cell(row=4, column=c, value=h).style = "header"
    for r, row in enumerate(ad.itertuples(index=False), start=5):
        ws_ad.cell(row=r, column=1, value=row.agent_id)
        ws_ad.cell(row=r, column=2, value=row.team_name)
        ws_ad.cell(row=r, column=3, value=(f'=IFNA(_xlfn.XLOOKUP(A{r},AgentLookup!$A$2:$A${last_lu},'
                                           f'AgentLookup!$B$2:$B${last_lu}),"—")'))
        ws_ad.cell(row=r, column=4, value=(f'=IFNA(VLOOKUP(A{r},AgentLookup!$A$2:$B${last_lu},'
                                           f'2,FALSE),"")'))
        ws_ad.cell(row=r, column=5, value=int(row.Promises))
        ws_ad.cell(row=r, column=6, value=int(row.Payments))

    params = wb.create_sheet("Parameters")
    params["A1"] = "Teams"
    teams = sorted(df["team_name"].dropna().unique())
    for i, team in enumerate(teams, start=2):
        params.cell(row=i, column=1, value=team)
    dv = DataValidation(type="list", formula1=f"=Parameters!$A$2:$A${len(teams) + 1}",
                        allow_blank=True, showErrorMessage=True,
                        errorTitle="Invalid team", error="Pick from the list.")
    ws_ad.add_data_validation(dv)
    dv.add(f"B5:B{4 + len(ad)}")

    summary = wb.create_sheet("Summary")
    summary["A1"] = "Period totals"
    summary["A1"].style = "title"
    for i, (label, value) in enumerate(
            [("Contacts", int(daily["Contacts"].sum())),
             ("Connects", int(daily["Connects"].sum())),
             ("RPCs", int(daily["RPCs"].sum())),
             ("Promises", int(daily["Promises"].sum())),
             ("Payments", int(daily["Payments"].sum()))], start=3):
        summary.cell(row=i, column=1, value=label).style = "grid"
        summary.cell(row=i, column=2, value=value).number_format = "#,##0"

    wb.save(output_path)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--out", default=str(OUT))
    args = ap.parse_args()
    build_pack(args.input, Path(args.out))
```

**Verify yourself:** run twice; diff via unzip of the xlsx (it's a zip): only timestamp-bearing parts differ. Spot-check Summary totals against SQL `v_daily_mis`.

---

## Task 9 — Reconciliation

```python
import os

import psycopg2
from dotenv import load_dotenv
from openpyxl import load_workbook

load_dotenv()


def reconcile(date: str, out="work/daily_mis.xlsx"):
    conn = psycopg2.connect(
        host=os.getenv("POSTGRES_HOST", "localhost"),
        port=os.getenv("POSTGRES_PORT"),
        user=os.getenv("POSTGRES_USER"),
        password=os.getenv("POSTGRES_PASSWORD"),
        dbname=os.getenv("POSTGRES_DB"))
    with conn, conn.cursor() as cur:
        cur.execute("""
            SELECT COALESCE(SUM(total_calls), 0),
                   COALESCE(SUM(connected_calls), 0),
                   COALESCE(SUM(rpc_count), 0),
                   COALESCE(SUM(ptp_count), 0),
                   COALESCE(SUM(payment_count), 0)
            FROM v_daily_mis
            WHERE date = %s
        """, (date,))
        sql_result = [int(v) for v in cur.fetchone()]

    wb = load_workbook(out, data_only=True)
    ws = wb["Daily"]
    rows = [row for row in ws.iter_rows(min_row=5, max_col=6, values_only=True)
            if row[0] and str(row[0])[:10] == date]
    excel_result = [sum(int(v or 0) for v in col) for col in zip(*rows)][1:]

    if sql_result != excel_result:
        raise ValueError(
            f"Reconciliation failure for {date}: SQL={sql_result}, Excel={excel_result}")
    print(f"PASS {date}: {sql_result}")
```

**Why:** anything exported must agree with the official SQL view (`v_daily_mis`). If it doesn't, that's a finding to explain — not something to eyeball away. Compare period sums, not one row, because `v_daily_mis` is agent-day grain.

**Verify yourself:** run the generator for a known date, call `reconcile(date)`, then compare one agent's row against SQL manually. Any mismatch = a finding to investigate before shipping.
