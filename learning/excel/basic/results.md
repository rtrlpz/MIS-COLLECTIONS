# Excel — Basic — Results (Guidance)

```
learning/
├── _reference/            ← datasets.md, kpi_glossary.md, data_dictionary.md
├── sql/  python/  notebooks/  powerbi/  git-cli/
├── excel/
│   ├── README.md
│   └── basic/             ← YOU ARE HERE
│       ├── tasks.md
│       ├── results.md     ← current file
│       └── work/
└── README.md
```

**How to use this file:** attempt → open the file → read one section. Guidance only — reasoning paths, steps-with-why, verification strategy, traps. No full code, no computed values.

---

## Task 1 — Workbook anatomy

**Thinking path:**
- openpyxl's mental model: a `Workbook` is sheets; a sheet is a grid of `Cell`s addressed `A1`-style; styles attach to cells via `Font/PatternFill/Alignment`. The *why* of the three-sheet split: Cover = identity (name + who + when), README = operating manual (what this file IS), Raw Input = the "put your data here" contract for the future me.
- Tab colors: recognizable-at-a-glance is the goal, not palette art — one color per sheet *kind* (identity/instruction/data) tells a reader where they are without reading a word.

**Verification strategy:**
- Reload the file (`openpyxl.load_workbook`) and assert sheet names + tab colors — a round trip that a *viewer open* can't give you.
- Sheet order matters to a reader: `Cover` first, then `README`, then `Raw Input`.

**Traps & worth knowing:**
- Merged cells for titles are fine; merging data ranges breaks sorting/filtering and confuses `read-only` loads — use a title merge, never a data merge.
- The default sheet name is `Sheet`; leaving it = a typo magnet. Rename or delete it every time.

---

## Task 2 — pandas → Excel

**Thinking path:**
- `df.to_excel(path, sheet_name=…, index=False)`: `index=False` because the Index is an artifact of pandas, not data (unless you deliberately promote a key column into a column first — which is the *right* move for account IDs).
- The draft→deliverable pass: header styling, column widths (`width` per header), number formats (counts as `#,##0`, not float with `.0`), and a total row.
- Live vs static: a `=SUM(...)` live cell refreshes when inputs change — right for a MIS that gets new data. A pasted total is static — right when the workbook must not re-communicate (a frozen audit copy). State which you chose; "decide and defend" is the discipline being practiced.

**Verification strategy:**
- Reopen and check: does the header row exist? Does the counts column show no `.0`? Do the per-team numbers match the proven numbers from Python basic Task 3?
- The total row = sum of the per-team column (an Excel SUM that a reader can point at).

**Traps & worth knowing:**
- `to_excel` writes values, not *live links* to the CSV; that's correct for a report.
- Default `startrow`/`startcol=0` leaves no room for a title block — start later (`header`/`startrow=2`) when you plan a title row above the table.

---

## Task 3 — Formatting is a second language

**Thinking path:**
- Vocabulary: `Font(bold=True, color="FFFFFF")`, `PatternFill(...)`, `Alignment(horizontal="center")`, thin `Border`, and above all `number_format`. A percent *must* be a number with format `0.0%` — a string `"35%"` is dead text: it breaks sorting, formulas, and pivots. The number format IS the contract.
- Restraint: banded rows (alternating fill) aid scanning; saturation gradients over a rate table are décor that misleads (readers scale color, not numbers). The goal is "the eye lands on the numbers", not on the filter.
- Freeze the header (`freeze_panes = "A2"`) so scrolling keeps the column sense alive.

**Verification strategy:**
- Open it: rate column displays `35.0%` while the underlying cell still holds `0.35` (select the cell and read the formula bar — that duality is the point).
- Alignment consistent (numbers right, text left, headers center) — the checker is a glance.

**Traps & worth knowing:**
- `fill` and `font` need `static` from a style object; reassigning a fresh style per cell is typical and *intended* in openpyxl.
- Don't format a string column with `0.0%`; the format is a reader contract, and the contract must be true.

---

## Task 4 — Printable or it doesn't exist

**Thinking path:**
- Page setup is where "report" earns its title: `page_setup.orientation = "landscape"` (a wide table), `fitToWidth=1` (one page wide *by scaling width only*, keeping rows flowing to page 2+), repeated header via `print_title_rows` so page 2 has column headers, and an explicit `print_area` so phantom empty columns don't bleed across pages.
- Why fit-to-width, not fit-to-one-page: a wide *short* table should print on one page total, but a *tall* table shouldn't be squashed to fit vertically — the tool must match the table's shape.
- Footers (`footer.center.text` style entries for sheet/page) give a printed doc breadcrumbs — "which sheet, which page" survives the drop on a desk.

**Verification strategy:**
- **Print preview** — the only honest check. Iterate: if page 2 exists, it's a *tall* continuation (fine) with headers repeated (required), not a *splatter* of overflow columns.
- Zoom is not a setting that travels — fitToWidth is what actually holds on other machines.

**Traps & worth knowing:**
- `print_area` as a range string must be kept in sync if your data grows — re-set it when you regenerate (it does not auto-track the used range).
- If rows to a page are few, the fix is the *data layout* (fewer columns, tighter wrap), not scaling font to 6pt.