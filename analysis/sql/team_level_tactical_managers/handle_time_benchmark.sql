-- ========================================================================
-- handle_time_benchmark.sql
-- Purpose: AHT by product, agent, and region with SLA compliance tracking
-- SLA Targets: RPC AHT < 300s, NonRPC AHT < 60s
-- Shows % of calls within SLA per agent and flags agents below threshold
-- ========================================================================

WITH sla_constants AS (
    SELECT 300 AS rpc_aht_target, 60 AS nonrpc_aht_target
),
agent_product_aht AS (
    SELECT 
        fi.agent_id,
        e.agent_name,
        e.team_name,
        e.region,
        dp.product_name,
        dp.product_type,
        COUNT(*) AS total_calls,
        SUM(CASE WHEN fi.rpc_flag THEN 1 ELSE 0 END) AS rpc_calls,
        SUM(CASE WHEN NOT fi.rpc_flag THEN 1 ELSE 0 END) AS nonrpc_calls,
        ROUND(AVG(CASE WHEN fi.rpc_flag THEN fi.aht_seconds END), 2) AS avg_aht_rpc,
        ROUND(AVG(CASE WHEN NOT fi.rpc_flag THEN fi.aht_seconds END), 2) AS avg_aht_nonrpc,
        -- % of RPC calls within SLA (< 300s)
        ROUND(
            SUM(CASE WHEN fi.rpc_flag AND fi.aht_seconds < (SELECT rpc_aht_target FROM sla_constants) THEN 1 ELSE 0 END)::numeric / 
            NULLIF(SUM(CASE WHEN fi.rpc_flag THEN 1 ELSE 0 END), 0) * 100, 2
        ) AS pct_rpc_within_sla,
        -- % of NonRPC calls within SLA (< 60s)
        ROUND(
            SUM(CASE WHEN NOT fi.rpc_flag AND fi.aht_seconds < (SELECT nonrpc_aht_target FROM sla_constants) THEN 1 ELSE 0 END)::numeric / 
            NULLIF(SUM(CASE WHEN NOT fi.rpc_flag THEN 1 ELSE 0 END), 0) * 100, 2
        ) AS pct_nonrpc_within_sla
    FROM fact_interactions fi
    JOIN dim_employees e ON fi.agent_id = e.agent_id
    JOIN dim_accounts acc ON fi.account_id = acc.account_id
    JOIN dim_products dp ON acc.product_id = dp.product_id
    GROUP BY fi.agent_id, e.agent_name, e.team_name, e.region, dp.product_name, dp.product_type
),
agent_summary AS (
    SELECT 
        agent_id,
        agent_name,
        team_name,
        region,
        SUM(total_calls) AS total_calls,
        SUM(rpc_calls) AS total_rpc_calls,
        SUM(nonrpc_calls) AS total_nonrpc_calls,
        ROUND(AVG(avg_aht_rpc), 2) AS overall_avg_aht_rpc,
        ROUND(AVG(avg_aht_nonrpc), 2) AS overall_avg_aht_nonrpc,
        ROUND(AVG(pct_rpc_within_sla), 2) AS overall_pct_rpc_within_sla,
        ROUND(AVG(pct_nonrpc_within_sla), 2) AS overall_pct_nonrpc_within_sla
    FROM agent_product_aht
    GROUP BY agent_id, agent_name, team_name, region
)
SELECT
    agent_name,
    team_name,
    region,
    total_calls,
    total_rpc_calls,
    total_nonrpc_calls,
    overall_avg_aht_rpc,
    overall_avg_aht_nonrpc,
    overall_pct_rpc_within_sla,
    overall_pct_nonrpc_within_sla,
    -- SLA Compliance Flags (80% threshold)
    CASE 
        WHEN overall_pct_rpc_within_sla < 80 THEN 'Below SLA'
        WHEN overall_pct_rpc_within_sla >= 95 THEN 'Excellent'
        ELSE 'Meets SLA'
    END AS rpc_sla_status,
    CASE 
        WHEN overall_pct_nonrpc_within_sla < 80 THEN 'Below SLA'
        WHEN overall_pct_nonrpc_within_sla >= 95 THEN 'Excellent'
        ELSE 'Meets SLA'
    END AS nonrpc_sla_status,
    -- Overall flag
    CASE 
        WHEN overall_pct_rpc_within_sla < 80 OR overall_pct_nonrpc_within_sla < 80 THEN 'Needs Coaching'
        WHEN overall_pct_rpc_within_sla >= 95 AND overall_pct_nonrpc_within_sla >= 95 THEN 'Top Performer'
        ELSE 'On Track'
    END AS overall_status
FROM agent_summary
ORDER BY region, team_name, overall_pct_rpc_within_sla DESC;
