# Excel Medium — Results (worked solutions)

**Philosophy:** Phase A (Tasks 1–9) is solved manually in **LibreOffice Calc** — that is the skill. Phase B (Tasks 10–13) rebuilds the same pack with `openpyxl` — that is the speed layer. Read a section only after you have attempted its task.

**Calc syntax:** the manual formulas below use semicolons (`;`) because that is LibreOffice's argument separator. The Python strings use commas (`,`) because they are written for Excel's file format.

---

## ═══ PHASE A — MANUAL (LibreOffice Calc) ═══

---

## Task 1 — Create the project structure and recreate the source data

### Folder layout

```bash
mkdir -p learning/excel/medium/data
mkdir -p learning/excel/medium/work/scripts
mkdir -p learning/excel/medium/work/exports
```

`.gitignore` already ignores `learning/excel/medium/data/` and `learning/**/work/*`. Your exports and scratch workbooks stay local by design.

### Manual/SQL version

Start the DB from the project root, then connect to `MIS_CollectionsDB` on `localhost:5433` with the credentials in `.env`.

```sql
-- data/raw_employee.csv
SELECT agent_id, agent_name, team_name
FROM dim_employees
WHERE is_current = TRUE
ORDER BY agent_id;
```

```sql
-- data/raw_daily_mis_team.csv
WITH activity AS (
    SELECT i.interaction_date AS date,
           e.team_name        AS team,
           COUNT(*)           AS contacts,
           SUM(COALESCE(i.calls_connected, 0)) AS connects,
           COUNT(*) FILTER (WHERE i.rpc_flag)  AS rpcs
    FROM fact_interactions i
    JOIN dim_employees e ON e.agent_id = i.agent_id
    GROUP BY 1, 2
),
promises AS (
    SELECT p.ptp_date AS date, e.team_name AS team,
           COUNT(*) AS promises,
           COUNT(*) FILTER (WHERE p.status = 'Kept')   AS kept,
           COUNT(*) FILTER (WHERE p.status = 'Broken') AS broken
    FROM fact_ptp_log p
    JOIN dim_employees e ON e.agent_id = p.agent_id
    GROUP BY 1, 2
),
payments AS (
    SELECT pay.payment_date AS date, e.team_name AS team, COUNT(*) AS payments
    FROM fact_payments pay
    JOIN dim_employees e ON e.agent_id = pay.agent_id
    GROUP BY 1, 2
)
SELECT COALESCE(a.date, pr.date, pa.date) AS "Date",
       COALESCE(a.team, pr.team, pa.team) AS "Team",
       COALESCE(a.contacts, 0)   AS "Contacts",
       COALESCE(a.connects, 0)   AS "Connects",
       COALESCE(a.rpcs, 0)       AS "RPCs",
       COALESCE(pr.promises, 0)  AS "Promises",
       COALESCE(pa.payments, 0)  AS "Payments",
       COALESCE(pr.kept, 0)      AS "Kept",
       COALESCE(pr.broken, 0)    AS "Broken"
FROM activity a
FULL OUTER JOIN promises pr
    ON pr.date = a.date AND pr.team = a.team
FULL OUTER JOIN payments pa
    ON pa.date = COALESCE(a.date, pr.date)
   AND pa.team = COALESCE(a.team, pr.team)
ORDER BY 1, 2;
```

**Why FULL OUTER JOIN:** the three facts do not share days. A promise-only or payment-only day must still appear, otherwise your monthly totals silently lose rows. `COALESCE` is what makes that safe.

### File-side fallback (same output, no DB)

