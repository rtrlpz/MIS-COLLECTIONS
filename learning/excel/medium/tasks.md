# Excel Medium — Your Inbox (level 2 of 3)

```
You are here: learning/excel/medium/
Assumed:      basic/ complete — shell script, NamedStyles, print setup all warm
Solutions:    medium/results.md — full openpyxl scripts; run, OPEN, and diff against your attempt
Theme:        self-updating packs — formula-driven RAG, refreshable data, dashboard sheet,
              protection, and the change log that keeps versions honest
```

---

## Task 1 — One producer, many consumers
📥 **Inbox:** From MIS Manager · Mon 9:00 · "stop emailing six different files"

> "Restructure: a `Data` sheet holds the raw daily table (from your loader), consumer sheets reference it via structured formulas. When June's numbers correct themselves, every downstream sheet updates without touching them."

**Done when:**
- [ ] Single Data sheet is the only place raw values live
- [ ] Consumer sheets use cell references/table refs (no copy-paste values)
- [ ] Edit one Data cell → consumers recalc

---

## Task 2 — Live formulas: monthly rollup organs
📥 **Inbox:** From Operations Manager · Tue 2:00 · "the summary tab"

> "Summary sheet with SUMIFS-driven monthly totals per KPI from the Data sheet, plus month-over-month delta column. All FORMULAS in cells — python writes structure once, Excel keeps it alive."

**Done when:**
- [ ] SUMIFS/SUMPRODUCT rollup by month working
- [ ] Delta column flags direction (▲▼ text or ±)
- [ ] Editing one daily value moves the month + delta

---

## Task 3 — RAG at scale: formula-driven conditional formatting
📥 **Inbox:** From Site Director · Thu 4:00 PM · "ten-second read"

> "RPC% and KP% columns get RAG backgrounds from THRESHOLD FORMULAS (not manual fills). Thresholds live on Parameters so strategy can tune them without asking you."

**Done when:**
- [ ] Conditional formatting rules reference Parameter cells
- [ ] Green #00B050 / amber #FFC000 / red #FF0000
- [ ] Moving a threshold repaints instantly

---

## Task 4 — The printed daily: freeze, fit, repeat
📥 **Inbox:** From Ops Lead · Fri 8:30 · "print run at 8:45 sharp"

> "Full pack polish: freeze panes everywhere sensible, print areas set per sheet, fit-to-width, headers repeat. Then export the Daily sheet to PDF programmatically — the 8:45 email attaches it."

**Done when:**
- [ ] Every sheet's page setup deliberate
- [ ] PDF exported by script (openpyxl can't — say which tool did)
- [ ] Print preview screenshots saved

---

## Task 5 — Multi-sheet discipline: the small MIS pack
📥 **Inbox:** From MIS Manager · Wed 10:00 · "the weekly shape of things"

> "Formalize the pack: Cover (title/date/owner), Daily, Summary, AgentLookup, Parameters, ChangeLog. Sheet order fixed, tab colors coded (data=blue, governance=gray). A stranger navigates it unaided."

**Done when:**
- [ ] Six sheets in order with color coding
- [ ] Cover states owner + generation timestamp (formula off a cell, not typed)
- [ ] Navigation note on Cover explaining each tab in one line

---

## Task 6 — The change log that saves careers
📥 **Inbox:** From Head of MIS · Fri 3:00 · "audit found three 'versions' of last month's pack"

> "ChangeLog sheet: Date · Author · What changed · Why · Cell range affected. Pre-populate this workbook's history honestly, including mistakes. Going forward NO edit ships without a row here."

**Done when:**
- [ ] Log sheet with ≥3 real entries (including one fix)
- [ ] Convention documented on Cover
- [ ] You actually used it for this task's own edits

---

## Finish

The pack now maintains itself and its own history. Advanced level automates the boring parts away — including with VBA: [`../advanced/tasks.md`](../advanced/tasks.md).
