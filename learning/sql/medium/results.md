# SQL Medium — Results (worked solutions)

Attempt first. Then run each solution, reconcile against the named `v_*` view, and keep your notes — the reconciliation comments are the real deliverable of this level.

---

## Task 1 — Daily MIS skeleton for one day

**Approach:** one CTE per fact, each pre-aggregated to agent grain, then LEFT-joined so an agent missing from any source still appears.

```sql
WITH report_date AS (
    SELECT DATE '2025-06-02' AS d
),
contacts AS (
    SELECT agent_id,
           SUM(calls_attempted)          AS total_calls,
           SUM(calls_connected)          AS connected_calls,
           SUM(rpc_flag::int)            AS rpc_count
    FROM fact_interactions, report_date
    WHERE interaction_date = d
    GROUP BY agent_id
),
promises AS (
    SELECT agent_id,
           COUNT(*)                      AS ptp_count
    FROM fact_ptp_log, report_date
    WHERE ptp_date = d
    GROUP BY agent_id
),
cures AS (
    SELECT agent_id,
           COUNT(*) FILTER (WHERE is_cured)       AS cure_count,
           COALESCE(SUM(amount_paid) FILTER (WHERE is_cured), 0) AS cured_amount
    FROM fact_payments, report_date
    WHERE payment_date = d
      AND agent_id IS NOT NULL
    GROUP BY agent_id
)
SELECT e.team_name,
       e.agent_name,
       COALESCE(c.total_calls,      0) AS total_calls,
       COALESCE(c.connected_calls,  0) AS connected_calls,
       COALESCE(c.rpc_count,        0) AS rpc_count,
       COALESCE(p.ptp_count,        0) AS ptp_count,
       COALESCE(u.cure_count,       0) AS cure_count,
       COALESCE(u.cured_amount,     0) AS cured_amount
FROM contacts  c
JOIN dim_employees e USING (agent_id)
LEFT JOIN promises p USING (agent_id)
LEFT JOIN cures    u USING (agent_id)
ORDER BY e.team_name, c.rpc_count DESC NULLS LAST;
```

**Why each part:** `contacts` is the spine (INNER) because the pack is about calling activity; promises and cures hang off it with LEFT JOINs so agents don't vanish on quiet promise days. Each CTE aggregates BEFORE joining — joining raw then grouping would work here but scales badly and invites duplicate-row bugs as sources grow. `FILTER (WHERE …)` counts cured rows inside a single pass.

**Verify yourself:** row count must equal `SELECT COUNT(DISTINCT agent_id) FROM v_daily_mis WHERE date = DATE '2025-06-02'`. Spot-check one agent's numbers against that view directly.

**Traps & alternatives:** comma-joins (`FROM fact_interactions, report_date`) are old-school cross joins tamed by WHERE — fine for a 1-row parameter table, but write explicit `CROSS JOIN` if your reviewers prefer loudness. Never sum `amount_paid` without the `agent_id IS NOT NULL` guard: self-cure payments have no agent and would fabricate a mystery-agent row.

---

## Task 2 — Installment plans: who really kept their promise?

**Approach:** aggregate payments to plan grain first; judge the PLAN, never the payment row.

```sql
WITH plan_totals AS (
    SELECT ptp_id,
           SUM(amount_paid)      AS paid_total,
           COUNT(*)              AS payment_count,
           MIN(payment_date)     AS first_payment,
           MAX(payment_date)     AS last_payment
    FROM fact_payments
    WHERE ptp_id IS NOT NULL
    GROUP BY ptp_id
)
SELECT pt.ptp_id,
       pt.promised_amount,
       pt.status,
       pt.grace_until_date,
       t.paid_total,
       t.payment_count,
       CASE WHEN t.paid_total >= 0.95 * pt.promised_amount
            THEN 'meets_95pct' ELSE 'underpaid' END AS cumulative_check,
       (t.payment_count > 1)                        AS is_installment
FROM fact_ptp_log pt
JOIN plan_totals t USING (ptp_id)
WHERE pt.status = 'Kept'
  AND pt.ptp_date >= DATE '2025-04-01'
  AND pt.ptp_date <  DATE '2025-07-01'
ORDER BY pt.promised_amount DESC;

-- The share the manager asked for: Kept plans needing more than one payment
SELECT ROUND(100.0 * AVG((payment_count > 1)::int), 1) AS multi_part_kept_pct
FROM (
    SELECT pt.ptp_id, COUNT(p.payment_id) AS payment_count
    FROM fact_ptp_log pt
    JOIN fact_payments p USING (ptp_id)
    WHERE pt.status = 'Kept'
    GROUP BY pt.ptp_id
) x;
```

