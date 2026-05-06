-- ========================================================================
-- workload_distribution.sql
-- Purpose: Accounts and calls per agent with deviation from team average
-- Uses AVG() OVER (PARTITION BY supervisor_id) for team averages
-- Identifies agents >2 std devs from team mean (overloaded or underloaded)
-- ========================================================================

WITH agent_workload AS (
    SELECT 
        fi.agent_id,
        da.agent_name,
        da.supervisor_id,
        ds.team_name,
        -- Count unique accounts handled
        COUNT(DISTINCT fi.account_id) AS unique_accounts,
        -- Total calls attempted
        SUM(fi.calls_attempted) AS total_calls,
        -- Number of interaction sessions
        COUNT(*) AS interaction_sessions,
        -- Unique accounts per call ratio
        ROUND(COUNT(DISTINCT fi.account_id)::numeric / NULLIF(SUM(fi.calls_attempted), 0), 2) AS accounts_per_call_ratio
    FROM fact_interactions fi
    JOIN dim_agents da ON fi.agent_id = da.agent_id
    JOIN dim_supervisors ds ON da.supervisor_id = ds.supervisor_id
    GROUP BY fi.agent_id, da.agent_name, da.supervisor_id, ds.team_name
),
team_stats AS (
    SELECT 
        *,
        -- Team averages using window functions
        AVG(unique_accounts) OVER (PARTITION BY supervisor_id) AS team_avg_accounts,
        AVG(total_calls) OVER (PARTITION BY supervisor_id) AS team_avg_calls,
        AVG(interaction_sessions) OVER (PARTITION BY supervisor_id) AS team_avg_sessions,
        -- Team standard deviations
        STDDEV(unique_accounts) OVER (PARTITION BY supervisor_id) AS team_std_accounts,
        STDDEV(total_calls) OVER (PARTITION BY supervisor_id) AS team_std_calls,
        STDDEV(interaction_sessions) OVER (PARTITION BY supervisor_id) AS team_std_sessions,
        -- Team size for context
        COUNT(*) OVER (PARTITION BY supervisor_id) AS team_size
    FROM agent_workload
),
with_z_scores AS (
    SELECT
        *,
        -- Z-scores: (value - team_avg) / std_dev
        ROUND((unique_accounts - team_avg_accounts) / NULLIF(team_std_accounts, 0), 2) AS accounts_z_score,
        ROUND((total_calls - team_avg_calls) / NULLIF(team_std_calls, 0), 2) AS calls_z_score,
        ROUND((interaction_sessions - team_avg_sessions) / NULLIF(team_std_sessions, 0), 2) AS sessions_z_score
    FROM team_stats
)
SELECT
    agent_name,
    team_name,
    team_size,
    unique_accounts,
    total_calls,
    interaction_sessions,
    ROUND(team_avg_accounts, 1) AS team_avg_accounts,
    ROUND(team_std_accounts, 1) AS team_std_accounts,
    accounts_z_score,
    ROUND(team_avg_calls, 1) AS team_avg_calls,
    ROUND(team_std_calls, 1) AS team_std_calls,
    calls_z_score,
    accounts_per_call_ratio,
    -- Outlier flags (>2 standard deviations)
    CASE 
        WHEN accounts_z_score > 2 THEN 'Overloaded (>2σ)'
        WHEN accounts_z_score < -2 THEN 'Underloaded (>2σ)'
        WHEN ABS(accounts_z_score) > 1 THEN 'Near Outlier (1-2σ)'
        ELSE 'Normal'
    END AS accounts_workload_status,
    CASE 
        WHEN calls_z_score > 2 THEN 'Overloaded (>2σ)'
        WHEN calls_z_score < -2 THEN 'Underloaded (>2σ)'
        WHEN ABS(calls_z_score) > 1 THEN 'Near Outlier (1-2σ)'
        ELSE 'Normal'
    END AS calls_workload_status
FROM with_z_scores
ORDER BY supervisor_id, accounts_z_score DESC;
