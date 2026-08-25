# SQL Advanced — Results (worked solutions)

These solutions are investigation harnesses: they RUN, they DIFF against the official views, and they leave the verdict columns for you to read. No outputs are printed here by design — the reconciliation you write up is the deliverable.

---

## Task 1 — Roll rates: how accounts move between buckets

**Approach:** pair consecutive month-end rows per account with `LAG`, translate bucket keys through the severity dimension twice, classify direction by rank distance.

```sql
WITH snap AS (
    SELECT account_id, snapshot_date, bucket_key,
           LAG(bucket_key)    OVER w AS prev_bucket_key
    FROM fact_eom_snapshot
    WINDOW w AS (PARTITION BY account_id ORDER BY snapshot_date)
),
transitions AS (
    SELECT account_id, bucket_key AS to_bucket, prev_bucket_key AS from_bucket
    FROM snap
    WHERE prev_bucket_key IS NOT NULL          -- first observed month has no predecessor
      AND snapshot_date >= DATE '2025-07-01'   -- transitions INTO H2 months
      AND snapshot_date <  DATE '2026-01-01'
)
SELECT bf.sort_order                                   AS from_rank,
       bf.bucket_label                                 AS from_bucket,
       bt.sort_order                                   AS to_rank,
       bt.bucket_label                                 AS to_bucket,
       COUNT(*)                                        AS accounts,
       CASE WHEN bt.sort_order > bf.sort_order THEN 'worsened'
            WHEN bt.sort_order < bf.sort_order THEN 'improved'
            ELSE 'stable' END                          AS direction
FROM transitions t
JOIN dim_delinquency_bucket bf ON bf.bucket_key = t.from_bucket
JOIN dim_delinquency_bucket bt ON bt.bucket_key = t.to_bucket
GROUP BY 1, 2, 3, 4
ORDER BY 1, 3;

-- Exits: accounts that stop appearing before the book ends
SELECT account_id, MAX(snapshot_date) AS last_seen
FROM fact_eom_snapshot
GROUP BY account_id
HAVING MAX(snapshot_date) < (SELECT MAX(snapshot_date) FROM fact_eom_snapshot);
```

**Why each part:** partitioning by `account_id` is what makes LAG mean "this account's previous month" instead of "someone's previous row". Severity comes from `sort_order`, never label text — alphabetical order would scatter Current between 1-30 and 31-60. The exits query finds charged-off departures deliberately: written-off accounts leave the book and never return.

**Verify yourself:** your matrix should reproduce `v_dpd_migration_matrix` cell counts for overlapping months. Known divergence to investigate and explain: the view additionally reports an Exited destination for accounts whose final month precedes the book end (it admits pre-end finals); plain LAG cannot see a transition that has no second row — reconcile the totals and state which convention answers which question.

**Traps & alternatives:** filtering transitions by `from_date` instead of `to_date` shifts the whole matrix one month and will silently disagree with the view. Self-joining snapshots on account+date works but scans more and breaks when a month is missing — LAG degrades gracefully.

---

## Task 2 — Vintage curves: Mora % by account age

```sql
WITH cohorts AS (
    SELECT account_id,
           DATE_TRUNC('month', open_date)::date AS cohort_month
    FROM dim_accounts
),
snap AS (
    SELECT account_id,
           DATE_TRUNC('month', snapshot_date)::date AS snap_month,
           (status = 'Mora')::int                   AS is_mora
    FROM fact_eom_snapshot
)
SELECT c.cohort_month,
         (EXTRACT(YEAR  FROM s.snap_month) - EXTRACT(YEAR  FROM c.cohort_month)) * 12
       + (EXTRACT(MONTH FROM s.snap_month) - EXTRACT(MONTH FROM c.cohort_month))   AS months_on_book,
       COUNT(*)                                        AS accounts,
       ROUND(100.0 * SUM(s.is_mora) / COUNT(*), 1)     AS mora_pct
FROM cohorts c
JOIN snap s USING (account_id)
WHERE s.snap_month >= DATE '2025-01-01'
GROUP BY 1, 2
ORDER BY 1, 2;
```

**Why each part:** the months-on-book expression is the calendar-safe month difference — no `AGE()` string parsing, no 30-day approximations. Filtering snapshots to 2025 keeps every cohort measured on the same observation window.

