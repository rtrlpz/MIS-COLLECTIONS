-- ========================================================================
-- campaign_effectiveness.sql
-- Purpose: Contact frequency vs RPC% and time-of-day PTP conversion analysis
-- Section 1: Scatter-plot-ready output (agent_id, calls_per_day, rpc_pct)
-- Section 2: PTP set rate by hour of day - best hours for PTP conversion
-- Uses EXTRACT(HOUR FROM interaction_time) for time-of-day analysis
-- ========================================================================

-- ========================================================================
-- SECTION 1: Scatter Plot Data - Calls per Day vs RPC%
-- Does more calls = better connections, or diminishing returns?
-- ========================================================================

WITH daily_agent_activity AS (
    SELECT 
        fi.agent_id,
        e.agent_name,
        e.team_name,
        e.region,
        fi.interaction_date,
        dc.iso_week,
        dc.month_name,
        COUNT(*) AS interaction_sessions,
        SUM(fi.calls_attempted) AS total_calls,
        SUM(fi.calls_connected) AS connected_calls,
        SUM(CASE WHEN fi.rpc_flag THEN 1 ELSE 0 END) AS rpc_count,
        ROUND(SUM(CASE WHEN fi.rpc_flag THEN 1 ELSE 0 END)::numeric / 
              NULLIF(SUM(fi.calls_connected), 0) * 100, 2) AS rpc_pct
    FROM fact_interactions fi
    JOIN dim_employees e ON fi.agent_id = e.agent_id
    JOIN dim_calendar dc ON fi.interaction_date = dc.date
    GROUP BY fi.agent_id, e.agent_name, e.team_name, e.region, 
             fi.interaction_date, dc.iso_week, dc.month_name
)

SELECT 
    'Scatter Plot Data' AS section,
    agent_id,
    agent_name,
    team_name,
    region,
    interaction_date,
    iso_week,
    month_name,
    total_calls AS calls_per_day,
    rpc_pct,
    interaction_sessions,
    connected_calls
FROM daily_agent_activity
ORDER BY total_calls DESC;

-- ========================================================================
-- SECTION 2: Hourly PTP Conversion Analysis
-- Which hours have highest PTP conversion rates?
-- ========================================================================

WITH hourly_rpc AS (
    SELECT 
        EXTRACT(HOUR FROM fi.interaction_time) AS hour_of_day,
        COUNT(*) AS total_rpc_calls,
        -- Count PTPs made during this hour
        COUNT(DISTINCT pl.ptp_id) AS ptp_count,
        -- Also count kept PTPs for quality metric
        SUM(CASE WHEN pl.status = 'Kept' THEN 1 ELSE 0 END) AS ptp_kept
    FROM fact_interactions fi
    LEFT JOIN fact_ptp_log pl 
        ON fi.agent_id = pl.agent_id 
        AND fi.interaction_date = pl.ptp_date
        AND EXTRACT(HOUR FROM fi.interaction_time) = EXTRACT(HOUR FROM pl.ptp_time)
    WHERE fi.rpc_flag = TRUE
    GROUP BY EXTRACT(HOUR FROM fi.interaction_time)
),
with_rates AS (
    SELECT 
        hour_of_day,
        total_rpc_calls,
        ptp_count,
        ptp_kept,
        ROUND(ptp_count::numeric / NULLIF(total_rpc_calls, 0) * 100, 2) AS ptp_conversion_rate,
        ROUND(ptp_kept::numeric / NULLIF(ptp_count, 0) * 100, 2) AS ptp_kept_rate
    FROM hourly_rpc
)

SELECT 
    'Hourly PTP Conversion' AS section,
    hour_of_day,
    total_rpc_calls,
    ptp_count,
    ptp_kept,
    ptp_conversion_rate,
    ptp_kept_rate,
    CASE 
        WHEN ptp_conversion_rate >= 25 THEN 'High Efficiency'
        WHEN ptp_conversion_rate >= 15 THEN 'Medium Efficiency'
        ELSE 'Low Efficiency'
    END AS effectiveness_tier
FROM with_rates
ORDER BY ptp_conversion_rate DESC;
