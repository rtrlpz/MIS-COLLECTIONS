# Excel Basic — Your Inbox (level 1 of 3)

```
You are here: learning/excel/basic/
Tooling:      openpyxl (Python → .xlsx) + Excel/LibreOffice to OPEN and READ what you ship
Data:         small extracts you export yourself (CSV) or read via pandas — files stay read-only
Solutions:    basic/results.md — after attempting; then run the script and OPEN the workbook
Rule:         a workbook you never opened is an untested claim.
```

**What this level gives you.** The morning pack's skeleton: a titled, formatted, printable daily sheet produced by a script instead of copy-paste — plus the lookup and validation moves every MIS workbook leans on.

---

## Words you'll meet

| Term | Plain meaning |
|---|---|
| **openpyxl** | Python library that WRITES .xlsx files (it does not compute formulas — Excel does at open time) |
| **Named style / format** | Reusable look: bold headers, number formats, column widths |
| **Lookup** | Pulling a value from another sheet by key (`XLOOKUP`/`VLOOKUP` written INTO cells) |
| **Print area / fit-to-width** | What the printer shows; set programmatically or suffer |

---

## Task 1 — Workbook anatomy: a title sheet with a pulse
📥 **Inbox:** From Ops Lead · Mon 8:00 · "today's pack template"

> "Build me the shell everyone will recognize: big title 'Collections Daily MIS', subtitle line with the report date pulled from ONE cell, column headers Date · Contacts · Connects · RPCs · Promises · Payments, frozen header row, sensible widths."

**Done when:**
- [ ] Script writes the layout; date cell drives the subtitle via formula (`="Report for "&TEXT(B2,"yyyy-mm-dd")`)
- [ ] Header row bold + frozen; widths set
- [ ] Opens clean in Excel AND LibreOffice

---

## Task 2 — Numbers through the door: data rows from files
📥 **Inbox:** From MIS Manager · Tue 9:00 · "feed it"

> "Extend the script: read one month's facts (your python loaders), aggregate to DAILY rows, and write them under the headers. Dates as real dates, counts as numbers — no text-that-looks-like-numbers."

**Done when:**
- [ ] One row per day, six columns filled
- [ ] Number formats applied (#,##0)
- [ ] Spot-check one day against your SQL/python morning pack

---

## Task 3 — Formatting is a second language
📥 **Inbox:** From Operations Manager · Wed 2:00 PM · "director reads this on paper"

> "Polish pass: consistent title font sizes, header fill color from our palette, thin borders on the data grid, right-aligned numbers, date format yyyy-mm-dd everywhere. No rainbow — two colors max."

**Done when:**
- [ ] Styles applied via NamedStyle objects (reusable), not cell-by-cell chaos
- [ ] Two-color discipline held
- [ ] Screenshot of opened file saved

---

## Task 4 — Printable or it doesn't exist
📥 **Inbox:** From Site Director · Thu 4:00 · "boardroom printer"

> "Set print area over the used range, landscape, fit-to-width one page, repeat header row on each printed page. I hit Ctrl+P and it must just work."

**Done when:**
- [ ] Page setup properties set in-script
- [ ] Print preview screenshot proves it

---

## Task 5 — Lookups that survive re-sorting
📥 **Inbox:** From Supervisor, Team 4 · Fri 10:00 · "agent names on demand"

> "Second sheet 'Agent Lookup': agent IDs and names from the employees extract. On the daily sheet add an Agent ID column; names must appear via XLOOKUP formula IN THE CELL (not pre-filled by python) so editing an ID updates the name live."

**Done when:**
- [ ] Formula present in cells (inspectable in Excel)
- [ ] Changing one ID updates its name after recalc
- [ ] Unknown ID shows friendly blank/message, not #N/A wall

---

## Task 6 — Guard rails: validation dropdowns
📥 **Inbox:** From MIS Manager · Mon 11:00 · "stop people typing Free Texxt"

> "Add a Parameters sheet holding valid team names and date formats. Data-sheet cells get dropdown validation from those lists. Try to type garbage — Excel must refuse."

**Done when:**
- [ ] Validation lists sourced from Parameters range
- [ ] Garbage input rejected (screenshot of the refusal)
- [ ] Note written: which cells stay free-type and why

---

## Finish

Six building blocks saved. Medium level makes the pack self-updating and RAG-colored: [`../medium/tasks.md`](../medium/tasks.md).
