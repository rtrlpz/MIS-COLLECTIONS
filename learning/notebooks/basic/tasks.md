# Notebooks — Basic — Tasks

```
learning/
├── _reference/            ← READ FIRST (datasets.md, kpi_glossary.md, data_dictionary.md)
├── sql/  python/  excel/  powerbi/  git-cli/
├── notebooks/
│   ├── README.md
│   └── basic/             ← YOU ARE HERE
│       ├── tasks.md       ← current file
│       ├── results.md     ← guidance, peek AFTER attempting
│       └── work/          ← your .ipynb files live here
└── README.md
```

**Up from python basic:** you can read CSVs, reassemble months, and group. A notebook adds the *reader*: markdown, cell discipline, and a chart that makes a point.

**Setup:** `jupyter lab` (see `notebooks/README.md`). Save every task as `learning/notebooks/basic/work/attempt_*.ipynb`.

**Discipline:** attempt → commit → **Restart Kernel & Run All** → then read `results.md`.

---

## Task 1 — The empty notebook is a blank contract

The supervisor: *"You're new. Write a two-cell notebook that tells a stranger what this project does and what the data looks like. Nothing more."*

**What you'll practice:** markdown-first thinking — the habit of writing the *question* before the code.

Steps:
1. Cell 1 (Markdown): a title and three sentences of *what this repo analyzes* (collections, the tables you keep meeting).
2. Cell 2 (Code): load one dim + one fact CSV, print shape, head, dtypes — just enough to prove you can.
3. Run cells in order; add a Markdown line under the output reading the *key observation* from the output (grain, sparseness — whatever is true).
4. Restart & Run All; if it breaks, fix the ordering (a newborn notebook should never need manual arranging).

**Guiding questions:**
- Which of your two cells would a reader read first? Why must a notebook be readable top-to-bottom *even by someone who never runs it*?
- Markdown before code: when is the question stated *before* the query, and why does that help you?

**Deliverable:** `work/attempt_1.ipynb` — title markdown + load cell + observation note.

---

## Task 2 — Code cells that don't wander

The supervisor: *"January per team, sorted. You proved this in pandas — now prove it *visibly*, three crisp cells."*

**What you'll practice:** cell granularity — one question per cell, self-labeled, "expectation line" before each computation (the EDA contract).

Steps:
1. Markdown cell: the supervisor's question, *restated in your words*.
2. Code cell: load + reassemble (reuse your python-basic reassembly; if it's long, that's a hint the cell is too fat — split into "load" / "transform").
3. Code cell: filter January, attach team, count, sort. Print result.
4. Markdown cell: what you expected vs what the numbers show — one or two sentences. (This "expectation vs reality" note is the analyst's drafts.)

**Guiding questions:**
- A cell that both loads AND computes AND prints — why is it harder to debug than three smaller ones?
- When you Restart & Run All, why must the *variable pipeline* (deps: table → filtered → counted) survive in order? What if you shadow-used a variable above?

**Deliverable:** `work/attempt_2.ipynb` — expectation-vs-result markdown + 3–4 clean cells.

---

## Task 3 — First chart, first lie

The supervisor: *"The ops manager asks 'did weekly volume dip?' — draw the answer and check it isn't an optical illusion."*

**What you'll practice:** one honest chart — weekly interaction volume from your reassembled table — plus the *reality-check discipline*: a chart is a claim, verify it.

Steps:
1. Compute weekly counts (Monday-anchored, as in python medium Task 2).
2. Plot a line of weekly volume. Put the axis labels and a title on it — unlabeled axes are unprofessional.
3. To test for an "optical dip": mark weekends in the x-axis (or annotate) since this portfolio has none by design — and compare a weekly-dip in the line to the *daily* trace. Is the "dip" real or an artifact of the resampling anchor?
4. Write a Markdown note: what the chart claims, and what you did to check it.

**Guiding questions:**
- Why is a weekly line "safe" while a daily line shows sawtooth weekends — and which might make a manager misread a dip?
- If your y-axis starts at a non-zero value, what claim does that imply? (Tune the axis, then state the choice.)

**Deliverable:** `work/attempt_3.ipynb` — weekly chart with labels + the illusion-check Markdown.

---

## Task 4 — A chart that takes a stand

The supervisor: *"Which channel dominates calls? Show it in a way a director can absorb in five seconds."*

**What you'll practice:** chart *choice* as analysis — categorical total vs rate, bar vs other idiom, and labeling the takeaway as the actual deliverable.

Steps:
1. From the year's interactions, per channel: total calls (attempted AND connected — decide) and RPC% (reuse your python-basic Task 4).
2. Pick the right idiom: a bar/column for volumes, a second small one (or same) for rate — or a two-axis figure? Justify the choice in Markdown.
3. Label your chart; put the one-sentence takeaway in the Markdown cell (this sentence IS the analysis; the chart is only evidence).
4. Optional polish: sort by volume, add value labels.

**Guiding questions:**
- Why would a % overlaid on bars mislead when denominators differ wildly per channel?
- If a channel has ~zero connected calls, does bar-height obscure an interesting story (undialable channel) — how would a rate-only view expose it?

**Deliverable:** `work/attempt_4.ipynb` — labeled chart + one-sentence takeaway + a "why this chart" comment.

---

### Finish

Attempt all four, then read `basic/results.md`. In your final notebook add a summary Markdown cell: what you learned about working cell-by-cell, and one thing you'd do differently.

**Move up when:** you can write a notebook that a stranger can read top-to-bottom and *believe*, without watching you run it once.