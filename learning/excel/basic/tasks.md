# Excel — Basic — Tasks

```
learning/
├── _reference/            ← READ FIRST (datasets.md, kpi_glossary.md, data_dictionary.md)
├── sql/  python/  notebooks/  powerbi/  git-cli/
├── excel/
│   ├── README.md
│   └── basic/             ← YOU ARE HERE
│       ├── tasks.md       ← current file
│       ├── results.md     ← guidance, peek AFTER attempting
│       └── work/          ← your .py + .xlsx files live here
└── README.md
```

**Up from python basic:** you can assemble data and compute proven numbers. Excel basic adds the *document*: a workbook is a file you ship, and its anatomy is the skill.

**Setup:** `pip install openpyxl` (see `excel/README.md`). Save scripts + outputs as `learning/excel/basic/work/attempt_*.xlsx`.

**Discipline:** attempt → **open the file in a real spreadsheet reader** → read `results.md`.

---

## Task 1 — Workbook anatomy: a title sheet with a pulse

The supervisor: *"Create the workbook skeleton: a cover sheet, a README sheet, and an empty 'data' sheet. Vibe: clean, professional, zero magic."*

**What you'll practice:** openpyxl ground floor — Workbook, sheets, cell addressing, and the discipline of *naming* sheets before filling them.

Steps:
1. Build with openpyxl: three sheets — `Cover`, `README`, `Raw Input`.
2. Cover: merged title cell (project name), author line, date cell. README: 5 lines of "what this workbook is".
3. Set a tab color on each sheet (titles should be recognizable at a glance — pick a palette reason, state it in a comment).
4. Save, reopen, confirm all three sheets exist with the right tab colors.

**Guiding questions:**
- Why merge cells for a *title* but avoid merging for *data*? (Hint: merging breaks filtering/sorting downstream.)
- What's the difference between `wb["Sheet"] = ws` mutation and `wb.create_sheet(name)`? Which hides a typo?

**Deliverable:** `work/attempt_1.xlsx` — 3-sheet skeleton, tab colors, cover merged title.

---

## Task 2 — Numbers through a door: pandas → Excel

The supervisor: *"Put January's per-team interaction counts into a sheet — panel they can actually read (not a raw dump)."*

**What you'll practice:** `df.to_excel` basics + the immediate cleanup that follows (a raw `to_excel` is a *draft*, never a deliverable).

Steps:
1. Recompute January per-team counts (Python basic Task 3 — proven number).
2. Write to a sheet with `index=False`, a clear sheet name, header row.
3. Repair the draft: red headers? column widths? number format (no trailing `.0` on counts)? Make the sheet *readable standing up*.
4. Add a total row (SUM formula or pandas-sum pasted — decide and defend: live vs static).

**Guiding questions:**
- `index=False` — when does the index *belong* in the output (and here, why not)?
- Live `=SUM(...)` vs pasted total: what does the reader lose with a static number? When is static actually *safer*?

**Deliverable:** `work/attempt_2.xlsx` — readable per-team January sheet + your live-vs-static decision noted in a cell comment or README note.

---

## Task 3 — Formatting is a second language

The supervisor: *"Eyeballs stop at the numbers, but they *trust* the formatting. Style the monthly RPC% sheet: headers, alignment, number format, and a professionalism pass."*

**What you'll practice:** the formatting vocabulary — `Font`, `PatternFill`, `Alignment`, `Border`, `number_format`, and *restraint* (formatting to communicate, not decorate).

Steps:
1. Get monthly RPC% by channel (python basic Task 4 product, monthly slice).
2. Build the sheet: header fill + bold white, freeze the header row, align center, apply a percent number format to the rate column.
3. Alternating row color for reading (consider legitimate *banded* rows vs garish rainbow — know the difference in goal).
4. Open it: does the rate column read `35%` not `0.35`? (Number formats ARE the contract with the reader.)

**Guiding questions:**
- Why must a percentage live as a *number* with `0.0%` format rather than a string like `"35%"`? What breaks downstream (sorting, formulas, pivot)?
- Borders: full-grid vs light — which *actually* helps a reader, and which is polish for its own sake?

**Deliverable:** `work/attempt_3.xlsx` — styled monthly-rate sheet, header-frozen, percent-formatted, banded.

---

## Task 4 — Printable or it doesn't exist

The supervisor: *"Ops prints this weekly. Set up print so it comes out readable: one page wide, title repeated, no random splatter across page 3."*

**What you'll practice:** page setup — the whole reason "print preview" exists — `page_setup`, `fit_to_width`, print titles, margins/orientation, and the difference between "fits" and "reads".

Steps:
1. Take attempt_3's sheet and add: landscape orientation (a wide table), `fitToWidth=1`, repeat the header row on every printed page (`print_title_rows`).
2. Add a print area equal to the used range (no phantom empty columns bleeding onto page 2).
3. Preview it (Excel/LibreOffice print preview). Iterate until it prints exactly one page wide.
4. Add a footer with the sheet name / page number — a professional print has breadcrumbs.

**Guiding questions:**
- `fitToWidth=1` vs shrinking to one *page total* — why is one-page-wide the right tool for a *wide* table and one-page-total the wrong one?
- If a column's width or font bloats the row count across pages, what does that say about your *data layout*, not your page settings?

**Deliverable:** `work/attempt_4.xlsx` — printable monthly-rate workbook (fit-to-width, repeated header, print area, footer) + your print-preview pass noted.

---

### Finish

Attempt all four, then read `basic/results.md`. For each task, note what you saw when you *opened the file as a reader* that you missed as a writer.

**Move up when:** you can produce a styled, printable workbook from a pandas frame without opening your notes — and know the difference between a live cell and a pasted value.