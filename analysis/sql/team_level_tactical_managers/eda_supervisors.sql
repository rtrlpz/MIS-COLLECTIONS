-- ========================================================================
-- eda_supervisors.sql
-- Purpose: Supervisor/team-level exploratory analysis and validation
-- 1. Supervisor tenure correlation: does supervisor experience correlate with team performance?
-- 2. Validate existing analysis: compute team-level metrics and compare against expected patterns
-- 3. Agent turnover proxy (if available) vs team performance
-- ========================================================================

-- ========================================================================
-- NOTE: Tenure analysis is NOT POSSIBLE
-- The dim_supervisors table does NOT have hire_date or tenure columns
-- If tenure analysis is needed, add hire_date column to dim_supervisors
-- ========================================================================

-- ========================================================================
-- NOTE: Turnover analysis is NOT POSSIBLE
-- There is no turnover/termination data in the schema
-- Agent IDs are static (no hire/termination dates in dim_agents)
-- ========================================================================

-- ========================================================================
-- SECTION 1: Team Performance Summary & Validation
-- ========================================================================

WITH team_metrics AS (
    SELECT 
        ms.supervisor_id,
        ms.team_name,
        ds.region,
        ROUND(AVG(ms.avg_rpc_pct)::numeric, 2) AS team_avg_rpc_pct,
        ROUND(AVG(ms.avg_ptp_pct)::numeric, 2) AS team_avg_ptp_pct,
        ROUND(AVG(ms.avg_kept_pct)::numeric, 2) AS team_avg_kept_pct,
        ROUND(AVG(ms.avg_cure_rate)::numeric, 2) AS team_avg_cure_rate,
        ROUND(AVG(ms.avg_utilization_pct)::numeric, 2) AS team_avg_utilization,
        SUM(ms.total_calls) AS team_total_calls,
        COUNT(DISTINCT ms.agent_id) AS team_size
    FROM v_monthly_summary ms
    JOIN dim_supervisors ds ON ms.supervisor_id = ds.supervisor_id
    WHERE ms.granularity = 'team'
    GROUP BY ms.supervisor_id, ms.team_name, ds.region, ms.month_num
)

SELECT 
    team_name,
    region,
    team_size,
    team_avg_rpc_pct,
    team_avg_ptp_pct,
    team_avg_kept_pct,
    team_avg_cure_rate,
    team_avg_utilization,
    team_total_calls,
    -- Team ranking within region
    RANK() OVER (PARTITION BY region ORDER BY team_avg_rpc_pct DESC) AS rpc_rank_in_region,
    RANK() OVER (PARTITION BY region ORDER BY team_avg_cure_rate DESC) AS cure_rank_in_region
FROM team_metrics
ORDER BY region, team_avg_rpc_pct DESC;

-- ========================================================================
-- SECTION 2: Team Size vs Performance Correlation
-- Do larger teams perform better or worse?
-- ========================================================================

WITH team_size_perf AS (
    SELECT 
        ms.supervisor_id,
        ms.team_name,
        ds.region,
        COUNT(DISTINCT ms.agent_id) AS team_size,
        ROUND(AVG(ms.avg_rpc_pct)::numeric, 2) AS avg_rpc_pct,
        ROUND(AVG(ms.avg_cure_rate)::numeric, 2) AS avg_cure_rate,
        ROUND(AVG(ms.avg_utilization_pct)::numeric, 2) AS avg_utilization
    FROM v_monthly_summary ms
    JOIN dim_supervisors ds ON ms.supervisor_id = ds.supervisor_id
    WHERE ms.granularity = 'team'
    GROUP BY ms.supervisor_id, ms.team_name, ds.region, ms.month_num
)

SELECT 
    'Team Size vs Performance' AS analysis,
    team_name,
    region,
    team_size,
    avg_rpc_pct,
    avg_cure_rate,
    avg_utilization,
    CASE 
        WHEN team_size <= 8 THEN 'Small'
        WHEN team_size <= 12 THEN 'Medium'
        ELSE 'Large'
    END AS team_size_category
FROM team_size_perf
ORDER BY team_size DESC;

-- ========================================================================
-- SECTION 3: Regional Performance Comparison
-- ========================================================================

