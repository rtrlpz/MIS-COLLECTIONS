-- ========================================================================
-- 002_kpi_views.sql
-- 7 KPI Views for Collections Analytics
-- ========================================================================

-- ========================================================================
-- 1. v_contact_metrics
-- Purpose: Contact KPIs per agent/day, team/day, and month
-- ========================================================================
CREATE OR REPLACE VIEW v_contact_metrics AS
WITH agent_daily AS (
    SELECT
        fi.agent_id,
        da.agent_name,
        da.supervisor_id,
        ds.team_name,
        fi.interaction_date,
        dc.month_num,
        dc.month_name,
        COUNT(*) AS total_calls,
        SUM(fi.calls_connected) AS connected_calls,
        SUM(CASE WHEN fi.rpc_flag THEN 1 ELSE 0 END) AS rpc_count,
        SUM(fi.rpc_arrears) AS rpc_arrears_total
    FROM fact_interactions fi
    JOIN dim_agents da ON fi.agent_id = da.agent_id
    JOIN dim_supervisors ds ON da.supervisor_id = ds.supervisor_id
    JOIN dim_calendar dc ON fi.interaction_date = dc.date
    GROUP BY fi.agent_id, da.agent_name, da.supervisor_id, ds.team_name, fi.interaction_date, dc.month_num, dc.month_name
),
team_daily AS (
    SELECT
        supervisor_id,
        team_name,
        interaction_date,
        month_num,
        month_name,
        SUM(total_calls) AS total_calls,
        SUM(connected_calls) AS connected_calls,
        SUM(rpc_count) AS rpc_count,
        SUM(rpc_arrears_total) AS rpc_arrears_total
    FROM agent_daily
    GROUP BY supervisor_id, team_name, interaction_date, month_num, month_name
),
monthly AS (
    SELECT
        agent_id,
        agent_name,
        supervisor_id,
        team_name,
        month_num,
        month_name,
        SUM(total_calls) AS total_calls,
        SUM(connected_calls) AS connected_calls,
        SUM(rpc_count) AS rpc_count,
        SUM(rpc_arrears_total) AS rpc_arrears_total
    FROM agent_daily
    GROUP BY agent_id, agent_name, supervisor_id, team_name, month_num, month_name
)
SELECT
    'agent' AS granularity,
    agent_id,
    agent_name,
    supervisor_id,
    team_name,
    interaction_date AS date,
    month_num,
    month_name,
    total_calls,
    connected_calls,
    rpc_count,
    CASE
        WHEN connected_calls > 0 THEN ROUND(rpc_count * 100.0 / connected_calls, 2)
        ELSE 0
    END AS rpc_pct,
    ROUND(rpc_arrears_total::numeric, 2) AS rpc_arrears_total,
    CASE
        WHEN operational_hours > 0 THEN ROUND(rpc_count::numeric / operational_hours, 2)
        ELSE 0
    END AS rpc_per_operating_hour
FROM agent_daily ad
LEFT JOIN (
    SELECT agent_id, log_date, SUM(operational_hours) AS operational_hours
    FROM fact_agent_time_log
    GROUP BY agent_id, log_date
) atl ON ad.agent_id = atl.agent_id AND ad.interaction_date = atl.log_date

UNION ALL

SELECT
    'team' AS granularity,
    NULL AS agent_id,
    NULL AS agent_name,
    supervisor_id,
    team_name,
    interaction_date AS date,
    month_num,
    month_name,
    total_calls,
    connected_calls,
    rpc_count,
    CASE
        WHEN connected_calls > 0 THEN ROUND(rpc_count * 100.0 / connected_calls, 2)
        ELSE 0
    END AS rpc_pct,
    ROUND(rpc_arrears_total::numeric, 2) AS rpc_arrears_total,
    NULL AS rpc_per_operating_hour
FROM team_daily

UNION ALL

SELECT
    'monthly' AS granularity,
    agent_id,
    agent_name,
    supervisor_id,
    team_name,
    NULL AS date,
    month_num,
    month_name,
    total_calls,
    connected_calls,
    rpc_count,
    CASE
        WHEN connected_calls > 0 THEN ROUND(rpc_count * 100.0 / connected_calls, 2)
        ELSE 0
    END AS rpc_pct,
    ROUND(rpc_arrears_total::numeric, 2) AS rpc_arrears_total,
    NULL AS rpc_per_operating_hour
FROM monthly;

