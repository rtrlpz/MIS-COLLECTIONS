# Notebooks — Basic — Results (Guidance)

```
learning/
├── _reference/            ← datasets.md, kpi_glossary.md, data_dictionary.md
├── sql/  python/  excel/  powerbi/  git-cli/
├── notebooks/
│   ├── README.md
│   └── basic/             ← YOU ARE HERE
│       ├── tasks.md
│       ├── results.md     ← current file
│       └── work/
└── README.md
```

**How to use this file:** attempt → commit → read one section. Guidance only — reasoning paths, steps-with-why, verification strategy, traps. No full code, no computed values.

---

## Task 1 — The blank contract

**Thinking path:**
- Markdown-first is not decoration: it forces you to *promise* what code will deliver. If you can't write the question in words, you don't know it clearly enough to code it. That's the contract.
- The title/three-sentences: describe the project (collections analytics; tables you meet; the one-liner story: 12 months of interactions/PTPs/payments over a star schema).
- Cell 2 loads one dim + one fact, prints shape/head/dtypes. "Just enough to prove you can" is the discipline — don't build a kitchen.

**Verification strategy:**
- Restart & Run All from a cold state. Success = top-to-bottom reproducibility — the notebook law.
- Actually *close* and re-open the file, then Run All — a notebook that depends on hidden Kernel state (a variable you computed in a cell you deleted) fails here. That's the test that separates "written" from "accidental".

**Traps & worth knowing:**
- Keep cells numbered/in-order by *content* dependency, not by whimsy. A reader following a notebook that jumps (cell 5 uses a variable defined in cell 2 with a mutation from cell 4) is reading someone's scratchpad.
- Output bloat: huge `head()` prints make the file ugly; print deliberately.

---

## Task 2 — Code cells that don't wander

**Thinking path:**
- The analyst drafts pose it well: the *expectation line* is the honesty device. You write "I expect January–per-team to sum roughly to Jan total and favor the bigger teams" before you run. When the data surprises you, that's a written finding, not a suspicion.
- Cell granularity: load/reassemble = cell; filter+attach+count = cell; print/sort human-read = cell. Each cell is one *logical step*. Debugging = knowing which step misbehaved.

**Verification strategy:**
- Run All: if the reassembly cell prints, the filter cell depends on its variable, the count cell on that — any ordering break is *visible when the notebook fails*, and that visibility is the point of clean cells.
- Compare output to python basic Task 3 (the number is already proven) — the notebook's value is *presentation*, not re-derivation.

**Traps & worth knowing:**
- Shadowing: a variable you reuse later (e.g. `df` at two grains) silently changes cell behavior when run in a different order. Name frames by meaning (`interactions_year`, `jan_team`).
- `%matplotlib inline`-style magic isn't the point here; matplotlib default backend in Jupyter is fine for line/bar.

---

## Task 3 — First chart, first lie

**Thinking path:**
- Weekly volume via Monday-anchored resample (python medium Task 2 knowledge). The chart's claim: "weekly volume is stable / dipped in week X". Every chart makes a claim — decide what yours is before drawing.
- The optical-illusion check is the heart: if you resample on Sunday-anchored buckets, weeks *split* oddly around month boundaries and one "week" can look empty or fat. Monday-anchored + weekend-void design means a naive dip can be purely an anchor artifact.
- Axis honesty: a non-zero y-origin exaggerates small dips; annotate/state the choice. Marking weekend columns ("this portfolio has no weekend interactions") turns the sawtooth from noise into *information*.

**Verification strategy:**
- Compute both daily and weekly; overlay or eyeball: does the "dip" in the weekly line appear as a real *weekday* drop in the daily trace, or a boundary artifact?
- Restart & Run All — the chart must regenerate from the reassembled table (no stale cached frames).

**Traps & worth knowing:**
- An unlabeled axis is a silent lie your future self will pay for — title + axis labels non-negotiable.
- An empty Monday bucket (holiday) produces a *legitimate* dip — note it as such rather than "fixing" it.

---

## Task 4 — A chart that takes a stand

**Thinking path:**
- Question 1: volumes per channel — counts attempted *and* connected matter (a channel with huge attempts but low connects is a dialer efficiency story).
- Question 2: RPC% per channel — a *rate* with wildly different denominators. A straight bar+% overlay misleads when denominators differ; you already know the ratio-of-sums trap. Two small panes (bars for volume, bars for rate) usually beat a fused two-axis chart for honesty.
- The takeaway sentence is the analysis: "Dialer carries the volume but its rate is X vs Manual's Y — the team should look at Z." If you can't write that sentence, the chart is just decoration.

**Verification strategy:**
- The RPC% values in your rate pane match python basic Task 4 (proven number, now *presented*).
- A stranger should absorb the takeaway from the Markdown sentence alone; the chart is its evidence.

**Traps & worth knowing:**
- Marginal-y-axis chart (echoing Task 3): two-axis figures are hard to read honestly; prefer small multiples.
- Value labels on bars: good; but labels *plus* a hierarchy of axes can clutter — sort by volume and keep labels tight.