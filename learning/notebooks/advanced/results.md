# Notebooks — Advanced — Results (Guidance)

```
learning/
├── _reference/            ← datasets.md, kpi_glossary.md, data_dictionary.md
├── sql/  python/  excel/  powerbi/  git-cli/
├── notebooks/
│   ├── README.md
│   └── advanced/          ← YOU ARE HERE
│       ├── tasks.md
│       ├── results.md     ← current file
│       └── work/
└── README.md
```

**How to use this file:** attempt → commit → read one section. Guidance only — reasoning paths, steps-with-why, verification strategy, traps. No full code, no computed values.

---

## Task 1 — The self-verifying EDA

**Thinking path:**
- The checks section is the soul: for each headline number, recompute it *against the reference view* in-adjacent cells. A rate → compare to `v_contact_metrics`/`v_promise_metrics`; the profile → `v_dpd_migration_matrix` (or the dictionary's documented conventions). This is SQL-advanced's "compare against the views" lesson, in the artifact where it becomes shareable.
- Tolerance: float `==` is fragile; a rates tolerance (a few percent) and a counts tolerance (exactness or one-part-per-thousand) are *different* tolerances — state them and their reasons in Markdown. The delta-print is the reviewer's evidence.
- `FAIL` handling: a FAIL with a root-cause cell is an *audit finding*; a FAIL without one is a bug in your own notebook. The discipline is to never ship a silent FAIL.

**Verification strategy:**
- Cold Run All → every *should-pass* check prints PASS. That's the finish line.
- The checks re-read the config cell (month/source) — flipping the config must not flip the verdict unless the analysis genuinely changed.

**Traps & worth knowing:**
- Comparing a rate you subtracted in `float64` arithmetic vs a view computed in SQL can differ at the 6th decimal — that's *not* a finding, that's noise; your stated tolerance makes the difference visible-or-not *by design*.
- A PASS with a *giant* tolerance is theater; shrink the tolerance until it's meaningful, then defend it.

---

## Task 2 — Director's export

**Thinking path:**
- The two-audience split is about the *grain of the message*: ops gets every number and the method to rebuild it (full tables + a reproducible config); the director gets the ≤12-line narrative (top rates, worst bucket, one trend, one risk). Decide the cut line in words: everything *decision-relevant* goes to the director; everything *reproducible* goes to ops.
- Anti-drift principle: the export cells reference the *same computed frames* as the display cells. Re-typing a value into an export = a future drift bug that only a diff catches.
- Written artifacts under `work/` (git-ignored) — CSV for ops, Markdown for the director — regenerated on every Run All, so the artifacts can never go stale relative to the analysis.

**Verification strategy:**
- After Run All: `pd.read_csv('work/...csv')` inside the notebook vs the in-memory frame — `.equals()` must be True.
- The director summary's claims each trace to a cell/figure in the notebook (a claim with no anchor is a source for a meeting-ambush).

**Traps & worth knowing:**
- Reassembling the year twice (display cell + export cell) doubles memory and invites ordering drift — compute once, reuse.
- A hand-edited `director_summary.md` between runs gets overwritten on the next Run All — that's *intended*: the artifact is generated, not authored.

---

## Task 3 — The audit notebook

**Thinking path:**
- Audit = reproducibility + citation + verdict. Today's value (source + date stated), shipped value (view or prior export), an audit table (today | shipped | delta | explanation), then *root-cause* analysis for any delta bigger than tolerance.
- Root-cause discipline: a hypothesis → a targeted mini-check (e.g. add the channel filter → does the delta close?) → a conclusion. This is the SQL advanced rule ("a divergence is a finding, prove it") made into a visible notebook section.
- The verdict is the professional deliverable: "current number supersedes X because… / matches / requires a decision." Never end an audit mid-air.

**Verification strategy:**
- A third party (or you, six months later) can re-run the notebook cold and reach the same verdict — citability of *cells*, not memory, is what makes that true. Test the reads: hide a line, then re-read.

**Traps & worth knowing:**
- Comparing two defensible definitions ("connected" vs "attempted" denominator) — the audit table should *show* the definition stated per row, not per remember.
- An audit that changes the source (DB today, CSV for shipped) subtly changes method; state the source line per figure.

---

## Task 4 — The finished costume

**Thinking path:**
- The reorder is the message-architecture: Title → TL;DR findings → analysis → verification → appendix. Findings *first* because a director reads the first screen; the appendix holds the config and methods a re-builder needs.
- Dead-ends: a deliverable notebook shows the *path that worked*. Hiding is friendlier than deleting if a scratch cell taught a trap worth memorializing — otherwise delete. Say in a Markdown note which you chose and why (that's an analyst communicating taste).
- Cell hygiene: no raw traceback dumps, no giant generic prints; every output is either a table, a chart, or a PASS/FAIL line.
- Run-order proof: because cells *reference* computed frames rather than relying on physical position, reordering keeps Run All green — the cross-check that ordering-vs-reference is healthy (and that you didn't rely on accidental state).

**Verification strategy:**
- The director-read test: read top-to-bottom as the exec would — if any figure lacks a source anchor, re-anchor before finishing.
- Cold Run All with zero manual steps; then read attempt_3/checks — all PASS. The deliverable is the whole notebook, not its filename.

**Traps & worth knowing:**
- "Restart & Run All" as the *last* edit: a notebook that passed at 3pm but fails cold at 3:01 has hidden state. The rule exists to catch exactly that.
- Over-deletion: cutting a cell to make it pretty but losing the *reproducibility* of a number breaks the auditability you built in earlier tasks — keep the evidence, hide the noise.