**Why each part:** `WHERE ptp_id IS NOT NULL` keeps self-cure/unlinked payments out of promise math. The `0.95` factor encodes the business rule (cumulative ≥95%). Kept-only filter turns the query into an invariant check — any `underpaid` row would be a data bug worth escalating, not a business finding.

**Verify yourself:** zero `underpaid` rows must remain. Your Q2 kept-plan count should line up with `v_promise_metrics WHERE granularity='monthly'` sums for months 4–6.

**Traps & alternatives:** per-row checks (`amount_paid >= promised_amount` on each payment) flag every legitimate first installment as underpaid — exactly how last month's false alarm happened. Broken plans CAN carry partial payments; that's Task 5's salvage list, not an error.

---

## Task 3 — Does the treatment arm change the channel mix?

```sql
SELECT s.strategy_name,
       f.channel,
       COUNT(*) AS interactions,
       ROUND(100.0 * COUNT(*)
             / SUM(COUNT(*)) OVER (PARTITION BY s.strategy_name), 1) AS pct_in_arm
FROM fact_interactions f
JOIN dim_strategy s USING (strategy_id)
GROUP BY s.strategy_name, f.channel
ORDER BY s.strategy_name, interactions DESC;
```

**Why each part:** `COUNT(*)` grouped by arm×channel gives cells; `SUM(COUNT(*)) OVER (PARTITION BY arm)` totals each arm's row-count AFTER grouping — the window rides on top of the aggregate, which is legal and saves a CTE. Percentage within arm answers "is this arm wired as designed".

**Verify yourself:** each arm's percentages sum to ~100. Compare the dominant channel per arm against `dim_strategy.channel_mix` intent: SMS_First should lean SMS/Manual; FICO_Priority leans FICO. If actuals mirror intent, the program is wired; write the verdict per arm.

**Traps & alternatives:** a global channel mix (no partition) would average arms together and hide mis-wiring completely — stratify first, summarize second. This exact split is also how you'll later show efficacy: same shape, `rpc_flag` instead of channel.

---

## Task 4 — AHT vs the team benchmark

```sql
WITH params AS (
    SELECT DATE '2025-07-01' AS m_start, DATE '2025-08-01' AS m_end
),
agent_aht AS (
    SELECT f.agent_id,
           SUM(f.aht_seconds)::numeric / NULLIF(SUM(f.rpc_flag::int), 0) AS aht_rpc
    FROM fact_interactions f, params p
    WHERE f.interaction_date >= p.m_start AND f.interaction_date < p.m_end
      AND f.rpc_flag
    GROUP BY f.agent_id
    HAVING SUM(f.rpc_flag::int) >= 50          -- activity floor for RANKING only
),
team_bench AS (
    SELECT e.team_name,
           SUM(f.aht_seconds)::numeric / NULLIF(SUM(f.rpc_flag::int), 0) AS bench_aht
    FROM fact_interactions f
    JOIN dim_employees e USING (agent_id), params p
    WHERE f.interaction_date >= p.m_start AND f.interaction_date < p.m_end
      AND f.rpc_flag
    GROUP BY e.team_name
)
SELECT e.team_name,
       e.agent_name,
       ROUND(a.aht_rpc, 0)                     AS agent_aht_rpc,
       ROUND(b.bench_aht, 0)                   AS team_bench,
       ROUND(a.aht_rpc - b.bench_aht, 0)       AS vs_team,
       ROUND(b.bench_aht
             - AVG(a.aht_rpc) OVER (PARTITION BY e.team_name), 0) AS bench_vs_avg_of_avgs
FROM agent_aht a
JOIN dim_employees e USING (agent_id)
JOIN team_bench  b ON b.team_name = e.team_name
ORDER BY vs_team DESC;
```

