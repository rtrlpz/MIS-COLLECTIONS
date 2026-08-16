# SQL — Advanced — Results (Guidance)

```
learning/
├── _reference/            ← datasets.md, kpi_glossary.md, data_dictionary.md
├── sql/
│   ├── README.md
│   └── advanced/          ← YOU ARE HERE
│       ├── tasks.md
│       ├── results.md     ← current file
│       └── work/
├── python/  notebooks/  excel/  powerbi/  git-cli/
└── README.md
```

**How to use this file:** attempt → commit → compare → read one section. Guidance only — reasoning paths, steps-with-why, verification strategy, traps. No full queries, no computed values. The **advanced rule applies here too**: divergence is a finding, not a failure.

---

## Task 1 — Rebuild `v_contact_metrics`

**Thinking path:**
- Write the definition first: "RPC% = RPCs ÷ the denominator the glossary names." If the glossary's primary convention is *RPC ÷ connected calls* (or ÷ operational hours — check), commit to it and note where the view also carries other numbers.
- Raw build: per team, `SUM` the two numerators from `fact_interactions`, joining `dim_employees` for the team label. If the metric needs *operational hours*, that lives in `fact_agent_time_log` — a cross-fact join changes the grain and may introduce fan-out; check whether the view computes hours at team level instead.
- Compare column by column with `v_contact_metrics`. Matching = validated. Diverging = hypotheses: (a) the view restricts channels (FICO/SMS excluded), (b) the view's denominator differs, (c) the view dedupes agents differently.
- Prove one hypothesis with a single targeted query — insert the suspected filter/denominator and see if it closes the gap. Don't guess; test.

**Verification strategy:**
- Sum-of-teams must equal the portfolio number *within the same population*. If you sum your rows but the view's total differs, the difference is a population/handle-time question, not arithmetic.
- Read `_reference/kpi_glossary.md`'s "calculation traps" — two of its items describe exactly the RPC% traps (averaging daily rates; wrong denominator).

**Traps & worth knowing:**
- A cross-fact join (interactions × time log) can blow up rows *before* you aggregate — if your team numbers look huge, that's the fan-out; aggregate each fact separately at team level and combine at the team key.
- "Operational hour" is a *denominator from another table* — mixing it with interaction sums is where most misalignment originates.

---

## Task 2 — Promise-and-kept chain

**Thinking path:**
- Draw: RPCs in `fact_interactions` (`rpc_flag = TRUE`) → PTPs in `fact_ptp_log` (one promise per RPC-chain hop) → KP in `fact_payments` (payments with a `ptp_id`, and `ptp_id` is intentionally FK-*less* — the dictionary notes this so nothing forces the join). Payments also carry cure flags (`is_cured`/`cure_flag`) — the glossary defines cure; kept-promise and cure are cousins, not twins.
- PTP% = promises ÷ RPCs (the glossary's convention — the opportunity set is RPCs). KP% needs the *evaluable* set: the glossary's fix history says BB = kept-rate × promise-rate (a *product* — because converting a promise into a payment only matters if a promise was *made*, and it's the compound odds both events happen).
- "Evaluable" is the bug trap: promises whose target date passed by the eval window, vs all promises ever. The view picks one. Match it — and when you see your KP% sitting different from theirs, this is the first suspect.

**Verification strategy:**
- Chain equality: your PTP count over a month should match a distinct count of PTP rows in that window (per the view's own filters). Same for the payment-kept side.
- Diff against `v_promise_metrics` per column; the write-up of *which hop* diverged is the entire value of the task.

**Traps & worth knowing:**
- Fact-to-fact joins multiply. The chain has three facts; join defensively (dedupe, keys) and prefer pre-aggregated stages.
- A promise can have multiple payments (partial) or one payment across promises — define "kept" (any payment on time? full amount?) before writing SQL, then check the glossary's exact kept definition.

---

## Task 3 — DPD migration matrix

**Thinking path:**
- Population: accounts present in **both** month-end snapshots. That's what makes it a *transition* matrix — you're observing the same set move buckets. Self-join `fact_eom_snapshot M1` + `fact_eom_snapshot M2` ON `account_id` (and each side's snapshot filter). `INNER` gives the both-pops population; an `OUTER` version surfaces new-in / left-accounts — reference both, decide which is the report population, and note it.
- Precedent: the view's population choice is discoverable by counting its total vs your paired count. If they differ by a few rows, they include/exclude partial-month accounts — that inclusion rule is the finding.
- Cells: pairs of bucket values (last-month bucket × this-month bucket). Aggregate to counts (and, optionally, arrears). The roll-to-worse off-diagonal cells (e.g., current → early) are the "crawl" story; same-bucket diagonal is "stuck"; better-than-last is "cure-ish" movement.
- Keyword: *snapshots, not events* — the matrix is a state-transition over monthly states. An account appears exactly once per month (1-row grain), so the pairing is clean.

**Verification strategy:**
- Row/column marginals: sum over last-month bucket = number of paired accounts = sum over this-month bucket (that's the identity check).
- Compare cell orientation vs the view (rows = last month, columns = this month). Transposed output is the classic silent bug — matches counts, wrong meaning.

**Traps & worth knowing:**
- Month pair choice: use the *most recent consecutive pair*; don't compare December to January unless they're adjacent snapshots in time.
- A month with weekend-anomaly accounts or missing snapshots shifts pair sizes — confirm both snapshot months exist with full population.
- "Migration" reads better as percentages of the *row* total (of last month's bucket) — the view likely does exactly that.

---

## Task 4 — Composite scorecard & audit

**Thinking path:**
- Weights are documented in the glossary: five components with fixed percentages that sum to 100% (RPC, KP, Cure, Utilization, Handle Time — find the exact split). Read the scorecard view's comment too (the `004` migration describes intent).
- Rebuild each component from raw facts — you now *can*: RPC side from interactions, KP side from the promise chain, cure side from payments' cure flags, utilization from the time log, handle time from interactions' AHT/ACW. Be explicit on each component's denominator (a rate, a ratio, a time).
- Composite: normalizing? The weight on a raw ratio vs a time value makes weighting meaningful only if the view scales components. Note honestly whether the view normalizes or not — the "comparability" question is a real one and the view has an answer.
- NULL policy: an agent missing one component (e.g., no interactions → no AHT). Match the view: does it carry NULL, treat as zero, or exclude? That policy changes scores materially.
- Audit: diff your per-agent scores vs `v_agent_scorecards`. For the top-3 diverging agents, drill to *component level* — usually one component's denominator or eval-window differs. Write the audit as a comment: each diff = hypothesis + evidence test.

**Verification strategy:**
- If your composite formula and the view's agree, the residuals should be all-zero or all-tiny. Non-zero = a component definition gap; triangulate by printing components side by side for one agent.
- Check an edge agent (new hire, no cures, all NULLs) — how the view scores an incomplete profile is a specification, and matching it is the pass criterion.

**Traps & worth knowing:**
- Mixing time (AHT seconds) and rates in a weighted mean — the view defines whether it normalizes; if it doesn't, a raw AHT in seconds can dwarf rates. Note *why the view still works* (weights small, values comparable) or where it breaks.
- Component denominators differ across agents naturally (an agent with 2 RPCs has a noisy rate) — weights don't fix variance, they only aggregate it.

---

### Finish

For each task, your `work/` file should carry a diff log: **matched / diverged / root cause**. A complete set of honest diff logs — not perfect matches — equals "graduate."

**Graduate when:** you can rebuild a view under time pressure and explain any one-number difference as a *choice of definition*, not a mystery.