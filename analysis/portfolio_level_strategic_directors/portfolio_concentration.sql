-- ========================================================================
-- portfolio_concentration.sql
-- Purpose: Identify concentration risk by product and region
-- Top 10% of accounts by balance - what % of total arrears do they represent?
-- Geographic/product mix risk: % of portfolio by product type and region
-- Flag if single product or region represents >40% of arrears
-- ========================================================================

-- ========================================================================
-- SECTION 1: Top 10% of accounts by balance vs arrears concentration
-- ========================================================================

WITH account_balances AS (
    SELECT 
        eom.account_id,
        eom.balance,
        eom.arrears,
        eom.dpd_bucket,
        acc.product_id,
        ROW_NUMBER() OVER (ORDER BY eom.balance DESC) AS balance_rank,
        COUNT(*) OVER () AS total_accounts
    FROM fact_eom_snapshot eom
    JOIN dim_accounts acc ON eom.account_id = acc.account_id
    WHERE eom.snapshot_month = 'October_2025'
),
top_10_pct AS (
    SELECT 
        COUNT(*) AS top_10_accounts,
        SUM(arrears) AS top_10_arrears
    FROM account_balances 
    WHERE balance_rank <= CEIL(total_accounts * 0.10)
),
total AS (
    SELECT 
        COUNT(*) AS total_accounts,
        SUM(arrears) AS total_arrears
    FROM account_balances
)
SELECT 
    'Top 10% Balance Concentration' AS analysis,
    top_10_pct.top_10_accounts,
    total.total_accounts,
    ROUND(top_10_pct.top_10_accounts * 100.0 / total.total_accounts, 2) AS pct_of_accounts,
    top_10_pct.top_10_arrears,
    total.total_arrears,
    ROUND(top_10_pct.top_10_arrears * 100.0 / NULLIF(total.total_arrears, 0), 2) AS pct_of_total_arrears
FROM top_10_pct
CROSS JOIN total;

-- ========================================================================
-- SECTION 2: Product concentration risk
-- ========================================================================

WITH product_arrears AS (
    SELECT 
        dp.product_type,
        dp.product_name,
        COUNT(DISTINCT eom.account_id) AS account_count,
        SUM(eom.arrears) AS product_arrears
    FROM fact_eom_snapshot eom
    JOIN dim_accounts acc ON eom.account_id = acc.account_id
    JOIN dim_products dp ON acc.product_id = dp.product_id
    WHERE eom.snapshot_month = 'October_2025'
    GROUP BY dp.product_type, dp.product_name
),
total_arrears AS (
    SELECT SUM(arrears) AS total_portfolio_arrears
    FROM fact_eom_snapshot
    WHERE snapshot_month = 'October_2025'
)
SELECT 
    'Product Concentration' AS analysis,
    product_type,
    product_name,
    account_count,
    product_arrears,
    ROUND(product_arrears * 100.0 / NULLIF(total_portfolio_arrears, 0), 2) AS pct_of_total_arrears,
    CASE 
        WHEN product_arrears * 100.0 / NULLIF(total_portfolio_arrears, 0) > 40 
        THEN 'HIGH CONCENTRATION RISK'
        ELSE 'Normal'
    END AS risk_flag
FROM product_arrears
CROSS JOIN total_arrears
ORDER BY product_arrears DESC;

-- ========================================================================
-- SECTION 3: Geographic (Region) concentration risk
-- NOTE: Schema limitation - fact_eom_snapshot has account_id but NO agent_id
-- To get region, we would need to find the latest agent assignment via fact_interactions
-- This is complex and may be inaccurate. Region analysis skipped.
-- Alternative: Use dim_clients.segment as a proxy for geographic concentration
-- ========================================================================

WITH segment_arrears AS (
    SELECT 
        cl.segment,
        COUNT(DISTINCT eom.account_id) AS account_count,
        SUM(eom.arrears) AS segment_arrears
    FROM fact_eom_snapshot eom
    JOIN dim_accounts acc ON eom.account_id = acc.account_id
    JOIN dim_clients cl ON acc.client_id = cl.client_id
    WHERE eom.snapshot_month = 'October_2025'
    GROUP BY cl.segment
),
total_arrears AS (
    SELECT SUM(arrears) AS total_portfolio_arrears
    FROM fact_eom_snapshot
    WHERE snapshot_month = 'October_2025'
)
SELECT 
    'Segment Concentration (Proxy for Region)' AS analysis,
    segment AS segment_type,
    account_count,
    segment_arrears,
    ROUND(segment_arrears * 100.0 / NULLIF(total_portfolio_arrears, 0), 2) AS pct_of_total_arrears,
    CASE 
        WHEN segment_arrears * 100.0 / NULLIF(total_portfolio_arrears, 0) > 40 
        THEN 'HIGH CONCENTRATION RISK'
        ELSE 'Normal'
    END AS risk_flag
FROM segment_arrears
CROSS JOIN total_arrears
ORDER BY segment_arrears DESC;

-- ========================================================================
-- SECTION 4: Overall concentration summary
-- ========================================================================

WITH concentration_summary AS (
    SELECT 
        dp.product_type,
        COUNT(DISTINCT eom.account_id) AS accounts,
        SUM(eom.arrears) AS arrears
    FROM fact_eom_snapshot eom
    JOIN dim_accounts acc ON eom.account_id = acc.account_id
    JOIN dim_products dp ON acc.product_id = dp.product_id
    WHERE eom.snapshot_month = 'October_2025'
    GROUP BY dp.product_type
),
total AS (
    SELECT SUM(arrears) AS total_arrears FROM fact_eom_snapshot WHERE snapshot_month = 'October_2025'
)
SELECT 
    'Summary' AS analysis,
    COUNT(*) AS product_types,
    SUM(accounts) AS total_accounts,
    SUM(arrears) AS total_arrears,
    MAX(ROUND(arrears * 100.0 / NULLIF((SELECT total_arrears FROM total), 0), 2)) AS max_product_concentration_pct,
    CASE 
        WHEN MAX(arrears * 100.0 / NULLIF((SELECT total_arrears FROM total), 0)) > 40 
        THEN 'PORTFOLIO AT RISK - High Concentration'
        ELSE 'Portfolio Risk Acceptable'
    END AS overall_risk_assessment
FROM concentration_summary;
