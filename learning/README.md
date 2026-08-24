# learning/ — Data Analyst Practice Lab

A practice environment built on this project's own data: one full year (Jan–Dec 2025) of realistic bank collections activity — calls made, promises kept or broken, payments received, account balances — about **1.8 million rows**, stored both as monthly CSV files and in a PostgreSQL database.

Everything here trains the skills a working **Data Analyst / BI Analyst** uses every week, on data that behaves like real production data.

---

## The big idea: same number, five tools

You will compute the same KPI (say, RPC% — the share of calls where you reach the right person) five different ways:

```
SQL → Python → Notebook → Excel → Power BI
```

When all five give the same number, you have proven you understand the whole pipeline. When one disagrees, you have found a real discrepancy — and explaining *why* numbers differ is one of the most valuable things a senior analyst does.

---

## What each track is for

| Folder | Tool | What it teaches | A real work request it prepares you for |
|---|---|---|---|
| `sql/` | PostgreSQL | Get answers out of a database | *"How many calls did we make in January, per team? Sorted, please."* |
| `python/` | pandas | Combine files, reshape data, automate repetitive work | *"Merge the 12 monthly files and list every agent whose keep-promise rate fell two months in a row."* |
| `notebooks/` | Jupyter | Explain how a number is calculated, step by step, with charts | *"Walk the new hires through exactly how we compute Cures per Hour."* |
| `excel/` | openpyxl (Python → .xlsx) | Build the report people actually open every morning | *"Produce the printable daily MIS sheet — totals, rates, red/yellow/green flags."* |
| `powerbi/` | Power BI Desktop | Build interactive dashboards with filters and security | *"Give each supervisor a dashboard that only shows their own teams."* |
| `git-cli/` | git (terminal) | Save versions of your work; recover from mistakes | *"The report worked yesterday. Show me what changed since then."* |

**Recommended order:** `sql/basic` first — everything else builds on knowing your way around the data. Then follow the sequence in each track's README.

---

## How a practice session works

Every track and level has the same three files:

| File | What it is | When to open it |
|---|---|---|
| `tasks.md` | Your assignments. Each task is written like a request from your supervisor — the kind of message that lands in your inbox at work. | First |
| `work/` folder | Where YOUR answer files go: `attempt_1.sql`, `attempt_2.py`, `attempt_1.ipynb`, … | While attempting |
| `results.md` | Reasoning guidance for each task — how to *think* about it, what to check, common mistakes. It never contains the ready-made answer. | **Only after** you attempted |

The routine:

1. Read a task in `tasks.md`.
2. Write your attempt in `work/`. Being stuck is normal — stuck-then-unstuck is where learning happens.
3. Open that task's section in `results.md`. Compare approaches. Note in your file what you would do differently.
4. Keep even "wrong" files. Your progress log is the trail of attempts.

> `work/` folders are git-ignored on purpose: they are your private scratchpad. Nothing you save there can break the repo.

---

## What this trains you for: a normal week as a collections BI analyst

These are the situations the tasks deliberately rehearse:

- **Monday, 8:40 AM.** Ops lead messages: *"What were yesterday's contacts and promises? Meeting is at 9:30."*
  → You pull two counts with filters (SQL basic).
- **Tuesday.** Manager: *"RPC% dropped this month in Tarjeta. Why?"*
  → You join calls to agents and accounts, slice by team/channel/date (SQL medium).
- **Wednesday.** Finance challenges the cure count in last month's pack.
  → You rebuild the number from raw tables and explain any difference line by line (SQL advanced).
- **Month end.** Someone must produce the period-end workbook with charts and checks.
  → That someone is you (Excel track).
- **Leadership wants a live dashboard instead of email attachments**, filtered so each supervisor sees only their teams.
  → Power BI track — which mirrors this very project's own Phase 9 dashboard build.

If these sound like things you want to be able to do without panic — welcome, this lab was built for exactly that.

---

## House rules (short version)

1. **Attempt first.** `results.md` only after you tried. Reading answers first feels productive and teaches nothing.
2. **Data is read-only.** Never edit files in `data_sources/raw/` and never change database contents. Every tool here only reads.
3. **Never commit secrets.** No `.env`, no passwords, no credentials in anything you save.
4. **A number that disagrees with the project's official views (`v_*`) is a finding, not a failure** — as long as you investigate and write down why it differs.

---

## One-time setup, then start

1. Start the database and confirm data is loaded:
   ```bash
   docker-compose -f database/docker-compose.yml up -d   # start Postgres
   ./run_pipeline.bat                                     # generate + load (only if empty)
   ```
2. Pick a SQL client and connect — recipe and connection details in `_reference/datasets.md` §5.
3. Skim `_reference/datasets.md` (where data lives) and `_reference/kpi_glossary.md` (what RPC%, PTP%, KP%… mean). Ten minutes well spent.
4. Open [`sql/basic/tasks.md`](sql/basic/tasks.md) and start Task 1.

### The reference shelf (`_reference/`)

| File | Use it when… |
|---|---|
| `datasets.md` | You need to know where data lives, table names, row counts, connection steps, typical value ranges. |
| `kpi_glossary.md` | A task mentions a KPI (RPC%, KP%, cure…) and you need its exact definition, formula and traps. |
| `data_dictionary.md` | You wonder what a specific column means or how tables connect. |

When a task says "check the glossary", it means `_reference/kpi_glossary.md`.
