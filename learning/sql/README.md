# SQL Track — README

```
learning/
├── _reference/            ← READ FIRST: datasets.md, kpi_glossary.md, data_dictionary.md
├── git-cli/
├── sql/                   ← YOU ARE HERE
│   ├── README.md
│   ├── basic/    tasks.md + results.md + work/
│   ├── medium/   tasks.md + results.md + work/
│   └── advanced/ tasks.md + results.md + work/
├── python/
├── notebooks/
├── excel/
├── powerbi/
└── README.md             ← MASTER GUIDE (learning path)
```

## Why SQL is the *first* track

**SQL is the language of the data itself.** Every other tool in this environment — Python, notebooks, Excel, Power BI — either *re-exports* what SQL produces or *reproduces* what SQL does. If you can express a KPI in SQL, you genuinely understand the data model: joins, grains, and rates stop being magic and become logic you control.

The moment of mastery is when a supervisor asks a question and you can answer it in ONE query faster than anyone in Excel.

## What this track is (and isn't)

- **Is:** realistic business questions against a live PostgreSQL database (~1.8M rows), answered with real SQL, verified against the project's own `v_` KPI views.
- **Is not:** a syntax encyclopedia. We cover the ~30 working parts of SQL that analysts use daily — you'll pick up exotic clauses from the project's own `002_kpi_views.sql` when you read them in advanced.

## Prerequisites

1. Docker Postgres running with data loaded (see `_reference/datasets.md` §5).
2. A SQL client. Any of:
   - **DBeaver** (recommended — free, connects fast, has a SQL editor with result grid)
   - **pgAdmin 4** (ships with your docker-compose)
   - **psql** (CLI, fastest once known; it's also what the pipeline uses)
3. Read `_reference/datasets.md` and `_reference/kpi_glossary.md` (10 min).

## The three levels

| Level | What you'll master | Checks |
|---|---|---|
| `basic/` | Read a star schema, filter, sort, aggregate, group. Answer "how many / how much" questions per slice. | 4 tasks |
| `medium/` | Join facts to dims, CASE bucketing, date logic, CTEs, window functions, deduplication. Answer "why did X change" questions. | 5 tasks |
| `advanced/` | Rebuild the project's own KPI views from raw tables, DPD migration logic, composite scorecards. Answer "is this true" questions and *verify against the real views*. | 4 tasks |

## The golden rule (per level)

1. Attempt every task in `work/`.
2. Keep your `.sql` files even when they're "wrong" — the wrong-then-fixed path is where learning happens.
3. Only then open `results.md`. Use it to *compare*, not to copy.

## Conventions used in answers

- `results.md` is **guidance-only**: it teaches the reasoning path, steps-with-why, and verification strategy — it deliberately shows **no full runnable query** and **no computed numbers**. The learning happens when *your* query gets compared to the guidance, not copied from an answer key.
- Short syntax fragments (never full solutions) appear only where the *syntax* is the lesson — e.g. `WHERE` vs `HAVING`, or `::numeric` for division.
- When a task should reproduce a project view (e.g. `v_daily_mis`), the guidance points you to *compare* your query's output against that view — "does my number match yours" is the real-world validation skill. The comparison is the lesson; the number is not printed.

## What you'll be able to do afterward

Produce, in one file, the answer to questions like:
> "RPC% by team for January, only Tarjeta accounts, sorted by worst first, with the previous month's RPC% beside it."

That is the SQL capability a collections department pays for. Let's start.