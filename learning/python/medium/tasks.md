# Python Medium — Your Inbox (level 2 of 3)

```
You are here: learning/python/medium/
Assumed:      basic/ complete — year-recombine and parity habits are warm
Solutions:    medium/results.md — after attempting; RUN everything
New tools:    per-plan groupby logic, memory discipline at 1.34M rows, pivot_table,
              reconciliation scripts, decline detectors
```

**What this level gives you.** The file-side of the hard questions: installment-aware promise math without a database, scripts that stay fast when the year is fully loaded, and a DB↔files reconciliation you can hand to an auditor.

---

## Task 1 — Installment plans: per-plan truth in pandas
📥 **Inbox:** From Collections Strategy Lead · Wed 11:00 · "the KP% challenge, files edition"

> "Same rule as before: a plan is kept when CUMULATIVE payments reach 95% of the promise within grace. Someone summed per payment row again last month. Rebuild the kept/broken evaluation from raw files for Q2 and prove no kept plan sits under the threshold."

**Your job:**
1. Load Q2's PTP + payments across relevant months (plans spill over month ends!).
2. Group payments by ptp_id → total paid.
3. Merge onto plans; evaluate status consistency; count multi-part keeps.

**Done when:**
- [ ] Zero Kept plans under 95% cumulative (asserted)
- [ ] Multi-installment share reported
- [ ] Note: why month-folder boundaries forced careful loading

---

## Task 2 — Memory discipline at full-year scale
📥 **Inbox:** From MIS Manager · Thu 2:00 · "before this becomes a slide deck that crashes laptops"

> "Load ALL twelve months of interactions in one frame and tell me its memory footprint. Then halve it with dtypes alone — category for anything low-cardinality, smallest integer that fits. Show before/after in MB."

**Your job:**
1. Baseline load (default dtypes) → `df.info(memory_usage='deep')`.
2. Optimized load via explicit dtypes.
3. Report both footprints; assert row counts identical.

**Done when:**
- [ ] Before/after MB documented in comments
- [ ] Zero data loss (row count + spot values equal)
- [ ] dtype table written as the reusable loading recipe

---

## Task 3 — Two-month decline detector
📥 **Inbox:** From Operations Manager · Mon 8:00 · "coaching list, automatic"

> "Every month I want agents whose RPC% fell TWO consecutive months — latest month vs prior vs the one before. Output: agent, team, three monthly numbers, flagged. This runs monthly forever; make it one function."

**Your job:**
1. Agent × month RPC% pivot from the year frame.
2. Sort columns chronologically; detect two consecutive drops ending at the latest month.
3. Return a tidy DataFrame; wrap as `def declining_agents(kpi_pivot): ...`

**Done when:**
- [ ] Function reusable for ANY monthly KPI pivot (pass column name)
- [ ] Manual sanity check on one known agent
- [ ] Handles agents with missing months honestly (no silent NaN math)

---

## Task 4 — DB ↔ files reconciliation script
📥 **Inbox:** From Head of MIS · Fri 10:00 · "auditor-proof the pipeline"

> "Write `reconcile.py`: compares CSV row counts against database table counts for every fact, plus a checksum-style total (e.g., sum of amount_paid) where money is involved. Exit non-zero on any mismatch. This becomes part of our pipeline QA."

**Your job:**
1. Table↔file mapping for all seven facts (dims too if generous).
2. Row-count compare + money-column sum compare via psycopg2.
3. Clear PASS/FAIL output; proper exit codes.

**Done when:**
- [ ] Script saved in `work/reconcile.py`, runnable standalone
- [ ] Fails loudly when you deliberately corrupt a test input
- [ ] Credentials read from `.env` only

---

## Task 5 — Channel mix by arm, pivoted
📥 **Inbox:** From Strategy Analyst · Tue 1:30 PM · "steering deck wants the grid"

> "Arm × channel interactions as a proper PIVOT — arms as rows, channels as columns, share-within-arm as cell values. Same verdicts as SQL or we investigate."

**Your job:**
1. Build with `pivot_table` (or crosstab) from merged interactions+strategy dims.
2. Normalize within arm (`apply`-free if possible).
3. Parity check against your SQL medium numbers.

**Done when:**
- [ ] Grid matches SQL arm×channel counts exactly
- [ ] Within-arm shares sum to 100 per row (checked)

---

## Task 6 — MIS-ready summary frames
📥 **Inbox:** From Ops Lead · daily · "Excel track will eat these"

> "Produce two tidy DataFrames the reporting layer can consume blindly: (a) daily KPIs for the month (contacts/connects/rpc/promises/payments), (b) agent-month summary (rpc%, utilization). Column names stable, dates typed, sorted. No formatting — pure shape."

**Your job:**
1. Build both frames from the year data.
2. Freeze schemas: exact column lists asserted.
3. Export to `work/` as parquet (why parquet? say it in comments).

**Done when:**
- [ ] Two stable-schema outputs saved
- [ ] Asserts guard the contract
- [ ] One-line rationale for the file format choice

---

## Finish

Six tools that scale and reconcile. [`../advanced/tasks.md`](../advanced/tasks.md): the full pipeline, roll-rate matrices, forecasting, and your own QC suite.
