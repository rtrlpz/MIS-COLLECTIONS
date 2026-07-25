-- ========================================================================
-- eda_agents.sql
-- Purpose: Exploratory Data Analysis on agent performance
-- 1. Distribution analysis: histogram of RPC% across all agents
-- 2. Tenure vs RPC% correlation: do newer agents perform differently?
-- 3. Summary statistics: mean, median, std dev, min, max for key metrics
-- Uses PERCENTILE_CONT() for distribution analysis
-- ========================================================================

-- ========================================================================
-- NOTE: Tenure analysis is NOT POSSIBLE
-- The dim_agents table does NOT have hire_date or tenure columns
-- If tenure analysis is needed, add hire_date column to dim_agents
-- ========================================================================

-- ========================================================================
-- SECTION 1: Summary Statistics for Key Metrics
-- ========================================================================

WITH agent_metrics AS (
    SELECT 
        agent_id,
        agent_name,
        team_name,
        AVG(avg_rpc_pct) AS avg_rpc_pct,
        AVG(avg_ptp_pct) AS avg_ptp_pct,
        AVG(avg_kept_pct) AS avg_kept_pct,
        AVG(avg_cure_rate) AS avg_cure_rate,
        AVG(avg_utilization_pct) AS avg_utilization
    FROM v_monthly_summary
    WHERE granularity = 'agent'
    GROUP BY agent_id, agent_name, team_name
)

SELECT 
    'RPC%' AS metric,
    ROUND(AVG(avg_rpc_pct)::numeric, 2) AS mean,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY avg_rpc_pct)::numeric, 2) AS median,
    ROUND(STDDEV(avg_rpc_pct)::numeric, 2) AS std_dev,
    ROUND(MIN(avg_rpc_pct)::numeric, 2) AS min_val,
    ROUND(MAX(avg_rpc_pct)::numeric, 2) AS max_val
FROM agent_metrics

UNION ALL

SELECT 
    'PTP%',
    ROUND(AVG(avg_ptp_pct)::numeric, 2),
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY avg_ptp_pct)::numeric, 2),
    ROUND(STDDEV(avg_ptp_pct)::numeric, 2),
    ROUND(MIN(avg_ptp_pct)::numeric, 2),
    ROUND(MAX(avg_ptp_pct)::numeric, 2)
FROM agent_metrics

UNION ALL

SELECT 
    'Kept%',
    ROUND(AVG(avg_kept_pct)::numeric, 2),
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY avg_kept_pct)::numeric, 2),
    ROUND(STDDEV(avg_kept_pct)::numeric, 2),
    ROUND(MIN(avg_kept_pct)::numeric, 2),
    ROUND(MAX(avg_kept_pct)::numeric, 2)
FROM agent_metrics

UNION ALL

SELECT 
    'Cure Rate',
    ROUND(AVG(avg_cure_rate)::numeric, 2),
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY avg_cure_rate)::numeric, 2),
    ROUND(STDDEV(avg_cure_rate)::numeric, 2),
    ROUND(MIN(avg_cure_rate)::numeric, 2),
    ROUND(MAX(avg_cure_rate)::numeric, 2)
FROM agent_metrics

UNION ALL

SELECT 
    'Utilization%',
    ROUND(AVG(avg_utilization)::numeric, 2),
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY avg_utilization)::numeric, 2),
    ROUND(STDDEV(avg_utilization)::numeric, 2),
    ROUND(MIN(avg_utilization)::numeric, 2),
    ROUND(MAX(avg_utilization)::numeric, 2)
FROM agent_metrics;

-- ========================================================================
-- SECTION 2: Histogram of RPC% (using NTILE for distribution buckets)
-- ========================================================================

WITH agent_rpc AS (
    SELECT 
        agent_id,
        agent_name,
        team_name,
        AVG(avg_rpc_pct) AS avg_rpc_pct
    FROM v_monthly_summary
    WHERE granularity = 'agent'
    GROUP BY agent_id, agent_name, team_name
),
rpc_buckets AS (
    SELECT 
        agent_id,
        agent_name,
        team_name,
        avg_rpc_pct,
        NTILE(10) OVER (ORDER BY avg_rpc_pct) AS rpc_decile
    FROM agent_rpc
)

SELECT 
    rpc_decile,
    (rpc_decile - 1) * 10 AS bucket_start,
    rpc_decile * 10 AS bucket_end,
    COUNT(*) AS agent_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct_of_agents,
    ROUND(MIN(avg_rpc_pct)::numeric, 2) AS min_rpc_in_bucket,
    ROUND(MAX(avg_rpc_pct)::numeric, 2) AS max_rpc_in_bucket
FROM rpc_buckets
GROUP BY rpc_decile
ORDER BY rpc_decile;

-- ========================================================================
-- SECTION 3: Histogram using WIDTH_BUCKET (more precise buckets)
-- ========================================================================

WITH agent_rpc AS (
    SELECT 
        AVG(avg_rpc_pct) AS avg_rpc_pct
    FROM v_monthly_summary
    WHERE granularity = 'agent'
    GROUP BY agent_id
),
histogram AS (
    SELECT 
        WIDTH_BUCKET(avg_rpc_pct, 0, 100, 10) AS bucket_num,
        COUNT(*) AS agent_count
    FROM agent_rpc
    GROUP BY WIDTH_BUCKET(avg_rpc_pct, 0, 100, 10)
)

SELECT 
    CASE 
        WHEN bucket_num = 0 THEN 'Below 0'
        WHEN bucket_num = 11 THEN 'Above 100'
        ELSE ((bucket_num - 1) * 10)::text || '-' || (bucket_num * 10)
    END AS rpc_bucket,
    agent_count,
    ROUND(agent_count * 100.0 / SUM(agent_count) OVER (), 2) AS pct_of_agents
FROM histogram
ORDER BY bucket_num;

-- ========================================================================
-- SECTION 4: Team-level distribution comparison
-- ========================================================================

WITH team_stats AS (
    SELECT 
        team_name,
        COUNT(DISTINCT agent_id) AS agent_count,
        ROUND(AVG(avg_rpc_pct)::numeric, 2) AS team_avg_rpc,
        ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY avg_rpc_pct)::numeric, 2) AS team_median_rpc,
        ROUND(STDDEV(avg_rpc_pct)::numeric, 2) AS team_stddev_rpc
    FROM v_monthly_summary
    WHERE granularity = 'agent'
    GROUP BY team_name, month_num
)

SELECT 
    team_name,
    agent_count,
    team_avg_rpc,
    team_median_rpc,
    team_stddev_rpc,
    CASE 
        WHEN team_stddev_rpc < 5 THEN 'Very Consistent'
        WHEN team_stddev_rpc < 10 THEN 'Consistent'
        WHEN team_stddev_rpc < 15 THEN 'Variable'
        ELSE 'Highly Variable'
    END AS consistency_rating
FROM team_stats
ORDER BY team_avg_rpc DESC;
