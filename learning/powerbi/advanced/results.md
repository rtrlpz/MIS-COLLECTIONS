# Power BI — Advanced — Results (Guidance)

```
learning/
├── _reference/            ← datasets.md, kpi_glossary.md, data_dictionary.md
├── sql/  python/  notebooks/  excel/  git-cli/
├── powerbi/
│   ├── README.md
│   └── advanced/          ← YOU ARE HERE
│       ├── tasks.md
│       ├── results.md     ← current file
│       └── work/
└── README.md
```

**How to use this file:** attempt → commit → read one section. Guidance only — reasoning paths, steps-with-why, verification strategy, traps. No full DAX, no computed values.

---

## Task 1 — Measure library, CSV-first

**Thinking path:**
- The project's 252-measure CSV exists because a library that big needs *portability* over the PBIX's binary: diff-able text, reviewable by eyeball, enforceable conventions (naming/folders/definition), and a path to automated checks. Your 12-measure `measures.csv` is the mini-version of that sociology.
- The conventions that scale (steal them from the reference): name = *family_metric_horizon* (`Contact_RPC%`, `Contact_RPC%_MoM`); folder = family (Contact / Promise / Recovery / Time Intelligence); every measure carries a definition + denominator + the "people misread this because…" note. The "definition bug vs naming bug" question resolves *in the CSV*: a name that lies about its denominator is both — the CSV makes the mismatch *readable* rather than buried in a formula body.
- Materialization: a small script reads `measures.csv` and emits the DAX-ready artifacts (the real project uses `import_measures.cs` in Tabular Editor — your script is the analog, on a smaller scale).

**Verification strategy:**
- Reviewer blind-test: hand a stranger `measures.csv`; can they reconstruct each measure's meaning without the PBIX? That's the whole point — the CSV is the review surface.
- A lint-style pass: every column of every row populated, every folder exists, names unique. If you had 252, an empty note column would be the lint failure.

**Traps & worth knowing:**
- Duplicate measure bodies under two names drift in secret (folder applies, body diverges) — the CSV's *unique-name + commented-denominator* discipline is what prevents the drift.
- Authoring "in the PBIX then exporting late" defeats the purpose: the CSV must be written *first*, imported, and divergences (`measure exists in PBIX but not CSV` or vice versa) treated as drift to resolve, not to ignore.

---

## Task 2 — Mini Calculation Group

**Thinking path:**
- A Calculation Group is a *parameterized* measure template: its items (Current / Previous / YoY) each carry an expression that wraps the referenced base measure (the `SELECTEDMEASURE()`-class callback — read the wording in `calculation_group_ti.json`). Applying a CG item as a slicer rewrites the context for any measure that supports it — one template, N measures.
- Why it collapses a library: without a CG, each base × each horizon = a *new named measure* (2 bases × 3 horizons = 6, × every future base = linear growth). With a CG: 2 bases + 1 CG with 3 items — new bases tomorrow cost zero extra measures. That counting (6 vs 2+1) is the hand-math proof (`cg_math.md`).
- Two-active-CGs rule: an active CG's item expression is applied; two CGs at once conflict unless one is inert — the format-string an item carries is what the *visual calls* use as a label, so item naming doubles as display taxonomy.

**Verification strategy:**
- One visual × CG slicer: flip Current → Previous → YoY; the numbers match the same slice by your proven SQL/Python values (a YoY RPC% = your earlier-computed same-horizon comparison).
- `cg_math.md`: 2 base + 1 CG×3 items = N measures you *didn't* need to author — write the arithmetic down.

**Traps & worth knowing:**
- Power BI Desktop's full CG authoring historically requires Tabular Editor (the project's `calculation_group_ti.json` + `create_calc_group.cs` are the production route) — if Desktop's UI restricts you, author the JSON/script route exactly like the project and import; that *is* the professional path, not a workaround.
- An item that forgets the base-measure callback renders every measure its own expression — the "all visuals same number" failure; always start the item body from the callback reference.

---

## Task 3 — RLS

**Thinking path:**
- RLS = a security role with a row rule; the rule uses a *user function* (`USERNAME()`-class) matched to a mapping table (supervisor ↔ agent), linking `dim_employees` so a login sees only their row-set's agents. The `rls_supervisor_map`-style pattern is exactly this in production.
- The *row-level* honesty: RLS filters rows — so a portfolio total on a secured page re-aggregates to the supervisor's slice (intended), while a *cross-team* total silently shrinks unless its visual is outside the secured scope. The policy decision ("supervisor sees own agents' detail, portfolio totals only from an unsecured summary") is a *design* decision to state, not a default.
- Effort model: adding a supervisor = adding a row to the mapping (a table change), not a new rule (a model change). That's the scaling argument for the map pattern over hardcoded rules.

**Verification strategy:**
- Impersonate as supervisor A: agent-level visuals show only A's agents; counts differ from the unsecured view. That delta is the proof — print both.
- A secured *summary* visual that must stay unsecured (e.g., the portfolio headline) — verify it shows *global* numbers under impersonation, or consciously accept the re-aggregation.

**Traps & worth knowing:**
- A role with no mapping row for a real supervisor = visibly empty brain for that login; test each actual login id in "View as".
- RLS protects *someone's* slice only if the fact tables filter through the secured dimension — a fact whose join chain bypasses `dim_employees` leaks. Test a payment's-worth visual under impersonation, not just the interactions page.

---

## Task 4 — Final audit

**Thinking path:**
- End-of-track audit = an *evidence file* (your proven outputs exported to `Truth`) imported into the model, and a Verification page computing, per metric, | live measure value − expected | within a stated tolerance → PASS/FAIL. The pattern: a `Truth` table keyed the same as the visual's slice (`RELATED`-class lookup), a delta, a pass bool; the page renders the whole audit at a glance.
- Stronger-proof question: a live view query is *current truth* (strong vs a moving target — views can evolve); an evidence CSV is *audited snapshot* (frozen & reproducible — STABLE). For a sign-off you want *stable*: the Evidence is the better anchor — it can't secretly recompute its own definition under the audit's feet.
- Tolerance policy writes first: rates in a percent of absolute terms, counts exact or tight; state it *before* any check (a FAIL after the fact isn't an audit, it's a post-mortem). A "my tolerance was too tight" FAIL is a real FAIL of *policy* — relax policy deliberately with a note, never in silence.

**Verification strategy:**
- Cold-read the Verification page: every headline metric has a row; FAILs have root-cause lines (definition gap → a targeted adjustment, filter window → re-slice, formatting → fix format); zero unexplained FAILs before "ship".
- The dashboard's cover numbers == the `Truth` rows — the five cover numbers and the audit agree, because the *proof* is the same file.

**Traps & worth knowing:**
- Delta on formatted cells (display `%` vs stored ratio) — same trap as Excel advanced; delta on *raw* values, format at display.
- A Verification table that never updates when the model changes says your `Truth` import isn't refreshed — the audit is only as alive as its evidence file; keep the refresh step in your regeneration pipeline.