-- ========================================================================
-- 2. v_promise_metrics
-- Purpose: Promise KPIs per agent/day, team/day, and month
-- ========================================================================
CREATE OR REPLACE VIEW v_promise_metrics AS
WITH agent_daily AS (
    SELECT
        fpl.agent_id,
        da.agent_name,
        da.supervisor_id,
        ds.team_name,
        fpl.ptp_date AS interaction_date,
        dc.month_num,
        dc.month_name,
        COUNT(*) AS ptp_count,
        SUM(CASE WHEN fpl.status = 'Kept' THEN 1 ELSE 0 END) AS kept_count,
        SUM(CASE WHEN fpl.status = 'Broken' THEN 1 ELSE 0 END) AS broken_count,
        SUM(fpl.promised_amount) AS promised_amount_total
    FROM fact_ptp_log fpl
    JOIN dim_agents da ON fpl.agent_id = da.agent_id
    JOIN dim_supervisors ds ON da.supervisor_id = ds.supervisor_id
    JOIN dim_calendar dc ON fpl.ptp_date = dc.date
    GROUP BY fpl.agent_id, da.agent_name, da.supervisor_id, ds.team_name, fpl.ptp_date, dc.month_num, dc.month_name
),
rpc_counts AS (
    SELECT
        agent_id,
        interaction_date,
        COUNT(*) AS rpc_count
    FROM fact_interactions
    WHERE rpc_flag = TRUE
    GROUP BY agent_id, interaction_date
)
SELECT
    ad.agent_id,
    ad.agent_name,
    ad.supervisor_id,
    ad.team_name,
    ad.interaction_date,
    ad.month_num,
    ad.month_name,
    ad.ptp_count,
    CASE
        WHEN rc.rpc_count > 0 THEN ROUND(ad.ptp_count * 100.0 / rc.rpc_count, 2)
        ELSE 0
    END AS ptp_pct,
    ad.kept_count,
    ad.broken_count,
    CASE
        WHEN ad.ptp_count > 0 THEN ROUND(ad.kept_count * 100.0 / ad.ptp_count, 2)
        ELSE 0
    END AS kept_pct,
    CASE
        WHEN ad.ptp_count > 0 THEN ROUND(ad.broken_count * 100.0 / ad.ptp_count, 2)
        ELSE 0
    END AS broken_pct,
    ad.promised_amount_total
FROM agent_daily ad
LEFT JOIN rpc_counts rc ON ad.agent_id = rc.agent_id AND ad.interaction_date = rc.interaction_date;

