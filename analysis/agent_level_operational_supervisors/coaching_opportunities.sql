-- ========================================================================
-- coaching_opportunities.sql
-- Purpose: Flag agents with week-over-week drops in key metrics
-- RPC% down >5pp, PTP kept% down >10pp, utilization down >10%
-- Uses LAG() to compare current week vs previous week (ISO week)
-- Shows metric, previous value, current value, and change
-- Ordered by magnitude of drop
-- ========================================================================

WITH weekly_metrics AS (
    SELECT 
        cm.agent_id,
        e.agent_name,
        e.team_name,
        dc.iso_week,
        dc.month_num,
        dc.month_name,
        -- Weekly averages for each metric
        ROUND(AVG(cm.rpc_pct), 2) AS weekly_rpc_pct,
        ROUND(AVG(pm.kept_pct), 2) AS weekly_kept_pct,
        ROUND(AVG(pr.utilization_pct), 2) AS weekly_utilization_pct,
        -- Count interaction days for debugging
        COUNT(DISTINCT cm.date) AS days_active
    FROM v_contact_metrics cm
    JOIN v_promise_metrics pm 
        ON cm.agent_id = pm.agent_id 
        AND cm.date = pm.date
    JOIN v_productivity_metrics pr 
        ON cm.agent_id = pr.agent_id 
        AND cm.date = pr.date
    JOIN dim_calendar dc 
        ON cm.date = dc.date
    JOIN dim_employees e 
        ON cm.agent_id = e.agent_id
    WHERE cm.granularity = 'agent'
    GROUP BY cm.agent_id, e.agent_name, e.team_name, dc.iso_week, dc.month_num, dc.month_name
),
with_lag AS (
    SELECT 
        *,
        -- Previous week values using LAG()
        LAG(weekly_rpc_pct) OVER (PARTITION BY agent_id ORDER BY iso_week) AS prev_rpc_pct,
        LAG(weekly_kept_pct) OVER (PARTITION BY agent_id ORDER BY iso_week) AS prev_kept_pct,
        LAG(weekly_utilization_pct) OVER (PARTITION BY agent_id ORDER BY iso_week) AS prev_utilization_pct,
        -- Previous week number for reference
        LAG(iso_week) OVER (PARTITION BY agent_id ORDER BY iso_week) AS prev_iso_week
    FROM weekly_metrics
),
with_drops AS (
    SELECT 
        agent_id,
        agent_name,
        team_name,
        iso_week,
        prev_iso_week,
        month_num,
        month_name,
        weekly_rpc_pct,
        prev_rpc_pct,
        weekly_kept_pct,
        prev_kept_pct,
        weekly_utilization_pct,
        prev_utilization_pct,
        -- Calculate drops (positive = drop from previous week)
        ROUND(COALESCE(prev_rpc_pct, 0) - weekly_rpc_pct, 2) AS rpc_drop,
        ROUND(COALESCE(prev_kept_pct, 0) - weekly_kept_pct, 2) AS kept_drop,
        ROUND(COALESCE(prev_utilization_pct, 0) - weekly_utilization_pct, 2) AS util_drop
    FROM with_lag
    WHERE prev_rpc_pct IS NOT NULL  -- Skip first week for each agent
)

-- RPC% drops >5 percentage points
SELECT 
    agent_name,
    team_name,
    iso_week AS current_week,
    prev_iso_week AS previous_week,
    month_name,
    'RPC%' AS metric,
    prev_rpc_pct AS previous_value,
    weekly_rpc_pct AS current_value,
    rpc_drop AS drop_amount,
    '>5pp drop' AS trigger_reason,
    rpc_drop AS sort_order
FROM with_drops 
WHERE rpc_drop > 5

UNION ALL

-- PTP Kept% drops >10 percentage points
SELECT 
    agent_name,
    team_name,
    iso_week AS current_week,
    prev_iso_week AS previous_week,
    month_name,
    'Kept%' AS metric,
    prev_kept_pct AS previous_value,
    weekly_kept_pct AS current_value,
    kept_drop AS drop_amount,
    '>10pp drop' AS trigger_reason,
    kept_drop AS sort_order
FROM with_drops 
WHERE kept_drop > 10

UNION ALL

-- Utilization% drops >10 percentage points
SELECT 
    agent_name,
    team_name,
    iso_week AS current_week,
    prev_iso_week AS previous_week,
    month_name,
    'Utilization%' AS metric,
    prev_utilization_pct AS previous_value,
    weekly_utilization_pct AS current_value,
    util_drop AS drop_amount,
    '>10pp drop' AS trigger_reason,
    util_drop AS sort_order
FROM with_drops 
WHERE util_drop > 10

ORDER BY sort_order DESC, team_name, agent_name;
