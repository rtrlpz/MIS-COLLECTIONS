-- ========================================================================
-- roll_rate_analysis.sql
-- Purpose: DPD migration matrix - track accounts moving between buckets month-over-month
-- Buckets: Current (0 DPD), 1-30, 31-60, 61-90, 90+
-- Shows: for accounts in bucket X in month N, what % moved to each bucket in month N+1?
-- Uses fact_eom_snapshot with LAG() OVER (PARTITION BY account_id ORDER BY snapshot_date)
-- Output: matrix format with from_bucket, to_bucket, count, pct
-- ========================================================================

-- ========================================================================
-- NOTE: Requires consecutive months in fact_eom_snapshot. Full year Jan-Dec
-- 2025 is loaded (12 months), so the migration matrix is meaningful.
-- ========================================================================

WITH with_prev AS (
    SELECT 
        account_id,
        snapshot_date,
        snapshot_month,
        dpd_bucket,
        LAG(dpd_bucket) OVER (PARTITION BY account_id ORDER BY snapshot_date) AS prev_bucket,
        LAG(snapshot_date) OVER (PARTITION BY account_id ORDER BY snapshot_date) AS prev_snapshot_date
    FROM fact_eom_snapshot
),
migration_raw AS (
    SELECT 
        prev_bucket AS from_bucket,
        dpd_bucket AS to_bucket,
        COUNT(*) AS account_count
    FROM with_prev
    WHERE prev_bucket IS NOT NULL  -- Skip first month for each account
    GROUP BY prev_bucket, dpd_bucket
),
with_totals AS (
    SELECT 
        from_bucket,
        to_bucket,
        account_count,
        SUM(account_count) OVER (PARTITION BY from_bucket) AS total_from_bucket
    FROM migration_raw
),
migration_pct AS (
    SELECT 
        from_bucket,
        to_bucket,
        account_count,
        total_from_bucket,
        ROUND(account_count * 100.0 / NULLIF(total_from_bucket, 0), 2) AS pct_of_from_bucket
    FROM with_totals
)

-- Final matrix output
SELECT 
    from_bucket,
    to_bucket,
    account_count,
    total_from_bucket,
    pct_of_from_bucket,
    -- Add visual indicator for roll rate
    CASE 
        WHEN from_bucket = 'Current' AND to_bucket = '1-30' THEN 'Roll Forward'
        WHEN from_bucket = '1-30' AND to_bucket = '31-60' THEN 'Roll Forward'
        WHEN from_bucket = '31-60' AND to_bucket = '61-90' THEN 'Roll Forward'
        WHEN from_bucket = '61-90' AND to_bucket = '90+' THEN 'Roll Forward'
        WHEN from_bucket = '90+' AND to_bucket = '90+' THEN 'Stuck in Deep Mora'
        WHEN to_bucket = 'Current' THEN 'Cured/Current'
        ELSE 'Other Movement'
    END AS movement_type
FROM migration_pct
ORDER BY 
    CASE from_bucket 
        WHEN 'Current' THEN 1
        WHEN '1-30' THEN 2
        WHEN '31-60' THEN 3
        WHEN '61-90' THEN 4
        WHEN '90+' THEN 5
        ELSE 6
    END,
    CASE to_bucket 
        WHEN 'Current' THEN 1
        WHEN '1-30' THEN 2
        WHEN '31-60' THEN 3
        WHEN '61-90' THEN 4
        WHEN '90+' THEN 5
        ELSE 6
    END;

-- ========================================================================
-- SECTION 2: Current snapshot - bucket distribution (always works)
-- ========================================================================

SELECT 
    'Current Snapshot' AS analysis,
    dpd_bucket,
    COUNT(*) AS account_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_portfolio,
    ROUND(SUM(arrears), 2) AS total_arrears,
    ROUND(SUM(arrears) * 100.0 / SUM(SUM(arrears)) OVER (), 2) AS pct_of_arrears
FROM fact_eom_snapshot
WHERE snapshot_month = 'October_2025'
GROUP BY dpd_bucket
ORDER BY 
    CASE dpd_bucket 
        WHEN 'Current' THEN 1
        WHEN '1-30' THEN 2
        WHEN '31-60' THEN 3
        WHEN '61-90' THEN 4
        WHEN '90+' THEN 5
        ELSE 6
    END;

-- ========================================================================
-- SECTION 3: Roll rate summary - average transitions (when multiple months available)
-- ========================================================================

WITH bucket_transitions AS (
    SELECT 
        account_id,
        snapshot_date,
        dpd_bucket,
        LAG(dpd_bucket) OVER (PARTITION BY account_id ORDER BY snapshot_date) AS prev_bucket
    FROM fact_eom_snapshot
),
bucket_ranks AS (
    SELECT
        account_id,
        snapshot_date,
        dpd_bucket,
        prev_bucket,
        CASE dpd_bucket WHEN 'Current' THEN 0 WHEN '1-30' THEN 1 WHEN '31-60' THEN 2 WHEN '61-90' THEN 3 WHEN '90+' THEN 4 ELSE 5 END AS cur_rank,
        CASE prev_bucket WHEN 'Current' THEN 0 WHEN '1-30' THEN 1 WHEN '31-60' THEN 2 WHEN '61-90' THEN 3 WHEN '90+' THEN 4 ELSE 5 END AS prev_rank
    FROM bucket_transitions
)

SELECT 
    'Roll Rate Summary' AS analysis,
    prev_bucket AS from_bucket,
    COUNT(*) AS total_accounts,
    SUM(CASE WHEN dpd_bucket = 'Current' THEN 1 ELSE 0 END) AS moved_to_current,
    SUM(CASE WHEN dpd_bucket = '1-30' THEN 1 ELSE 0 END) AS moved_to_1_30,
    SUM(CASE WHEN dpd_bucket = '31-60' THEN 1 ELSE 0 END) AS moved_to_31_60,
    SUM(CASE WHEN dpd_bucket = '61-90' THEN 1 ELSE 0 END) AS moved_to_61_90,
    SUM(CASE WHEN dpd_bucket = '90+' THEN 1 ELSE 0 END) AS moved_to_90_plus,
    ROUND(SUM(CASE WHEN cur_rank > prev_rank THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS pct_rolled_forward
FROM bucket_ranks
WHERE prev_bucket IS NOT NULL
GROUP BY prev_bucket
ORDER BY 
    CASE prev_bucket 
        WHEN 'Current' THEN 1
        WHEN '1-30' THEN 2
        WHEN '31-60' THEN 3
        WHEN '61-90' THEN 4
        WHEN '90+' THEN 5
        ELSE 6
    END;
