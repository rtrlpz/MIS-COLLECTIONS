# learning/ — The MIS-COLLECTIONS Learning Environment

```
learning/
├── _reference/                  ← READ FIRST: datasets.md · kpi_glossary.md · data_dictionary.md
├── git-cli/                     ← version control for your work (single level, ~30 min)
├── sql/                         ← the launch pad — query the live star schema
│   ├── README.md
│   ├── basic/      tasks.md + results.md + work/
│   ├── medium/     tasks.md + results.md + work/
│   └── advanced/   tasks.md + results.md + work/
├── python/                      ← the reshaping tool — pandas on the raw CSVs
│   ├── README.md
│   ├── basic/  ├── medium/  └── advanced/      (same shape as sql/)
├── notebooks/                   ← the explainer — how a number was made, cell by cell
│   ├── README.md
│   ├── basic/  ├── medium/  └── advanced/
├── excel/                       ← the shipper — printable reports, live formulas, audit packs
│   ├── README.md
│   ├── basic/  ├── medium/  └── advanced/
├── powerbi/                     ← the living dashboard — DAX, RLS, Calculation Groups
│   ├── README.md
│   ├── basic/  ├── medium/  └── advanced/
└── README.md                    ← current file (master guide)
```

## What this is

A self-contained practice lab built on this project's **own datasets**. Everything you touch is real project material — the same 12 months of collections data that lives in the PostgreSQL star schema and as monthly CSV folders. You are not doing toy exercises; you are building the skills to defend the numbers a collections department ships.

**Five tools, one truth.** The point of the whole environment is that the *same* number flows through SQL → Python → notebooks → Excel → Power BI. When your pandas answer matches your SQL answer matches your Excel audit matches your dashboard, you have *proven* the pipeline, not just practiced syntax.

## The learning path (read in order)

| Step | Track | You'll end up able to… |
|---|---|---|
| 1 | **SQL** (`sql/`) | Query the star schema: filter, join, bucket, window, and **reproduce the project's own KPI views** — then audit your number against theirs. |
| 2 | **Python** (`python/`) | Reassemble the month-folder CSVs, reshape with pandas, rebuild the KPI logic *without a database*, at full 1.36M-row scale. |
| 3 | **Notebooks** (`notebooks/`) | Present the analysis as a living, self-verifying, reproducible document (the "explainer"). |
| 4 | **Excel** (`excel/`) | Ship the numbers as a report: live formulas, target-driven RAG, a period-end pack that **audits itself** against the views. |
| 5 | **Power BI** (`powerbi/`) | Build the living dashboard: measures, time intelligence, a Calculation Group, RLS — and a Verification page that proves its own numbers. |
| 6 | **git-cli** (`git-cli/`) | Version-control all of the above safely: staging, branches, recovery, and the never-ship-secrets pact. |

Each track has `basic / medium / advanced` levels. `tasks.md` poses the supervisor's questions; `results.md` teaches the *reasoning path* (never a ready-made answer).

## The rules that make this environment work

1. **Attempt → commit → compare.** Do the task in `work/`, commit to your answer, *then* open `results.md`. Keeping "wrong" files is not failure — the wrong-then-fixed path is where learning lives.
2. **No answer keys with numbers.** `results.md` guides, it never hands you the result. If a number can be found by running the data, you find it — the guidance teaches you *how to think about it*.
3. **The advanced rule:** a number that differs from the reference views (`v_*`) is a **finding**, not a failure. Name the semantic divergence and prove it. This rule is the track's spine: SQL advanced, Python advanced, Excel advanced, Power BI advanced all practice it.
4. **Never edit the data.** The raw CSVs (`data_sources/raw/`) are generated; the DB is loaded by the pipeline. All tools only *read*.
5. **Keep the repo honest.** Never commit `.env`/credentials, generated data, or `work/` scratch (all git-ignored). Your saved attempts live in `work/`; your *documentation* (tasks/results/READMEs) is what belongs in history.

## Prerequisites

| Track | Needs | Where to get it |
|---|---|---|
| SQL | PostgreSQL 15 in Docker + data loaded + a client (DBeaver/pgAdmin/psql) | `_reference/datasets.md` §5 |
| Python | conda env `mis-collections` (pandas, numpy) | `python/README.md` |
| Notebooks | Jupyter (any client) + the env above | `notebooks/README.md` |
| Excel | `pip install openpyxl` + Excel/LibreOffice | `excel/README.md` |
| Power BI | Power BI Desktop (Windows) + the DB | `powerbi/README.md` |
| git-cli | a terminal with `git` | nothing to install |

## Reference strategy (the shared library)

`_reference/` holds the environment's shared map, copied **self-contained** so the lab works offline:
- `datasets.md` — where the data lives, tables, KPI views list, connection recipe, healthy ranges.
- `kpi_glossary.md` — the KPI definitions, formulas, calculation traps, targets, RAG colors, scorecard weights.
- `data_dictionary.md` — the live star schema, column-by-column, plus the trap list and house conventions.

Read `datasets.md` first, always. When a task says "the glossary says…", it means `_reference/kpi_glossary.md`.

## Starting the lab

```bash
docker-compose -f database/docker-compose.yml up -d     # Postgres
./run_pipeline.bat                                       # generate + load data (only if empty)
conda activate mis-collections
```

Then open `sql/README.md` and start Task 1. Good hunting.