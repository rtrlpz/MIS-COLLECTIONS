# Power BI Track — README

```
learning/
├── _reference/            ← READ FIRST: datasets.md, kpi_glossary.md, data_dictionary.md
├── git-cli/
├── sql/  python/  notebooks/  excel/   ← done first (the launch pads + the report crafters)
├── powerbi/               ← YOU ARE HERE
│   ├── README.md
│   ├── basic/    tasks.md + results.md + work/
│   ├── medium/   tasks.md + results.md + work/
│   └── advanced/ tasks.md + results.md + work/
└── README.md             ← MASTER GUIDE
```

## Why Power BI last

SQL proved the numbers, Python reshaped them, notebooks explained them, Excel shipped them as documents. Power BI is where the same numbers become **a living dashboard**: filters, drill-through, row-level security, and a measure language (DAX) that runs *inside* the star schema you already understand.

This project has a real Phase 9 to reference: a 9-page dashboard, a documented 252-measure DAX library (`dashboards/dax/collections_dax_v2.csv`), a Calculation Group for time intelligence, and RLS by supervisor. The track trains you to build up to that stack — and to poke it.

## The project's Power BI laws (carry them into the track)

1. **DAX measures live in CSV, not PBIX-first** — the CSV (`collections_dax_v2.csv`) is the source of truth; importing into the PBIX is a copy action. You'll author measures *in the CSV's spirit*: named, documented, reviewable.
2. **Import mode**, star schema — the model mirrors the `Dim_*` / `Fact_*` names and the 12 KPI views you can already reproduce.
3. **The Calculation Group** (`_Time Intelligence`) replaces dozens of legacy measures — you'll meet this pattern at advanced.
4. **RLS by supervisor** for the real deployment — same `rls_supervisor_map` idea.

## Setup

1. **Power BI Desktop** (Windows only — you're on Windows). Free download.
2. Data source choice per task: connect Import-mode to the DB (`MSI_CollectionsDB`) **or** import the raw CSVs (reassembled = your `work/` parquet/CSV). Say which and why per task.
3. Save work files as `learning/powerbi/<level>/work/attempt_*.pbix` + take *screenshots* of each page into `work/` (a `.pbix` is binary and not git-diffable).

## The three levels

| Level | What you'll master | Checks |
|---|---|---|
| `basic/` | Model the star schema, build the first measures (simple rates), first visuals, formatting basics on ONE page. | 4 tasks |
| `medium/` | DAX fundamentals — measure vs column, filter context, CALCULATE, time intelligence — plus visual interactions and slicers on a 2-3 page report. | 5 tasks |
| `advanced/` | The project-level stack: measure library conventions, a mini Calculation Group, RLS, and the cross-track audit (PBIX visual == your SQL/Python/Excel numbers). | 4 tasks |

## Golden rule

Attempt → commit → **read the visual, not just the number** (a dashboard is a claim; a percentage that renders wrong is a liar on a slide) → then read `results.md`.

## The cross-track law that never changes

Every number you put on a dashboard was *already proven* in SQL/Python/Excel. Power BI's job is to make it **live and filterable** — never to silently re-derive with different definitions. Any visual that disagrees with your proven numbers is a finding to explain, not a mystery to compose a legend around.