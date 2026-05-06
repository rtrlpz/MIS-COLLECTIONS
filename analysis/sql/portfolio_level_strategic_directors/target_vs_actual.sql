-- ========================================================================
-- target_vs_actual.sql
-- Purpose: Compare KPI actuals vs targets with gap analysis and trend
-- KPI Targets: RPC% >= 65%, PTP% >= 70%, Kept% >= 60%, Cure Rate >= 25%
-- Shows gap (actual - target) and trend (is gap closing or widening?)
-- ========================================================================

WITH targets AS (
    SELECT 
        65.0 AS target_rpc_pct,
        70.0 AS target_ptp_pct,
        60.0 AS target_kept_pct,
        25.0 AS target_cure_rate
),
team_actuals AS (
    SELECT 
        month_num,
        month_name,
        team_name,
        ROUND(AVG(avg_rpc_pct)::numeric, 2) AS actual_rpc_pct,
        ROUND(AVG(avg_ptp_pct)::numeric, 2) AS actual_ptp_pct,
        ROUND(AVG(avg_kept_pct)::numeric, 2) AS actual_kept_pct,
        ROUND(AVG(avg_cure_rate)::numeric, 2) AS actual_cure_rate
    FROM v_monthly_summary 
    WHERE granularity = 'team'
    GROUP BY month_num, month_name, team_name
),
portfolio_actuals AS (
    SELECT 
        month_num,
        month_name,
        ROUND(AVG(avg_rpc_pct)::numeric, 2) AS actual_rpc_pct,
        ROUND(AVG(avg_ptp_pct)::numeric, 2) AS actual_ptp_pct,
        ROUND(AVG(avg_kept_pct)::numeric, 2) AS actual_kept_pct,
        ROUND(AVG(avg_cure_rate)::numeric, 2) AS actual_cure_rate
    FROM v_monthly_summary 
    WHERE granularity = 'portfolio'
    GROUP BY month_num, month_name
),
with_gaps AS (
    SELECT 
        a.*,
        t.*,
        ROUND(actual_rpc_pct - target_rpc_pct, 2) AS rpc_gap,
        ROUND(actual_ptp_pct - target_ptp_pct, 2) AS ptp_gap,
        ROUND(actual_kept_pct - target_kept_pct, 2) AS kept_gap,
        ROUND(actual_cure_rate - target_cure_rate, 2) AS cure_gap,
        LAG(actual_rpc_pct) OVER (PARTITION BY team_name ORDER BY month_num) AS prev_rpc,
        LAG(actual_ptp_pct) OVER (PARTITION BY team_name ORDER BY month_num) AS prev_ptp,
        LAG(actual_kept_pct) OVER (PARTITION BY team_name ORDER BY month_num) AS prev_kept,
        LAG(actual_cure_rate) OVER (PARTITION BY team_name ORDER BY month_num) AS prev_cure
    FROM team_actuals a
    CROSS JOIN targets t
),
combined AS (
    SELECT 
        'Team' AS level,
        team_name,
        month_name,
        month_num,
        actual_rpc_pct,
        target_rpc_pct,
        rpc_gap,
        CASE WHEN rpc_gap >= 0 THEN 'Above Target'
             WHEN rpc_gap >= -5 THEN 'Near Target'
             ELSE 'Below Target'
        END AS rpc_status,
        ROUND(actual_rpc_pct - prev_rpc, 2) AS rpc_mom_change,
        actual_ptp_pct,
        target_ptp_pct,
        ptp_gap,
        CASE WHEN ptp_gap >= 0 THEN 'Above Target'
             WHEN ptp_gap >= -5 THEN 'Near Target'
             ELSE 'Below Target'
        END AS ptp_status,
        ROUND(actual_ptp_pct - prev_ptp, 2) AS ptp_mom_change,
        actual_kept_pct,
        target_kept_pct,
        kept_gap,
        CASE WHEN kept_gap >= 0 THEN 'Above Target'
             WHEN kept_gap >= -5 THEN 'Near Target'
             ELSE 'Below Target'
        END AS kept_status,
        ROUND(actual_kept_pct - prev_kept, 2) AS kept_mom_change,
        actual_cure_rate,
        target_cure_rate,
        cure_gap,
        CASE WHEN cure_gap >= 0 THEN 'Above Target'
             WHEN cure_gap >= -5 THEN 'Near Target'
             ELSE 'Below Target'
        END AS cure_status,
        ROUND(actual_cure_rate - prev_cure, 2) AS cure_mom_change,
        1 AS sort_order
    FROM with_gaps

    UNION ALL

    SELECT 
        'Portfolio' AS level,
        'ALL TEAMS' AS team_name,
        month_name,
        month_num,
        actual_rpc_pct,
        65.0 AS target_rpc_pct,
        ROUND(actual_rpc_pct - 65.0, 2) AS rpc_gap,
        CASE WHEN actual_rpc_pct >= 65.0 THEN 'Above Target' ELSE 'Below Target' END AS rpc_status,
        NULL AS rpc_mom_change,
        actual_ptp_pct,
        70.0 AS target_ptp_pct,
        ROUND(actual_ptp_pct - 70.0, 2) AS ptp_gap,
        CASE WHEN actual_ptp_pct >= 70.0 THEN 'Above Target' ELSE 'Below Target' END AS ptp_status,
        NULL AS ptp_mom_change,
        actual_kept_pct,
        60.0 AS target_kept_pct,
        ROUND(actual_kept_pct - 60.0, 2) AS kept_gap,
        CASE WHEN actual_kept_pct >= 60.0 THEN 'Above Target' ELSE 'Below Target' END AS kept_status,
        NULL AS kept_mom_change,
        actual_cure_rate,
        25.0 AS target_cure_rate,
        ROUND(actual_cure_rate - 25.0, 2) AS cure_gap,
        CASE WHEN actual_cure_rate >= 25.0 THEN 'Above Target' ELSE 'Below Target' END AS cure_status,
        NULL AS cure_mom_change,
        2 AS sort_order
    FROM portfolio_actuals
)

SELECT 
    level,
    team_name,
    month_name,
    actual_rpc_pct,
    target_rpc_pct,
    rpc_gap,
    rpc_status,
    rpc_mom_change,
    actual_ptp_pct,
    target_ptp_pct,
    ptp_gap,
    ptp_status,
    ptp_mom_change,
    actual_kept_pct,
    target_kept_pct,
    kept_gap,
    kept_status,
    kept_mom_change,
    actual_cure_rate,
    target_cure_rate,
    cure_gap,
    cure_status,
    cure_mom_change
FROM combined
ORDER BY 
    sort_order,
    team_name, 
    month_num;