```python
import glob
import pandas as pd

EMP = "data_sources/raw/shared/Dim_Employees.csv"
OUT = "learning/excel/medium/data/raw_daily_mis_team.csv"

emp = pd.read_csv(EMP, usecols=["agent_id", "team_name", "is_current"])
emp = emp[emp["is_current"] == True]

frames = []
for month in sorted(glob.glob("data_sources/raw/*_2025")):
    inter = pd.read_csv(f"{month}/Fact_Interactions.csv", parse_dates=["interaction_date"])
    ptp = pd.read_csv(f"{month}/Fact_PTP_Log.csv", parse_dates=["ptp_date"])
    pay = pd.read_csv(f"{month}/Fact_Payments.csv", parse_dates=["payment_date"])

    inter = inter.merge(emp[["agent_id", "team_name"]], on="agent_id")
    ptp = ptp.merge(emp[["agent_id", "team_name"]], on="agent_id")
    pay = pay.merge(emp[["agent_id", "team_name"]], on="agent_id")

    a = (inter.groupby(["interaction_date", "team_name"])
               .agg(Contacts=("interaction_id", "size"),
                    Connects=("calls_connected", "sum"),
                    RPCs=("rpc_flag", "sum")).reset_index()
               .rename(columns={"interaction_date": "Date", "team_name": "Team"}))
    p = (ptp.groupby(["ptp_date", "team_name"])
             .agg(Promises=("ptp_id", "size"),
                  Kept=("status", lambda s: (s == "Kept").sum()),
                  Broken=("status", lambda s: (s == "Broken").sum()))
             .reset_index()
             .rename(columns={"ptp_date": "Date", "team_name": "Team"}))
    q = (pay.groupby(["payment_date", "team_name"]).size()
            .rename("Payments").reset_index()
            .rename(columns={"payment_date": "Date", "team_name": "Team"}))
    frames.append(a.merge(p, how="outer", on=["Date", "Team"])
                   .merge(q, how="outer", on=["Date", "Team"]))

out = pd.concat(frames).fillna(0)
out["RPCs"] = out["RPCs"].astype(int)
out.sort_values(["Date", "Team"]).to_csv(OUT, index=False)
```

**Why the fallback re-derives instead of copying `learning/excel/basic/data/`:** Basic exported daily activity only. Medium needs a team dimension and a promise/payment split, so a copy would be the wrong shape even if the numbers overlapped.

**Verify yourself:** open the CSV in Calc with **Comma** + **Detect special numbers**. Dates must be right-aligned (real dates), the last date `2025-12-31`, and `Team 1` … `Team 8` must appear. Sort by Team and count eight groups. Sum `Promises` and compare with a direct `SELECT COUNT(*) FROM fact_ptp_log` for 2025 — the difference should only be payments/promises with a null `agent_id` (self-cures, not team-attributable).

**Traps & alternatives:** `dim_employees` is the **current-state** table (one row per agent), so `is_current = TRUE` is a safe guard but not a de-duplicator. History lives in `dim_employee_history`; joining that here would multiply rows for the six transferred agents. And do not `GROUP BY` day + team and then join raw facts at the end; it multiplies promise and payment counts (this is the duplicate-row trap the CTEs exist to avoid).

---

## Task 2 — Build the workbook shell from scratch

### Manual steps (LibreOffice Calc)

1. **File → New → Spreadsheet**.
2. **File → Save As** → `learning/excel/medium/work/daily_mis_medium.xlsx` → file type **Excel 2007–365 (.xlsx)** → **Use Excel 2007–365 Format**.
3. Rename `Sheet1` → `Cover` (right-click tab → **Rename Sheet**).
4. On `Cover`:

   | Cell | Value | Format |
   |---|---|---|
   | `A1` | `Collections Daily MIS` | 16 pt bold, `#262A76` |
   | `A2` | `="Report for "&TEXT(B2;"yyyy-mm-dd")` | italic |
   | `B2` | `2025-06-30` | `yyyy-mm-dd` |
   | `A4` / `B4` | `Owner:` / your name | — |
   | `A5` / `B5` | `Generated:` / `=NOW()` | `yyyy-mm-dd hh:mm` |
   | `A7` | `How to use this pack` | bold |
   | `A8:A13` | one line per tab | — |

5. Insert the remaining sheets in order: `Data`, `Summary`, `Parameters`, `AgentLookup`, `ChangeLog`.
6. Tab colours: blue `#262A76` for `Data`/`Summary`/`AgentLookup`, grey `#808080` for `Cover`/`Parameters`/`ChangeLog`.
7. Freeze header rows: click `A2`, **View → Freeze Rows and Columns** (on `Data`, `Summary`, `AgentLookup`, `ChangeLog`).
8. **Format → Columns → Optimal Width** on the used columns.

**Why each part:** the Cover is a contract with the next reader. Coloured tabs encode "data" versus "governance" without a legend. Freezing row 1 means the header survives scrolling, which is the difference between a table and a wall of numbers.

