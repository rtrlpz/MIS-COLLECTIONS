# Excel Track — build the report people open every morning

```
You are here: learning/excel/   (basic → medium → advanced)
Master guide: learning/README.md
Prerequisite: python/basic (the numbers come from there)
```

Notebooks explain numbers; **Excel ships them**. The daily MIS sheet, the month-end pack, the file a supervisor opens, reads and prints — in most companies that file is a workbook.

This track teaches you to **USE Excel first, then automate it.** Every level is split into two phases:
- **Phase A — Excel-Native:** you build the workbook in Excel/LibreOffice using the UI — formulas typed by hand, pivot tables created by clicking, conditional formatting set in dialogs, Power Query configured via the Data tab. You learn *what the workbook does* and *how it behaves when you interact with it.*
- **Phase B — Automate:** you convert the manual workbook into a Python generator + VBA pipeline. The manual version is the spec; the automation is just a faster version of the same thing.

**The rule:** if you can't build it manually in Excel, you can't automate it correctly.

## At work, you reach for Excel when…

- Ops needs the same report every morning — you build it once manually, then automate it.
- A stakeholder won't open a notebook or query a database, but will absolutely open Excel.
- Month-end demands a pack: cover sheet, tables, charts, checks.
- Someone prints your report and it should look professional on paper, not like a database dump.

## Two skills, two phases

| Skill | Phase A (Manual) | Phase B (Automation) |
|---|---|---|
| **Formulas** | Type XLOOKUP, VLOOKUP, SUMIFS by hand in cells | openpyxl writes the same formulas into cells |
| **Pivot Tables** | Insert → PivotTable → configure rows/values/filters in UI | Understand pivot cache; generator produces data structured for pivots |
| **Power Query** | Data → Get Data → From CSV → transform → Refresh on open | Generator produces the Data sheet that Power Query reads |
| **Conditional Formatting** | Home → Conditional Formatting → New Rule → reference Parameter cells | openpyxl `conditional_formatting.add()` with CellIsRule |
| **Validation** | Data → Data Validation → List → select range | openpyxl `DataValidation` object |
| **Charts & Slicers** | Insert → PivotChart → Insert Slicer | Understand what the automation must reproduce |
| **VBA** | Understand what the macro must do | Author `.bas` modules, import via VBE, `Workbook_Open` event |

## Setup

1. `conda activate mis-collections`
2. Two dependencies: `pip install openpyxl`, then verify with `import openpyxl`.
3. Also install **LibreOffice** for manual workbook creation (or use Excel).
4. Scripts and `.xlsx` outputs go under `learning/excel/<level>/work/`. Raw CSVs stay read-only.

## What each level covers

| Level | Phase A (Excel-Native) | Phase B (Automate) | Typical deliverable |
|---|---|---|---|
| `basic/` | Manual workbook shell, VLOOKUP/XLOOKUP typed by hand, Pivot Table creation, validation dropdowns | NamedStyles, print setup, full generator script, reconciliation | A clean multi-sheet workbook you built by hand |
| `medium/` | Manual SUMIFS, conditional formatting via UI, PivotChart + slicer, Power Query refresh | Pack structure, change log, full automated pack generator | The morning report, interactive and self-updating |
| `advanced/` | Full manual dashboard assembly, pivot cache deep-dive | VBA Workbook_Open, one-button PDF pipeline, .xlsm via keep_vba, Task Scheduler | An automated, governed, finance-sign-off pack |

## How the files work

Each level folder has:

- `tasks.md` — your inbox: workplace requests with Done-When checklists (no code, no expected numbers)
- `results.md` — full worked solutions: **manual steps first** (what to click, what to type), then openpyxl/VBA automation; open **only after** attempting, then run/rebuild yourself
- `work/` — your scripts and `.xlsx`/`.xlsm` files; git-ignored scratchpad

Routine: read task → **build it manually in Excel** → open it and poke it (change values, refresh pivots, test validation) → then compare with `results.md` for the automation version. A spreadsheet you never opened is an untested claim.

## Move up when…

- **basic → medium:** you can build the full workbook manually — every formula typed, every pivot configured — without notes.
- **medium → advanced:** you understand pivot caches, Power Query refresh, and the full dashboard layout — and can automate all of it.
- **done:** you can hand over a multi-sheet pack whose numbers match the database, and you know *exactly* what's behind every formula, pivot, and slicer — because you built it by hand first.
