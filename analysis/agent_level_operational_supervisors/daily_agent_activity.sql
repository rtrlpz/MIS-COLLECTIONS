-- ========================================================================
-- daily_agent_activity.sql
-- Purpose: Per-agent daily activity totals with running totals and 7-day moving averages
-- ========================================================================

WITH interaction_daily AS (
    SELECT
        agent_id,
        interaction_date,
        SUM(calls_attempted) AS calls_attempted,
        SUM(calls_connected) AS calls_connected,
        SUM(CASE WHEN rpc_flag THEN 1 ELSE 0 END) AS rpc_count
    FROM fact_interactions
    GROUP BY agent_id, interaction_date
),
ptp_daily AS (
    SELECT
        agent_id,
        ptp_date AS interaction_date,
        COUNT(*) AS ptp_count
    FROM fact_ptp_log
    GROUP BY agent_id, ptp_date
),
payment_daily AS (
    SELECT
        agent_id,
        payment_date AS interaction_date,
        COUNT(*) AS payment_count
    FROM fact_payments
    WHERE agent_id IS NOT NULL  -- Exclude self-cures (no agent attributed)
    GROUP BY agent_id, payment_date
),
base AS (
    -- Get all unique agent-date combinations across all activity types
    SELECT agent_id, interaction_date FROM interaction_daily
    UNION
    SELECT agent_id, interaction_date FROM ptp_daily
    UNION
    SELECT agent_id, interaction_date FROM payment_daily
),
combined AS (
    SELECT
        b.agent_id,
        b.interaction_date,
        COALESCE(i.calls_attempted, 0) AS calls_attempted,
        COALESCE(i.calls_connected, 0) AS calls_connected,
        COALESCE(i.rpc_count, 0) AS rpc_count,
        COALESCE(p.ptp_count, 0) AS ptp_count,
        COALESCE(pay.payment_count, 0) AS payment_count
    FROM base b
    LEFT JOIN interaction_daily i 
        ON b.agent_id = i.agent_id AND b.interaction_date = i.interaction_date
    LEFT JOIN ptp_daily p 
        ON b.agent_id = p.agent_id AND b.interaction_date = p.interaction_date
    LEFT JOIN payment_daily pay 
        ON b.agent_id = pay.agent_id AND b.interaction_date = pay.interaction_date
)
SELECT
    agent_id,
    interaction_date,
    calls_attempted,
    calls_connected,
    rpc_count,
    ptp_count,
    payment_count,
    -- Running window totals (cumulative sum per agent)
    SUM(calls_attempted) OVER (
        PARTITION BY agent_id 
        ORDER BY interaction_date 
        ROWS UNBOUNDED PRECEDING
    ) AS running_total_calls_attempted,
    SUM(calls_connected) OVER (
        PARTITION BY agent_id 
        ORDER BY interaction_date 
        ROWS UNBOUNDED PRECEDING
    ) AS running_total_calls_connected,
    SUM(rpc_count) OVER (
        PARTITION BY agent_id 
        ORDER BY interaction_date 
        ROWS UNBOUNDED PRECEDING
    ) AS running_total_rpc_count,
    SUM(ptp_count) OVER (
        PARTITION BY agent_id 
        ORDER BY interaction_date 
        ROWS UNBOUNDED PRECEDING
    ) AS running_total_ptp_count,
    SUM(payment_count) OVER (
        PARTITION BY agent_id 
        ORDER BY interaction_date 
        ROWS UNBOUNDED PRECEDING
    ) AS running_total_payment_count,
    -- 7-day moving averages (current + 6 previous rows)
    AVG(rpc_count) OVER (
        PARTITION BY agent_id 
        ORDER BY interaction_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS moving_avg_7d_rpc_count,
    AVG(ptp_count) OVER (
        PARTITION BY agent_id 
        ORDER BY interaction_date 
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS moving_avg_7d_ptp_count
FROM combined
ORDER BY agent_id, interaction_date;