**Verify yourself:** change `B2` to `2025-12-31`; `A2` must immediately read `Report for 2025-12-31`. Restore it. Click every tab and confirm the order matches the task.

**Traps & alternatives:** saving as `.ods` first and converting later loses some Excel-specific formatting. Save as `.xlsx` from the start and always confirm the **Use Excel 2007–365 Format** dialog.

---

## Task 3 — Import the data and create named ranges

### Manual steps

1. Open `data/raw_daily_mis_team.csv` in Calc → import dialog: **Comma**, tick **Detect special numbers**.
2. `Ctrl+A`, `Ctrl+C`.
3. In your workbook: `Data!A1`, `Ctrl+V`. Headers land in row 1: `Date, Team, Contacts, Connects, RPCs, Promises, Payments, Kept, Broken`.
4. `J1` = `Month`; `J2`:

   ```
   =DATE(YEAR(A2);MONTH(A2);1)
   ```

   Fill down to the last data row (double-click the fill handle).
5. Formats: `A` → `yyyy-mm-dd`, `J` → `yyyy-mm`, `C:I` → `#,##0`.
6. **Sheet → Named Ranges and Expressions → Define**, then add:

   | Name | Range |
   |---|---|
   | `tblDate` | `$Data.$A$2:$A$10000` |
   | `tblTeam` | `$Data.$B$2:$B$10000` |
   | `tblContacts` | `$Data.$C$2:$C$10000` |
   | `tblConnects` | `$Data.$D$2:$D$10000` |
   | `tblRPCs` | `$Data.$E$2:$E$10000` |
   | `tblPromises` | `$Data.$F$2:$F$10000` |
   | `tblPayments` | `$Data.$G$2:$G$10000` |
   | `tblKept` | `$Data.$H$2:$H$10000` |
   | `tblBroken` | `$Data.$I$2:$I$10000` |
   | `tblMonth` | `$Data.$J$2:$J$10000` |

**Why each part:** named ranges are Calc's substitute for structured table references. They keep formulas range-free when rows are appended, and the 10,000-row ceiling costs nothing because the ranges are mostly empty.

**Verify yourself:** in an empty cell `=SUM(tblPromises)` must equal the total of column `F`; `=COUNTA(tblTeam)` must equal the number of data rows. Delete the test cells.

**Traps & alternatives:** defining `tblMonth` over `$H$2:$H$10000` while only filling `H` down to the last row is fine — `SUMIFS` ignores blanks. Do **not** define the names as absolute single cells; the whole point is that they grow.

---

## Task 4 — Write the SUMIFS monthly summary

### Manual steps

1. `Summary!A1` = `Monthly Summary`, bold 14 pt.
2. Row 4 headers: `Month, Contacts, Connects, RPCs, RPC %, Promises, Payments, KP %, Promises Δ MoM`.
3. `A5` = `2025-01-01`, `A6` = `2025-02-01`, select both, drag to `A16`. Format `A5:A16` as `yyyy-mm`.
4. Formulas, then fill down:

   ```
   B5  =SUMIFS(tblContacts;tblMonth;$A5)
   C5  =SUMIFS(tblConnects;tblMonth;$A5)
   D5  =SUMIFS(tblRPCs;tblMonth;$A5)
   E5  =IFERROR(D5/C5;0)          format 0.0%
   F5  =SUMIFS(tblPromises;tblMonth;$A5)
   G5  =SUMIFS(tblPayments;tblMonth;$A5)
   H5  =IFERROR(SUMIFS(tblKept;tblMonth;$A5)/
                (SUMIFS(tblKept;tblMonth;$A5)+SUMIFS(tblBroken;tblMonth;$A5));0)
                                   format 0.0%
   I6  =F6-F5                     format +#,##0;-#,##0;0
   ```

**Why each part:** `SUMIFS` lets the month column carry the whole comparison, so no start/end date arithmetic and no hardcoded month boundaries. `IFERROR(...,0)` keeps an empty month readable. KP% uses resolved promises only: Kept ÷ (Kept + Broken), so `Pending` cannot dilute the rate. The delta is a plain subtraction — the number format does the sign decoration.

**Verify yourself:** add `100` to one `Promises` cell on `Data`. The month's `F` and the next month's `I` must both move. `=SUM(tblPromises)` must equal `=SUM(F5:F16)`. Recompute one `H` cell by hand and confirm it matches.

