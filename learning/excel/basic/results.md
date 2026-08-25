# Excel Basic — Results (worked solutions)

One script per task (or one growing script). After each: OPEN the file in Excel/LibreOffice — the reader test is part of the solution.

---

## Task 1 — Workbook anatomy

```python
"""daily_mis_shell.py — builds the recognizable pack shell."""
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
for c, h in enumerate(headers, start=2):          # data starts col B; A reserved
    cell = ws.cell(row=4, column=c, value=h)
    cell.font = Font(bold=True, color="FFFFFF")
    cell.alignment = Alignment(horizontal="center")

ws["B2"] = "2025-06-30"                            # THE date cell
ws["A2"] = '="Report for "&TEXT(B2,"yyyy-mm-dd")'
ws["A2"].font = Font(italic=True)

ws.freeze_panes = "A5"                             # headers stay put
for c in range(2, 8):
    ws.column_dimensions[get_column_letter(c)].width = 14

wb.save(OUT)
print(f"written {OUT}")
```

**Why each part:** the date lives in ONE cell (`B2`) and the subtitle is a FORMULA off it — change B2, subtitle follows. Freeze at `A5` keeps rows 1–4 visible. Column A intentionally narrow/reserved for agent labels later.

**Verify yourself:** open in both Excel and LibreOffice; edit B2 → subtitle recalculates. If LibreOffice chokes on a formula, simplify it — portability is a requirement here, not a nicety.

---

## Task 2 — Daily rows from files

```python
import pandas as pd

inter = pd.read_csv("data_sources/raw/june_2025/Fact_Interactions.csv",
                    parse_dates=["interaction_date"])
ptp   = pd.read_csv("data_sources/raw/june_2025/Fact_PTP_Log.csv",
                    parse_dates=["ptp_date"])
pay   = pd.read_csv("data_sources/raw/june_2025/Fact_Payments.csv",
                    parse_dates=["payment_date"])

daily = pd.DataFrame({
    "Date":     sorted(inter["interaction_date"].dt.normalize().unique()),
}).set_index("Date")
daily["Contacts"] = inter.groupby(inter["interaction_date"].dt.normalize()).size()
daily["Connects"] = inter.groupby(inter["interaction_date"].dt.normalize())["calls_connected"].sum()
daily["RPCs"]     = inter.groupby(inter["interaction_date"].dt.normalize())["rpc_flag"].sum()
daily["Promises"] = ptp.groupby(ptp["ptp_date"].dt.normalize()).size()
daily["Payments"] = pay.groupby(pay["payment_date"].dt.normalize()).size()
daily = daily.fillna(0).astype(int).reset_index()

# ...after Task 1's layout code:
for r in range(len(daily)):
    for c, col in enumerate(daily.columns):
        cell = ws.cell(row=5 + r, column=2 + c, value=daily.iloc[r, c].item())
        if c == 0:
            cell.number_format = "yyyy-mm-dd"
        else:
            cell.number_format = "#,##0"
wb.save(OUT)
```

**Why each part:** aggregation happens in pandas (its job), formatting in openpyxl (its job) — don't fight either. `.item()` converts numpy ints to native Python so openpyxl writes real numbers. Explicit `number_format` beats trusting defaults.

**Verify yourself:** pick any row; compare its six numbers against your python morning pack for that date — exact match required.

---

## Task 3 — NamedStyle polish

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

Apply by assignment (`cell.style = header`) while building rows.

**Why:** NamedStyles are the workbook's design system — change `header` once, every sheet inherits. Two-color discipline: palette blue for identity, white space elsewhere; borders do the separating.

**Verify yourself:** screenshot after opening; hairline grid reads professional, rainbow reads amateur.

---

## Task 4 — Print setup

```python
ws.print_area = f"A1:H{5 + len(daily)}"
ws.page_setup.orientation = "landscape"
ws.page_setup.fitToWidth  = 1
ws.page_setup.fitToHeight = 0          # as many pages tall as needed
ws.sheet_properties.pageSetUpPr.fitToPage = True
ws.print_title_rows = "4:4"            # repeat header row on every page
```

**Why each part:** `fitToWidth=1` guarantees columns never split across pages; `print_title_rows` re-prints your styled header — the two settings people always forget until the boardroom print fails.

**Verify yourself:** File → Print preview screenshot into `work/`.

---

## Task 5 — Live XLOOKUP names

```python
# Sheet 'AgentLookup':
ws_lu = wb.create_sheet("AgentLookup")
emps = pd.read_csv("data_sources/raw/shared/Dim_Employees.csv", dtype="string")[["agent_id","agent_name"]]
ws_lu.append(["AgentID", "Name"])
for _, r in emps.iterrows():
    ws_lu.append([r.agent_id, r.agent_name])
n_rows = len(emps) + 1

# On Daily sheet: Agent ID in col A (typed or pasted), name formula in col I:
for r in range(5, 5 + len(daily)):
    ws.cell(row=r, column=1,
            value=f'=IFNA(XLOOKUP(A{r},AgentLookup!$A$2:$A${n_rows},AgentLookup!$B$2:$B${n_rows}),"—")')
```

**Why each part:** the FORMULA lives in the cell — python never pre-fills names — so editing an ID recalculates live. `IFNA` turns misses into an em-dash instead of an error wall.

**Verify yourself:** change one ID to garbage → shows `—`, not #N/A. Change to a valid other ID → name updates. Note: older Excel versions lack XLOOKUP — fallback documented in comments (`INDEX/MATCH`) for compatibility.

---

## Task 6 — Validation dropdowns

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

**Why each part:** validation sourced from a PARAMETERS RANGE (not a literal list) means adding a team updates dropdowns without touching code. `showErrorMessage` is what makes typing garbage actually refuse.

**Verify yourself:** type "Free Texxt" in J5 → refused with your title/message. Free-type cells (notes columns) deliberately left unvalidated — document which and why.