**Why each part:** two separate aggregations because they answer different questions: agent level ranks people; team level defines the bar. The benchmark uses ALL agents' seconds (no HAVING) so part-timers still count toward reality. `bench_vs_avg_of_avgs` exists purely as evidence: it shows how far the naive mean-of-agent-means drifts from the defensible ratio-of-sums.

**Verify yourself:** pick your team; total its RPC seconds ÷ total RPCs in a calculator — must equal `bench_aht`. Cross-check agent AHTs against `v_handle_time_metrics` for July.

**Traps & alternatives:** putting the HAVING floor on the benchmark CTE would quietly exclude juniors from their own team's baseline. Weighting note for coaching chats: one chatty senior can move avg-of-avgs by seconds while barely moving true AHT.

---

## Task 5 — Broken promises with money already paid

```sql
WITH plan_totals AS (
    SELECT ptp_id,
           SUM(amount_paid)  AS paid_total,
           MAX(payment_date) AS last_payment
    FROM fact_payments
    WHERE ptp_id IS NOT NULL
    GROUP BY ptp_id
)
SELECT pt.ptp_id,
       pt.account_id,
       pt.promised_amount,
       COALESCE(t.paid_total, 0)          AS collected,
       t.last_payment,
       pt.ptp_date                        AS promised_on,
       pt.grace_until_date
FROM fact_ptp_log pt
LEFT JOIN plan_totals t USING (ptp_id)
WHERE pt.status = 'Broken'
  AND COALESCE(t.paid_total, 0) > 0
ORDER BY collected DESC;
```

**Why each part:** LEFT JOIN keeps the full broken universe available (useful for a "salvage rate" denominator later); the `COALESCE(…,0) > 0` filter then selects the salvageables. Ordering by collected puts the biggest recoverable cash at the top of Monday's rework queue.

