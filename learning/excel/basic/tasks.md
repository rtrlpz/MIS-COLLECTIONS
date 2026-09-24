# Excel Basic — Your Inbox (level 1 of 3)

```
You are here: learning/excel/basic/
Tooling:      openpyxl (Python → .xlsx) + Excel/LibreOffice to OPEN and READ what you ship
Data:         small extracts you export yourself (CSV) or read via pandas — files stay read-only
Solutions:    basic/results.md — after attempting; then run the script and OPEN the workbook
Rule:         a workbook you never opened is an untested claim.
```

**What this level gives you.** The morning pack's skeleton: a titled, formatted, printable daily sheet produced by a script instead of copy-paste — plus the lookup and validation moves every MIS workbook leans on.

**How to work through this level.** Phase A (Tasks 1–5) is Excel-native: you build and manipulate the workbook **in Excel/LibreOffice** using the UI — formulas typed by hand, pivots created by clicking, dropdowns configured in dialogs. Phase B (Tasks 6–9) teaches you to automate everything you just built with openpyxl. The rule: **master the manual version first; the automation is just a faster version of the same thing.**

---

## Words you'll meet

| Term | Plain meaning |
|---|---|
| **XLOOKUP / VLOOKUP** | Pulling a value from another sheet by key — typed IN the cell, not pre-filled by Python |
| **Pivot Table** | An interactive summary built in Excel from raw data — rows, columns, values, filters |
| **Data Validation** | Dropdown lists that reject garbage input — set via Excel UI |
| **Named range** | A readable name for a cell range (easier than A1:A100) |
| **Refresh** | Updating a pivot or query when the source data changes |
| **Print area / fit-to-width** | What the printer shows; set in Excel's Page Layout |

---

## ═══ PHASE A — Excel-Native Skills ═══

*These tasks teach you to USE Excel. Every formula you type, every pivot you build, every dropdown you configure is done with the mouse and keyboard in Excel/LibreOffice.*

---

## Task 1 — Workbook anatomy: build the shell in Excel

📥 **Inbox:** From Ops Lead · Mon 8:00 · "today's pack template"

> "Build me the shell everyone will recognize: big title 'Collections Daily MIS', subtitle line with the report date pulled from ONE cell, column headers Date · Contacts · Connects · RPCs · Promises · Payments, frozen header row, sensible widths."

**Your job (Excel first):**
1. Open Excel/LibreOffice. Create a new workbook.
2. Type the title in A1. Build the subtitle formula in A2: `="Report for "&TEXT(B2,"yyyy-mm-dd")`
3. Add headers in row 4. Freeze panes at A5.
4. Set column widths. Apply bold headers, center alignment.
5. **Save as `work/daily_mis_manual.xlsx`.** Open it again to confirm it looks right.
6. *Then* read the results.md to see how openpyxl replicates this — compare what's the same and what differs.

**Done when:**
- [ ] Workbook built manually, opens clean in Excel AND LibreOffice
- [ ] Subtitle formula recalculates when B2 changes
- [ ] Freeze panes and widths verified
- [ ] Saved to `work/daily_mis_manual.xlsx`

---

## Task 2 — Data rows: import and explore manually

📥 **Inbox:** From MIS Manager · Tue 9:00 · "feed it"

> "Extend the shell: read one month's facts (your python loaders), aggregate to DAILY rows, and write them under the headers. Dates as real dates, counts as numbers — no text-that-looks-like-numbers."

**Your job (Excel first):**
1. Export one month of aggregated data to CSV (from your python/pandas loaders).
2. In Excel: **Data → Get Data → From CSV** (or just paste the data). Import the daily rows.
3. Manually sort by date. Confirm dates show as real dates (not text). Apply `#,##0` number format.
4. Spot-check one day against your SQL/python morning pack — verify the numbers match.
5. *Then* read the results.md to see the openpyxl version.

