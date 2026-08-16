# Python Track — README

```
learning/
├── _reference/            ← READ FIRST: datasets.md, kpi_glossary.md, data_dictionary.md
├── git-cli/
├── sql/                   ← done first (the launch pad)
├── python/                ← YOU ARE HERE
│   ├── README.md
│   ├── basic/    tasks.md + results.md + work/
│   ├── medium/   tasks.md + results.md + work/
│   └── advanced/ tasks.md + results.md + work/
├── notebooks/  excel/  powerbi/
└── README.md             ← MASTER GUIDE
```

## Why Python after SQL

You know *what* the data says (SQL). Python is where you ask the data things SQL wasn't made for: file recombining, machine-shaped exploration, custom transformations, and — at the end — building the exact numbers a dashboard will show.

**The one rule that makes this track work:** the CSVs in `data_sources/raw/` and the PostgreSQL database hold the **same data**. You already verified answers in SQL. Now you'll reach the same answers through pandas. When your Python number matches your earlier SQL number, you've *confirmed the pipeline*, not just practiced syntax.

## Setup

1. Activate the conda env: `conda activate mis-collections` (Python + pandas already present).
2. Confirm the imports below work.
3. You'll be reading `data_sources/raw/` — **read-only**. Never write into it; save work under `learning/python/<level>/work/`.

```python
import pandas as pd
import numpy as np
```

## How this track differs from SQL

| SQL mindset | Python mindset |
|---|---|
| One query answers one question | One script answers a question AND reshapes output |
| Joins    expressed in `JOIN … ON` | Merges expressed in `pd.merge(...)` |
| Aggregation expressed in `GROUP BY` | Aggregation expressed in `groupby(...)` |
| Date logic in SQL functions | Date logic in `pd.to_datetime`, `dt.*`, `resample` |

Rule of thumb: **if the answer needs to be *reused* or *combined*, Python wins. If it needs to be *audited against a view*, SQL wins.** You'll flex both.

## Principles

- **Never mutate the raw CSVs** — copy what you need into `work/`.
- **Recombine the month folders** — the whole trick of this track is that data arrives split by month, exactly like a real warehouse partition. Your first step is *re-assembling* it.
- **Prefer `pd.merge(..., how=...)` to SQL-style confessional comments** — state the `how` out loud; it is the join semantics.
- Attempt → commit to your numbers → **cross-check against the SQL numbers you already got** → then read `results.md`.

## The three levels

| Level | What you'll master | Checks |
|---|---|---|
| `basic/` | Read CSVs, recombine the 12 month folders, filter/group/aggregate, first rate columns. | 4 tasks |
| `medium/` | Merges, datetime/resampling, bucketing, group transforms (rank within group), pivot/crosstab. | 5 tasks |
| `advanced/` | Rebuild the project's KPI logic purely in pandas, the promise chain, the migration matrix, and working at ~1.36M rows with fixed dtypes. | 4 tasks |

## Golden rule

Attempt everything in `work/`. Keep "wrong" files — the diff between your attempt and the guidance *is* the lesson.

## What you'll be able to do afterward

Turn "RPC% by team for January, only Tarjeta accounts, sorted by worst first" into a **reusable pandas function** — one you could hand to a colleague who doesn't write SQL at all.