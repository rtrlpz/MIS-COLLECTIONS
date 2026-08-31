# Phase 9 Execution Plan — Guided Dashboard Build

> **Status:** PLANNED (saved Aug 2026) · **Mode:** user drives Power BI Desktop + Tabular Editor,
> AI supplies prep materials, step-by-step guidance, parity validation, and fixes.
> **Prereq check (done):** DB live on :5433 with post-P3/P4 data (interactions 1,338,499),
> 16 views green, DAX v3.2 CSV ready (148 active measures), blueprint final.
> **Note:** existing `collections_dashboard_v3.pbix` predates P3/P4 — build FRESH (`collections_v4.pbix`), don't migrate it.

---

## Roles

| Side | Owns |
|---|---|
| **You (GUI)** | Power BI Desktop modeling, Tabular Editor runs, visual building, screenshots |
| **AI (guide)** | Import manifest, parity queries per page, debugging mismatches, RLS test plan, doc updates |

---

## M0 — Prep pack (AI builds when Phase 9 kicks off)

| Deliverable | Where |
|---|---|
| Import manifest: 15 tables, load/hide column decisions, relationship key list | this folder |
| Parity query pack: one query set per page against its source view (see table below) | `dashboards/validation/page_*.sql` |
| Measure-import kit: regenerate `measures.tsv` from `collections_dax_v2.csv` (148) for `import_measures.cs` | `dashboards/dax/measures.tsv` |
| RLS test plan: identities, expected teams, page checklist | appended below |

Parity sources per page:

| Page | Reconcile against |
|---|---|
| 1 Executive Collections | `v_daily_mis`, `v_monthly_summary` |
| 2 Agent Performance | `v_agent_scorecards` |
| 3 Dialer Performance | `fact_interactions` aggregates |
| 4 Portfolio Management | `v_monthend_portfolio` |
| 5 Operations Command Center | `fact_agent_time_log` |
| 6 Credit Risk | snapshots × `dim_delinquency_bucket` |
| 7 Financial Recovery | `v_writeoff_recovery` (+ writeoffs/recoveries facts) |
| 8 Vintage Analysis | cohort grid (SQL advanced pattern) |
| 9 Roll Rate Analysis | `v_dpd_migration_matrix` |

## M1 — Model import (you, ~30 min)

1. Get Data → PostgreSQL → `localhost:5433` · `MIS_CollectionsDB` · **Import mode**.
2. Select exactly the 15 tables in the import manifest (no views unless the manifest says so).
3. Model view: every relationship dim(1)→fact(*), single direction; fix anything auto-guessed.
4. Hide all key columns; mark `Dim_Calendar` as date table; turn OFF Auto date/time.

## M2 — Measures + Calculation Group (Tabular Editor, ~20 min)

1. Run `import_measures.cs` against the model with `measures.tsv` (148 measures, 5 measure tables).
   - Do NOT import the retired TI file (`dashboards/dax/legacy/time_intelligence_legacy.csv`).
2. Create calculated tables `Dim_Targets` + `Color Reference` (DAX in `dax_targets_and_comparisons.md` / CSV `_Goals & Targets` DATATABLE row).
3. Run `create_calc_group.cs` → `_Time Intelligence` CG (18 items).
4. **Gate:** model shows 148 measures + 18-item CG; spot-check 5 measures vs parity pack before any visuals.

## M3 — Pages batch 1 (Executive · Agent · Dialer)

Build from `dashboard_blueprint.md` field wells → run that page's parity SQL → reconcile to zero before moving on.

## M4 — Pages batch 2 (Portfolio · Ops · Credit Risk · Financial Recovery · Vintage · Roll Rate)

Same rhythm. Known thin spots: Ops (occupancy-grade WFM fields were deferred — page stays limited by design), Roll Rate (use `v_dpd_migration_matrix`; severity order via bucket sort_order).

## M5 — RLS + polish

1. Role via `RLS Map` ← import `v_rls_supervisor_map`, add email convention column, filter `[Email] = USERPRINCIPALNAME()`, both-direction security filter to `dim_employees`.
2. View As ≥2 supervisor identities across ALL pages (incl. drillthrough); screenshot log.
3. Apply theme JSON (`dashboards/theme/Tema 1.json`); performance pass; save `dashboards/pbix/collections_v4.pbix`.

---

## Definition of Done

- [ ] 9 pages matching blueprint wireframes (1920×1080)
- [ ] Every headline number reconciled to its SQL view (zero unexplained deltas)
- [ ] RLS proven for two identities, negative test included
- [ ] 148 measures + 18-item CG loaded; legacy TI not imported
- [ ] File saved as `dashboards/pbix/collections_v4.pbix` + screenshots for docs

## Sequencing note

Learning first: the `learning/powerbi/` track (basic → medium → advanced) rehearses every
pattern this build needs (modeling, safe-divide measures, TI, targets+RAG, roll-rate matrix,
drillthrough, SVG cards, RLS, governance). Finish it — or at least basic+medium — then run
this plan; the real build becomes pure execution.
