# Excel Track — README

```
learning/
├── _reference/            ← READ FIRST: datasets.md, kpi_glossary.md, data_dictionary.md
├── git-cli/
├── sql/  python/  notebooks/   ← done first (the launch pads)
├── excel/                 ← YOU ARE HERE
│   ├── README.md
│   ├── basic/    tasks.md + results.md + work/
│   ├── medium/   tasks.md + results.md + work/
│   └── advanced/ tasks.md + results.md + work/
├── powerbi/
└── README.md             ← MASTER GUIDE
```

## Why Excel after notebooks

Notebooks are where numbers get *explained*. Excel is where numbers get **shipped**: the daily MIS sheet, the period-end pack, the file a supervisor opens without Python. This project has a real one in its roadmap (`reports/generate_daily_mis.py`), and this track trains you to build it.

**The theme of the whole track:** an Excel deliverable is a *document* — layout, formatting, formulas, printability — not just `df.to_excel()`.

## Setup

1. `conda activate mis-collections`
2. Install the one dependency: `pip install openpyxl` (used by pandas' `to_excel` *and* the direct `openpyxl` API). Verify:
   ```python
   import openpyxl, pandas
   ```
3. All work files (`.xlsx`, scripts) go under `learning/excel/<level>/work/`. Raw CSVs stay read-only.

## Two Excel skill families

| Family | Tool | Use |
|---|---|---|
| Data in / out | `pandas.to_excel` (needs XlsxWriter/openpyxl) | fast bulk writes, one call |
| Document engineering | `openpyxl` Workbook API | styles, formulas, merged cells, print setup, charts — the *document* |

**Rule of thumb: pandas writes the numbers, openpyxl makes it a report.** You'll learn to clean up pandas' output with openpyxl — and to build from scratch with openpyxl when the layout demands it.

## The MIS discipline that carries over

- Every rate you put in Excel was proven in SQL/Python already. Excel's job is **presentation + live formulas**, not re-analysis.
- **Formulas are live**: a formula cell (`=B2/C2`) refreshes when a reader edits inputs. A pasted value is dead. Decide per-cell which is right — a MIS wants a few live cells, not a spreadsheet explosion of tens of thousands of volatile formulas.
- Cross-track audit: an exported Excel MIS must agree with `v_daily_mis`. (Same advanced rule as always: divergence = finding, proof required.)

## The three levels

| Level | What you'll master | Checks |
|---|---|---|
| `basic/` | Workbook anatomy — sheets, headers, styles, pandas→Excel, page setup for printing. | 4 tasks |
| `medium/` | The daily MIS report: multi-sheet, live formulas, RAG formatting, freeze panes, print areas. | 5 tasks |
| `advanced/` | The period-end pack: workbook with charts, validations, a cover/dashboard sheet, and a cross-track audit vs the SQL view. | 4 tasks |

## Golden rule

Attempt → commit → open the `.xlsx` in a real reader (Excel or LibreOffice) and *look at it* → then read `results.md`. A spreadsheet you never opened is an untested claim.