**Done when:**
- [ ] Data imported manually, dates confirmed as real dates
- [ ] One row per day, six columns filled
- [ ] Number formats verified
- [ ] Spot-check passed against source data

---

## Task 3 — Lookups that survive re-sorting: VLOOKUP + XLOOKUP typed by hand

📥 **Inbox:** From Supervisor, Team 4 · Fri 10:00 · "agent names on demand"

> "Second sheet 'Agent Lookup': agent IDs and names from the employees extract. On the daily sheet add an Agent ID column; names must appear via XLOOKUP formula IN THE CELL (not pre-filled by python) so editing an ID updates the name live."

**Your job (Excel first):**
1. On a new sheet `AgentLookup`, manually type agent IDs and names (paste from the CSV).
2. On the Daily sheet, add an Agent ID column (type IDs manually).
3. **Type the XLOOKUP formula by hand** in the name column:
   `=IFNA(XLOOKUP(A5,AgentLookup!$A$2:$A$100,AgentLookup!$B$2:$B$100,"—"),"")`
4. **Now also type VLOOKUP** in the next column:
   `=IFNA(VLOOKUP(A5,AgentLookup!$A$2:$B$100,2,FALSE),"")`
5. Test both: change an ID to valid, change to garbage. Confirm both work.
6. Note the differences: XLOOKUP handles direction, VLOOKUP needs column index. What breaks if you insert a column?
7. *Then* read results.md for the openpyxl automation version.

