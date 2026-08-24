# Notebooks Track — explain your work so others trust it

```
You are here: learning/notebooks/   (basic → medium → advanced)
Master guide: learning/README.md
Prerequisites: sql/basic + python/basic
```

A query answers a question; a script produces a number. A **notebook** is where you show a *reader* how the number was made — code, results, charts and explanations in one document, top to bottom. At work, this is how analysts document methodology, hand over projects, and win arguments: not *"trust me"*, but *"run it yourself, here's every step."*

## At work, you reach for a notebook when…

- Someone asks *"how exactly is this KPI calculated?"* and a one-liner won't settle it.
- You need to share an analysis with commentary so a colleague can rerun it next month.
- An audit or review wants to see your working — assumptions, checks and all.
- You're exploring a new dataset and want your thinking to be saved as you go.

## Setup

1. `conda activate mis-collections`
2. Launch with `jupyter lab` in the repo root (or use VS Code's notebook editor — equivalent).
3. Save notebooks under `learning/notebooks/<level>/work/` (git-ignored scratchpad).

- **basic** reads the same CSVs Python reads (no database needed).
- **medium+** can also query the live database — handy for putting your calculation and the project's official view side by side in one artifact.

## The one law of notebooks

Cells run in whatever order *you* ran them — which means a notebook can quietly depend on steps executed out of order (or on variables deleted hours ago). The fix is one habit:

> Before sharing or finishing: **Restart Kernel → Run All**. If it doesn't run cleanly from the top, it isn't done.

## What each level covers

| Level | You master | Typical deliverable |
|---|---|---|
| `basic/` | Notebook hygiene: cells, markdown text, run-order discipline, a first chart | A tidy mini-analysis anyone could rerun |
| `medium/` | Mixing SQL and pandas in one notebook; clear charts; date-based visuals | *"Here's the trend, here's why, here's the proof"* |
| `advanced/` | A self-verifying EDA that checks its own numbers against the project views | The kind of artifact that survives an audit |

## How the files work

Each level folder has:

- `tasks.md` — assignments written as supervisor requests
- `results.md` — reasoning guidance; open **only after** attempting
- `work/` — your notebooks; git-ignored scratchpad

Routine: read task → attempt in `work/` → Restart & Run All → then compare with `results.md`. Where a task repeats a SQL/Python task, the *number* is already proven — your job is the explanation, not re-derivation.

## Move up when…

- **basic → medium:** your notebook runs top-to-bottom on a fresh kernel, first try.
- **medium → advanced:** your charts make the point before you finish the sentence.
- **done:** you can hand a colleague a notebook that explains, computes and verifies a KPI without you in the room.
