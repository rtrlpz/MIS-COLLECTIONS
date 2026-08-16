# Notebooks Track — README

```
learning/
├── _reference/            ← READ FIRST: datasets.md, kpi_glossary.md, data_dictionary.md
├── git-cli/
├── sql/  python/          ← done first (the launch pads)
├── notebooks/             ← YOU ARE HERE
│   ├── README.md
│   ├── basic/    tasks.md + results.md + work/
│   ├── medium/   tasks.md + results.md + work/
│   └── advanced/ tasks.md + results.md + work/
├── excel/  powerbi/
└── README.md             ← MASTER GUIDE
```

## Why notebooks after SQL and Python

You can query (SQL) and you can program (pandas). A notebook is where those two **meet a reader**: cell-by-cell documentation of *how* a number was made. In a production shop this is how an EDA becomes a *explainable* artifact — sibling of the KPI views you've been re-deriving.

Notebooks mix both tools on purpose:
- **basic** reads the same CSVs Python reads (no server needed).
- **medium+** can reach the live database, so you can hold a notebook computation against a `v_` view in the same artifact.

## Why this track is useful at all (say it out loud)

> "A notebook is the only artifact in this stack that shows *how* — not just *what*." — commit this to memory.

## Setup

1. `conda activate mis-collections`
2. `jupyter lab` in the repo root (or VS Code `.ipynb` editor, equivalent).
3. `.ipynb_checkpoints/` is git-ignored project-wide — save notebooks under `learning/notebooks/<level>/work/`.

## The three levels

| Level | What you'll master | Checks |
|---|---|---|
| `basic/` | Notebook hygiene — cells, markdown, run-order discipline, and a first chart. | 4 tasks |
| `medium/` | Mixing SQL and pandas in one artifact; storytelling charts; datetime viz. | 5 tasks |
| `advanced/` | A reproducible EDA that **verifies itself** against the project views — the deliverable notebook. | 4 tasks |

## Running-order discipline (the #1 notebook law)

- A notebook has no hidden state; cells execute in **any order you choose**. That's the power and the trap.
- Rule: after writing the whole notebook, **Restart Kernel & Run All** as the last act. If it fails, your notebook was written by accident, not by design.

## Golden rule

Same as always: attempt → commit → then read `results.md`. Where a task mirrors a SQL/Python task, its *number* is already proven — the notebook's job is to present, not re-derive from scratch.