-- ========================================================================
-- portfolio_health.sql
-- Purpose: Portfolio health metrics - DPD buckets, cure rates by product, arrears trend MoM
-- Uses fact_eom_snapshot for DPD buckets and arrears; fact_payments for cure rates
-- Includes portfolio-level summary rows for each section
-- ========================================================================

-- ========================================================================
-- SECTION 1: % of Accounts per DPD Bucket (1-30, 31-60, 61-90, 90+)
-- ========================================================================
WITH dpd_monthly AS (
    SELECT
        snapshot_month,
        dpd_bucket,
        COUNT(*) AS account_count
    FROM fact_eom_snapshot
    GROUP BY snapshot_month, dpd_bucket
),
dpd_with_total AS (
    SELECT
        snapshot_month,
        dpd_bucket,
        account_count,
        SUM(account_count) OVER (PARTITION BY snapshot_month) AS total_accounts
    FROM dpd_monthly
)
SELECT
    snapshot_month,
    dpd_bucket,
    account_count,
    ROUND(account_count * 100.0 / total_accounts, 2) AS pct_of_portfolio
FROM dpd_with_total

UNION ALL

-- Portfolio-level summary row per month
SELECT
    snapshot_month,
    'TOTAL' AS dpd_bucket,
    SUM(account_count) AS account_count,
    100.0 AS pct_of_portfolio
FROM dpd_with_total
GROUP BY snapshot_month

ORDER BY snapshot_month,
         CASE WHEN dpd_bucket = 'TOTAL' THEN 2 ELSE 1 END,
         dpd_bucket;

-- ========================================================================
-- SECTION 2: Cure Rate by Product (MoM)
-- ========================================================================
WITH product_cures AS (
    SELECT
        dc.month_name,
        dp.product_name,
        COUNT(*) AS total_payments,
        SUM(CASE WHEN fp.is_cured THEN 1 ELSE 0 END) AS cure_count
    FROM fact_payments fp
    JOIN dim_calendar dc ON fp.payment_date = dc.date
    JOIN dim_accounts da ON fp.account_id = da.account_id
    JOIN dim_products dp ON da.product_id = dp.product_id
    GROUP BY dc.month_name, dp.product_name
)
SELECT
    month_name,
    product_name,
    total_payments,
    cure_count,
    ROUND(cure_count * 100.0 / NULLIF(total_payments, 0), 2) AS cure_rate_pct
FROM product_cures

UNION ALL

-- Portfolio-level summary row per month (total across all products)
SELECT
    month_name,
    'TOTAL' AS product_name,
    SUM(total_payments) AS total_payments,
    SUM(cure_count) AS cure_count,
    ROUND(SUM(cure_count) * 100.0 / NULLIF(SUM(total_payments), 0), 2) AS cure_rate_pct
FROM product_cures
GROUP BY month_name

ORDER BY month_name,
         CASE WHEN product_name = 'TOTAL' THEN 2 ELSE 1 END,
         product_name;

-- ========================================================================
-- SECTION 3: Arrears Trend MoM
-- ========================================================================
WITH arrears_monthly AS (
    SELECT
        snapshot_month,
        SUM(arrears) AS total_arrears
    FROM fact_eom_snapshot
    GROUP BY snapshot_month
)
SELECT
    snapshot_month,
    total_arrears,
    LAG(total_arrears) OVER (ORDER BY snapshot_month) AS prev_month_arrears,
    ROUND(total_arrears - LAG(total_arrears) OVER (ORDER BY snapshot_month), 2) AS mom_change,
    ROUND(
        (total_arrears - LAG(total_arrears) OVER (ORDER BY snapshot_month)) * 100.0 /
        NULLIF(LAG(total_arrears) OVER (ORDER BY snapshot_month), 0), 2
    ) AS mom_change_pct
FROM arrears_monthly

UNION ALL

-- Portfolio-level summary row (overall total)
SELECT
    'TOTAL' AS snapshot_month,
    SUM(total_arrears) AS total_arrears,
    NULL AS prev_month_arrears,
    NULL AS mom_change,
    NULL AS mom_change_pct
FROM arrears_monthly

ORDER BY
    CASE WHEN snapshot_month = 'TOTAL' THEN 2 ELSE 1 END,
    snapshot_month;
