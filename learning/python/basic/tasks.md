# Python Basic — Your Inbox (level 1 of 3)

```
You are here: learning/python/basic/
Assumed:      sql/basic done — you know the tables; pandas basics assumed, depth not
Setup:        conda env mis-collections · read ONLY from data_sources/raw/ · save work/attempt_*.py
Solutions:    basic/results.md — after attempting; then RUN the solution and diff behavior
Discipline:   where a task mirrors a SQL task, your numbers must agree. Disagreement = finding.
```

**What this level gives you.** The file-side of the same job: recombine monthly extracts into a year, compute the morning KPIs in pandas instead of SQL, and never ship a number that disagrees with the database without knowing why.

---

## Words you'll meet

| Term | Plain meaning |
|---|---|
| **DataFrame / df** | pandas' table — think query result you can program against |
| **Monthly folders** | `data_sources/raw/january_2025/ …` each holding that month's fact CSVs; dims live in `shared/` |
| **dtype** | A column's data type. Wrong dtype = silent wrong answers (`"EID-001"` as NaN-prone float) |
| **groupby** | The `GROUP BY` of pandas — split, apply, combine |
| **Parity check** | Comparing a pandas number against its SQL twin until they match exactly |

---

## Task 1 — Meet the raw files
📥 **Inbox:** From MIS Manager · Day 1 · "orientation before touching anything"

> "Same drill as SQL onboarding, files edition: list what's actually in `data_sources/raw/`, open ONE month's interaction file safely, and report its shape plus dtypes. I want to know if you'd spot a broken export."

**Your job:**
1. Walk the folder tree programmatically: shared dims + 12 month dirs + per-fact CSVs.
2. Load one month's `Fact_Interactions.csv`; print shape, dtypes, head(3).
3. Note which columns pandas guessed WRONG without help (ids? dates? flags?).

**Done when:**
- [ ] Folder walk printed for all 12 months + shared
- [ ] One month loaded; dtype suspicions written as comments
- [ ] Saved `work/attempt_1.py`

---

## Task 2 — Rebuild the year from monthly folders
📥 **Inbox:** From Ops Lead · Tue 9:00 · "the extracts arrive monthly; analysis needs a year"

> "Concatenate all twelve months of interactions into one DataFrame. Row count must equal the sum of the parts — prove it in the script. And carry a proper datetime column, not strings."

**Your job:**
1. Loop/glob the 12 month dirs; read each interactions CSV with correct dtypes.
2. Concat; add nothing else yet.
3. Assert: len(year_df) == sum(len(month_dfs)); parse dates.

**Done when:**
- [ ] One concatenated frame, dates parsed
- [ ] Sum-of-parts assertion passes in-code
- [ ] Total row count noted in a comment vs `_reference/datasets.md`

---

## Task 3 — RPC% by team, pandas edition
📥 **Inbox:** From Operations Manager · Mon 8:15 · "same numbers, different tool"

> "The SQL kid gave me January RPC% by team. You replicate it from files — if you two disagree, I need to know WHICH one is wrong and why."

**Your job:**
1. Merge interactions (Jan) with the employees dim for team names.
2. Groupby team → connected calls sum, rpc count sum.
3. Compute RPC% with divide-guarding; sort desc.

**Done when:**
- [ ] Team-level table matching your SQL attempt's shape
- [ ] Parity check executed vs `v_contact_metrics` numbers (or your SQL twin)
- [ ] Any mismatch investigated, not rounded away

---

## Task 4 — Month slicing like SQL ranges
📥 **Inbox:** From MIS Manager · Thu 11:00 · "quarterly cut"

> "Q1-only slice of the year frame using date RANGES like we do in SQL (>= start, < end), not string tricks. Show it survives February properly."

**Your job:**
1. Slice Q1 via boolean mask on parsed dates.
2. Prove edge safety: include Feb fully, exclude Apr 1.
3. Report rows per month within the slice.

**Done when:**
- [ ] Range-based mask (no `.dt.strftime('%Y-%m') == '2025-01'` crutches)
- [ ] Per-month counts shown; edges asserted

---

## Task 5 — Payments: weekend rule, verified in files
📥 **Inbox:** From QA Supervisor · Fri 3:30 PM · "trust, but verify — files this time"

> "SQL said zero weekend interactions but weekend payments exist. Confirm BOTH facts from raw CSVs across the full year. Same verdicts as the DB or something's off between extract and load."

**Your job:**
1. Full-year payments + one month's interactions (enough) loaded with parsed dates.
2. Weekend counts per weekday-number function of your choice.
3. Verdicts in comments; note any divergence from DB truth.

**Done when:**
- [ ] Both rules checked; verdicts stated
- [ ] Divergence handling explained (there should be none)

---

## Task 6 — The morning pack, file edition
📥 **Inbox:** From Ops Lead · daily 8:40 · "same four sticky numbers, no database allowed today"

> "DB is under maintenance. Yesterday's contacts, connects, promises, payments — from FILES only. One saved script taking a date; tomorrow I change one line."

**Your job:**
1. Parameter = single date at top of script.
2. Load only what's needed (which months? think).
3. Print exactly four labeled numbers.

**Done when:**
- [ ] One-line date change reruns everything
- [ ] Numbers equal the DB pack for a test date (parity!)
- [ ] Runtime sane because you loaded selectively

---

## Finish

Six scripts. Files hold no secrets now — next level makes them fast and honest at scale: [`../medium/tasks.md`](../medium/tasks.md).