**Traps & alternatives:** `I5` is deliberately empty — the first month has no prior month. Do not "fix" that with a `0`; it would read as a real delta of zero. The `$A5` anchor is relative in the row so it fills correctly; using `$A$5` everywhere would freeze every month to January.

---

## Task 5 — Add RAG conditional formatting from Parameters

### Manual steps

1. On `Parameters`:

   | Cell | Value |
   |---|---|
   | `A1` | `Team` |
   | `A2:A9` | `Team 1` … `Team 8` |
   | `D1` | `Threshold` |
   | `D2` / `E2` | `KP% amber` / `0.68` (format `0.0%`) |
   | `D3` / `E3` | `KP% green` / `0.80` (format `0.0%`) |

2. Select `Summary!H5:H16` → **Format → Conditional → Manage → Add**.
3. Green: **Cell value is → greater than or equal to → `$Parameters.$E$3`**, background `#00B050`, font white.
4. Amber: **Cell value is → between → `$Parameters.$E$2` and `$Parameters.$E$3`**, background `#FFC000`.
5. Red: **Cell value is → less than → `$Parameters.$E$2`**, background `#FF0000`, font white.
6. **Move Up** so green is evaluated first.
7. Test: `E3` → `0.90` repaints almost everything; restore to `0.80`.

**Why each part:** the rules point at a cell, not at a literal, so the threshold is a business decision stored next to the team list — not a code change. Green-first ordering matters: Calc evaluates rules in order and the first match wins. The 0.68 amber bound is the project rule: amber starts at 85% of the 80% KP goal.

**Verify yourself:** set both thresholds to `0` → every KP% cell goes green. Restore `0.68` and `0.80`. Change one `Data` kept/broken count to push a month below `0.68` and confirm it turns red.

**Traps & alternatives:** KP% is stored as a decimal (`0.80`), so thresholds must be decimals. Typing `68` makes every cell red and looks "buggy" when the formula is actually correct. In Excel the range reference would read `$E$3` (same sheet) or `Parameters!$E$3`; Calc's `$Parameters.$E$3` is the inter-sheet form.

---

## Task 6 — Build a PivotTable from Data

### Manual steps

1. `Data!A1:J{last row}` → **Insert → Pivot Table**.
2. Source **Current Selection**, destination **New Sheet** → OK → rename `PivotMonthly`.
3. Layout:

   - `Month` → **Row Fields**
   - `Team` → **Row Fields** (below Month)
   - `Promises` → **Data Fields** (`Sum - Promises`)
   - `Payments` → **Data Fields** (`Sum - Payments`)
   - `Team` → **Page Fields**

4. Change one `Payments` value on `Data`, right-click the pivot → **Refresh** (or **Data → Refresh Range**).

**Why each part:** the pivot is a cached snapshot, not a live formula. Page Fields are Calc's filter mechanism; dragging `Team` there is the equivalent of an Excel slicer. Months and teams as nested rows give the director drill-down without a new sheet per filter.

**Verify yourself:** the pivot's grand total for Promises equals `=SUM(tblPromises)`. Filter to `Team 1` and confirm the total drops. Refresh after editing `Data` and confirm the change appears.

**Traps & alternatives:** the pivot does not extend when you paste more rows into `Data` — the source range is fixed at creation. Re-select the range or rebuild the pivot. This is exactly why the Excel Table / named-range habit exists.

---

## Task 7 — Add a chart and a team filter on a Dashboard sheet

### Manual steps

1. Click inside `PivotMonthly` (not the page field) → **Insert → Chart** → **Column** or **Line** → **Finish**.
2. Right-click chart → **Cut**.
3. Insert sheet `Dashboard` → click `A1` → **Paste**.
4. Resize the chart so labels are legible.
5. Filter with the `Team` Page Field on `PivotMonthly`, then **Data → Refresh Range**.

**Why each part:** a chart built from a pivot is not a screenshot — it re-renders from the pivot cache, so the filter flows through. Putting it on a separate `Dashboard` sheet separates "read" from "maintain".

**Verify yourself:** `Team 1` → note the highest month; `Team 2` → the chart changes; clear the filter → the full series returns.

