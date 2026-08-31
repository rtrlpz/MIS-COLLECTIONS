# Dashboards Layer

Power BI + DAX artifacts for the MIS Collections project. For dashboard documentation (blueprint, execution guide, DAX reference) see `../docs/dashboards/`.

## Contents

| Folder | Purpose | Git status |
|---|---|---|
| `dax/` | DAX source of truth: `collections_dax_v2.csv` (148 active measures + 18-item `_Time Intelligence` CG), `calculation_group_ti.json` (Time Intelligence CG), `dax_targets_and_comparisons.md`, generator script | tracked |
| `theme/` | Power BI theme `Tema 1.json` (Scotia blue #262A76, Calibri) | tracked |
| `scripts/` | Tabular Editor C# helpers + Python utilities (import_measures, create_calc_group, prefix_removal, csv_to_tsv, md_to_pdf) | tracked |
| `pbix/` | Working dashboard: `collections_dashboard_v3.pbix` | ignored (*.pbix) |
| `models/` | Tabular Editor model exports (`Model.bim`, `database.json`) | ignored — STALE (old schema), regenerate from v3 when needed |
| `assets/` | Visual assets only: `icons/` (SVG/PNG), `bg/` (canvas templates), `screenshots/` | tracked (icons/bg/screenshots) |

## DAX Workflow

- CSV is **source of truth** — do NOT author measures exclusively in PBIX. Edit `dax/collections_dax_v2.csv`, then import via `scripts/import_measures.cs`.
- After importing all measures, run `scripts/create_calc_group.cs` in Tabular Editor to build the `_Time Intelligence` Calculation Group.
- Regenerate the reference doc from CSV: `python dax/generate_dax_reference.py`.

## Rebuilding Note

`models/` exports predate the unified `dim_employees` refactor. If you need a `.bim`, export from `pbix/collections_dashboard_v3.pbix` via Tabular Editor rather than trusting the checked-in copy.