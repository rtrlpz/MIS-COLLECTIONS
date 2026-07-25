-- ========================================================================
-- agent_leaderboard.sql
-- Purpose: Top 10 and bottom 10 agents by composite score with MoM trend analysis
-- Uses v_agent_scorecards for composite scores and team ranks
-- Note: Data is monthly; using month-over-month (MoM) instead of weekly
-- LAG() OVER (PARTITION BY agent_id ORDER BY month_num) for trend comparisons
-- ========================================================================

WITH agent_scores AS (
    SELECT
        agent_id,
        agent_name,
        supervisor_id,
        team_name,
        month_num,
        month_name,
        composite_score,
        team_rank,
        -- Overall portfolio rank (across all agents, not just team)
        RANK() OVER (PARTITION BY month_num ORDER BY composite_score DESC) AS overall_rank,
        COUNT(*) OVER (PARTITION BY month_num) AS total_agents_in_month
    FROM v_agent_scorecards
),
scored_with_lag AS (
    SELECT
        *,
        -- Previous month's score and rank using LAG
        LAG(composite_score) OVER (PARTITION BY agent_id ORDER BY month_num) AS prev_composite_score,
        LAG(overall_rank) OVER (PARTITION BY agent_id ORDER BY month_num) AS prev_overall_rank,
        LAG(team_rank) OVER (PARTITION BY agent_id ORDER BY month_num) AS prev_team_rank
    FROM agent_scores
),
with_trends AS (
    SELECT
        agent_id,
        agent_name,
        team_name,
        month_num,
        month_name,
        composite_score,
        overall_rank,
        team_rank,
        -- Score change from previous month
        ROUND(composite_score - COALESCE(prev_composite_score, composite_score), 2) AS score_change,
        -- Rank change from previous month (positive = improved rank = lower number)
        COALESCE(prev_overall_rank, overall_rank) - overall_rank AS overall_rank_change,
        COALESCE(prev_team_rank, team_rank) - team_rank AS team_rank_change,
        -- Flag first month (no previous data)
        CASE WHEN prev_composite_score IS NULL THEN 'First Month' ELSE 'MoM Change' END AS trend_type
    FROM scored_with_lag
),
ranked_for_top_bottom AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY month_num ORDER BY overall_rank) AS rank_seq,
        total_agents_in_month - overall_rank + 1 AS bottom_rank_seq
    FROM with_trends
)
-- TOP 10 AGENTS
SELECT
    'Top 10' AS category,
    month_name,
    overall_rank,
    agent_name,
    team_name,
    composite_score,
    score_change,
    overall_rank_change,
    team_rank,
    team_rank_change
FROM ranked_for_top_bottom
WHERE rank_seq <= 10

UNION ALL

-- BOTTOM 10 AGENTS
SELECT
    'Bottom 10' AS category,
    month_name,
    overall_rank,
    agent_name,
    team_name,
    composite_score,
    score_change,
    overall_rank_change,
    team_rank,
    team_rank_change
FROM ranked_for_top_bottom
WHERE bottom_rank_seq <= 10

ORDER BY 
    month_num, 
    category DESC, 
    overall_rank;
