# Documentation Index (docs/)

Single entry point for all MIS-Collections documentation. Private/personal material stays out of version control — see `unused/` and `interviews/`.

## Project Quick Links
| Doc | Purpose |
|---|---|
| `CONTEXT.md` | Full project context, data model, session notes |
| `ROADMAP.md` | Phase-by-phase task checklist |
| `CHANGELOG.md` | Version history |
| `QUICKSTART.md` | 5-minute setup guide |
| `DUAL_OS_SETUP.md` | Cross-platform workflow (Ubuntu data factory + Windows Power BI) |
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

## Power BI Docs (`powerbi/`)
Continues the earlier `dashboards/assets/docs/` + `docs/dashboards/` line — now consolidated under `docs/powerbi/`. Only current docs live here; superseded material moves to `legacy/`:

| Doc | Purpose |
|---|---|
| `powerbi/dashboard_blueprint.md` | Page-by-page wireframes (9 pages, 1920x1080) |
| `powerbi/dax_measures_all.md` | Complete DAX reference (148 measures + 18 TI CG items) |
| `powerbi/PHASE9_EXECUTION_PLAN.md` | Actionable Phase 9 Power BI build plan |
| `powerbi/legacy/` | Superseded / historical docs (execution_guide, reference_guide.html, DAX dictionaries, build plans, May-24 notes, visual catalogs) |

## Version-Control Boundaries
- `docs/powerbi/` and everything in `docs/` (excluding below) are **tracked**.
- `docs/unused/` — **gitignored**: real Scotiabank reports (MTD xlsx), historic data CSVs, technical-exam SQL practice, archived PBIX prototypes. Local reference only.
- `docs/interviews/` — **gitignored**: private interview prep material.