**Traps & alternatives:** Calc has no slicer. A slicer is a clickable filter wired to one or more pivots; the Page Field is the single-pivot equivalent. Saying that out loud is the point of the task — the UI differs, the concept does not. Copying the chart (rather than cutting) leaves two linked copies and one confused analyst later.

---

## Task 8 — Refresh the pack from the CSV

### Manual steps

1. Insert sheet `RawRefresh`.
2. **Sheet → Link to External Data** → browse to `data/raw_daily_mis_team.csv` → OK through the import options.
3. Edit one `Contacts` value in the CSV (text editor), save.
4. Back in Calc: **Data → Refresh Range**; then refresh the pivot.
5. Write the routine on `Cover`: "After replacing the CSV: Data → Refresh Range, then refresh the pivot."

**Why each part:** a link is a pointer, not a paste. That is the same conceptual gap as Power Query: source changes, workbook refreshes, nobody retypes numbers. Calc can link and refresh but cannot replay transformation steps.

**Verify yourself:** set a CSV `Contacts` value from `0` to `999`, refresh, and watch the linked cell and pivot total move. Set it back and refresh again.

**Traps & alternatives:** if the link dialog fails (locale/CSV quoting), re-paste the data over the existing range and refresh the pivot. The lesson survives; only the mechanism changes. Do not edit the linked range in Calc — it is overwritten on the next refresh.

---

## Task 9 — Set up printing and export a PDF

### Manual steps

1. `Summary!A1:I16` → **Format → Print Ranges → Define**.
2. **Format → Page Style → Page**: Landscape, scaling **Fit print range(s) on number of pages**, Width `1`, Height `0`.
3. **Format → Print Ranges → Edit → Rows to repeat**: `$4:$4`.
4. Repeat for `Data`: range `A1:J{last row}`, rows to repeat `$1:$1`.
5. **File → Export as PDF** → `learning/excel/medium/work/exports/daily_mis_medium.pdf`.
6. Open the PDF and inspect every page.

**Why each part:** fit-to-width stops a KPI column being split mid-number; repeating rows stop page 2 becoming an unlabeled grid. Both are print settings, not data settings — which is why they are forgotten until the boardroom.

**Verify yourself:** the header row appears on page 1 and every later page; no column is split; Summary fits one page wide; the PDF opens at all.

**Traps & alternatives:** `Height = 0` means "as many pages as needed" in Calc's fit dialog — setting it to `1` squeezes the whole year onto one unreadable page. Print ranges can overlap; define Summary and Data separately.

---

## ═══ PHASE B — AUTOMATION (Python + openpyxl) ═══

> openpyxl cannot create a PivotTable, a chart, or a Power Query connection. The script produces a clean, pivot-ready workbook; the pivot and dashboard stay manual. That limitation is a fact to document, not to work around.

---

## Task 10 — Set up openpyxl and generate the shell

```bash
python --version
python -m pip install openpyxl
```

`work/scripts/build_shell.py`:

```python
from pathlib import Path

from openpyxl import Workbook
from openpyxl.styles import Font

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "work" / "daily_mis_auto.xlsx"
OUT.parent.mkdir(parents=True, exist_ok=True)

wb = Workbook()
wb.remove(wb.active)

for name in ["Cover", "Data", "Summary", "Parameters",
             "AgentLookup", "ChangeLog"]:
    wb.create_sheet(name)

cover = wb["Cover"]
cover["A1"] = "Collections Daily MIS"
cover["A1"].font = Font(size=16, bold=True, color="262A76")
cover["B2"] = "2025-06-30"
cover["B2"].number_format = "yyyy-mm-dd"
cover["A2"] = '="Report for "&TEXT(B2,"yyyy-mm-dd")'
cover["A2"].font = Font(italic=True)
cover["A4"], cover["B4"] = "Owner:", "Your Name"
cover["A5"], cover["B5"] = "Generated:", "=NOW()"
cover["B5"].number_format = "yyyy-mm-dd hh:mm"
cover["A7"] = "How to use this pack"
for i, line in enumerate([
        "Data — the only place raw daily values live",
        "Summary — monthly totals, RPC% and KP%",
        "Parameters — teams and RAG thresholds",
        "AgentLookup — agent ID to name",
        "ChangeLog — every shipped edit is recorded here"], start=8):
    cover[f"A{i}"] = line

for name, color in {"Cover": "808080", "Data": "262A76", "Summary": "262A76",
                    "Parameters": "808080", "AgentLookup": "262A76",
                    "ChangeLog": "808080"}.items():
    wb[name].sheet_properties.tabColor = color

cover.column_dimensions["A"].width = 46
cover.column_dimensions["B"].width = 22

wb.save(OUT)
print(f"Saved {OUT}")
```