**Verify yourself:** pick one cohort and one age; recompute Mora% with a direct two-condition count on the snapshot table. Read the grid diagonally: cells where `months_on_book` is large AND cohort is recent should be empty or thin — that's right-edge censoring, not a data hole; note it before drawing conclusions.

**Traps & alternatives:** comparing cohorts at the same CALENDAR month answers nothing about underwriting quality — the whole point of the age axis. If someone wants "performance since open", that's this table pivoted, not a new metric.

---

## Task 3 — Re-entry: cured accounts coming back

**Approach:** build three-month windows, collapse each account's rows inside a window to three boolean flags with `BOOL_OR`, then classify.

```sql
WITH eom AS (
    SELECT account_id,
           DATE_TRUNC('month', snapshot_date)::date AS mo,
           status
    FROM fact_eom_snapshot
),
months AS (
    SELECT mo, ROW_NUMBER() OVER (ORDER BY mo) AS rn
    FROM (SELECT DISTINCT mo FROM eom) d
),
windows AS (
    SELECT m0.mo AS m0, m1.mo AS m1, m2.mo AS m2
    FROM months m0
    JOIN months m1 ON m1.rn = m0.rn + 1
    JOIN months m2 ON m2.rn = m0.rn + 2
),
flagged AS (
    SELECT w.m0,
           s.account_id,
           BOOL_OR(s.mo = w.m0 AND s.status = 'Mora')   AS was_mora_m0,
           BOOL_OR(s.mo = w.m1 AND s.status = 'Activo') AS activo_m1,
           BOOL_OR(s.mo = w.m2 AND s.status = 'Mora')   AS back_to_mora_m2
    FROM windows w
    JOIN eom  s ON s.mo IN (w.m0, w.m1, w.m2)
    GROUP BY w.m0, s.account_id
)
SELECT m0                                                    AS window_start,
       COUNT(*) FILTER (WHERE was_mora_m0 AND activo_m1)      AS cured_n,
       COUNT(*) FILTER (WHERE was_mora_m0 AND activo_m1
                            AND back_to_mora_m2)              AS reentered_n,
       ROUND(100.0 * COUNT(*) FILTER (WHERE was_mora_m0 AND activo_m1 AND back_to_mora_m2)
             / NULLIF(COUNT(*) FILTER (WHERE was_mora_m0 AND activo_m1), 0), 1) AS reentry_pct
FROM flagged
GROUP BY m0
ORDER BY m0;
```

**Why each part:** `BOOL_OR` collapses up-to-three snapshot rows per account-window into one flag triple — the pattern generalizes to any window definition without joining status sets pairwise. The denominator is cured accounts only; accounts Mora in all three months correctly never enter it.

**Verify yourself:** rates should land in the project's documented 5–25% band for this engine (see `_reference/kpi_glossary.md` → re-entry). A near-zero column means your window join matched nothing — check `IN (w.m0, …)` didn't become an empty set due to date-type mismatch.

**Traps & alternatives:** a two-month window measures "instant bounce" and misses late relapse; three is the project's convention. Don't average the monthly percentages at the end — sum numerators and denominators across windows if leadership wants ONE number.

---

## Task 4 — Audit the agent scorecard from raw tables

**Approach:** read `004_agents_scorecards.sql` first; rebuild the five components at agent-month grain from raw, compute BOTH aggregation variants where the official definition is ambiguous, apply the documented normalization + weights, and diff against the view.

