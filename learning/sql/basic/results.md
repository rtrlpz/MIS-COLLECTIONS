# SQL Basic — Results (worked solutions)

**How to use:** attempt in `work/` first. Then read your task's section, **run the solution**, and reconcile: does it behave like yours? Where the solution differs stylistically, ask which you'd defend in a code review. Solutions deliberately show **no outputs** — run them and see.

---

## Task 1 — Take inventory of the database

**Approach:** ask the catalog, never memory; classify by naming convention + grain; find join keys by looking for shared `_id`/`_key` columns.

```sql
-- 1) Every base table in the analytics schema
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type   = 'BASE TABLE'
ORDER BY table_name;

-- 2) Row counts per table (the size signature separates facts from dims)
SELECT 'fact_interactions' AS t, COUNT(*) AS rows FROM fact_interactions
UNION ALL SELECT 'fact_ptp_log',        COUNT(*) FROM fact_ptp_log
UNION ALL SELECT 'fact_payments',       COUNT(*) FROM fact_payments
UNION ALL SELECT 'fact_agent_time_log', COUNT(*) FROM fact_agent_time_log
UNION ALL SELECT 'fact_eom_snapshot',   COUNT(*) FROM fact_eom_snapshot
UNION ALL SELECT 'fact_writeoffs',      COUNT(*) FROM fact_writeoffs
UNION ALL SELECT 'fact_recoveries',     COUNT(*) FROM fact_recoveries
UNION ALL SELECT 'dim_employees',       COUNT(*) FROM dim_employees
UNION ALL SELECT 'dim_employee_history',COUNT(*) FROM dim_employee_history
UNION ALL SELECT 'dim_strategy',        COUNT(*) FROM dim_strategy
UNION ALL SELECT 'dim_clients',         COUNT(*) FROM dim_clients
UNION ALL SELECT 'dim_products',        COUNT(*) FROM dim_products
UNION ALL SELECT 'dim_delinquency_bucket', COUNT(*) FROM dim_delinquency_bucket
UNION ALL SELECT 'dim_calendar',        COUNT(*) FROM dim_calendar
UNION ALL SELECT 'dim_accounts',        COUNT(*) FROM dim_accounts
ORDER BY rows DESC;

-- 3) Join keys per fact: shared columns with dimension PKs
SELECT f.table_name  AS fact_table,
       kcu.column_name AS key_column,
       c.table_name  AS dim_table
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage c
  ON tc.constraint_name = c.constraint_name
WHERE tc.table_schema = 'public' AND tc.constraint_type = 'FOREIGN KEY'
ORDER BY f.table_name, key_column;
```

**Why each part:** the catalog queries survive schema changes — a typed list rots the day someone adds a table. The UNION-ALL counts are dumb on purpose: one result set, zero cleverness. The FK query answers "what connects to what" with authority instead of guessing.

**Verify yourself:** facts should number seven and dwarf every dim except `dim_calendar`; `dim_writeoffs`… doesn't exist — if your list shows something `_reference/data_dictionary.md` doesn't, that's a finding to write down.

**Traps & alternatives:** `\dt` (psql) only shows your search_path; `information_schema` is portable and explicit. Don't classify by row count alone — `fact_recoveries` is tiny because write-offs take months to age in, not because it's a dimension.

---

## Task 2 — Count January interactions by team

**Approach:** range filter (`>=` start, `<` next month) beats `BETWEEN` habits; team name comes from the employee dimension via `agent_id`; the join must be a plain inner join on a NOT NULL key so totals survive.

```sql
-- Total
SELECT COUNT(*) AS january_interactions
FROM fact_interactions
WHERE interaction_date >= DATE '2025-01-01'
  AND interaction_date <  DATE '2025-02-01';

-- Per team (desc)
SELECT e.team_name,
       COUNT(*) AS interactions
FROM fact_interactions f
JOIN dim_employees e USING (agent_id)
WHERE f.interaction_date >= DATE '2025-01-01'
  AND f.interaction_date <  DATE '2025-02-01'
GROUP BY e.team_name
ORDER BY interactions DESC;

-- Per day (asc)
SELECT f.interaction_date,
       COUNT(*) AS interactions
FROM fact_interactions f
WHERE f.interaction_date >= DATE '2025-01-01'
  AND f.interaction_date <  DATE '2025-02-01'
GROUP BY f.interaction_date
ORDER BY f.interaction_date;
```

**Why each part:** the half-open range `[Jan 1, Feb 1)` is timestamp-proof — it stays correct whether the column is a date or a timestamp. `USING (agent_id)` is shorthand for the equality join; totals stay identical because every interaction has an agent.

**Verify yourself:** sum the per-team counts and compare to the total — must match exactly. Cross-check the total against `v_contact_metrics WHERE granularity='monthly'`.