**Why each part:** `parents[2]` resolves from `work/scripts/` to `learning/excel/medium/`, so the script runs from any working directory. `wb.remove(wb.active)` removes the default `Sheet` instead of leaving an unnamed orphan. `tabColor` expects the bare hex, no `#`.

**Verify yourself:** run it twice — the second run overwrites cleanly. Open the file in Calc, change `B2`, and confirm `A2` recalculates. The six tabs appear in order.

**Traps & alternatives:** openpyxl writes formulas as text; Calc computes them on open (`Ctrl+Shift+F9` forces a recalc if needed). Do not use `Path.cwd()` for `ROOT` — the script is meant to be run from the project root *and* from elsewhere.

---

## Task 11 — Automate Data, named ranges, Summary, and RAG

Copy `build_shell.py` → `build_pack.py`, then add:

```python
import pandas as pd
from openpyxl.formatting.rule import CellIsRule
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.workbook.defined_name import DefinedName

DATA_CSV = ROOT / "data" / "raw_daily_mis_team.csv"
df = pd.read_csv(DATA_CSV, parse_dates=["Date"])
df["Month"] = df["Date"].values.astype("datetime64[M]")

ws_d = wb["Data"]
ws_d.append(["Date", "Team", "Contacts", "Connects", "RPCs",
             "Promises", "Payments", "Kept", "Broken", "Month"])
for _, row in df.iterrows():
    ws_d.append([row["Date"].to_pydatetime(), row["Team"],
                 int(row["Contacts"]), int(row["Connects"]), int(row["RPCs"]),
                 int(row["Promises"]), int(row["Payments"]),
                 int(row["Kept"]), int(row["Broken"]),
                 row["Month"].to_pydatetime()])

last = ws_d.max_row
for r in range(2, last + 1):
    ws_d[f"A{r}"].number_format = "yyyy-mm-dd"
    ws_d[f"J{r}"].number_format = "yyyy-mm"
    for col in "CDEFGHI":
        ws_d[f"{col}{r}"].number_format = "#,##0"

ws_d.freeze_panes = "A2"
for col, width in {"A": 12, "B": 10, "C": 11, "D": 11,
                   "E": 9, "F": 11, "G": 11, "H": 9,
                   "I": 9, "J": 10}.items():
    ws_d.column_dimensions[col].width = width

for name, col in {"tblDate": "A", "tblTeam": "B", "tblContacts": "C",
                  "tblConnects": "D", "tblRPCs": "E", "tblPromises": "F",
                  "tblPayments": "G", "tblKept": "H", "tblBroken": "I",
                  "tblMonth": "J"}.items():
    wb.defined_names.add(DefinedName(
        name, attr_text=f"Data!${col}$2:${col}$10000"))
```

```python
ws_s = wb["Summary"]
ws_s["A1"] = "Monthly Summary"
ws_s["A1"].font = Font(size=14, bold=True, color="262A76")

head = ["Month", "Contacts", "Connects", "RPCs", "RPC %",
        "Promises", "Payments", "KP %", "Promises Δ MoM"]
for c, text in enumerate(head, start=1):
    cell = ws_s.cell(row=4, column=c, value=text)
    cell.font = Font(bold=True, color="FFFFFF")
    cell.fill = PatternFill("solid", fgColor="262A76")
    cell.alignment = Alignment(horizontal="center")

months = pd.date_range("2025-01-01", periods=12, freq="MS")
formula_cols = {"B": "tblContacts", "C": "tblConnects", "D": "tblRPCs",
                "F": "tblPromises", "G": "tblPayments"}
for i, month in enumerate(months, start=5):
    ws_s[f"A{i}"] = month.to_pydatetime()
    ws_s[f"A{i}"].number_format = "yyyy-mm"
    for col, name in formula_cols.items():
        ws_s[f"{col}{i}"] = f"=SUMIFS({name},tblMonth,$A{i})"
    ws_s[f"E{i}"] = f"=IFERROR(D{i}/C{i},0)"
    ws_s[f"E{i}"].number_format = "0.0%"
    ws_s[f"H{i}"] = (
        f"=IFERROR(SUMIFS(tblKept,tblMonth,$A{i})/"
        f"(SUMIFS(tblKept,tblMonth,$A{i})+SUMIFS(tblBroken,tblMonth,$A{i})),0)")
    ws_s[f"H{i}"].number_format = "0.0%"
    if i > 5:
        ws_s[f"I{i}"] = f"=F{i}-F{i-1}"
        ws_s[f"I{i}"].number_format = "+#,##0;-#,##0;0"

ws_s.freeze_panes = "A5"
ws_s.column_dimensions["A"].width = 12
for col in "BCDEFGHI":
    ws_s.column_dimensions[col].width = 14
```

