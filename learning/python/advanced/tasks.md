# Python Advanced — Your Inbox (level 3 of 3)

```
You are here: learning/python/advanced/
Assumed:      medium/ complete — loaders, memory discipline, reconciliation all warm
Solutions:    advanced/results.md — after a serious attempt; RUN and DIFF
Theme:        the file-side of the senior job — pipeline modules, roll-rate matrices,
              forecasting for capacity, and your own QC suite
Scale:        full year, ~1.34M interaction rows — everything here must stay honest at scale
```

---

## Task 1 — The KPI pipeline as a module
📥 **Inbox:** From MIS Manager · Mon 9:00 · "graduate from scripts"

> "Turn your scattered scripts into ONE importable module: `load_year()`, `contact_kpis()`, `promise_kpis()` (installment-aware), `utilization_kpis()`, each returning typed frames. Prove it: rebuild three official view numbers from raw in under a minute of runtime."

**Your job:**
1. Module `kpi_pipeline.py` with the four functions + a `__main__` smoke test.
2. Docstrings state grain + parity target (`v_*` view name) per function.
3. Runtime printed per stage.

**Done when:**
- [ ] Importable without side effects (no top-level loads)
- [ ] Three parity checks pass vs SQL views
- [ ] Stage timings logged

---

## Task 2 — Roll-rate transition matrix from snapshots
📥 **Inbox:** From Credit Risk Director · Tue 9:00 · "the board matrix, files edition"

> "From EOM snapshot files only: account-level transitions between consecutive month-ends for H2, bucket rows/columns ordered by severity, direction classified. Must equal your SQL advanced Task 1 exactly."

**Your job:**
1. Load full-year snapshots; sort by account+date.
2. Groupby-shift to get previous bucket; drop first-month rows.
3. Crosstab from×to with severity ordering via the buckets dim.

**Done when:**
- [ ] Matrix equals SQL twin cell-for-cell
- [ ] Exits handled explicitly (documented choice)
- [ ] Worsened/stable/improved classification present

---

## Task 3 — Seasonal-naive forecast → capacity estimate
📥 **Inbox:** From Site Director · Thu 4:00 · "January staffing pre-work"

> "Same ask as SQL advanced Task 7 but from files: Mora stock series, trailing-3-month projection for January, converted to collector-hours and FTE with every assumption inline. Then tell me how the number would move if attempts-per-account doubles."

**Your job:**
1. Stock series from snapshots (status counts by month-end).
2. Projection + capacity math with named constants.
3. Sensitivity table: attempts ×2 scenario side-by-side.

**Done when:**
- [ ] Series + projection + hours + FTE delivered
- [ ] Assumptions block a director could read aloud
- [ ] Sensitivity computed, not hand-waved

---

## Task 4 — Your own QC assertion suite
📥 **Inbox:** From Head of MIS · Fri 11:00 · "before anyone trusts files blindly"

> "Write `qc_checks.py`: a battery of assertions over the loaded year — PK uniqueness, null rates on critical columns, weekend rules, kept-plan threshold, re-entry band, calendar coverage. Each check returns PASS/FAIL + detail. This is our data contract, executable."

**Your job:**
1. ≥8 checks spanning structure + business rules.
2. Runner prints a table and exits non-zero on any FAIL.
3. One deliberately failing check demonstrated (then fixed).

**Done when:**
- [ ] Suite runs standalone in seconds on parquet caches
- [ ] Covers both structural AND business-rule layers
- [ ] Failure output actionable (names the broken rule + row counts)

---

## Task 5 — Batch processing & timing benchmark
📥 **Inbox:** From MIS Manager · Wed 3:00 · "prove the chunked path"

> "Somebody claims chunked reading is slower than load-everything. Measure it properly: same aggregation (monthly RPC%) via (a) full-year frame, (b) 250K-row chunks accumulated incrementally. Same answer, compared wall-times, memory peaks noted."

**Your job:**
1. Implement both paths correctly (chunked partial sums must weight identically!).
2. Time with `time.perf_counter`; capture peak memory (`tracemalloc`).
3. Verdict paragraph: when chunking wins, when it doesn't.

**Done when:**
- [ ] Identical results asserted between paths
- [ ] Timing + memory numbers recorded in comments
- [ ] Honest conclusion (chunking is not always faster)

---

## Finish

You now build production-grade file pipelines end to end. The notebooks track replays these skills as *explanations* — [`../notebooks/basic/tasks.md`](../notebooks/basic/tasks.md).
