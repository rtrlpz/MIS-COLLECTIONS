-- ========================================================================
-- agent_exception_report.sql
-- Purpose: Flag agents in top 5% and bottom 5% for RPC%, AHT-RPC, PTP Kept%
-- Uses PERCENT_RANK() to identify extreme performers
-- Shows metric value, team average, and deviation from team average
-- ========================================================================

WITH agent_metrics AS (
    SELECT
        agent_id,
        agent_name,
        team_name,
        month_num,
        month_name,
        avg_rpc_pct AS rpc_pct,
        avg_aht_rpc AS aht_rpc,
        avg_kept_pct AS kept_pct
    FROM v_monthly_summary
    WHERE granularity = 'agent'
),
unpivoted AS (
    -- RPC% (higher is better)
    SELECT agent_id, agent_name, team_name, month_num, month_name,
           'RPC%' AS metric_category, rpc_pct AS metric_value
    FROM agent_metrics
    WHERE rpc_pct IS NOT NULL
    UNION ALL
    -- AHT-RPC (lower is better, so we'll rank in reverse)
    SELECT agent_id, agent_name, team_name, month_num, month_name,
           'AHT_RPC' AS metric_category, aht_rpc AS metric_value
    FROM agent_metrics
    WHERE aht_rpc IS NOT NULL
    UNION ALL
    -- PTP Kept% (higher is better)
    SELECT agent_id, agent_name, team_name, month_num, month_name,
           'PTP_Kept%' AS metric_category, kept_pct AS metric_value
    FROM agent_metrics
    WHERE kept_pct IS NOT NULL
),
with_team_avg AS (
    SELECT
        *,
        AVG(metric_value) OVER (PARTITION BY team_name, month_num, metric_category) AS team_average,
        metric_value - AVG(metric_value) OVER (PARTITION BY team_name, month_num, metric_category) AS deviation_from_team_avg
    FROM unpivoted
),
with_percentiles AS (
    SELECT
        *,
        -- For RPC% and PTP Kept% (higher is better): use ascending order
        CASE
            WHEN metric_category IN ('RPC%', 'PTP_Kept%')
            THEN PERCENT_RANK() OVER (PARTITION BY month_num, metric_category ORDER BY metric_value)
            -- For AHT_RPC (lower is better): use descending order
            ELSE PERCENT_RANK() OVER (PARTITION BY month_num, metric_category ORDER BY metric_value DESC)
        END AS pct_rank
    FROM with_team_avg
)
SELECT
    metric_category,
    agent_id,
    agent_name,
    team_name,
    month_num,
    month_name,
    ROUND(metric_value, 2) AS metric_value,
    ROUND(team_average, 2) AS team_average,
    ROUND(deviation_from_team_avg, 2) AS deviation_from_team_avg,
    CASE
        WHEN pct_rank <= 0.05 THEN 'Top 5%'
        WHEN pct_rank >= 0.95 THEN 'Bottom 5%'
    END AS performance_tier
FROM with_percentiles
WHERE pct_rank <= 0.05 OR pct_rank >= 0.95
ORDER BY metric_category, deviation_from_team_avg;
