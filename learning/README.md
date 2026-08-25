# learning/ — Collections MIS Analyst Practice Lab

A practice environment built on this project's own data: one full year (Jan–Dec 2025) of realistic bank collections activity — calls made, promises kept or broken, payments received, accounts written off and recovered — about **1.9 million rows**, stored both as monthly CSV files and in a PostgreSQL database.

Everything here trains the day-to-day skills of a working **Collections MIS Analyst**, aligned to the actual job description this lab was built against (timely MIS delivery, developing and adjusting reports, scheduled automation, KPI trend analysis, roll-rate/forecast work, report governance). The JD→track coverage map lives in [`_reference/REFACTOR_PLAN.md`](_reference/REFACTOR_PLAN.md).

---

## The big idea: same number, five tools

You will compute the same KPI (say, RPC% — the share of calls where you reach the right person) several different ways:

```
SQL → Python → Notebook → Excel → Power BI
```

When all of them give the same number, you have proven you understand the whole pipeline. When one disagrees, you have found a real discrepancy — and explaining *why* numbers differ is one of the most valuable things a senior analyst does.

The project itself is your answer key: its SQL views (`v_contact_metrics`, `v_promise_metrics`, …) are the official implementations. Reproducing them from raw tables — and auditing any difference — is real analyst work, not an exercise.

---

## What each track is for

| Folder | Tool | What it teaches | A real work request it prepares you for |
|---|---|---|---|
| `sql/` | PostgreSQL | Get answers out of a database; audit the official views | *"MIS Manager wants January contacts per team, sorted, before the 9:30 meeting."* |
| `python/` | pandas | Recombine monthly extracts, reshape at scale (~1.34M rows), automate reconciliation | *"Merge 12 months and flag every agent whose keep-promise rate fell two months straight."* |
| `notebooks/` | Jupyter | Explain how a number is calculated, step by step, with charts | *"Walk the new hires through exactly how Cures per THT hour works."* |
| `excel/` | openpyxl + VBA | Build the report people actually open every morning — and make it build itself | *"The daily MIS pack must refresh on open and export to PDF at 8:00 AM."* |
| `powerbi/` | Power BI Desktop | Star-schema models, DAX metrics, RLS so each supervisor sees only their teams | *"Give each supervisor a live dashboard scoped to their own portfolio."* |
| `git-cli/` | git (terminal) | Version your work; recover from mistakes without panic | *"Yesterday's pack was right and today's isn't. Show me what changed."* |

**Recommended order:** `sql/basic` first — everything else builds on knowing your way around the data. Then follow each track's README sequence.

---

## How every task is written

Tasks arrive the way work actually arrives: as a message in your inbox.

```
## Task 3 — Why did Tarjeta RPC% drop?
📥 Inbox: From Operations Manager · Tuesday 11:20 · needed before tomorrow's stand-up
> "RPC% in Tarjeta fell off a cliff this month. I need to know if it's a channel
>  problem or a team problem before I get grilled in stand-up."
Background … Your job (steps, each with why) … Guiding questions …
Data pointers … Done when: [ ] acceptance criteria
```

Every task has: **who asked, when it's due, business background, numbered steps with the *why* attached, guiding questions** (answer them as comments in your own file), **data pointers** into `_reference/`, and a **Done-When checklist** that tells you when you're genuinely finished.

What tasks never contain: the code to write, or the numbers you should see. That's the exercise.

---

## How a practice session works

Each track and level has the same three files:

| File | What it is | When to open it |
|---|---|---|
| `tasks.md` | Your inbox — assignments styled as workplace requests | First |
| `work/` folder | Where YOUR attempts go: `attempt_1.sql`, `attempt_2.py`, `attempt_1.ipynb`, … | While attempting |
| `results.md` | Full worked solution: the reasoning path, **the complete runnable code**, how to verify it, and the traps. It shows the code you should have written — never the output tables you should see | After your honest attempt |

The routine:

1. Read a task. Understand who's asking and what "done" means.
2. Write your attempt in `work/`. Stuck is normal — stuck-then-unstuck is where learning happens.
3. Open that task's section in `results.md`. Compare approaches, then **run the provided solution yourself** and check it behaves as described.
4. Reconcile: where your answer differs from the solution's approach (or your numbers differ between tools), write down why. That note is the lesson.
5. Keep every attempt, including the bad ones. The trail IS your progress log.

> `work/` folders are git-ignored on purpose: they're your private scratchpad. Nothing you save there can break the repo.

---

## A normal week this lab rehearses

- **Monday, 8:40 AM.** Ops lead: *"What were yesterday's contacts and promises? Meeting is at 9:30."*
  → filtered counts, fast (SQL basic).
- **Tuesday.** Manager: *"RPC% dropped in Tarjeta. Channel problem or team problem?"*
  → joins, slicing by arm/team/date (SQL medium).
- **Wednesday.** Finance challenges the cure count in last month's pack.
  → rebuild the number from raw tables, explain differences line by line (SQL advanced).
- **Thursday.** *"These three reports measure KP% three different ways. Fix that."*
  → standardization & report governance (Power BI / SQL advanced).
- **Month end.** Someone must produce the period-end workbook — automatically.
  → openpyxl generator + VBA auto-refresh pipeline (Excel track).
- **Leadership wants live dashboards, scoped per supervisor.**
  → star schema + RLS (Power BI track).

If these sound like things you want to do without panic — welcome; this lab was built for exactly that.

---

## House rules

1. **Attempt first.** Reading solutions first feels productive and teaches nothing.
2. **Run the solution, don't just read it.** Code you haven't executed isn't learned yet.
3. **A number is only right after a cross-check.** Compare tool vs tool, and vs the project's `v_*` views.
4. **Data is read-only.** Never edit `data_sources/raw/`; never change database contents.
5. **Never commit secrets.** No `.env`, no passwords, no credentials in anything you save.
6. **Disagreement with the official views is a finding, not a failure** — as long as you investigate and write down why.

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
| [`datasets.md`](_reference/datasets.md) | You need table names, row counts, connection steps, typical value ranges. |
| [`kpi_glossary.md`](_reference/kpi_glossary.md) | A task mentions a KPI and you need its exact definition, formula and traps. |
| [`data_dictionary.md`](_reference/data_dictionary.md) | You wonder what a column means or how tables connect. |
| [`REFACTOR_PLAN.md`](_reference/REFACTOR_PLAN.md) | You want the JD coverage map or the refactor's phase status. |
| [`LEARNING_GUIDE.md`](_reference/LEARNING_GUIDE.md) | You want the recommended order and the *why* behind each step. |

When a task says "check the glossary", it means `_reference/kpi_glossary.md`.
