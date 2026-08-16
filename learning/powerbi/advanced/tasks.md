# Power BI — Advanced — Tasks

```
learning/
├── _reference/            ← READ FIRST (datasets.md, kpi_glossary.md, data_dictionary.md)
├── sql/  python/  notebooks/  excel/  git-cli/
├── powerbi/
│   ├── README.md
│   └── advanced/          ← YOU ARE HERE
│       ├── tasks.md       ← current file
│       ├── results.md     ← guidance, peek AFTER attempting
│       └── work/          ← your .pbix + screenshots + .csv live here
└── README.md
```

**Up from powerbi medium:** CALCULATE, time intelligence, measure-library discipline, multi-page navigation. Advanced builds the **project-grade stack**: measure library authored "CSV-first", a mini Calculation Group, row-level security, and the final cross-track audit of the whole dashboard.

**Setup:** Power BI Desktop + DB. Reference the project's own stack for the pattern: `dashboards/dax/collections_dax_v2.csv` (the 252-measure source of truth), `dashboards/dax/calculation_group_ti.json`, `docs/dashboards/dashboard_blueprint.md`. Save each as `learning/powerbi/advanced/work/attempt_*.pbix` + artifacts.

**Discipline:** attempt → commit → read as a viewer → read `results.md`. Every number on every page was *proven* earlier in the track — Power BI is the last mile, not a recompute.

> **The advanced rule (house rule):** divergence from the proven number is a *finding*; a dashboard with an unexplained divergence is an unshipped dashboard.

---

## Task 1 — The measure library, CSV-first

The supervisor: *"252 measures live as a CSV, the PBIX imports them. Prove you can *author* to that standard: a mini library of 12 measures, documented in a CSV, then materialized in your model."*

**What you'll practice:** the project's source-of-truth discipline — measures **authored and documented outside the PBIX** (a CSV + manifest), imported into the model; the PBIX is a *consumer*, not the *author*.

Steps:
1. Study the pattern in `dashboards/dax/collections_dax_v2.csv`: structure, naming, folders, expression style. Write down the three conventions that would scale (name ← family+metric+horizon; folder = family; every measure has a definition/denominator).
2. Author a **mini `measures.csv`** (12 measures, your own family set: Contact / Promise / Recovery / Time Intelligence-adjacent), columns: name, table, folder, expression, note (denominator + why — the reference style).
3. Create an import path: a tiny script (reuse your Python) that reads your `measures.csv` and outputs measures ready for a Tabular-Editor-style bulk import (your project has `dashboards/scripts/import_measures.cs` as the real analog — yours can be a CSV→.txt/dax script). Materialize the 12 in the model.
4. Sanity: a stranger reading `measures.csv` can reconstruct each measure's *meaning* without the PBIX open.

**Guiding questions:**
- What does "CSV is source of truth" buy that "authoring in the PBIX" can't (diff-ability, review, CI-adjacent checks, portability)? Which of those matters most for a 252-measure library?
- A measure whose *name* implies a denominator it doesn't use — is that a naming bug or a definition bug? Where does the CSV make that answer *enforceable*?

**Deliverable:** `work/measures.csv` (12 measures, documented) + `work/attempt_1.pbix` (measures materialized) + a one-page `work/measure_conventions.md`.

---

## Task 2 — A mini Calculation Group

The supervisor: *"The project replaces a pile of legacy measures with ONE Calculation Group (`_Time Intelligence`). Build a mini one: Current / Previous Month / Year-over-Year as items over any base measure."*

**What you'll practice:** the Calculation Group *concept* — a column-like selector that injects time context into any measure via an implicit `CALCULATE` — and why a CG collapses dozens of copies into one.