```python
ws_p = wb["Parameters"]
ws_p["A1"] = "Team"
for i, team in enumerate(sorted(df["Team"].unique()), start=2):
    ws_p[f"A{i}"] = team
ws_p["D1"] = "Threshold"
ws_p["D2"], ws_p["E2"] = "KP% amber", 0.68
ws_p["E2"].number_format = "0.0%"
ws_p["D3"], ws_p["E3"] = "KP% green", 0.80
ws_p["E3"].number_format = "0.0%"

rng = "H5:H16"
ws_s.conditional_formatting.add(rng, CellIsRule(
    operator="greaterThanOrEqual", formula=["Parameters!$E$3"],
    fill=PatternFill("solid", fgColor="00B050")))
ws_s.conditional_formatting.add(rng, CellIsRule(
    operator="between", formula=["Parameters!$E$2", "Parameters!$E$3"],
    fill=PatternFill("solid", fgColor="FFC000")))
ws_s.conditional_formatting.add(rng, CellIsRule(
    operator="lessThan", formula=["Parameters!$E$2"],
    fill=PatternFill("solid", fgColor="FF0000")))

wb.save(OUT)
```

**Why each part:** `DefinedName` is the file-format home of the manual named ranges; the same names make the generated SUMIFS identical to the typed ones. Conditional-formatting formulas are stored with Excel's `Parameters!` sheet syntax even when the file is opened in Calc. Thresholds are written as decimals to match `RPC %` being a `DIVIDE`.

**Verify yourself:** `=SUM(tblPromises)` equals `=SUM(F5:F16)`. Change `Parameters!E3` to `0.90` and watch the repaint. Compare one month's five totals with the manual workbook — they must match exactly.

**Traps & alternatives:** `df["Date"].values.astype("datetime64[M]")` yields a `datetime64` column; converting with `.to_pydatetime()` before writing stops openpyxl storing a numpy type. If you see `#NAME?` on the SUMIFS, your defined names were not saved — check `wb.defined_names` before saving.

---

## Task 12 — Automate lookups, validation, ChangeLog, and print setup

```python
emp = pd.read_csv(ROOT / "data" / "raw_employee.csv")
ws_l = wb["AgentLookup"]
ws_l.append(["AgentID", "Name"])
for _, row in emp.iterrows():
    ws_l.append([row["agent_id"], row["agent_name"]])
ws_l.freeze_panes = "A2"
ws_l.column_dimensions["A"].width = 14
ws_l.column_dimensions["B"].width = 32

ws_d["L4"], ws_d["M4"] = "Agent ID", "Name (VLOOKUP)"
ws_d["L5"] = "EID-001"
ws_d["M5"] = '=IFERROR(VLOOKUP(L5,AgentLookup!$A$2:$B$89,2,FALSE),"—")'
```

```python
from openpyxl.worksheet.datavalidation import DataValidation

dv = DataValidation(type="list", formula1="Parameters!$A$2:$A$9",
                    allow_blank=True, showErrorMessage=True,
                    errorTitle="Invalid team",
                    error="Pick a team from the list.")
ws_d.add_data_validation(dv)
dv.add(f"B2:B{last}")
```

