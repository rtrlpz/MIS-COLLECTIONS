# Documentation Index (docs/)

Single entry point for all MIS-Collections documentation. Private/personal material stays out of version control — see `unused/` and `interviews/`.

## Project Quick Links
| Doc | Purpose |
|---|---|
| `CONTEXT.md` | Full project context, data model, session notes |
| `ROADMAP.md` | Phase-by-phase task checklist |
| `CHANGELOG.md` | Version history |
| `QUICKSTART.md` | 5-minute setup guide |
| `TROUBLESHOOTING.md` | Docker/ETL error resolution |

## Schema & KPI Reference
| Doc | Purpose |
|---|---|
| `KPI_VIEWS.md` | 13 of 16 KPI views documented |
| `kpi_definitions.md` | KPI formulas and benchmarks |
| `data_dictionary.md` | Full column-level dictionary |
| `schema_v2_notes.md` | Audited schema findings + post-learning redesign backlog |
| `executive_summary.md` | 1-page leadership summary |

## Planning
| Doc | Purpose |
|---|---|
| `PLAN_DASHBOARDS.md` | 9-dashboard implementation plan (DAX coverage analysis) |
| `PHASES_12_14_GUIDE.md` | Enterprise infrastructure roadmap (CACS, dialer/WFM, PEGA) |

## Dashboard Docs (`dashboards/`)
Moved from `dashboards/assets/docs/` — these live here so all documentation is in one place:

| Doc | Purpose |
|---|---|
| `dashboards/dashboard_blueprint.md` + `.pdf` | Page-by-page wireframes (9 pages, 1920x1080) |
| `dashboards/execution_guide.md` | 2,499-line enterprise build guide (13 sections) |
| `dashboards/mis_collections_build_plan.md` | 5-phase Power BI build plan |
| `dashboards/dax_measures_all.md` | Complete DAX reference (all measures as code blocks) |
| `dashboards/dax_measures_dictionary_v2.md` | Full DAX dictionary (formulas, formats, deps) |
| `dashboards/reference_guide.html` | DAX + blueprint reference (HTML) |
| `dashboards/legacy/` | Superseded docs (v1 DAX dictionary, earlier dashboard ideas) |

## Version-Control Boundaries
- `docs/dashboards/` and everything in `docs/` (excluding below) are **tracked**.
- `docs/unused/` — **gitignored**: real Scotiabank reports (MTD xlsx), historic data CSVs, technical-exam SQL practice, archived PBIX prototypes. Local reference only.
- `docs/interviews/` — **gitignored**: private interview prep material.