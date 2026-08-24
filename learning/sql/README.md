# SQL Track — query the database like it's your job

```
You are here: learning/sql/   (basic → medium → advanced)
Master guide: learning/README.md
```

SQL is how you ask a database questions. In this project, all 1.8M rows of collections data live in PostgreSQL, and **every other track depends on this one**: Python re-checks what SQL proves, Excel and Power BI display it. If you can express a KPI in SQL, you genuinely understand the data.

## At work, you reach for SQL when…

- The morning meeting needs yesterday's contact and payment counts — and you have 20 minutes.
- A manager asks *"which teams improved this month and which slipped?"* — one grouped query answers it.
- Someone doubts a dashboard number and you need to prove it from the raw tables.
- Month-end: delinquency buckets, top exposures, how accounts moved between risk levels.

That is exactly what the tasks rehearse.

## What each level covers

| Level | You master | The kind of question you can answer |
|---|---|---|
| `basic/` | Look around a schema; filter, count, sort, group | *"How many? How much? Who are the biggest?"* |
| `medium/` | Join facts to dimensions, bucket with CASE, date logic, CTEs, window functions | *"Why did it change? Break it down by X."* |
| `advanced/` | Rebuild this project's own KPI views (`v_*`) from raw tables and audit differences | *"Is this number true? Prove it."* |

## Setup (one-time)

1. Database running with data loaded — recipe in `_reference/datasets.md` §5.
2. Any SQL client:
   - **DBeaver** (recommended — free, visual, fast to start)
   - **pgAdmin 4** (already ships with the project's docker-compose)
   - **psql** (terminal, fastest once you know it)

## How the files work

Each level folder has:

- `tasks.md` — the assignments, written as supervisor requests
- `results.md` — reasoning guidance per task; open **only after** attempting
- `work/` — your attempt files (`attempt_1.sql`, …); git-ignored scratchpad

Routine: read task → write attempt in `work/` → compare with `results.md` → note what you'd change in your file.

## Move up when…

- **basic → medium:** you can write "count by group for a month, sorted" from memory, no notes.
- **medium → advanced:** joins and date filters feel routine rather than scary.
- **done:** you can rebuild a `v_*` view from raw tables and explain any single-number difference between yours and theirs — that skill *is* the job interview.