**Traps & alternatives:** `LEFT JOIN` here would silently preserve nothing extra (agent_id is NOT NULL) but on other facts it can *multiply* rows if the dim has duplicates — always re-check the total after any new join. Filtering an alias in `WHERE` fails: Postgres evaluates `WHERE` before `SELECT`.

---

## Task 3 — RPC% by channel, done properly

**Approach:** mirror the official view's definition — numerator is RPC rows, denominator is connected calls — and make division NULL-safe.

```sql
SELECT f.channel,
       SUM(f.calls_connected)                                AS connected_calls,
       SUM(f.rpc_flag::int)                                  AS rpc_count,
       ROUND(100.0 * SUM(f.rpc_flag::int)
             / NULLIF(SUM(f.calls_connected), 0), 1)         AS rpc_pct
FROM fact_interactions f
WHERE f.interaction_date >= DATE '2025-01-01'
  AND f.interaction_date <  DATE '2025-04-01'
GROUP BY f.channel
ORDER BY rpc_pct DESC;

-- Reconciliation against the official implementation:
SELECT channel, rpc_pct
FROM v_contact_metrics
WHERE granularity = 'monthly' AND month_num BETWEEN 1 AND 3;
```

**Why each part:** `rpc_flag::int` turns the boolean into 0/1 so `SUM` works. `NULLIF(denominator, 0)` converts an empty divisor into NULL — the row shows a blank percentage instead of crashing. `100.0` forces decimal math; `100` would do integer division and hand you zeros.

**Verify yourself:** aggregate your per-channel numbers across all channels and compare to the view's monthly totals for the same months. Equal means your definition matches production.

**Traps & alternatives:** dividing by `SUM(calls_attempted)` is the intern mistake from the request — attempts include unanswered dials. Don't average per-day percentages (`AVG(rpc_pct)`) when you want a period rate; weight by volume or compute from sums (this exact trap returns in medium Task 6).

---

## Task 4 — Biggest overdue accounts at month-end

```sql
SELECT s.account_id,
       a.product_type,
       s.dpd_bucket,
       s.arrears,
       s.balance
FROM fact_eom_snapshot s
JOIN dim_accounts a USING (account_id)
WHERE s.snapshot_date = DATE '2025-03-31'
  AND s.status = 'Mora'
ORDER BY s.arrears DESC
LIMIT 25;
```

**Why each part:** equality on `snapshot_date` pins the freeze-frame; `status='Mora'` keeps the delinquent book only; `LIMIT` after `ORDER BY arrears DESC` is how "top N" is spelled in SQL.

**Verify yourself:** remove status/LIMIT and confirm March 31 has roughly one row per live account (charged-off accounts have exited the book — see `_reference/data_dictionary.md`). Cross-check the biggest account's bucket against its `dpd` value: they must agree with `_reference/kpi_glossary.md` band edges.

**Traps & alternatives:** `snapshot_month = 'March_2025'` also works but is a display string — date comparison survives format changes. If someone asks for "current worst accounts", that's a different question entirely: snapshots don't answer it.

---

## Task 5 — The 8:40 morning pack

```sql
WITH report_date AS (
    SELECT DATE '2025-06-02' AS d          -- ← change ONE character daily
)
SELECT 'interactions'     AS metric, COUNT(*)                        AS value
FROM fact_interactions, report_date
WHERE interaction_date = d
UNION ALL
SELECT 'connected_calls', COALESCE(SUM(calls_connected), 0)
FROM fact_interactions, report_date
WHERE interaction_date = d
UNION ALL
SELECT 'promises',        COUNT(*)
FROM fact_ptp_log, report_date
WHERE ptp_date = d
UNION ALL
SELECT 'payments',        COUNT(*)
FROM fact_payments, report_date
WHERE payment_date = d;
```

**Why each part:** one CTE holds the parameter so tomorrow's edit touches exactly one line. `UNION ALL` stacks four independent counts into one result set without any join semantics to get wrong. `COALESCE` on the sum guards a zero-call day.

**Verify yourself:** run it for a known busy Monday and a Sunday (payments-only day). Contacts should be ~0 on Sunday while payments are not — if both move together, you're reading the wrong column.

**Traps & alternatives:** joining all three facts to combine them would multiply rows (different grains). Counts from separate scans UNIONed is the correct pattern here. For real automation this script becomes the SQL behind the Excel track's morning pack.

---

## Task 6 — How are clients actually paying?

```sql
SELECT payment_method,
       COUNT(*)                                          AS payments,
       ROUND(SUM(amount_paid)::numeric, 2)               AS total_paid,
       ROUND(100.0 * SUM(amount_paid)
             / NULLIF(SUM(SUM(amount_paid)) OVER (), 0), 1) AS dollar_share_pct
FROM fact_payments
WHERE payment_date >= DATE '2025-05-01'
  AND payment_date <  DATE '2025-06-01'
GROUP BY payment_method
ORDER BY total_paid DESC;
```

