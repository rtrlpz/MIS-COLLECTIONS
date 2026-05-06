-- ============================================================================
-- 004_agents_scorecards.sql — Agent Scorecard View
-- ============================================================================
-- Purpose: Monthly agent scorecards with composite performance scores
-- Composite score = weighted combination of 5 KPIs, each normalized to 0-100
-- Includes team ranking using RANK() window function
-- ============================================================================

CREATE OR REPLACE VIEW v_agent_scorecards AS
WITH base AS (
    SELECT
        agent_id,
        agent_name,
        supervisor_id,
        team_name,
        month_num,
        month_name,
        avg_rpc_pct,
        avg_kept_pct,
        avg_cure_rate,
        avg_utilization_pct,
        avg_aht_rpc
    FROM v_monthly_summary
    WHERE granularity = 'agent'
),
normalized AS (
    SELECT
        agent_id,
        agent_name,
        supervisor_id,
        team_name,
        month_num,
        month_name,
        -- Normalize each component to 0-100 scale
        -- rpc_pct: already 0-100
        avg_rpc_pct AS rpc_norm,
        -- kept_pct: already 0-100
        avg_kept_pct AS kept_norm,
        -- cure_rate: already 0-100
        avg_cure_rate AS cure_norm,
        -- utilization: already 0-100
        avg_utilization_pct AS util_norm,
        -- inverse_aht: lower AHT is better, normalize using (300 - aht) / 300 * 100
        -- Cap at 0-100 range, assuming 300 seconds (5 min) as max reasonable AHT
        CASE
            WHEN avg_aht_rpc IS NULL THEN 0
            WHEN avg_aht_rpc >= 300 THEN 0
            ELSE ROUND((300 - avg_aht_rpc) / 300 * 100, 2)
        END AS aht_norm
    FROM base
),
scored AS (
    SELECT
        agent_id,
        agent_name,
        supervisor_id,
        team_name,
        month_num,
        month_name,
        rpc_norm,
        kept_norm,
        cure_norm,
        util_norm,
        aht_norm,
        -- Composite score: weighted average of normalized components
        ROUND(
            (rpc_norm * 0.25) +
            (kept_norm * 0.25) +
            (cure_norm * 0.20) +
            (util_norm * 0.15) +
            (aht_norm * 0.15)
        , 2) AS composite_score
    FROM normalized
)
SELECT
    agent_id,
    agent_name,
    supervisor_id,
    team_name,
    month_num,
    month_name,
    rpc_norm AS rpc_pct,
    kept_norm AS kept_pct,
    cure_norm AS cure_rate,
    util_norm AS utilization_pct,
    aht_norm AS inverse_aht_score,
    composite_score,
    RANK() OVER (PARTITION BY supervisor_id, month_num ORDER BY composite_score DESC) AS team_rank,
    COUNT(*) OVER (PARTITION BY supervisor_id, month_num) AS team_size
FROM scored
ORDER BY supervisor_id, month_num, team_rank;
