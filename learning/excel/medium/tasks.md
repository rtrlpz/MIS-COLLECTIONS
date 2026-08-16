# Excel — Medium — Tasks

```
learning/
├── _reference/            ← READ FIRST (datasets.md, kpi_glossary.md, data_dictionary.md)
├── sql/  python/  notebooks/  powerbi/  git-cli/
├── excel/
│   ├── README.md
│   └── medium/            ← YOU ARE HERE
│       ├── tasks.md       ← current file
│       ├── results.md     ← guidance, peek AFTER attempting
│       └── work/          ← your .py + .xlsx files live here
└── README.md
```

**Up from excel basic:** workbook anatomy, pandas→Excel, styled sheets, print setup. Medium assembles the real thing: **the daily MIS workbook** — the file format a collections dept actually opens every morning.

**Setup:** `excel/README.md`. Save as `learning/excel/medium/work/attempt_*.xlsx`.

**Discipline:** attempt → open as a reader → read `results.md`.

---

## Task 1 — One producer, many consumers

The supervisor: *"Ops wants per-team today, the manager wants per-product, the c-suite wants monthly. Same source, three slices. Show me you built the pipeline once, not three times."*

**What you'll practice:** the data-pipeline-before-workbook discipline — compute frames once (reusing your Python skills), tune only the *presentation* per sheet.

Steps:
1. From the reassembled year (or DB — pick and state), build ONE function that returns: daily per-team, time per-product, and monthly timeseries frames — three *views* of one dataset (not three loads).
2. Emit the three as three sheets with *distinct* layouts (daily table / product table / monthly line-ready table) — but share header style and number formats (consistent visual language = a single producer).
3. Add a `README` tab documenting the single source + the three views' purposes.
4. Note in the README which cells (if any) are *formulas* vs *values* and why.

**Guiding questions:**
- What breaks if each sheet recomputes its own aggregates from disk — beyond speed (consistency of filters, one definition)?
- When would you *deliberately* show a number on two sheets with different formatting — and why is that *not* duplication?

**Deliverable:** `work/attempt_1.xlsx` — 3-slice workbook from one pipeline + README tab.

---

## Task 2 — Live formulas: the MIS's vital organs

The supervisor: *"The daily sheet must *compute* on open — rates as formulas, not numbers pasted from pandas. A manager may tweak a headcount and the sheet must update."*

**What you'll practice:** writing Excel formulas via openpyxl — `=...` strings as cell values — and the discipline of *where* formulas live (aggregate cells, not the raw data body).

Steps:
1. Build the daily MIS core: rows = teams, columns = calls, connects, RPCs, RPC%, PTP count, PTP%, KP count, KP% (define from the glossary; reuse your proven SQL/Python definitions).
2. Write RPC%, PTP%, KP% as **formula cells** (`=B2/C2` style) — with proper parentheses and percent format — not computed pandas floats.
3. Protect the structure: keep raw counts as values (from pandas), formulas only in derived cells. State why a body-of-1000-cells full of formulas is a liability.
4. Test the "manager tweak" claim: edit a headcount/count cell in a viewer, watch the rate cell move.

**Guiding questions:**
- If a rate formula divides by zero (no connects for a team), what displays — and is `#DIV/0!` the honest answer or a footgun the workbook designer should pre-empt (e.g., an `IFERROR` policy, stated)?
- Why are raw bodies *values* but derived cells *formulas*? What happens to a MIS built the other way around?

**Deliverable:** `work/attempt_2.xlsx` — daily MIS sheet where every rate is a live formula, edited-and-reopened to prove the refresh.

---

## Task 3 — RAG at scale: conditionally coloring the truth

The supervisor: *"Color is a language: green/red per target. Apply RAG to the daily rates — and make it *conditional*, so a reader swapping in next week's data gets the same verdicts."*

**What you'll practice:** conditional formatting (CF) — the openpyxl `rule` API — as opposed to hand-painting cells (which dies the moment data changes).

Steps:
1. Read the project's RAG thresholds from `_reference/kpi_glossary.md` (there are documented goals/targets and colors — reuse them).
2. Apply **conditional formatting** to each rate column: green/amber/red based on the documented thresholds (use the documented hex colors, not your eyeball).
3. Prove the "swaps in new data" claim: the formatting is *rules*, so changing an input value flips the verdict without touching styles.
4. Add a tiny legend cell/sheet documenting "green = meets target, amber = short, red = far short" — CF with no legend is a private language.

**Guiding questions:**
- CF vs manual `PatternFill` on computation: what does each do the day the data changes? (The whole lesson lives here.)
- Thresholds with a *crossover* (e.g., higher-is-better for rates but lower-is-better for AHT) — how do you express "direction" in a rule without explaining in words?

**Deliverable:** `work/attempt_3.xlsx` — daily MIS with target-driven conditional RAG + legend sheet.

---

## Task 4 — The printed daily: freeze, fit, repeat

The supervisor: *"Ops prints this at 7am. Freeze the headers when scrolling, fit it wide, repeat the header on every page, and keep the legend visible."*

**What you'll practice:** combining freeze panes, print titles, fit-to-width, and print areas into one *deliverable print layout* — the "seven o'clock file" test.

Steps:
1. Freeze the header row(s) and team column so scroll pain is zero.
2. Set landscape + fit-to-width so the printed page is one page wide.
3. Repeat headers (`print_title_rows`) and set a print area that stops at the legend.
4. Print preview like a manager: does page 2 start with *headers*, not orphan columns? Iterate.

**Guiding questions:**
- Freeze panes == what a reader experiences scrolling, print titles == what a reader experiences printing — which are the same coordinate problem and how do they differ?
- If the legend must survive on page 1, do you put it in the print area or in the page *footer*? Trade-offs?

**Deliverable:** `work/attempt_4.xlsx` — the printable daily MIS (freeze + fit + repeat + legend placement), print-preview-verified.

---

## Task 5 — Multi-sheet discipline: the small MIS pack

The supervisor: *"Roll Tasks 1–4 into ONE workbook: cover, daily core with live rates, RAG panes, printable version. No orphan files, one open = all the answers."*

**What you'll practice:** the multi-sheet assembly — order, naming, navigation (a link/README map), and keeping sheet-specific print setups without duplicating computation.

Steps:
1. Compose the workbook: `Cover` → `README` → `Daily Core` (Task 2) → `RAG` (Task 3) → `Print` (Task 4) — the navigation order of a daily reader.
2. Make every sheet *refer* to the same computed frames (the single-producer rule from Task 1 — no recompute per sheet).
3. Give each sheet its own print setup (the Print sheet is printable by design; the RAG sheet need not be).
4. Add a one-line navigation note on Cover: "Start here, then Daily Core" — a reader should never ask how the file works.

**Guiding questions:**
- Sheet order vs reader order: is the physical tab order the reading order? What happens when a sheet is provided by someone else's habit (e.g., data tab first)?
- A workbook that shares one *computed frame* across sheets vs one that recomputes per sheet — where does drift between tabs come from in the second design?

**Deliverable:** `work/attempt_5.xlsx` — the integrated MIS pack, one open = all answers, README navigation.

---

### Finish

Attempt all five, then read `medium/results.md`. Add one note per task on what a *reader* experienced when you opened the file that a *writer* couldn't see.

**Move up when:** you can ship a daily MIS workbook — live rates, target-driven RAG, printable — without a second thought, and you *successfully* defended a live-vs-static choice in words.