```sql
-- Component rebuild (contacts & AHT shown for both styles; kept/cures/util below)
WITH params AS (
    SELECT DATE '2025-01-01' AS m_start, DATE '2026-01-01' AS m_end
),
days AS (
    SELECT f.agent_id,
           f.interaction_date::date                       AS d,
           SUM(f.rpc_flag::int)                           AS rpcs,
           SUM(f.calls_connected)                         AS conn,
           SUM(f.aht_seconds) FILTER (WHERE f.rpc_flag)   AS aht_rpc_secs
    FROM fact_interactions f, params p
    WHERE f.interaction_date >= p.m_start AND f.interaction_date < p.m_end
    GROUP BY 1, 2
),
agent_month_contacts AS (
    SELECT agent_id,
           EXTRACT(MONTH FROM d)::int                              AS month_num,
           -- variant A: average of daily rates (suspected official style)
           AVG(100.0 * rpcs / NULLIF(conn, 0))                     AS rpc_pct_avg_daily,
           AVG(aht_rpc_secs / NULLIF(rpcs, 0)::numeric)            AS aht_rpc_avg_daily,
           -- variant B: ratio-of-sums over the month
           100.0 * SUM(rpcs) / NULLIF(SUM(conn), 0)                AS rpc_pct_ratio,
           SUM(aht_rpc_secs) / NULLIF(SUM(rpcs), 0)::numeric       AS aht_rpc_ratio
    FROM days
    GROUP BY 1, 2
),
kept AS (   -- per-plan cumulative >=95% rule, plans attributed to making month
    SELECT pt.agent_id,
           EXTRACT(MONTH FROM pt.ptp_date)::int                    AS month_num,
           COUNT(*) FILTER (WHERE pt.status = 'Kept')              AS kept_n,
           COUNT(*) FILTER (WHERE pt.status IN ('Kept','Broken'))  AS evaluated_n
    FROM fact_ptp_log pt
    GROUP BY 1, 2
),
cures AS (
    SELECT pay.agent_id,
           EXTRACT(MONTH FROM pay.payment_date)::int               AS month_num,
           ROUND(100.0 * SUM(pay.amount_paid) FILTER (WHERE pay.is_cured)
                 / NULLIF(SUM(pay.amount_paid), 0), 2)             AS cure_rate_legacy_pct
    FROM fact_payments pay
    WHERE pay.agent_id IS NOT NULL
    GROUP BY 1, 2
),
util AS (
    SELECT t.agent_id,
           EXTRACT(MONTH FROM t.log_date)::int                     AS month_num,
           100.0 * SUM(t.tht_hours) / NULLIF(SUM(t.operational_hours), 0) AS util_pct
    FROM fact_agent_time_log t
    GROUP BY 1, 2
),
rebuilt AS (
    SELECT c.agent_id, c.month_num, k.kept_n, k.evaluated_n,
           u.util_pct, cu.cure_rate_legacy_pct,
           c.rpc_pct_avg_daily, c.rpc_pct_ratio,
           c.aht_rpc_avg_daily,  c.aht_rpc_ratio
    FROM agent_month_contacts c
    LEFT JOIN kept  k USING (agent_id, month_num)
    LEFT JOIN cures cu USING (agent_id, month_num)
    LEFT JOIN util  u USING (agent_id, month_num)
)
SELECT r.*,
       v.rpc_pct          AS view_rpc_pct,
       v.kept_pct         AS view_kept_pct,
       v.composite_score  AS view_composite
FROM rebuilt r
JOIN v_agent_scorecards v ON v.agent_id = r.agent_id AND v.month_num = r.month_num;
```

Then score whichever variant matched best and diff composites:

```sql
-- Wrap `rebuilt` + chosen variant in normalization exactly as 004 does:
--   aht_norm = CASE WHEN aht >= 300 OR aht IS NULL THEN 0 ELSE (300-aht)/300*100 END
--   composite = rpc_norm*0.25 + kept_norm*0.25 + cure_norm*0.20 + util_norm*0.15 + aht_norm*0.15
-- Diff pattern:
--   SELECT ... ROUND(rebuilt_composite - view_composite, 2) AS gap
--   HAVING ABS(gap) > 0.05     -- rounding noise vs definitional mismatch
```

**Why each part:** computing BOTH variants is the audit — whichever matches `view_rpc_pct` reveals how production aggregates, and the other column becomes your documented improvement candidate. Kept uses plan-status counts (the per-plan rule already lives in status); cure uses the legacy honest ratio that 002 documents.

**Verify yourself:** count mismatches per component at |gap| > 0.05. Expected shape: one aggregation style snaps most agents to near-zero gaps while the other drifts systematically — name it in your memo. Missing agent-months usually mean the view's base (`v_monthly_summary`) drops low-activity rows: prove it by listing agents absent from one side only.

