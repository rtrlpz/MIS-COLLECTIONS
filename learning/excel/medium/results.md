# Excel — Medium — Results (Guidance)

```
learning/
├── _reference/            ← datasets.md, kpi_glossary.md, data_dictionary.md
├── sql/  python/  notebooks/  powerbi/  git-cli/
├── excel/
│   ├── README.md
│   └── medium/            ← YOU ARE HERE
│       ├── tasks.md
│       ├── results.md     ← current file
│       └── work/
└── README.md
```

**How to use this file:** attempt → open → read one section. Guidance only — reasoning paths, steps-with-why, verification strategy, traps. No full code, no computed values.

---

## Task 1 — One producer, many consumers

**Thinking path:**
- The producer/consumer split is the engineering lesson: a single well-factored computation pipeline (reusing your Python) returns the three views; the workbook then styles each differently. Duplication of *presentation* is fine in Excel; duplication of *computation* is where inconsistent numbers come from.
- Consistent visual language across sheets (shared header style, shared percent format) says "one author, one source" to the reader — the opposite of a franken-file.
- The README tab documents source + purposes + which cells are formulas vs values — the operating manual (same role as Cover/README in basic Task 1).

**Verification strategy:**
- Three sheets agree on any overlapping figure (per-team daily *sums to* the per-product totals within a team-agnostic slice — the partition identity again).
- Re-open after regeneration: the three views still trace to one source cell/doc line.

**Traps & worth knowing:**
- Same number, two processes = real drift risk. When you catch yourself pasting from a *second* computation, that's the smell to fix at the producer, not the consumer.
- A view you *want* to format differently (e.g., monthly as % vs count) isn't duplication — state the choice in README so future-you doesn't "fix" it.

---

## Task 2 — Live formulas

**Thinking path:**
- Formula-string cells (`=B2/C2`) are openpyxl's way to write live cells. The MIS design rule: raw counts = *values* (pandas, proven); derived rates = *formulas* (live). A body of thousands of volatile formulas is slow AND fragile — one wrong drag in a viewer and a column of `#REF!` propagates.
- Divide-by-zero: a team with zero connects yields `#DIV/0!`. That *is* the honest datum, but a 7am MIS with error glyphs is a distraction — an explicit `IFERROR` policy (`""` blank vs a dash) stated in the README is the professional pre-empt. Decide it deliberately (the view pipeline already shows how the house treats sparse channels).
- Test the claim: open, edit a count cell, watch the rate cell move. If it doesn't, you wrote a value, not a formula.

**Verification strategy:**
- Spot the same rate computed as formula vs the proven value from SQL/Python basic — agree.
- Re-derive one formula result by hand in a comment (the "does my formula make sense" pass).

**Traps & worth knowing:**
- Formulas reference cells by *address*, so inserting a column can silently shift semantics — lock ranges deliberately (`$B2`, `$B$2`).
- A pasted `0.35` with `0.0%` format is *not* a formula — the format lies for values; only a real `=…` is live.

---

## Task 3 — RAG at scale

**Thinking path:**
- Conditional formatting (the `rule` API — e.g. a *cell-is/**between/above* rule in a spec, or an equivalent openpyxl rule) evaluates against cell *values at display time*. Handpainted fills are static — the moment data changes, the verdict is stale. CF is the only truthful color at scale.
- Thresholds come from the reference (documented goals for PTP%, KP%, RPC%, utilization, ACW/AHT; colors green `00B050`, amber `FFC000`, red `FF0000`) — reuse, don't re-improvise.
- Direction: higher-is-better (rates) vs lower-is-better (AHT/ACW) — CF rules are value-bounded only; state the direction in the legend, or encode via operator choice per column.
- A legend cell/sheet is the language key — without it, color is cryptography.

**Verification strategy:**
- Edit an input (push a rate under its threshold) → the CF verdict flips without touching styles. That demo IS the test.
- Legend thresholds match the reference *to the digit*.

**Traps & worth knowing:**
- Applying CF to a range that later grows leaves new cells ungoverned — extend rules to a reasonable superset row range deliberately.
- Two rules on one range conflict silently; keep one rule per column-family and verify by eyeball on 3 boundary rows.

---

## Task 4 — Printed daily

**Thinking path:**
- Freeze panes = the *scroll* experience; print titles = the *page* experience; same coordinate insight, two outputs. `freeze_panes` at the header+key-column corner, `print_title_rows` for repeat.
- Fit-to-width (landscape + up to one page wide) is the daily sheet's body shape — a *tall* table, not a squash-to-one-page artifact. Print area stops at the legend so a trailing empty column never bleeds.
- Legend placement: inside print area (scroll-safe, costs page 1 real estate) vs page footer (always visible, static) — trade widths; pick and defend.

**Verification strategy:**
- **Print preview**, iterated: page 2 begins with headers and the ramp of data, no orphan columns, legend either in footer or page 1.
- Scrolling test: header + team column stay under your thumb.

**Traps & worth knowing:**
- `print_title_rows` and `print_area` are separate; forgetting either yields the classic "page 2 is naked columns" print.
- A wide sheet auto-fit via scaling can shrink the rate text to unreadability — the *layout* (fewer columns, wrapped headers) is the lever, not font foreshortening.

---

## Task 5 — Multi-sheet discipline

**Thinking path:**
- Composition: `Cover → README → Daily Core → RAG → Print`. Sheet order = reading order for *this* file. Shared computation frames mean sheets *reference* the same data — cross-sheet drift is eliminated by construction, not by discipline.
- Per-sheet print setup is part of the spec: the Print sheet is meant to be printed; RAG is an on-screen analytic — don't force one global page setup.
- The Cover navigation line ("Start at Daily Core") is the reader contract; a file with no orientation line expects the reader to reverse-engineer tab order.

**Verification strategy:**
- Change one raw count in an input location → Daily Core rates, RAG verdicts, and Print sheet all update in one open (single-producer proof, in workbook form).
- A stranger opens the file and, following the Cover line, reaches Daily Core without asking how it works.

**Traps & worth knowing:**
- "Data tab first" is a file-author habit, not a reader need — the *reader* opens the file to *answer*, so put the answer sheet first and data deeper.
- Hidden helper sheets (a scratch computations tab) should be named obviously (`!Helpers`) — hiding state without signaling it is the notebook-hidden-cell trap in workbook form.