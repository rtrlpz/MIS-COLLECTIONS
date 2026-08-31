# LEARNING GUIDE — What to tackle, in what order, and why

> Companion to `REFACTOR_PLAN.md` (what each track contains). This file answers the
> *sequencing* question: which skill first, which later, and the reasoning — so the
> order is a decision you understand, not a rule you follow.

---

## The three principles everything follows

1. **Same number, five tools.** A KPI only counts as understood when SQL, Python,
   notebook, Excel and Power BI agree. Disagreement isn't failure — it's a finding.
2. **Attempt first, always.** Struggling ~20 minutes encodes the lesson; reading the
   answer encodes nothing. `results.md` exists to compare against your honest try.
3. **The project's own `v_*` views are the answer key.** Reproducing them from raw
   tables is real analyst work; auditing differences is the senior skill.

Structural fact that makes sequencing easy: **every track assumes only `sql/basic`.**
Everything else is payoff timing, not hard dependencies.

---

## The path at a glance

```
Stage 0  Setup (10 min)
Stage 1  sql/basic ──────────────── THE FOUNDATION
Stage 2  sql/medium                breakdowns & traps
Stage 3  powerbi/basic → medium    your target module
Stage 4  PHASE 9 real build        guided
Stage 5  powerbi/advanced          post-build depth
Stage 6  python → notebooks → excel   git-cli anytime
```

---

## Stage 0 — Setup (~10 min, one time)

**Do:** connect a client (`datasets.md` §5); skim glossary Contact + Promise sections.

**Why before tasks:** no client = no attempts; and the glossary prevents the classic
beginner bug (reading RPC% as RPC÷attempts instead of RPC÷connected).

---

## Stage 1 — `sql/basic` (9 tasks) — START HERE

Teaches: catalog inventory · counts by team/day · safe rates · top-N from snapshots ·
speed under deadline (morning pack) · count-vs-dollar thinking · denormalization
awareness · house-rule verification · freshness gate.

**Why first:**
- Every other track audits against SQL numbers — parity requires fluency here.
- Power BI Task 1 rebuilds this star as a model; querying it first turns modeling
  from copying-a-picture into obviousness.
- Cheapest feedback loop in the lab: seconds per attempt.

**Why not Python first:** pandas adds API + file-wrangling friction before any data
understanding. SQL delivers the *data* fastest; Python then teaches moving it.

---

## Stage 2 — `sql/medium` (8 tasks)

Teaches: CTE chains · installment-plan logic (cumulative ≥95%) · strategy-arm splits ·
AHT benchmarks vs ratio-of-sums team bars · utilization methods · weekly rollups.

**Why now:** these become DAX measures verbatim. Meeting KP% semantics and the
ratio-of-sums-vs-average-of-averages trap in SQL — where wrong numbers look obviously
wrong — trains instincts that protect you when DAX errors are quieter.

---

## Stage 3 — `powerbi/basic → medium` (12 tasks)

Basic = hygiene: marked date table, auto date/time OFF, safe-divide measures, slicer
interactions. Skipping means redoing visuals when months sort alphabetically in March.
Medium = analysis patterns: MTD/YTD, targets-from-table, field-value RAG, severity-
ordered roll-rate matrix, drillthrough, dynamic titles.

**Why after sql/medium:** measures re-express aggregations you've already written by
hand — translation, not new math.

**Why `advanced` waits:** SVG cards, RLS, governance and performance tuning solve pains
you only feel during a real build.

---

## Stage 4 — PHASE 9: the real build (guided)

Why now rather than after all five tracks: portfolio centerpiece, fresh motivation, and
basic+medium cover ~90% of the nine pages. The gap becomes a live lesson (guided mode),
not a blocker. Rhythm per page: build from blueprint field wells → run that page's
parity query → reconcile to zero.

Plan of record: `docs/powerbi/PHASE9_EXECUTION_PLAN.md`.

---

## Stage 5 — `powerbi/advanced` (5 tasks, post-build)

RLS roles, SVG cards, trend methodology, governance standards, performance hygiene —
land as solutions to pains you personally felt during Phase 9.

---

## Stage 6+ — `python` → `notebooks` → `excel`

| Track | Why in this slot | Why not earlier |
|---|---|---|
| `python/` | Reconciliation scripts, memory discipline at scale, decline detectors — its parity targets are SQL numbers you already own | File-wrangling friction before data sense |
| `notebooks/` | Explains what Python computes | Explaining nothing is hollow |
| `excel/` (+VBA) | Ships finished numbers to non-analysts; generator reuses pandas loaders | Formatting numbers you don't yet understand |
| `git-cli/` | Standalone and short — version everything above | Anytime, lunch-break sized |

---

## Session cadence (every task)

1. Read the inbox request — who wants it, by when.
2. Attempt in `work/`. **Stuck >20 min → bring it to the guide.**
3. Read that task's `results.md`; RUN the solution yourself.
4. Note one thing you'd do differently.
5. Tick Done-When boxes honestly.

---

## One-line version

> SQL teaches you the truth, Power BI teaches you to serve it, Python teaches you to
> move it, notebooks teach you to explain it, Excel ships it — and git remembers it.