**Traps & alternatives:** do NOT import view columns into your component math "temporarily" — that's circular auditing. Keep raw-only upstream, join views only in the final diff.

---

## Task 5 — Reconcile portfolio cure rate (the industry definition)

**Approach:** mirror the view FIRST (payment-flagged cures ÷ prior month-end stock), certify agreement, THEN show the status-flip alternative and quantify how far it drifts — that drift is your governance finding, not a bug hunt failure.

```sql
WITH monthly AS (
    SELECT snapshot_date,
           COUNT(*) FILTER (WHERE status = 'Mora') AS mora_accounts
    FROM fact_eom_snapshot
    GROUP BY snapshot_date
),
stock AS (
    SELECT snapshot_date,
           LAG(mora_accounts) OVER (ORDER BY snapshot_date) AS stock_entering
    FROM monthly
),
view_style AS (   -- matches v_monthend_portfolio: is_cured PAYMENTS in calendar month
    SELECT DATE_TRUNC('month', payment_date)::date AS mo,
           COUNT(DISTINCT account_id)              AS cured_accounts
    FROM fact_payments
    WHERE is_cured
    GROUP BY 1
),
flip_style AS (   -- status-transition definition: Mora -> Activo across consecutive month-ends
    SELECT to_mo AS mo,
           COUNT(*) AS cured_accounts
    FROM (
        SELECT account_id,
               DATE_TRUNC('month', snapshot_date)::date AS to_mo,
               LAG(status) OVER (PARTITION BY account_id ORDER BY snapshot_date) AS prev_status,
               status
        FROM fact_eom_snapshot
    ) x
    WHERE prev_status = 'Mora' AND status = 'Activo'
    GROUP BY 1
)
SELECT m.snapshot_date,
       s.stock_entering,
       COALESCE(vw.cured_accounts, 0)                                        AS cured_view_style,
       ROUND(100.0 * COALESCE(vw.cured_accounts, 0)
             / NULLIF(s.stock_entering, 0), 2)                               AS rebuilt_pct,
       v.portfolio_cure_rate                                                 AS view_pct,
       ROUND(100.0 * COALESCE(vw.cured_accounts, 0) / NULLIF(s.stock_entering, 0), 2)
         - v.portfolio_cure_rate                                             AS gap_vs_view,
       ROUND(100.0 * COALESCE(ff.cured_accounts, 0) / NULLIF(s.stock_entering, 0), 2) AS flip_pct
FROM stock s
LEFT JOIN view_style vw ON vw.mo = DATE_TRUNC('month', s.snapshot_date)::date - INTERVAL '1 month' + INTERVAL '1 month'
LEFT JOIN flip_style ff ON ff.mo = DATE_TRUNC('month', s.snapshot_date)::date
JOIN v_monthend_portfolio v ON v.snapshot_date = s.snapshot_date
ORDER BY s.snapshot_date;
```

Correction note before you run it: align the cure month with the STOCK month exactly as the view does (`cures.snapshot_month = m.snapshot_month`, i.e., same calendar month label). If your first attempt joins the prior month instead, the gap column will scream at you — that IS the reconciliation exercise working.

**Why each part:** the view-style CTE reproduces production semantics from raw tables (payment flags, not status flips); the flip-style CTE is the stricter operational definition many credit teams prefer. Showing both against one denominator makes the definitional gap visible and auditable.