WITH regional_metrics AS (
    SELECT 
        ds.region,
        COUNT(DISTINCT ms.supervisor_id) AS num_teams,
        COUNT(DISTINCT ms.agent_id) AS total_agents,
        ROUND(AVG(ms.avg_rpc_pct)::numeric, 2) AS region_avg_rpc_pct,
        ROUND(AVG(ms.avg_ptp_pct)::numeric, 2) AS region_avg_ptp_pct,
        ROUND(AVG(ms.avg_kept_pct)::numeric, 2) AS region_avg_kept_pct,
        ROUND(AVG(ms.avg_cure_rate)::numeric, 2) AS region_avg_cure_rate,
        ROUND(AVG(ms.avg_utilization_pct)::numeric, 2) AS region_avg_utilization,
        SUM(ms.total_calls) AS region_total_calls
    FROM v_monthly_summary ms
    JOIN dim_supervisors ds ON ms.supervisor_id = ds.supervisor_id
    WHERE ms.granularity = 'team'
    GROUP BY ds.region, ms.month_num
)

SELECT 
    region,
    num_teams,
    total_agents,
    region_avg_rpc_pct,
    region_avg_ptp_pct,
    region_avg_kept_pct,
    region_avg_cure_rate,
    region_avg_utilization,
    region_total_calls,
    -- Regional ranking
    RANK() OVER (ORDER BY region_avg_rpc_pct DESC) AS rpc_rank,
    RANK() OVER (ORDER BY region_avg_cure_rate DESC) AS cure_rank
FROM regional_metrics
ORDER BY region_avg_rpc_pct DESC;

-- ========================================================================
-- SECTION 4: Validate Expected Patterns
-- Expected: Higher utilization should correlate with higher RPC/PTP
-- ========================================================================

WITH validation AS (
    SELECT 
        ms.agent_id,
        ms.agent_name,
        ms.team_name,
        ROUND(AVG(ms.avg_utilization_pct)::numeric, 2) AS avg_utilization,
        ROUND(AVG(ms.avg_rpc_pct)::numeric, 2) AS avg_rpc_pct,
        ROUND(AVG(ms.avg_ptp_pct)::numeric, 2) AS avg_ptp_pct,
        ROUND(AVG(ms.avg_cure_rate)::numeric, 2) AS avg_cure_rate
    FROM v_monthly_summary ms
    WHERE ms.granularity = 'agent'
    GROUP BY ms.agent_id, ms.agent_name, ms.team_name, ms.month_num
)

SELECT 
    'Utilization vs Performance' AS analysis,
    team_name,
    COUNT(*) AS agent_count,
    ROUND(AVG(avg_utilization)::numeric, 2) AS team_avg_utilization,
    ROUND(AVG(avg_rpc_pct)::numeric, 2) AS team_avg_rpc,
    ROUND(AVG(avg_cure_rate)::numeric, 2) AS team_avg_cure_rate,
    -- Correlation proxy: Do high-utilization teams have high RPC?
    CASE 
        WHEN AVG(avg_utilization) > 80 AND AVG(avg_rpc_pct) > 70 THEN 'Strong Positive'
        WHEN AVG(avg_utilization) > 80 AND AVG(avg_rpc_pct) < 60 THEN 'Negative (Inefficient)'
        WHEN AVG(avg_utilization) < 70 AND AVG(avg_rpc_pct) > 70 THEN 'Efficient (Low Effort)'
        ELSE 'Normal'
    END AS utilization_rpc_pattern
FROM validation
GROUP BY team_name
ORDER BY team_avg_utilization DESC;

-- ========================================================================
-- SECTION 5: Summary Statistics for Teams
-- ========================================================================

WITH team_stats AS (
    SELECT 
        ms.supervisor_id,
        ms.team_name,
        ROUND(AVG(ms.avg_rpc_pct)::numeric, 2) AS avg_rpc_pct,
        ROUND(AVG(ms.avg_cure_rate)::numeric, 2) AS avg_cure_rate
    FROM v_monthly_summary ms
    WHERE ms.granularity = 'team'
    GROUP BY ms.supervisor_id, ms.team_name, ms.month_num
)

SELECT 
    'Summary Statistics' AS analysis,
    COUNT(DISTINCT team_name) AS total_teams,
    ROUND(AVG(avg_rpc_pct)::numeric, 2) AS portfolio_avg_rpc,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY avg_rpc_pct)::numeric, 2) AS median_rpc,
    ROUND(STDDEV(avg_rpc_pct)::numeric, 2) AS stddev_rpc,
    ROUND(MIN(avg_rpc_pct)::numeric, 2) AS min_rpc,
    ROUND(MAX(avg_rpc_pct)::numeric, 2) AS max_rpc
FROM team_stats;
