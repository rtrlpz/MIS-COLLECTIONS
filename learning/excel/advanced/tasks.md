# Excel — Advanced — Tasks

```
learning/
├── _reference/            ← READ FIRST (datasets.md, kpi_glossary.md, data_dictionary.md)
├── sql/  python/  notebooks/  powerbi/  git-cli/
├── excel/
│   ├── README.md
│   └── advanced/          ← YOU ARE HERE
│       ├── tasks.md       ← current file
│       ├── results.md     ← guidance, peek AFTER attempting
│       └── work/          ← your .py + .xlsx files live here
└── README.md
```

**Up from excel medium:** multi-sheet daily MIS with live rates and RAG. Advanced builds the *period-end pack* — the file a finance/ops team checks against the book at month close — and audits it against the project's view. This is the shape of the project's real `reports/generate_daily_mis.py` roadmap.

**Setup:** `excel/README.md` + DB running (for the audit). Save as `learning/excel/advanced/work/attempt_*.xlsx`.

**Discipline:** attempt → open as a reader → read `results.md`.

> **The advanced rule (house rule):** a number that differs from the reference view is a *finding*. A workbook that asserts PASS/FAIL for it is the professional form.

---

## Task 1 — Charts that earn their ink

The supervisor: *"The month-close review shows trends. Add to the pack: a 12-month line (the headline trend) and a bar (comparison), both worth their place on a slide."*

**What you'll practice:** `openpyxl` charts — the chart API (`BarChart`, `LineChart`, series, categories, titles/axes) — and the discipline that a chart in a *fixedsize* workbook needs its data referenced reliably.

Steps:
1. Build the 12-month line of RPC% from your proven monthly series (SQL/Python already have the numbers).
2. Add a bar chart for a *categorical* comparator (e.g., per-channel or per-product rate).
3. Label every chart: title, axis titles, and a legend that names the series (unlabeled = decorative).
4. Anchor each chart to its data range *by reference* (series from cells), so refreshing the workbook's data re-plots the chart — no static screenshot of a chart.

**Guiding questions:**
- Line vs bar: which risk *implying* a trend when none exists (a categorical bar suggesting sequence)? Pick per-claim, not per-preference.
- If the monthly series frame rebuilds larger (next period adds a month), does your chart's reference extend or die? What does that imply for your anchor strategy?

**Deliverable:** `work/attempt_1.xlsx` — line + bar charts, labeled, series-referenced to data cells.

---

## Task 2 — The dashboard cover: five numbers, one glance

The supervisor: *"The exec opens the pack and the FIRST screen must answer: what's the month, are we holding targets, and the three numbers that drive ops today."*

**What you'll practice:** the summary/cover sheet — big-number cells with live formulas feeding the visual, target-sourced RAG, and the discipline of *pick five, not fifty*.

Steps:
1. Design the cover: title, period selector (one cell that drives the whole pack), and five headline numbers (choose from the core rates — say *why* those five in a note).
2. Make each headline a **live formula** feeding off the pack's data sheet (so changing the period selector refreshes the skyline).
3. Apply the documented RAG treatment per target (reuse the glossary targets — any green, one amber/red is a *story* to annotate).
4. Add a one-line "so what" comment under the worst number (state what an ops lead does with it).

**Guiding questions:**
- "Five, not fifty": how do you decide which five? (The handful whose change *moves a decision* vs the numbers that are merely countable.)
- A period selector cell → every sheet: what's the mechanism (a defined name / a formula chain), and what breaks if a sheet hardcodes instead?

**Deliverable:** `work/attempt_2.xlsx` — dashboard cover with a period selector, 5 live headline cells, RAG + so-what notes.

---

## Task 3 — The self-auditing pack: PASS/FAIL vs the view

The supervisor: *"At close, the pack must *prove* its numbers: a Check tab that pulls the reference views and marks each of my headline cells PASS or FAIL within tolerance."*

**What you'll practice:** the cross-track audit *inside the workbook* — DB `v_` values vs workbook cells, a PASS/FAIL verdict per line, and a root-cause line for any FAIL (the SQL advanced rule, in Excel form).

Steps:
1. Pull the reference values: run `v_daily_mis` (or the KPI views your analysis reproduces) from the DB and load each into the workbook as an "expected" column.
2. In a `Checks` tab, pair each workbook cell with its reference: | metric | workbook | view | delta | tolerance | PASS/FAIL |.
3. Tolerance: state and justify per metric type (rates vs counts) — printed, not implied.
4. For any FAIL: a root-cause line (definition, filter window, formatting) — and fix the workbook if the workbook was wrong.

**Guiding questions:**
- Who is the reader of a `Checks` tab — and why is a printed delta column stronger evidence than a bare PASS?
- If you must choose between "PASS with wide tolerance" and "FAIL with a root cause", which tells the truth better for a *finance sign-off*? Defend.

**Deliverable:** `work/attempt_3.xlsx` — checks tab: workbook vs view vs delta vs tolerance vs PASS/FAIL + root-cause lines.

---

## Task 4 — Validation, polish, and the finished pack

The supervisor: *"Ship it. Validation on inputs (a period must be a real month-string), no corrupt cells, print setup that survives, and a file that opens in Excel AND LibreOffice without shouting."*

**What you'll practice:** the hardening pass — data validation (dropdown/month pick), error-friendly inputs, the no-red-triangle sweep, print/page polish, and a final *open-in-two-readers* acceptance.

Steps:
1. Data validation on the period selector: restricted to the 12 real month values (a dropdown, not free text) — and an error dialog that explains itself.
2. The red-triangle sweep: reopen and hunt cells with stored errors/warnings (`#REF!`, `#DIV/0!`, corrupted formats) — fix every one or justify it in a note.
3. Polish: consistent print setups across printable sheets, a `CHANGELOG` note on the pack (v0.x, date, author), and a `raw` inputs tab that's clearly *input*, not *answer*.
4. Acceptance: open the SAME file in Excel and LibreOffice (or a second reader) — no broken formulas, no missing fonts, no mis-kerfuffled charts. Note any difference you tolerated and why.

**Guiding questions:**
- What does "a file that opens in two readers" actually test (format dialect, font fallbacks, chart engine parity)? Which differences are *worth* fighting?
- Validation restricts the period selector — where does that *help* a user and where does it *annoy*? (A dropdown on a *stable* input is ergonomics; on free-text notes it's a straitjacket.)

**Deliverable:** `work/attempt_4.xlsx` — the hardened pack (validation, no red triangles, print polish) + your two-reader acceptance note.

---

### Finish

Attempt all four, then read `advanced/results.md`. Close attempt_4 with an author's note: the pack's version, the five numbers chosen and why, and the last `Checks` result.

**Graduate when:** you can ship a period-end pack that *proves* its numbers (self-audit), opens cleanly in two readers, and a stranger can navigate from cover to checks without asking questions.