**Done when:**
- [ ] Both formulas typed manually in cells (inspectable in Excel's formula bar)
- [ ] Changing one ID updates its name after recalc (both XLOOKUP and VLOOKUP)
- [ ] Unknown ID shows `—`, not #N/A wall
- [ ] Notes on XLOOKUP vs VLOOKUP differences written

---

## Task 4 — Pivot Table basics: summarize without writing formulas

📥 **Inbox:** From MIS Manager · Wed 10:00 · "the quick summary"

> "I need to see total Promises and Payments by team for the month. Don't give me another formula sheet — give me something I can filter and drill into."

**Your job (Excel first):**
1. Select the Data sheet range. Go to **Insert → PivotTable**.
2. Place it on a new sheet called `PivotDaily`.
3. Rows = Team. Values = SUM of Promises, SUM of Payments.
4. Add a report filter for Month. Try dragging fields around — feel how the pivot rebuilds.
5. **Refresh** the pivot after changing one Data value. Confirm it updates.
6. Note: how many clicks vs. writing a SUMIFS formula? When would you choose a pivot over a formula?
7. *Then* read results.md for the openpyxl pivot automation version.

**Done when:**
- [ ] Pivot created via Excel UI (not openpyxl)
- [ ] Rows = Team, Values = SUM(Promises) + SUM(Payments)
- [ ] Filter works, refresh confirmed
- [ ] Notes on when to use pivot vs. formula written

---

## Task 5 — Guard rails: validation dropdowns via Excel UI

📥 **Inbox:** From MIS Manager · Mon 11:00 · "stop people typing Free Texxt"

> "Add a Parameters sheet holding valid team names and date formats. Data-sheet cells get dropdown validation from those lists. Try to type garbage — Excel must refuse."

**Your job (Excel first):**
1. Create a `Parameters` sheet. Type valid team names in column A (from the CSV extract).
2. Select the team cell on the Data sheet. Go to **Data → Data Validation → List**.
3. Set the source to `=Parameters!$A$2:$A$100`.
4. Enable "Show error message" on invalid input.
5. **Try to type "Free Texxt"** — confirm Excel refuses with your error message.
6. Also set a date validation: restrict the report-date cell to real dates only.
7. Note which cells stay free-type and why (e.g., notes columns).
8. *Then* read results.md for the openpyxl automation version.

**Done when:**
- [ ] Validation lists sourced from Parameters range (set via Excel UI)
- [ ] Garbage input refused with visible error message
- [ ] Date validation configured
- [ ] Note written: which cells stay free-type and why

---

## ═══ PHASE B — Automate with Python ═══

*These tasks teach you to generate everything you built manually in Phase A using openpyxl. The goal: write the script once, regenerate forever.*

---

## Task 6 — Formatting is a second language

📥 **Inbox:** From Operations Manager · Wed 2:00 PM · "director reads this on paper"

> "Polish pass: consistent title font sizes, header fill color from our palette, thin borders on the data grid, right-aligned numbers, date format yyyy-mm-dd everywhere. No rainbow — two colors max."

**Your job:**
1. Build on the manual workbook from Task 1.
2. Apply NamedStyles: `title`, `header`, `grid`, `datecell`, `numcell`.
3. Reusable styles — change `header` once, every sheet inherits.
4. Two-color discipline: palette blue (#262A76) for identity, white space elsewhere.
5. Screenshot of opened file saved.

**Done when:**
- [ ] Styles applied via NamedStyle objects
- [ ] Two-color discipline held
- [ ] Screenshot saved of opened file

---

## Task 7 — Printable or it doesn't exist

📥 **Inbox:** From Site Director · Thu 4:00 · "boardroom printer"

> "Set print area over the used range, landscape, fit-to-width one page, repeat header row on each printed page. I hit Ctrl+P and it must just work."

**Your job:**
1. Apply page setup programmatically: print area, landscape, fit-to-width, repeat header rows.
2. Export to PDF using LibreOffice: `soffice --headless --convert-to pdf work/daily_mis.xlsx`
3. Print preview screenshot proves it.

**Done when:**
- [ ] Page setup properties set in-script
- [ ] PDF exported and verified
- [ ] Print preview screenshot saved

---

## Task 8 — The full generator: build the pack from scratch

📥 **Inbox:** From Head of MIS · Mon 9:00 · "the flagship deliverable"

> "Write `generate_daily_mis.py`: reads the daily KPI extract (CSV export of `v_daily_mis`), builds the FULL pack — Cover, Daily, Summary, AgentLookup, Parameters — with every style, formula, lookup, validation, and print setting applied. One command, zero manual steps."

**Your job:**
1. Assemble everything from Tasks 1–7 into a single CLI script.
2. Input: CSV path + output xlsx path.
3. All sheets built with Phase A behaviors intact: XLOOKUP formulas written to cells, validation dropdowns, pivot-ready data layout, named styles, print setup.
4. Fresh run reproduces the workbook byte-stable except timestamps.

**Done when:**
- [ ] Single CLI script: input CSV path + output xlsx path
- [ ] All sheets built with Phase A behaviors
- [ ] Fresh run reproduces workbook (byte-stable except timestamps)

---

## Task 9 — The audit habit: reconcile against the source

📥 **Inbox:** From MIS Manager · Fri 3:00 · "nothing leaves this desk without it"

> "Before ANY workbook ships, verify it agrees with the official SQL view (`v_daily_mis`). Build a reconciliation check into the generator: compare one day's numbers from the generated file against the query result."

**Your job:**
1. Run a SQL query for a test date and note the four numbers (contacts, connects, RPCs, promises).
2. Generate the workbook from the same date's data.
3. Open the generated file and read back the numbers from the Data sheet.
4. Compare. Any mismatch = a finding, not a rounding error.
5. Document the reconciliation step in the generator.

**Done when:**
- [ ] Reconciliation step in the generator script
- [ ] Generated numbers match SQL view exactly
- [ ] Any discrepancy documented as a finding

---

## Finish

Nine building blocks saved. Phase A taught you to *use* Excel — pivot tables, VLOOKUP/XLOOKUP, validation dropdowns, manual formula construction. Phase B taught you to automate it with openpyxl. Medium level makes the pack self-updating and RAG-colored: [`../medium/tasks.md`](../medium/tasks.md).
