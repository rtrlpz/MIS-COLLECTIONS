# Python Track — pandas, the analyst's automation tool

```
You are here: learning/python/   (basic → medium → advanced)
Master guide: learning/README.md
Prerequisite: sql/basic (so you already know the data)
```

SQL tells you *what* the data says. Python (pandas) is what you use when the work goes beyond one query: **data arrives split into 12 monthly files and someone wants one annual view**, the same cleanup repeats every week and should be automated, or a question needs reshaping that SQL does awkwardly. In real analyst job ads, this is the "Python/pandas" requirement.

## At work, you reach for Python when…

- Data lands as a pile of monthly files and the request is about *the whole year*.
- You catch yourself doing the same copy-paste-clean routine for the third time — time to script it.
- A stakeholder who doesn't know SQL needs a reusable number: *"give me a file/metric I can rerun."*
- You're preparing clean input for an Excel report or a Power BI model.

## The rule that makes this track click

The CSVs in `data_sources/raw/` hold **exactly the same data** as the database you queried in SQL. So every number you compute here has a known correct answer — the one you already proved in SQL.

> When your pandas number matches your earlier SQL number, you didn't just practice syntax — you verified the pipeline end to end. When they differ, you found something worth understanding.

## Setup

1. `conda activate mis-collections` (pandas and numpy are already installed).
2. Confirm these imports run:
   ```python
   import pandas as pd
   import numpy as np
   ```
3. Read from `data_sources/raw/` freely — but it's **read-only**. Save your scripts and outputs under `learning/python/<level>/work/`.

## What each level covers

| Level | You master | Typical request |
|---|---|---|
| `basic/` | Read CSVs, recombine the 12 month folders, filter/group/aggregate, first rate columns | *"Give me January's totals — from files, not the DB."* |
| `medium/` | Merges, datetime handling and resampling, bucketing, rank-within-group, pivots | *"Rank agents within each team by KP%; flag the bottom three."* |
| `advanced/` | Rebuild the project's KPI logic purely in pandas at ~1.36M-row scale | *"Prove the SQL numbers using only files."* |

## How the files work

Each level folder has:

- `tasks.md` — assignments written as supervisor requests
- `results.md` — reasoning guidance; open **only after** attempting
- `work/` — your scripts and outputs; git-ignored scratchpad

Routine: read task → attempt in `work/` → cross-check against your SQL numbers → then compare with `results.md`.

## Move up when…

- **basic → medium:** you can load and combine two months of files without looking anything up.
- **medium → advanced:** merges and date handling feel like tools, not obstacles.
- **done:** you can turn *"RPC% by team for January, Tarjeta only, worst first"* into a reusable function — and defend every denominator in it.
