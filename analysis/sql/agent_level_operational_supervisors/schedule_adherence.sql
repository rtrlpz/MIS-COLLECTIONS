-- ========================================================================
-- schedule_adherence.sql
-- Purpose: Hourly activity vs expected schedule analysis
-- Uses fact_interactions to count interactions per hour per agent
-- Compares against expected 8-hour schedule (8:00-12:00, 13:00-17:00)
-- Flags hours with zero activity during expected working hours (weekdays only)
-- Provides summary by agent and detailed gaps view
-- ========================================================================

-- Summary: Agents with most schedule gaps
WITH expected_hours AS (
    -- Expected working hours: 8-11 and 13-16 (8 hours total with 1hr break at 12)
    SELECT 8 AS hour UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11
    UNION ALL SELECT 13 UNION ALL SELECT 14 UNION ALL SELECT 15 UNION ALL SELECT 16
),
agent_active_days AS (
    -- Get distinct agent-day combinations from interactions (weekdays only)
    SELECT DISTINCT 
        fi.agent_id, 
        da.agent_name,
        ds.team_name,
        fi.interaction_date
    FROM fact_interactions fi
    JOIN dim_agents da ON fi.agent_id = da.agent_id
    JOIN dim_supervisors ds ON da.supervisor_id = ds.supervisor_id
    JOIN dim_calendar dc ON fi.interaction_date = dc.date
    WHERE dc.is_weekday = TRUE
),
schedule_grid AS (
    -- CROSS JOIN to get all expected hours for each agent-day
    SELECT 
        ad.agent_id,
        ad.agent_name,
        ad.team_name,
        ad.interaction_date,
        eh.hour AS expected_hour
    FROM agent_active_days ad
    CROSS JOIN expected_hours eh
),
hourly_activity AS (
    -- Count interactions by hour for each agent-day
    SELECT 
        fi.agent_id,
        fi.interaction_date,
        EXTRACT(HOUR FROM fi.interaction_time) AS hour,
        COUNT(*) AS interaction_count
    FROM fact_interactions fi
    GROUP BY fi.agent_id, fi.interaction_date, EXTRACT(HOUR FROM fi.interaction_time)
),
with_adherence AS (
    SELECT 
        sg.agent_id,
        sg.agent_name,
        sg.team_name,
        sg.interaction_date,
        sg.expected_hour,
        COALESCE(ha.interaction_count, 0) AS interactions
    FROM schedule_grid sg
    LEFT JOIN hourly_activity ha 
        ON sg.agent_id = ha.agent_id 
        AND sg.interaction_date = ha.interaction_date 
        AND sg.expected_hour = ha.hour
)

-- SUMMARY: Agents with most gaps
SELECT 
    'Summary - Top Gap Agents' AS report_type,
    agent_name,
    team_name,
    COUNT(*) FILTER (WHERE interactions = 0) AS total_gaps,
    COUNT(*) AS total_expected_hours,
    ROUND(COUNT(*) FILTER (WHERE interactions = 0)::numeric / COUNT(*) * 100, 2) AS pct_gaps
FROM with_adherence
GROUP BY agent_id, agent_name, team_name
HAVING COUNT(*) FILTER (WHERE interactions = 0) > 0
ORDER BY total_gaps DESC
LIMIT 20;

-- DETAIL: Specific gaps (uncomment to see details)
/*
SELECT 
    agent_name,
    interaction_date,
    expected_hour,
    interactions,
    CASE 
        WHEN interactions = 0 THEN 'Gap - No Activity'
        WHEN interactions < 3 THEN 'Low Activity'
        ELSE 'Active'
    END AS adherence_status
FROM with_adherence
WHERE interactions = 0
ORDER BY agent_id, interaction_date, expected_hour;
*/
