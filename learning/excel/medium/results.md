# Excel Medium — Results (worked solutions)

Extend your basic script into `daily_mis_pack.py`. Run → OPEN → poke cells → confirm recalc.

---

## Task 1 — One producer, many consumers

Layout contract: sheet `Data` = flat table starting A4 (headers) with columns Date · Team · Contacts · Connects · RPCs · Promises · Payments. Everything else references it.

```python
from openpyxl.worksheet.table import Table, TableStyleInfo

ws_d = wb.create_sheet("Data")
ws_d.append(["Date", "Team", "Contacts", "Connects", "RPCs", "Promises", "Payments"])
for _, r in data_df.iterrows():          # data_df: daily × team aggregation
    ws_d.append(list(r))
tbl = Table(displayName="tblDaily", ref=f"A4:G{4+len(data_df)}")
tbl.tableStyleInfo = TableStyleInfo(name="TableStyleMedium2", showRowStripes=True)
ws_d.add_table(tbl)
```

**Why each part:** a real Excel TABLE gives structured references (`tblDaily[RPCs]`) that survive row growth — consumer formulas never need range surgery when next month adds rows.

**Verify yourself:** add a dummy row under the table in Excel; it auto-joins the table and every SUMIFS downstream moves. Delete the dummy; re-verify.

---

## Task 2 — Live rollup organs

```python
ws_s = wb.create_sheet("Summary")
ws_s["A1"] = "Monthly rollup"; ws_s["A1"].style = title
hdrs = ["Month", "Contacts", "Connects", "RPCs", "RPC %", "Δ vs prior month"]
# months listed down col A as real dates (first of month), then:
for r, mrow in enumerate(month_rows, start=5):
    ws_s.cell(row=r, column=2,
        value=f'=SUMIFS(tblDaily[Contacts],tblDaily[Date],">="&A{r},tblDaily[Date],"<"&EDATE(A{r},1))')
    # ...repeat per KPI column...
    ws_s.cell(row=r, column=5,
        value=f'=IFERROR(D{r}/C{r},"")')                      # RPC %
    if r > 5:
        ws_s.cell(row=r, column=6,
            value=f'=TEXT(D{r}-D{r-1},"+0;-0;±0")')
```

**Why each part:** SUMIFS bounded by `EDATE` month windows reads naturally AND handles partial months. The Δ uses TEXT's "+0;-0;±0" format for sign-aware display without helper columns.

**Verify yourself:** nudge one Data value ±100 in its month → month total and delta move; check against a hand count.

---

## Task 3 — Formula-driven RAG

Parameters first:

```python
ws_p.cell(row=1, column=4, value="RAG thresholds"); 
ws_p["D2"]="RPC% low amber"; ws_p["E2"]=35
ws_p["D3"]="RPC% green";      ws_p["E3"]=45
```

Conditional formatting via openpyxl:

```python
from openpyxl.formatting.rule import CellIsRule, FormulaRule

rng = f"F5:F{4+len(data_df)}"     # RPC % column on Summary
ws_s.conditional_formatting.add(rng, CellIsRule(
    operator="greaterThanOrEqual", formula=["$E$3"],
    fill=PatternFill("solid", fgColor="00B050")))
ws_s.conditional_formatting.add(rng, CellIsRule(
    operator="between",
    formula=[f"$E$2", "$E$3"],
    fill=PatternFill("solid", fgColor="FFC000")))
ws_s.conditional_formatting.add(rng, CellIsRule(
    operator="lessThan", formula=["$E$2"],
    fill=PatternFill("solid", fgColor="FF0000")))
```

For share-of-total style rules use FormulaRule with relative refs (`=F5/$F$4>=0.8`).

**Why each part:** rules point at `$E$2/$E$3` — strategy tunes thresholds ON the Parameters sheet; zero code changes, instant repaint. Hexes match the project RAG standard.

**Verify yourself:** set E3 to 90 → nearly everything reds/greens shift; restore. Screenshot before/after saved.

---

## Task 4 — Print polish + PDF export

openpyxl sets page setup (as basic Task 4); PDF needs an engine — documented options:

```python
# Option A (Windows + Excel installed): COM automation
from win32com import client as win32_client   # pywin32
excel = win32_client.Dispatch("Excel.Application")
wbx = excel.Workbooks.Open(str(OUT.resolve()))
ws_print = wbx.Worksheets("Daily")
ws_print.ExportAsFixedFormat(0, str(OUT.with_name("daily_mis.pdf")))  # 0 = PDF
wbx.Close(False); excel.Quit()
```

Document Option B for LibreOffice shops: `soffice --headless --convert-to pdf daily_mis.xlsx`.

**Why each part:** openpyxl deliberately doesn't render/print; delegating to a real engine keeps fidelity. COM route also demonstrates the automation seam VBA later replaces cleanly.

**Verify yourself:** PDF opens, header repeats on page breaks, one page wide.

---

## Task 5 — Pack structure

Sheet order: Cover · Daily · Summary · AgentLookup · Parameters · ChangeLog. Tab colors: `ws.sheet_properties.tabColor = "262A76"` (data tabs), `"808080"` (governance tabs). Cover:

```python
ws_c["B6"] = "Owner:";   ws_c["C6"] = "MIS Analyst — Collections"
ws_c["B7"] = "Generated:"; ws_c["C7"] = '="Snapshot "&TEXT(Data!A5,"yyyy-mm-dd")&" · refreshed "&TEXT(NOW(),"yyyy-mm-dd hh:mm")'
```

Navigation lines: one sentence per tab on the Cover.

**Verify yourself:** stranger test — colleague finds the current RPC% in <30 seconds using only the Cover text.

---

## Task 6 — Change log

ChangeLog headers: Date · Author · Sheet/Range · What changed · Why.

```python
ws_log.append(["2025-08-25", "Analyst", "Summary!F5:F16",
               "Added MoM delta column", "Ops asked direction-at-a-glance"])
ws_log.append(["2025-08-25", "Analyst", "Parameters!E2:E3",
               "Raised RPC% amber floor 33→35", "Strategy recalibration memo 2025-08"])
ws_log.append(["2025-08-26", "Analyst", "Daily!B9",
               "Fixed June-09 double count", "Caught by reconcile vs v_daily_mis — my paste error"])
```

**Why each part:** the third entry is the important one — logging MISTAKES is what makes the log trustworthy. Convention note goes on the Cover: "No edit ships without a ChangeLog row."

**Verify yourself:** you actually added these rows while doing Tasks 1–5 — retro-fabricated logs defeat themselves.
