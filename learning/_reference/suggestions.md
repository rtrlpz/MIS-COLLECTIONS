# Suggestions for Learning Files

This is a living document. Add corrections, improvements, and traps you discover while working through any learning task across all tracks (sql, python, notebooks, powerbi, excel, git-cli).

---

## SQL / basic / task1.sql — Typos & Corrections

### Section b — Row count query (line 33–50)

| Line | Issue | Fix |
|------|-------|-----|
| 33 | Double space: "every  known table" | "every known table" |
| 39 | Label `'fact_writeoff'` missing trailing 's' | `'fact_writeoffs'` (actual table name is `fact_writeoffs`) |
| 40 | Label `'fact_eom_snapshop'` has double 's' | `'fact_eom_snapshot'` (actual table name is `fact_eom_snapshot`) |

> **Why it matters:** The string labels appear in query output and the ORDER BY sorts by them. Wrong labels propagate to any report or documentation that references these rows.

### Section c — Classification block (line 55–125)

| Line | Issue | Fix |
|------|-------|-----|
| 55 | "one row per current employees" | "one row per current employee" |
| 65 | "one row per collection interactions" | "one row per collection interaction" |
| 69 | "one row per payment transactions" | "one row per payment transaction" |
| 111 | "events happend repeatedly ove time" | "events happen repeatedly over time" |
| 114 | "These table's changes are less often" | "These tables' changes are less frequent" (plural possessive + wording) |
| 125 | "quaters" | "quarters" |

### Section d — FK query limitations (line 87–105)

- The query only surfaces tables with **explicit FK constraints**. Facts like `fact_payments` (where `ptp_id` has no FK constraint per project docs) will have implicit relationships that won't appear.
- **Suggestion:** Add a comment noting this limitation, or supplement with a query against `information_schema.columns` to list all `_id` / `_key` columns per fact table regardless of constraints.

### General completeness notes

- Steps 9–11 of the discovery checklist (date coverage, column profiles, data dictionary comparison) were intentionally skipped per the student's plan — acceptable for a first pass but worth revisiting in medium/advanced tasks.
- All actual `FROM` / `SELECT` table names (`fact_writeoffs`, `fact_eom_snapshot`, `dim_delinquency_bucket`) are correct. Only the string labels have typos.

---

## Template for future suggestions

Add new entries below this pattern when you find issues in other learning files:

```
## [Track] / [Level] / [taskN.sql|tasks.md|results.md] — [Brief title]

### [Section or component]

| Line | Issue | Fix |
|------|-------|-----|
| X | Description | Correction |

> Why it matters: explanation.
```

---

## Pending / To-verify items

- [ ] Verify `dim_delinquency_bucket` vs `dim_delinquency` — check if `dim_delinquency` exists anywhere (AGENTS.md references `dim_delinquency_bucket` consistently)
- [ ] Cross-check `fact_writeoffs` grain description — "post-write-off" may need clarification (writeoff vs post-writeoff distinction)
- [ ] Confirm `fact_agent_time_log` date column name (`log_date` per results.md Task 9) matches actual schema