Steps:
1. Read `dashboards/dax/calculation_group_ti.json` for the pattern (items, expressions, column name). Understand what an item *is* (a template expression that wraps the measure reference).
2. Define a mini CG `_Time Intelligence` with **3 items**: Current Period, Previous Period, Year-over-Year (each = a `CALCULATE`-driven template over the referenced base measure, with `SELECTEDMEASURE()`-class mechanics — the reference's vocabulary).
3. Apply it as a slicer against your base measures (e.g. RPC%, PTP%) and show the same visual flipping Current/Previous/YoY without any measure copy.
4. Prove the replacement claim in miniature: count the measures you'd have needed WITHOUT the CG vs the number WITH it (2 base measures ×3 horizons = 6 vs 2 + 1 CG with 3 items).

**Guiding questions:**
- How is a CG *different* from a measure that already has time-intel baked in (a `PY RPC%`)? What does the CG add when a stakeholder wants a *new* horizon on a *new* base measure tomorrow?
- What breaks if two CGs are active at once — and what's the rule about the "format string" an item carries?

**Deliverable:** `work/attempt_2.pbix` (mini CG working as a slicer) + screenshot of the same 2 base measures × 3 horizons under one CG + a hand count in `work/cg_math.md`.

---

## Task 3 — The door only opens for your team (RLS)

The supervisor: *"The real deployment ships RLS by supervisor: a manager logs in, sees exactly their agents. Model it — role, rule, test."*

**What you'll practice:** row-level security — a role with a `supervisor→agent` mapping rule, tested from an impersonation login — the `rls_supervisor_map`-style pattern in your own model.

Steps:
1. Build (or import) a small `SupervisorMap` table: supervisor_id ↔ agent_id (from `dim_employees`' self-referencing supervisor structure — the dictionary documents the parent link).
2. Create a security ROLE with a row rule joining the map: filters `dim_employees` so `agent_id` (in the row context) belongs to the *current user*'s supervisor row (`username()`-driven mapping).
3. Test from "View as role" as a specific supervisor: the agent page + any agent-level visuals show ONLY their agents; counts differ from the unsecured view (that difference **is** the proof).
4. Reflect: which visuals must NOT be RLS-scoped (portfolio-wide summary the supervisor is allowed to see) — and say the policy out loud in a note (who may exist which number).

**Guiding questions:**
- RLS filters rows; it cannot hide a *wrong aggregate* — so what happens to a portfolio total when a supervisor's role filters the fact table? (Either it re-aggregates to their slice — desired — or a "total" that crosses teams silently shrinks — a design decision.)
- Security by *role* vs openness by default: what's the safe default for a stakeholder's dashboards, and where does RLS impose *effort* (adding a supervisor = a row in the map, not a new rule)?

**Deliverable:** `work/attempt_3.pbix` (role + rule) + screenshots: unsecured total vs one-supervisor view, plus your RLS policy note.

---

## Task 4 — The final audit: one dashboard, one truth

The supervisor: *"Ship it ONLY if it proves itself. A verification page that cross-checks dashboard numbers against the SQL/Python/Excel evidence — with PASS/FAIL and deltas. The dashboard ends as an auditable artifact."*

**What you'll practice:** the end-of-track audit — every headline visual compared in-model against the reference source (re-imported as a "truth" table from your work output, or against the view via query), PASS/FAIL + delta, and a root-cause for any FAIL (the advanced rule, now the final gate).

Steps:
1. Produce a **truth table** outside the PBIX (reuse your Python/Excel outputs: per-team RPC%, monthly PTP%, top-10 arrears as-of, bucket profile) as CSV — the "evidence file".
2. Import it into the model (a `Truth` table with `report:key + expected + tolerance`) and build a `Verification` page: each metric's LIVE dashboard value vs `Truth.expected` vs delta vs tolerance vs PASS/FAIL.

   (Mechanism: the live value = your base measure; expected = `RELATED`-style lookup from the truth table keyed on the same slice values — the classic "checked artifact" pattern.)
3. Drive every FAIL to green **or** to a documented root cause (definition gap, filter window, formatting — prove with a targeted adjustment, don't relax the tolerance to fake a pass).
4. Final cold-read: reset all, stranger clicks through nav, the Verification page truthfully reports all-PASS (or zero unexplained FAILs), and the author's note (version, as-of date, the five cover numbers) sits on the cover.

**Guiding questions:**
- Verifying against a *copy* (your truth CSV) vs against the *live view* (query the DB directly): which is a stronger proof, and why does the copy sometimes be *more* honest (a view can evolve; an evidence file is an audited snapshot)?
- A FAIL that is only "my tolerance was image-tight" — is that a real FAIL? State the tolerance policy the Verification page enforces, in words, *before* any check runs.

**Deliverable:** `work/attempt_4.pbix` (with the Verification page) + `work/truth_evidence.csv` + `work/final_audit.md` (tolerance policy + PASS/FAIL outcome + any root-cause notes).

---

### Finish

Attempt all four, then read `advanced/results.md`. Close `final_audit.md` with a one-paragraph verdict a director would accept.

**Graduate when:** your dashboard *proves* itself (self-audit), restricts itself (RLS), self-documents (CSV-first library), and a stranger can verify the claim by clicking the Verification page — in under a minute.