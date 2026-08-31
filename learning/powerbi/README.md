# Power BI Track — the living dashboard

```
You are here: learning/powerbi/   (basic → medium → advanced)
Master guide: learning/README.md
Prerequisites: sql/basic (the model mirrors the database you already know)
```

SQL proves numbers, Python reshapes them, notebooks explain them, Excel ships them. **Power BI makes them live**: filters, drill-down, automatic refresh, and row-level security so each supervisor sees only their own teams. This project has a real dashboard build to reference (9 pages, a 148-measure DAX library + 18-item time-intelligence calculation group, RLS by supervisor) — this track walks you up to that level.

## At work, you reach for Power BI when…

- Leadership wants numbers they can slice themselves — by month, team, product — without asking you each time.
- The same report goes to many managers, but **each should only see their own data** (row-level security).
- A number must stay current without anyone re-running anything.
- Someone asks *"can I see that broken down by…?"* and the honest answer becomes *"yes, click here."*

## The project's three habits you inherit

1. **Measures live in a CSV first** (`dashboards/dax/collections_dax_v2.csv`), then get imported into the .pbix. Measures are reviewed like code — named, documented, consistent. You'll write yours in the same spirit.
2. **Star schema import mode** — the model uses the same `Dim_*` / `Fact_*` tables you queried in SQL. Knowing the database *is* knowing the model.
3. **A number on a visual is a claim.** Every dashboard number was already proven elsewhere; if a visual disagrees with your SQL/Python/Excel number, you investigate — you don't decorate around it.

## Setup

1. **Power BI Desktop** (free, Windows — you're covered).
2. Connect Import-mode to `MIS_CollectionsDB`, or load the reassembled CSVs — tasks tell you which and ask you to justify.
3. `.pbix` files are binary (git can't show differences): save as `learning/powerbi/<level>/work/attempt_*.pbix` plus a **screenshot of each page** into the same folder.

## What each level covers

| Level | You master | Typical deliverable |
|---|---|---|
| `basic/` | Model the star schema; first simple measures; one clean formatted page | A one-page report answering "how many / how much" with slicers |
| `medium/` | DAX fundamentals: measure vs calculated column, filter context, CALCULATE, time intelligence; visual interactions | A 2–3 page report where clicking one chart filters everything else |
| `advanced/` | Measure-library conventions, calculation groups, RLS by supervisor, cross-checking visuals vs proven numbers | The project-style stack — and an audit proving it's right |

## How the files work

Each level folder has:

- `tasks.md` — your inbox: workplace requests with Done-When checklists (no code, no expected numbers)
- `results.md` — full worked solutions with the complete DAX/model steps; open **only after** attempting, then rebuild the solution yourself
- `work/` — your `.pbix` files + screenshots; git-ignored scratchpad

Routine: read task → attempt in `work/` → **read the visual, not just the number** (a percentage that renders wrong lies convincingly) → then compare with `results.md`.

## Move up when…

- **basic → medium:** relationships, formatting and simple measures stop requiring tutorials.
- **medium → advanced:** you can predict what a measure returns under a slicer before pressing enter.
- **done:** you can build a filtered, secured, self-consistent dashboard — and trace any visual back to a SQL query that agrees with it.