**Verify yourself:** every row must show `collected < promised_amount` (else it should have been Kept — if you find one, that's an audit finding: check its installment history). Cross-check `paid_amount` for the same plans in `v_promise_timeline` — definitional differences (e.g., whether only pre-grace payments count) go in your notes.

**Traps & alternatives:** INNER JOIN would silently drop zero-payment broken plans from your awareness and make salvage share look rosier. When finance asks "how much money is sitting on broken plans?", this same CTE with no filter answers instantly.

---

## Task 6 — Utilization for July: daily vs month-level

```sql
WITH params AS (
    SELECT DATE '2025-07-01' AS m_start, DATE '2025-08-01' AS m_end
),
july AS (
    SELECT t.agent_id,
           SUM(t.operational_hours)              AS op_hours,
           SUM(t.tht_hours)                      AS tht_hours,
           AVG(t.utilization)                    AS avg_daily_util
    FROM fact_agent_time_log t, params p
    WHERE t.log_date >= p.m_start AND t.log_date < p.m_end
    GROUP BY t.agent_id
)
SELECT e.team_name,
       e.agent_name,
       ROUND(j.op_hours, 1)                                   AS op_hours,
       ROUND(j.tht_hours, 1)                                  AS tht_hours,
       ROUND(100.0 * j.tht_hours / NULLIF(j.op_hours, 0), 1)   AS util_ratio_of_sums_pct,
       ROUND(100.0 * j.avg_daily_util, 1)                     AS util_avg_of_days_pct,
       ROUND(100.0 * j.tht_hours / NULLIF(j.op_hours, 0)
             - 100.0 * j.avg_daily_util, 1)                   AS method_gap
FROM july j
JOIN dim_employees e USING (agent_id)
ORDER BY method_gap DESC;
```

**Why each part:** ratio-of-sums (`Σtht ÷ Σop`) is the defensible month-level number — busy days count more than quiet ones. Averaging daily percentages treats a 2-hour day equal to a 9-hour day. The `method_gap` column makes the error visible instead of hypothetical.

**Verify yourself:** `util_ratio_of_sums_pct` should track `v_productivity_metrics` utilization_pct for July within rounding. Largest positive gaps belong to agents mixing short idle-heavy days with long packed days — spot-check one agent's calendar to feel it.

**Traps & alternatives:** remember stored `utilization` is capped at 0.95; sums inherit that cap, so both methods top out near 95% — don't "fix" values above it by hand. If ops hours are zero on a logged day (training day), NULLIF protects the divide but consider excluding those days deliberately.

---

## Task 7 — Cure rate by product (the aggregation trap)

```sql
WITH product_month AS (
    SELECT a.product_type,
           DATE_TRUNC('month', pay.payment_date)::date        AS mo,
           COUNT(DISTINCT pay.account_id) FILTER (WHERE pay.is_cured) AS cured_accts,
           COUNT(DISTINCT pay.account_id)                             AS paying_accts
    FROM fact_payments pay
    JOIN dim_accounts a USING (account_id)
    WHERE pay.payment_date >= DATE '2025-07-01'
      AND pay.payment_date <  DATE '2026-01-01'
    GROUP BY 1, 2
)
SELECT product_type,
       ROUND(100.0 * SUM(cured_accts)::numeric
             / NULLIF(SUM(paying_accts), 0), 1)                 AS h2_rate_correct,
       ROUND(100.0 * AVG(100.0 * cured_accts
             / NULLIF(paying_accts, 0)), 1)                     AS naive_avg_of_months,
       ROUND(100.0 * SUM(cured_accts)::numeric / NULLIF(SUM(paying_accts), 0)
             - AVG(100.0 * cured_accts / NULLIF(paying_accts, 0)), 1) AS gap
FROM product_month
GROUP BY product_type
ORDER BY gap DESC;
```

**Why each part:** the CTE freezes monthly cells once; the outer query demonstrates both aggregations from identical inputs so the comparison is honest. `COUNT(DISTINCT account_id)` matters because one account can cure, re-enter, and cure again inside H2.

**Verify yourself:** which column matches the number the committee has historically seen? Trace one month where the two methods differ most and explain in one sentence why (month size vs rate).

**Traps & alternatives:** distinct-cure counting vs raw payment counting is a classic double-count source — this project fixed exactly that bug once (see `_reference/kpi_glossary.md` → cure). If someone insists on the naive number, at least label it.

---

## Task 8 — Weekly activity summary per agent

```sql
WITH weekly AS (
    SELECT DATE_TRUNC('week', f.interaction_date)::date AS week_start,
           f.agent_id,
           COUNT(*)                                     AS interactions,
           SUM(f.rpc_flag::int)                         AS rpc_count,
           SUM(f.rpc_flag::int)::numeric
             / NULLIF(SUM(f.calls_connected), 0) * 100  AS rpc_pct,
           ROUND(AVG(f.aht_seconds), 0)                 AS avg_aht,
           COUNT(DISTINCT f.account_id)                 AS accounts_touched
    FROM fact_interactions f
    WHERE f.interaction_date >= DATE '2025-09-01'
      AND f.interaction_date <  DATE '2025-10-01'
    GROUP BY 1, 2
)
SELECT w.week_start,
       e.team_name,
       e.agent_name,
       w.interactions,
       w.rpc_count,
       ROUND(w.rpc_pct, 1) AS rpc_pct,
       w.avg_aht,
       w.accounts_touched
FROM weekly w
JOIN dim_employees e USING (agent_id)
ORDER BY e.team_name, w.week_start, e.agent_name;
```

**Why each part:** `DATE_TRUNC('week')` truncates to Monday under ISO semantics in Postgres. RPC% computed from weekly sums (volume-weighted) — averaging daily percentages here would let a quiet Friday drag a team's number around.

**Verify yourself:** compare September rows against `v_weekly_agent_summary`: agent set should match; small metric differences are expected because the official view defines weeks/averages slightly differently — write down WHAT differs, that reconciliation note is the assignment's real output.

**Traps & alternatives:** `AVG(aht)` here is per-interaction average — fine at this grain, but say so in the header comment; someone WILL assume it's RPC-only handle time like Task 4 taught.