```python
ws_cl = wb["ChangeLog"]
ws_cl.append(["Date", "Author", "Sheet/Range", "What changed", "Why"])
ws_cl.append(["2025-08-25", "Your Name", "Summary!I5:I16",
              "Added MoM delta column", "Ops asked for direction at a glance"])
ws_cl.append(["2025-08-25", "Your Name", "Parameters!E2:E3",
              "Set KP% thresholds", "Strategy calibration"])
ws_cl.append(["2025-08-26", "Your Name", "Data!C5",
              "Fixed a paste error caught by reconciliation",
              "Workbook must agree with the source"])
for cell in ws_cl[1]:
    cell.font = Font(bold=True, color="FFFFFF")
    cell.fill = PatternFill("solid", fgColor="262A76")

for ws in wb.worksheets:
    ws.page_setup.orientation = "landscape"
    ws.page_setup.fitToWidth = 1
    ws.page_setup.fitToHeight = 0
    ws.sheet_properties.pageSetUpPr.fitToPage = True
    ws.print_title_rows = "1:1"

ws_s.print_title_rows = "4:4"
ws_s.print_area = "A1:I16"

wb.save(OUT)
```

```bash
python learning/excel/medium/work/scripts/build_pack.py
soffice --headless --convert-to pdf --outdir learning/excel/medium/work/exports learning/excel/medium/work/daily_mis_auto.xlsx
```

**Why each part:** the lookup is a formula in the cell, not a pre-filled name — editing `L5` must update `M5`, which is the whole point of the drill. VLOOKUP is used because it works in every Calc version; XLOOKUP needs Calc 24.8+. `print_title_rows = "1:1"` is applied to all sheets and then overridden for Summary, which has a two-row title block.

**Verify yourself:** type `Free Texxt` into a `Data` team cell → refused with your message. Change `L5` to `EID-042` → the name updates. Change it to garbage → `—`. Open the PDF: landscape, one page wide, header repeats.

**Traps & alternatives:** the lookup range `$A$2:$B$89` is a fixed guess. Compute it from `emp.shape[0] + 1` so it follows the roster. Data validation renders in Calc as a dropdown arrow; the `showErrorMessage` flag is what makes an invalid paste fail rather than pass silently. openpyxl cannot author VBA or Power Query — the PDF step is the honest automation boundary.

---

## Task 13 — Reconcile against the source and do the final review

```python
import csv

from openpyxl import load_workbook


def reconcile(date_text, team, out=OUT):
    with open(ROOT / "data" / "raw_daily_mis_team.csv", newline="") as f:
        source = next(r for r in csv.DictReader(f)
                      if r["Date"] == date_text and r["Team"] == team)

    wb = load_workbook(out, data_only=True)
    ws = wb["Data"]
    sheet = None
    for row in ws.iter_rows(min_row=2, values_only=True):
        if row[0] and row[0].strftime("%Y-%m-%d") == date_text and row[1] == team:
            sheet = {
                "Contacts": row[2], "Connects": row[3], "RPCs": row[4],
                "Promises": row[5], "Payments": row[6],
                "Kept": row[7], "Broken": row[8],
            }
            break

    if sheet is None:
        print(f"FAIL {date_text} / {team}: row not found in workbook")
        return False

    for key, value in sheet.items():
        expected = int(source[key])
        if value != expected:
            print(f"FAIL {key}: sheet={value} source={expected}")
            return False
    print(f"PASS {date_text} / {team}: all seven metrics match")
    return True


reconcile("2025-06-02", "Team 1")
```

**Why each part:** `data_only=True` reads cached values, so the check compares numbers rather than formula text. Comparing all seven metrics catches the classic paste error that changes one column only. A `FAIL` is a finding to explain — never a line to delete.

**Verify yourself:** the script prints `PASS 2025-06-02 / Team 1`. Edit one `Data` cell in the saved workbook, rerun, and see `FAIL` with the metric name. Restore and rerun for `PASS`.

**Traps & alternatives:** if `data_only=True` returns `None`, the workbook was written by openpyxl and never opened by a spreadsheet application — there are no cached values yet. Open/save it once, or reconcile against the CSV directly. `next(...)` raises `StopIteration` when the date/team pair does not exist; catch it and report "row missing" rather than a traceback.

**Final review:** all ten boxes on the Task 13 checklist should be true. The two honest questions from the finish section — can you rebuild the manual workbook from blank, and can you explain every formula and rule — are the exit criteria, not the script.
