-- ========================================================================
-- agent_scorecard.sql
-- Purpose: Agent scorecards with composite scores, component breakdowns, and performance status
-- Queries v_agent_scorecards view directly
-- ========================================================================

SELECT
    agent_id,
    agent_name,
    team_name,
    month_num,
    month_name,
    composite_score,
    rpc_pct AS rpc_component_score,
    kept_pct AS kept_component_score,
    cure_rate AS cure_component_score,
    utilization_pct AS utilization_component_score,
    inverse_aht_score AS aht_component_score,
    team_rank,
    team_size,
    CASE
        WHEN team_rank <= CEIL(team_size * 0.25) THEN 'Top Performer'
        WHEN team_rank <= CEIL(team_size * 0.75) THEN 'On Track'
        ELSE 'Needs Coaching'
    END AS status
FROM v_agent_scorecards
ORDER BY team_name, team_rank;