**Verify yourself:** `gap_vs_view` must be ~0 once months are aligned correctly. Then read the `flip_pct` column: where it diverges materially from `rebuilt_pct`, write down WHY (a cure paid in month M can belong to an account whose status flip lands at M+1's month-end — timing, not error). Your certification memo states which definition the bank reports and what the other one would change.

**Traps & alternatives:** counting `is_cured` payments without DISTINCT account_id re-introduces the double-count bug this project fixed historically. Month-label string joins (`FMMonth_YYYY`) work but date-trunc joins survive locale changes.

---

## Task 6 — Post-write-off recovery curve by cohort

```sql
WITH pairs AS (
    SELECT w.writeoff_date,
           r.recovery_date,
           r.amount_recovered,
           (EXTRACT(YEAR  FROM r.recovery_date) - EXTRACT(YEAR  FROM w.writeoff_date)) * 12
         + (EXTRACT(MONTH FROM r.recovery_date) - EXTRACT(MONTH FROM w.writeoff_date)) AS months_since
    FROM fact_writeoffs w
    JOIN fact_recoveries r USING (account_id)
)
SELECT DATE_TRUNC('month', writeoff_date)::date          AS cohort_month,
       months_since,
       ROUND(SUM(amount_recovered)::numeric, 2)          AS recovered_usd,
       ROUND(100.0 * SUM(amount_recovered)
             / SUM(SUM(amount_recovered)) OVER (PARTITION BY DATE_TRUNC('month', writeoff_date)::date), 1) AS pct_of_cohort
FROM pairs
GROUP BY 1, 2
ORDER BY 1, 2;

-- Cumulative share per cohort (running total over month-since):
--   ADD: SUM(SUM(amount_recovered)) OVER (PARTITION BY cohort ORDER BY months_since)
--   divided by the cohort total from the same window frame.
```

**Why each part:** joining recoveries to write-offs by `account_id` inherits whatever grain the recovery table has — multiple partials per account are correct and wanted. The partitioned window gives within-cohort shares; the commented variant turns them into the cumulative curve ops asked for.

**Verify yourself:** every cohort's `pct_of_cohort` should sum to ~100 across its rows. Cross-check one cohort's grand total against `v_writeoff_recovery`'s recovered column for the same month.

**Traps & alternatives:** an account with no recoveries yet contributes nothing here — if you need "recoverable still outstanding", that's `remaining_recoverable` aggregated by cohort, a different (complementary) query. Sparse early cells are real emptiness, not bugs.

---

## Task 7 — Delinquency forecast baseline → capacity planning

```sql
WITH stock AS (
    SELECT snapshot_date,
           COUNT(*) FILTER (WHERE status = 'Mora') AS mora_accounts
    FROM fact_eom_snapshot
    GROUP BY snapshot_date
),
numbered AS (
    SELECT snapshot_date, mora_accounts,
           ROW_NUMBER() OVER (ORDER BY snapshot_date) AS rn
    FROM stock
),
baseline AS (
    SELECT snapshot_date, mora_accounts,
           ROUND(AVG(mora_accounts) OVER (ORDER BY rn
                 ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)) AS ma3_forecast_next
    FROM numbered
)
SELECT snapshot_date,
       mora_accounts,
       ma3_forecast_next
FROM baseline
ORDER BY snapshot_date;

-- Capacity arithmetic (assumptions stated inline so reviewers can attack them):
--   A1 attempts_per_delinquent_account_per_month ≈ 6      (dialer strategy, quoted from config commentary)
--   A2 productive_attempts_per_collector_hour    ≈ 3      (connect-rate reality, per glossary ranges)
--   A3 collector_hours_per_month                 = 8 * 22
-- hours_needed       = projected_mora * A1 / A2
-- fte_equivalent     = hours_needed / A3
```

**Why each part:** trailing-average forecasting is defensible precisely because it claims nothing about causality; every business assumption lives as a named constant in comments, so the debate lands on numbers you chose openly. FTE conversion makes it budget-speak.

**Verify yourself:** recompute one month's moving average by hand from three visible stocks. Sensitivity check the director WILL run: vary A2 ±50% and show the FTE swing — include that table unprompted.

**Traps & alternatives:** seasonality exists in this data (documented G7 wiring); say out loud that December holidays break the naive method and propose a seasonal factor as follow-up work. Never present a projection without its assumption table — that's the governance habit this whole track rehearses.

---

## Task 8 — Report governance audit: same metric, three definitions?

```sql
-- Deliverable 1: inventory of views exposing the contested metrics
SELECT c.table_name AS view_name,
       c.column_name
FROM information_schema.columns c
WHERE c.table_schema = 'public'
  AND c.table_name LIKE 'v\_%'
  AND (c.column_name ILIKE '%rpc_pct%' OR c.column_name ILIKE '%kept_pct%')
ORDER BY 1, 2;

-- Deliverable 2: pairwise discrepancy on a FIXED sample (one agent, all months)
WITH promise_side AS (
    SELECT month_num, agent_id, kept_pct
    FROM v_promise_metrics
    WHERE granularity = 'monthly'
      AND agent_id = 'EID-001'
),
scorecard_side AS (
    SELECT month_num, agent_id, kept_pct
    FROM v_agent_scorecards
    WHERE agent_id = 'EID-001'
)
SELECT COALESCE(p.month_num, s.month_num)                    AS month_num,
       p.kept_pct                                            AS promise_view_kept_pct,
       s.kept_pct                                            AS scorecard_kept_pct,
       ROUND(COALESCE(p.kept_pct,0) - COALESCE(s.kept_pct,0), 2) AS gap
FROM promise_side p
FULL OUTER JOIN scorecard_side s USING (agent_id, month_num)
ORDER BY month_num;
```

**Why each part:** the catalog query is governance's first tool — you cannot standardize what you haven't enumerated. The FULL OUTER JOIN exposes months present in one view but missing from the other: coverage drift is a finding just like value drift.

**Verify yourself:** extend the pattern to `rpc_pct` across `v_contact_metrics` / `v_daily_mis` / `v_agent_scorecards`. Classify every gap: rounding (≤0.05), coverage (NULL side), or definitional (systematic offset). Your memo names a canonical source per metric and lists which views must change or be retired.

**Traps & alternatives:** identical column NAMES prove nothing — definitions can drift while headers match; only output comparison catches it. Resist auditing all 16 views in one pass; two metrics, done rigorously, is the pilot the initiative needs.

---

## Task 9 — Point-in-time team attribution (SCD2)

**Approach:** range-join interactions to the history version valid on each interaction date. Verify July credits RECEIVING teams (should equal current state — transfers applied), then compare JUNE, where history and current-state must disagree for exactly the six movers.

```sql
-- Step 1: point-in-time attribution helper for any month
WITH pit AS (
    SELECT f.agent_id,
           f.interaction_date,
           h.team_name AS team_at_call_time
    FROM fact_interactions f
    JOIN dim_employee_history h
         ON h.agent_id = f.agent_id
        AND f.interaction_date >= h.valid_from
        AND f.interaction_date <= LEAST(h.valid_to, DATE '2025-12-31')
    WHERE f.interaction_date >= DATE '2025-06-01'
      AND f.interaction_date <  DATE '2025-08-01'      -- June + July in one pass
)
SELECT CASE WHEN j.interaction_date < DATE '2025-07-01' THEN 'June' ELSE 'July' END AS month_bucket,
       j.team_at_call_time,
       e.team_name AS team_current_state,
       COUNT(DISTINCT j.agent_id) AS agents,
       COUNT(*)                   AS interactions
FROM pit j
JOIN dim_employees e USING (agent_id)
GROUP BY 1, 2, 3
HAVING j.team_at_call_time <> e.team_name            -- keep only disagreement rows
ORDER BY 1, interactions DESC;

-- Naive baseline to quantify the shift against:
SELECT e.team_name, COUNT(*) AS interactions_june_current_state
FROM fact_interactions f
JOIN dim_employees e USING (agent_id)
WHERE f.interaction_date >= DATE '2025-06-01' AND f.interaction_date < DATE '2025-07-01'
GROUP BY 1 ORDER BY 2 DESC;
```

**Why each part:** the range join `valid_from <= date <= valid_to` IS point-in-time attribution; `LEAST(valid_to, …)` tames the open-ended sentinel row (`9999-12-31`). The HAVING keeps disagreement rows only — in June those are the six pre-transfer agents still credited to their OLD team; in July the same query should return ZERO rows, which is itself the verification that transfers were applied cleanly.

**Verify yourself:** June disagreement set must contain exactly six agents spanning old-team/receiving-team pairs; July must return nothing. Sum interactions across both attribution styles per team-month — totals equal, only labels move.

**Traps & alternatives:** overlapping history windows would double-count interactions — add a per-agent/date version-count check if you ever suspect the history table. Current-state attribution stays correct for "who owns this TODAY"; anything historical needs the range join. State which one your report uses, in its footer.

---

## Where you are now

You can audit production metrics end to end. Keep these nine scripts — they are the seed of your personal QA suite, and the other tracks rebuild them without SQL: [`../../python/basic/tasks.md`](../../python/basic/tasks.md).