**Why each part:** `SUM(...) OVER ()` after `GROUP BY` is the window over the *grouped* totals — the whole-table denominator without a second CTE. The inner `SUM(amount_paid)::numeric` cast happens before division so shares are decimals.

**Verify yourself:** the three `dollar_share_pct` values must sum to ~100. Compare each method's count-share vs dollar-share mentally: a method with more counts but fewer dollars means small-ticket payments — that's an insight for the deck.

**Traps & alternatives:** `COUNT(*)` counts rows = payments; if you ever need distinct clients paying, that's `COUNT(DISTINCT account_id)` — different question, different number (this exact distinction once fixed a real double-count in this project's cure metrics).

---

## Task 7 — What do we collect? Products 101

```sql
SELECT product_type,
       COUNT(*)                                AS accounts,
       ROUND(AVG(credit_limit)::numeric, 0)    AS avg_credit_limit
FROM dim_accounts
GROUP BY product_type
ORDER BY accounts DESC;

-- Proof for the favor: would joining dim_products change anything?
SELECT DISTINCT a.product_type, p.product_name
FROM dim_accounts a
JOIN dim_products  p ON p.product_type = a.product_type
ORDER BY a.product_type;
```

**Why each part:** the first query answers with zero joins because `product_type` is denormalized onto every account — a deliberate star-schema convenience. The second proves the join adds only labels (`product_name`, rates), not granularity: one row per account before and after.

**Verify yourself:** run both; the join result should have exactly one product row per distinct `product_type`. If it ever fans out to more, someone duplicated `dim_products` and your averages everywhere are now lies.

**Traps & alternatives:** never trust a denormalized column blindly — this query IS the blind-trust test. A periodic reconciliation (compare distinct pairs) is the analyst-grade habit.

---

## Task 8 — House rules check: weekends

```sql
SELECT 'weekend_interactions' AS rule_check,
       COUNT(*)               AS violations
FROM fact_interactions
WHERE EXTRACT(ISODOW FROM interaction_date) IN (6, 7)
UNION ALL
SELECT 'weekend_payments',
       COUNT(*)
FROM fact_payments
WHERE EXTRACT(ISODOW FROM payment_date) IN (6, 7);
```

**Why each part:** `EXTRACT(ISODOW ...)` returns 1=Mon … 7=Sun regardless of locale/server settings — safer than `DOW` whose week start varies.

**Verify yourself:** expected shape: interactions violations = 0 (weekday-only rule), payments violations > 0 (payments allowed any day — the rule is "allowed", not "required"). State both verdicts in comments above each half.

**Traps & alternatives:** don't use `TO_CHAR(date,'Day')` — output depends on `lc_time`; a server setting could silently flip your rule check.

---

## Task 9 — Freshness check before you hit send

```sql
WITH maxima AS (
    SELECT 'fact_interactions'   AS table_name, MAX(interaction_date) AS max_date FROM fact_interactions
    UNION ALL SELECT 'fact_ptp_log',        MAX(ptp_date)        FROM fact_ptp_log
    UNION ALL SELECT 'fact_payments',       MAX(payment_date)    FROM fact_payments
    UNION ALL SELECT 'fact_agent_time_log', MAX(log_date)        FROM fact_agent_time_log
    UNION ALL SELECT 'fact_eom_snapshot',   MAX(snapshot_date)   FROM fact_eom_snapshot
    UNION ALL SELECT 'fact_writeoffs',      MAX(writeoff_date)   FROM fact_writeoffs
    UNION ALL SELECT 'fact_recoveries',     MAX(recovery_date)   FROM fact_recoveries
)
SELECT table_name,
       max_date,
       (MAX(max_date) OVER () - max_date) AS days_behind_newest
FROM maxima
ORDER BY max_date DESC;

-- Official implementation to compare against:
SELECT * FROM v_data_freshness ORDER BY max_date DESC;
```

**Why each part:** the CTE collects one max per table into a uniform shape; the window `MAX(max_date) OVER ()` finds the global newest date and expresses everyone else as lag in days — instantly visible staleness ranking.

**Verify yourself:** your seven rows should agree with `v_data_freshness` on dates. Expect `fact_eom_snapshot` to trail daily tables by design (month-end grain) — knowing which lag is *normal* is the actual skill.

**Traps & alternatives:** if two daily-grain tables ever disagree on max date while the pipeline claims success, suspect a partial load — check `etl_load_log` next. This script belongs in your permanent toolbox; you will run it before every deliverable for the rest of this job.

---

## Where to next

All nine done and reconciled? Move to [`../medium/tasks.md`](../medium/tasks.md) — same data, harder questions.