-- ========================================================================
-- 3. v_recovery_metrics
-- Purpose: Recovery KPIs - cures, cured amounts, agent vs self-cures
-- ========================================================================
CREATE OR REPLACE VIEW v_recovery_metrics AS
SELECT
    fp.payment_date,
    dc.month_num,
    dc.month_name,
    fp.agent_id,
    da.agent_name,
    da.supervisor_id,
    ds.team_name,
    dp.product_id,
    dp.product_name,
    COUNT(*) AS payment_count,
    SUM(CASE WHEN fp.is_cured THEN 1 ELSE 0 END) AS cure_count,
    SUM(CASE WHEN fp.is_cured THEN fp.amount_paid ELSE 0 END) AS cured_amount,
    CASE
        WHEN COUNT(*) > 0 THEN ROUND(SUM(CASE WHEN fp.is_cured THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)
        ELSE 0
    END AS cure_rate,
    SUM(CASE WHEN fp.is_cured AND fp.agent_id IS NOT NULL THEN 1 ELSE 0 END) AS agent_cure_count,
    SUM(CASE WHEN fp.is_cured AND fp.agent_id IS NULL THEN 1 ELSE 0 END) AS self_cure_count
FROM fact_payments fp
JOIN dim_calendar dc ON fp.payment_date = dc.date
JOIN dim_accounts da2 ON fp.account_id = da2.account_id
JOIN dim_products dp ON da2.product_id = dp.product_id
LEFT JOIN dim_agents da ON fp.agent_id = da.agent_id
LEFT JOIN dim_supervisors ds ON da.supervisor_id = ds.supervisor_id
GROUP BY fp.payment_date, dc.month_num, dc.month_name, fp.agent_id, da.agent_name, da.supervisor_id, ds.team_name, dp.product_id, dp.product_name;

-- ========================================================================
-- 4. v_productivity_metrics
-- Purpose: Productivity KPIs - utilization, contacts per hour, no-touch rate
-- ========================================================================
CREATE OR REPLACE VIEW v_productivity_metrics AS
SELECT
    atl.log_date AS date,
    dc.month_num,
    dc.month_name,
    atl.agent_id,
    da.agent_name,
    da.supervisor_id,
    ds.team_name,
    atl.utilization AS utilization_pct,
    CASE
        WHEN atl.operational_hours > 0 THEN ROUND(fi.total_calls::numeric / atl.operational_hours, 2)
        ELSE 0
    END AS contacts_per_agent_hour,
    CASE
        WHEN atl.schedule_hours > 0 THEN ROUND((1 - (atl.utilization / 100)) * 100, 2)
        ELSE 0
    END AS no_touch_letter_rate
FROM fact_agent_time_log atl
JOIN dim_agents da ON atl.agent_id = da.agent_id
JOIN dim_supervisors ds ON da.supervisor_id = ds.supervisor_id
JOIN dim_calendar dc ON atl.log_date = dc.date
LEFT JOIN (
    SELECT agent_id, interaction_date, SUM(calls_attempted) AS total_calls
    FROM fact_interactions
    GROUP BY agent_id, interaction_date
) fi ON atl.agent_id = fi.agent_id AND atl.log_date = fi.interaction_date;

-- ========================================================================
-- 5. v_handle_time_metrics
-- Purpose: AHT and ACW metrics separated by RPC and non-RPC
-- ========================================================================
CREATE OR REPLACE VIEW v_handle_time_metrics AS
SELECT
    fi.interaction_date AS date,
    dc.month_num,
    dc.month_name,
    fi.agent_id,
    da.agent_name,
    da.supervisor_id,
    ds.team_name,
    ROUND(AVG(CASE WHEN fi.rpc_flag THEN fi.aht_seconds ELSE NULL END), 2) AS avg_aht_rpc,
    ROUND(AVG(CASE WHEN NOT fi.rpc_flag THEN fi.aht_seconds ELSE NULL END), 2) AS avg_aht_nonrpc,
    ROUND(AVG(CASE WHEN fi.rpc_flag THEN fi.acw_seconds ELSE NULL END), 2) AS avg_acw_rpc,
    ROUND(AVG(CASE WHEN NOT fi.rpc_flag THEN fi.acw_seconds ELSE NULL END), 2) AS avg_acw_nonrpc
FROM fact_interactions fi
JOIN dim_agents da ON fi.agent_id = da.agent_id
JOIN dim_supervisors ds ON da.supervisor_id = ds.supervisor_id
JOIN dim_calendar dc ON fi.interaction_date = dc.date
GROUP BY fi.interaction_date, dc.month_num, dc.month_name, fi.agent_id, da.agent_name, da.supervisor_id, ds.team_name;

-- ========================================================================
-- 6. v_daily_mis
-- Purpose: Consolidated daily view combining all KPI categories for MIS reporting
-- ========================================================================
CREATE OR REPLACE VIEW v_daily_mis AS
SELECT
    cm.date,
    cm.month_num,
    cm.month_name,
    cm.agent_id,
    cm.agent_name,
    cm.supervisor_id,
    cm.team_name,
    cm.total_calls,
    cm.connected_calls,
    cm.rpc_count,
    cm.rpc_pct,
    cm.rpc_arrears_total,
    pm.ptp_count,
    pm.ptp_pct,
    pm.kept_count,
    pm.broken_count,
    pm.kept_pct,
    rm.cure_count,
    rm.cured_amount,
    rm.cure_rate,
    pr.utilization_pct,
    pr.contacts_per_agent_hour,
    ht.avg_aht_rpc,
    ht.avg_aht_nonrpc,
    ht.avg_acw_rpc,
    ht.avg_acw_nonrpc
FROM v_contact_metrics cm
LEFT JOIN v_promise_metrics pm ON cm.agent_id = pm.agent_id AND cm.date = pm.interaction_date AND cm.granularity = 'agent'
LEFT JOIN v_recovery_metrics rm ON cm.agent_id = rm.agent_id AND cm.date = rm.payment_date AND cm.granularity = 'agent'
LEFT JOIN v_productivity_metrics pr ON cm.agent_id = pr.agent_id AND cm.date = pr.date AND cm.granularity = 'agent'
LEFT JOIN v_handle_time_metrics ht ON cm.agent_id = ht.agent_id AND cm.date = ht.date AND cm.granularity = 'agent'
WHERE cm.granularity = 'agent';

-- ========================================================================
-- 7. v_monthly_summary
-- Purpose: Month-level rollup of all KPIs for dashboard trends
-- ========================================================================
CREATE OR REPLACE VIEW v_monthly_summary AS
SELECT
    cm.month_num,
    cm.month_name,
    cm.agent_id,
    cm.agent_name,
    cm.supervisor_id,
    cm.team_name,
    SUM(cm.total_calls) AS total_calls,
    SUM(cm.connected_calls) AS connected_calls,
    SUM(cm.rpc_count) AS rpc_count,
    ROUND(AVG(cm.rpc_pct), 2) AS avg_rpc_pct,
    SUM(pm.ptp_count) AS ptp_count,
    ROUND(AVG(pm.ptp_pct), 2) AS avg_ptp_pct,
    SUM(pm.kept_count) AS kept_count,
    ROUND(AVG(pm.kept_pct), 2) AS avg_kept_pct,
    SUM(rm.cure_count) AS cure_count,
    ROUND(AVG(rm.cure_rate), 2) AS avg_cure_rate,
    ROUND(AVG(pr.utilization_pct), 2) AS avg_utilization_pct
FROM v_contact_metrics cm
LEFT JOIN v_promise_metrics pm ON cm.agent_id = pm.agent_id AND cm.month_num = pm.month_num AND cm.granularity = 'monthly'
LEFT JOIN v_recovery_metrics rm ON cm.agent_id = rm.agent_id AND cm.month_num = rm.month_num AND cm.granularity = 'monthly'
LEFT JOIN v_productivity_metrics pr ON cm.agent_id = pr.agent_id AND cm.month_num = pr.month_num AND cm.granularity = 'monthly'
WHERE cm.granularity = 'monthly'
GROUP BY cm.month_num, cm.month_name, cm.agent_id, cm.agent_name, cm.supervisor_id, cm.team_name;
