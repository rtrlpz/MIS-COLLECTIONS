-- ========================================================================
-- 002_kpi_views.sql
-- 9 KPI Views for Collections Analytics
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
        da.team_name,
        fi.interaction_date,
        dc.month_num,
        dc.month_name,
        SUM(fi.calls_attempted) AS total_calls,
        SUM(fi.calls_connected) AS connected_calls,
        SUM(CASE WHEN fi.rpc_flag THEN 1 ELSE 0 END) AS rpc_count,
        SUM(fi.rpc_arrears) AS rpc_arrears_total,
        COALESCE(SUM(atl.operational_hours), 0) AS operational_hours
    FROM fact_interactions fi
    JOIN dim_employees da ON fi.agent_id = da.agent_id
    JOIN dim_calendar dc ON fi.interaction_date = dc.date
    LEFT JOIN (
        SELECT agent_id, log_date, SUM(operational_hours) AS operational_hours
        FROM fact_agent_time_log
        GROUP BY agent_id, log_date
    ) atl ON fi.agent_id = atl.agent_id AND fi.interaction_date = atl.log_date
    GROUP BY fi.agent_id, da.agent_name, da.supervisor_id, da.team_name, fi.interaction_date, dc.month_num, dc.month_name
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
        SUM(rpc_arrears_total) AS rpc_arrears_total,
        SUM(operational_hours) AS operational_hours
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
        SUM(rpc_arrears_total) AS rpc_arrears_total,
        SUM(operational_hours) AS operational_hours
    FROM agent_daily
    GROUP BY agent_id, agent_name, supervisor_id, team_name, month_num, month_name
)
SELECT
    'agent' AS granularity,
    ad.agent_id,
    ad.agent_name,
    ad.supervisor_id,
    ad.team_name,
    ad.interaction_date AS date,
    ad.month_num,
    ad.month_name,
    ad.total_calls,
    ad.connected_calls,
    ad.rpc_count,
    ROUND(ad.rpc_count * 100.0 / NULLIF(ad.connected_calls, 0), 2) AS rpc_pct,
    ROUND(ad.rpc_arrears_total::numeric, 2) AS rpc_arrears_total,
    CASE
        WHEN ad.operational_hours > 0 THEN ROUND(ad.rpc_count::numeric / ad.operational_hours, 2)
        ELSE 0
    END AS rpc_per_operating_hour
FROM agent_daily ad

UNION ALL

SELECT
    'team' AS granularity,
    NULL AS agent_id,
    NULL AS agent_name,
    td.supervisor_id,
    td.team_name,
    td.interaction_date AS date,
    td.month_num,
    td.month_name,
    td.total_calls,
    td.connected_calls,
    td.rpc_count,
    ROUND(td.rpc_count * 100.0 / NULLIF(td.connected_calls, 0), 2) AS rpc_pct,
    ROUND(td.rpc_arrears_total::numeric, 2) AS rpc_arrears_total,
    CASE
        WHEN td.operational_hours > 0 THEN ROUND(td.rpc_count::numeric / td.operational_hours, 2)
        ELSE 0
    END AS rpc_per_operating_hour
FROM team_daily td

UNION ALL

SELECT
    'monthly' AS granularity,
    md.agent_id,
    md.agent_name,
    md.supervisor_id,
    md.team_name,
    NULL AS date,
    md.month_num,
    md.month_name,
    md.total_calls,
    md.connected_calls,
    md.rpc_count,
    ROUND(md.rpc_count * 100.0 / NULLIF(md.connected_calls, 0), 2) AS rpc_pct,
    ROUND(md.rpc_arrears_total::numeric, 2) AS rpc_arrears_total,
    CASE
        WHEN md.operational_hours > 0 THEN ROUND(md.rpc_count::numeric / md.operational_hours, 2)
        ELSE 0
    END AS rpc_per_operating_hour
FROM monthly md;

-- ========================================================================
-- 2. v_promise_metrics
-- Purpose: Promise KPIs per agent/day, team/day, and month
-- ========================================================================
CREATE OR REPLACE VIEW v_promise_metrics AS
WITH ptp_agent_daily AS (
    SELECT
        fpl.agent_id,
        da.agent_name,
        da.supervisor_id,
        da.team_name,
        fpl.ptp_date AS date,
        dc.month_num,
        dc.month_name,
        COUNT(*) AS ptp_count,
        SUM(CASE WHEN fpl.status = 'Kept' THEN 1 ELSE 0 END) AS kept_count,
        SUM(CASE WHEN fpl.status = 'Broken' THEN 1 ELSE 0 END) AS broken_count,
        SUM(CASE WHEN fpl.status = 'Kept' THEN LEAST(fpl.promised_amount, fpl.rpc_arrears_at_contact) ELSE 0 END) AS capped_kp
    FROM fact_ptp_log fpl
    JOIN dim_employees da ON fpl.agent_id = da.agent_id

    JOIN dim_calendar dc ON fpl.ptp_date = dc.date
    GROUP BY fpl.agent_id, da.agent_name, da.supervisor_id, da.team_name, fpl.ptp_date, dc.month_num, dc.month_name
),
rpc_agent_daily AS (
    SELECT
        agent_id,
        interaction_date,
        COUNT(*) AS rpc_count,
        SUM(rpc_arrears) AS rpc_arrears_total
    FROM fact_interactions
    WHERE rpc_flag = TRUE
    GROUP BY agent_id, interaction_date
),
rpc_team_daily AS (
    SELECT
        da.supervisor_id,
        fi.interaction_date,
        COUNT(*) AS rpc_count,
        SUM(fi.rpc_arrears) AS rpc_arrears_total
    FROM fact_interactions fi
    JOIN dim_employees da ON fi.agent_id = da.agent_id
    WHERE fi.rpc_flag = TRUE
    GROUP BY da.supervisor_id, fi.interaction_date
),
rpc_monthly AS (
    SELECT
        fi.agent_id,
        dc.month_num,
        COUNT(*) AS rpc_count,
        SUM(fi.rpc_arrears) AS rpc_arrears_total
    FROM fact_interactions fi
    JOIN dim_calendar dc ON fi.interaction_date = dc.date
    WHERE fi.rpc_flag = TRUE
    GROUP BY fi.agent_id, dc.month_num
),
ptp_team_daily AS (
    SELECT
        supervisor_id,
        team_name,
        date,
        month_num,
        month_name,
        SUM(ptp_count) AS ptp_count,
        SUM(kept_count) AS kept_count,
        SUM(broken_count) AS broken_count,
        SUM(capped_kp) AS capped_kp
    FROM ptp_agent_daily
    GROUP BY supervisor_id, team_name, date, month_num, month_name
),
ptp_monthly AS (
    SELECT
        agent_id,
        agent_name,
        supervisor_id,
        team_name,
        month_num,
        month_name,
        SUM(ptp_count) AS ptp_count,
        SUM(kept_count) AS kept_count,
        SUM(broken_count) AS broken_count,
        SUM(capped_kp) AS capped_kp
    FROM ptp_agent_daily
    GROUP BY agent_id, agent_name, supervisor_id, team_name, month_num, month_name
)
SELECT
    'agent' AS granularity,
    pad.agent_id,
    pad.agent_name,
    pad.supervisor_id,
    pad.team_name,
    pad.date,
    pad.month_num,
    pad.month_name,
    pad.ptp_count,
    ROUND(pad.ptp_count * 100.0 / NULLIF(rad.rpc_count, 0), 2) AS ptp_pct,
    pad.kept_count,
    pad.broken_count,
    ROUND(pad.kept_count * 100.0 / NULLIF(pad.kept_count + pad.broken_count, 0), 2) AS kept_pct,
    ROUND(
        (pad.kept_count * 100.0 / NULLIF(pad.kept_count + pad.broken_count, 0))
        * pad.ptp_count / NULLIF(rad.rpc_count, 0),
    2) AS bucket_conversion,
    ROUND(pad.capped_kp::numeric, 2) AS capped_kp,
    ROUND(pad.capped_kp::numeric / NULLIF(rad.rpc_arrears_total, 0), 4) AS capped_kp_rpc_arrears
FROM ptp_agent_daily pad
LEFT JOIN rpc_agent_daily rad ON pad.agent_id = rad.agent_id AND pad.date = rad.interaction_date

UNION ALL

SELECT
    'team' AS granularity,
    NULL AS agent_id,
    NULL AS agent_name,
    ptd.supervisor_id,
    ptd.team_name,
    ptd.date,
    ptd.month_num,
    ptd.month_name,
    ptd.ptp_count,
    ROUND(ptd.ptp_count * 100.0 / NULLIF(rtd.rpc_count, 0), 2) AS ptp_pct,
    ptd.kept_count,
    ptd.broken_count,
    ROUND(ptd.kept_count * 100.0 / NULLIF(ptd.kept_count + ptd.broken_count, 0), 2) AS kept_pct,
    ROUND(
        (ptd.kept_count * 100.0 / NULLIF(ptd.kept_count + ptd.broken_count, 0))
        * ptd.ptp_count / NULLIF(rtd.rpc_count, 0),
    2) AS bucket_conversion,
    ROUND(ptd.capped_kp::numeric, 2) AS capped_kp,
    ROUND(ptd.capped_kp::numeric / NULLIF(rtd.rpc_arrears_total, 0), 4) AS capped_kp_rpc_arrears
FROM ptp_team_daily ptd
LEFT JOIN rpc_team_daily rtd ON ptd.supervisor_id = rtd.supervisor_id AND ptd.date = rtd.interaction_date

UNION ALL

SELECT
    'monthly' AS granularity,
    pm.agent_id,
    pm.agent_name,
    pm.supervisor_id,
    pm.team_name,
    NULL AS date,
    pm.month_num,
    pm.month_name,
    pm.ptp_count,
    ROUND(pm.ptp_count * 100.0 / NULLIF(rm.rpc_count, 0), 2) AS ptp_pct,
    pm.kept_count,
    pm.broken_count,
    ROUND(pm.kept_count * 100.0 / NULLIF(pm.kept_count + pm.broken_count, 0), 2) AS kept_pct,
    ROUND(
        (pm.kept_count * 100.0 / NULLIF(pm.kept_count + pm.broken_count, 0))
        * pm.ptp_count / NULLIF(rm.rpc_count, 0),
    2) AS bucket_conversion,
    ROUND(pm.capped_kp::numeric, 2) AS capped_kp,
    ROUND(pm.capped_kp::numeric / NULLIF(rm.rpc_arrears_total, 0), 4) AS capped_kp_rpc_arrears
FROM ptp_monthly pm
LEFT JOIN rpc_monthly rm ON pm.agent_id = rm.agent_id AND pm.month_num = rm.month_num;

-- ========================================================================
-- 3. v_recovery_metrics
-- Purpose: Recovery KPIs - cures, cured amounts, agent vs self cures
-- ========================================================================
CREATE OR REPLACE VIEW v_recovery_metrics AS
WITH agent_daily AS (
    SELECT
        fp.payment_date AS date,
        dc.month_num,
        dc.month_name,
        fp.agent_id,
        da.agent_name,
        da.supervisor_id,
        da.team_name,
        COUNT(*) AS payment_count,
        COUNT(DISTINCT CASE WHEN fp.is_cured THEN fp.account_id ELSE NULL END) AS cure_count,
        SUM(CASE WHEN fp.is_cured THEN fp.amount_paid ELSE 0 END) AS cured_amount,
        COUNT(DISTINCT CASE WHEN fp.is_cured AND fp.agent_id IS NOT NULL THEN fp.account_id ELSE NULL END) AS agent_cure_count,
        COUNT(DISTINCT CASE WHEN fp.is_cured AND fp.agent_id IS NULL THEN fp.account_id ELSE NULL END) AS self_cure_count
    FROM fact_payments fp
    JOIN dim_calendar dc ON fp.payment_date = dc.date
    LEFT JOIN dim_employees da ON fp.agent_id = da.agent_id

    GROUP BY fp.payment_date, dc.month_num, dc.month_name, fp.agent_id, da.agent_name, da.supervisor_id, da.team_name
),
product_daily AS (
    SELECT
        fp.payment_date AS date,
        dc.month_num,
        dc.month_name,
        dp.product_id,
        dp.product_name,
        COUNT(*) AS payment_count,
        COUNT(DISTINCT CASE WHEN fp.is_cured THEN fp.account_id ELSE NULL END) AS cure_count,
        SUM(CASE WHEN fp.is_cured THEN fp.amount_paid ELSE 0 END) AS cured_amount,
        COUNT(DISTINCT CASE WHEN fp.is_cured AND fp.agent_id IS NOT NULL THEN fp.account_id ELSE NULL END) AS agent_cure_count,
        COUNT(DISTINCT CASE WHEN fp.is_cured AND fp.agent_id IS NULL THEN fp.account_id ELSE NULL END) AS self_cure_count
    FROM fact_payments fp
    JOIN dim_calendar dc ON fp.payment_date = dc.date
    JOIN dim_accounts da2 ON fp.account_id = da2.account_id
    JOIN dim_products dp ON da2.product_id = dp.product_id
    GROUP BY fp.payment_date, dc.month_num, dc.month_name, dp.product_id, dp.product_name
),
agent_monthly AS (
    SELECT
        fp.agent_id,
        da.agent_name,
        da.supervisor_id,
        da.team_name,
        dc.month_num,
        dc.month_name,
        COUNT(*) AS payment_count,
        COUNT(DISTINCT CASE WHEN fp.is_cured THEN fp.account_id ELSE NULL END) AS cure_count,
        SUM(CASE WHEN fp.is_cured THEN fp.amount_paid ELSE 0 END) AS cured_amount,
        COUNT(DISTINCT CASE WHEN fp.is_cured AND fp.agent_id IS NOT NULL THEN fp.account_id ELSE NULL END) AS agent_cure_count,
        COUNT(DISTINCT CASE WHEN fp.is_cured AND fp.agent_id IS NULL THEN fp.account_id ELSE NULL END) AS self_cure_count
    FROM fact_payments fp
    JOIN dim_calendar dc ON fp.payment_date = dc.date
    LEFT JOIN dim_employees da ON fp.agent_id = da.agent_id

    GROUP BY fp.agent_id, da.agent_name, da.supervisor_id, da.team_name, dc.month_num, dc.month_name
),
product_monthly AS (
    SELECT
        dp.product_id,
        dp.product_name,
        dc.month_num,
        dc.month_name,
        COUNT(*) AS payment_count,
        COUNT(DISTINCT CASE WHEN fp.is_cured THEN fp.account_id ELSE NULL END) AS cure_count,
        SUM(CASE WHEN fp.is_cured THEN fp.amount_paid ELSE 0 END) AS cured_amount,
        COUNT(DISTINCT CASE WHEN fp.is_cured AND fp.agent_id IS NOT NULL THEN fp.account_id ELSE NULL END) AS agent_cure_count,
        COUNT(DISTINCT CASE WHEN fp.is_cured AND fp.agent_id IS NULL THEN fp.account_id ELSE NULL END) AS self_cure_count
    FROM fact_payments fp
    JOIN dim_calendar dc ON fp.payment_date = dc.date
    JOIN dim_accounts da2 ON fp.account_id = da2.account_id
    JOIN dim_products dp ON da2.product_id = dp.product_id
    GROUP BY dp.product_id, dp.product_name, dc.month_num, dc.month_name
)
SELECT
    'agent' AS granularity,
    ad.date,
    ad.month_num,
    ad.month_name,
    ad.agent_id,
    ad.agent_name,
    ad.supervisor_id,
    ad.team_name,
    NULL AS product_id,
    NULL AS product_name,
    ad.payment_count,
    ad.cure_count,
    ad.cured_amount,
    ROUND(ad.cure_count * 100.0 / NULLIF(ad.payment_count, 0), 2) AS cure_rate,
    ad.agent_cure_count,
    ad.self_cure_count
FROM agent_daily ad

UNION ALL

SELECT
    'product' AS granularity,
    pd.date,
    pd.month_num,
    pd.month_name,
    NULL AS agent_id,
    NULL AS agent_name,
    NULL AS supervisor_id,
    NULL AS team_name,
    pd.product_id,
    pd.product_name,
    pd.payment_count,
    pd.cure_count,
    pd.cured_amount,
    ROUND(pd.cure_count * 100.0 / NULLIF(pd.payment_count, 0), 2) AS cure_rate,
    pd.agent_cure_count,
    pd.self_cure_count
FROM product_daily pd

UNION ALL

SELECT
    'monthly_agent' AS granularity,
    NULL AS date,
    am.month_num,
    am.month_name,
    am.agent_id,
    am.agent_name,
    am.supervisor_id,
    am.team_name,
    NULL AS product_id,
    NULL AS product_name,
    am.payment_count,
    am.cure_count,
    am.cured_amount,
    ROUND(am.cure_count * 100.0 / NULLIF(am.payment_count, 0), 2) AS cure_rate,
    am.agent_cure_count,
    am.self_cure_count
FROM agent_monthly am

UNION ALL

SELECT
    'monthly_product' AS granularity,
    NULL AS date,
    pm.month_num,
    pm.month_name,
    NULL AS agent_id,
    NULL AS agent_name,
    NULL AS supervisor_id,
    NULL AS team_name,
    pm.product_id,
    pm.product_name,
    pm.payment_count,
    pm.cure_count,
    pm.cured_amount,
    ROUND(pm.cure_count * 100.0 / NULLIF(pm.payment_count, 0), 2) AS cure_rate,
    pm.agent_cure_count,
    pm.self_cure_count
FROM product_monthly pm;

-- ========================================================================
-- 4. v_productivity_metrics
-- Purpose: Productivity KPIs - utilization, contacts per hour
-- ========================================================================
CREATE OR REPLACE VIEW v_productivity_metrics AS
WITH agent_daily AS (
    SELECT
        atl.log_date AS date,
        dc.month_num,
        dc.month_name,
        atl.agent_id,
        da.agent_name,
        da.supervisor_id,
        da.team_name,
        atl.utilization AS utilization_pct,
        atl.operational_hours,
        atl.tht_hours,
        atl.schedule_hours,
        COALESCE(fi.total_calls, 0) AS total_calls
    FROM fact_agent_time_log atl
    JOIN dim_employees da ON atl.agent_id = da.agent_id

    JOIN dim_calendar dc ON atl.log_date = dc.date
    LEFT JOIN (
        SELECT agent_id, interaction_date, SUM(calls_attempted) AS total_calls
        FROM fact_interactions
        GROUP BY agent_id, interaction_date
    ) fi ON atl.agent_id = fi.agent_id AND atl.log_date = fi.interaction_date
),
team_daily AS (
    -- C3: weighted utilization = total handle time / total operating time
    -- (never AVG of daily ratios — biased when days differ in length/load)
    SELECT
        supervisor_id,
        team_name,
        date,
        month_num,
        month_name,
        CASE WHEN SUM(operational_hours) > 0
             THEN SUM(tht_hours) / SUM(operational_hours)
             ELSE 0 END AS utilization_pct,
        SUM(operational_hours) AS operational_hours,
        SUM(tht_hours) AS tht_hours,
        SUM(schedule_hours) AS schedule_hours,
        SUM(total_calls) AS total_calls
    FROM agent_daily
    GROUP BY supervisor_id, team_name, date, month_num, month_name
),
monthly AS (
    SELECT
        agent_id,
        agent_name,
        supervisor_id,
        team_name,
        month_num,
        month_name,
        CASE WHEN SUM(operational_hours) > 0
             THEN SUM(tht_hours) / SUM(operational_hours)
             ELSE 0 END AS utilization_pct,
        SUM(operational_hours) AS operational_hours,
        SUM(tht_hours) AS tht_hours,
        SUM(schedule_hours) AS schedule_hours,
        SUM(total_calls) AS total_calls
    FROM agent_daily
    GROUP BY agent_id, agent_name, supervisor_id, team_name, month_num, month_name
)
SELECT
    'agent' AS granularity,
    date,
    month_num,
    month_name,
    agent_id,
    agent_name,
    supervisor_id,
    team_name,
    ROUND(utilization_pct, 2) AS utilization_pct,
    CASE
        WHEN operational_hours > 0 THEN ROUND(total_calls::numeric / operational_hours, 2)
        ELSE 0
    END AS contacts_per_agent_hour,
    operational_hours,
    tht_hours
FROM agent_daily

UNION ALL

SELECT
    'team' AS granularity,
    date,
    month_num,
    month_name,
    NULL AS agent_id,
    NULL AS agent_name,
    supervisor_id,
    team_name,
    ROUND(utilization_pct, 2) AS utilization_pct,
    CASE
        WHEN operational_hours > 0 THEN ROUND(total_calls::numeric / operational_hours, 2)
        ELSE 0
    END AS contacts_per_agent_hour,
    operational_hours,
    tht_hours
FROM team_daily

UNION ALL

SELECT
    'monthly' AS granularity,
    NULL AS date,
    month_num,
    month_name,
    agent_id,
    agent_name,
    supervisor_id,
    team_name,
    ROUND(utilization_pct, 2) AS utilization_pct,
    CASE
        WHEN operational_hours > 0 THEN ROUND(total_calls::numeric / operational_hours, 2)
        ELSE 0
    END AS contacts_per_agent_hour,
    operational_hours,
    tht_hours
FROM monthly;

-- ========================================================================
-- 5. v_handle_time_metrics
-- Purpose: AHT and ACW metrics separated by RPC and non-RPC
-- ========================================================================
CREATE OR REPLACE VIEW v_handle_time_metrics AS
WITH agent_daily AS (
    SELECT
        fi.interaction_date AS date,
        dc.month_num,
        dc.month_name,
        fi.agent_id,
        da.agent_name,
        da.supervisor_id,
        da.team_name,
        -- C3: raw numerator/denominator parts — rollups must SUM these and
        -- divide, never average the daily means.
        SUM(CASE WHEN fi.rpc_flag   THEN fi.aht_seconds ELSE 0 END) AS aht_rpc_secs,
        COUNT(CASE WHEN fi.rpc_flag THEN 1 ELSE NULL END)           AS aht_rpc_n,
        SUM(CASE WHEN NOT fi.rpc_flag THEN fi.aht_seconds ELSE 0 END) AS aht_nrpc_secs,
        COUNT(CASE WHEN NOT fi.rpc_flag THEN 1 ELSE NULL END)         AS aht_nrpc_n,
        SUM(CASE WHEN fi.rpc_flag   THEN fi.acw_seconds ELSE 0 END) AS acw_rpc_secs,
        COUNT(CASE WHEN fi.rpc_flag THEN 1 ELSE NULL END)           AS acw_rpc_n,
        SUM(CASE WHEN NOT fi.rpc_flag THEN fi.acw_seconds ELSE 0 END) AS acw_nrpc_secs,
        COUNT(CASE WHEN NOT fi.rpc_flag THEN 1 ELSE NULL END)         AS acw_nrpc_n
    FROM fact_interactions fi
    JOIN dim_employees da ON fi.agent_id = da.agent_id

    JOIN dim_calendar dc ON fi.interaction_date = dc.date
    GROUP BY fi.interaction_date, dc.month_num, dc.month_name, fi.agent_id, da.agent_name, da.supervisor_id, da.team_name
),
team_daily AS (
    SELECT
        interaction_date AS date,
        dc.month_num,
        dc.month_name,
        da.supervisor_id,
        da.team_name,
        SUM(CASE WHEN fi.rpc_flag   THEN fi.aht_seconds ELSE 0 END) AS aht_rpc_secs,
        COUNT(CASE WHEN fi.rpc_flag THEN 1 ELSE NULL END)           AS aht_rpc_n,
        SUM(CASE WHEN NOT fi.rpc_flag THEN fi.aht_seconds ELSE 0 END) AS aht_nrpc_secs,
        COUNT(CASE WHEN NOT fi.rpc_flag THEN 1 ELSE NULL END)         AS aht_nrpc_n,
        SUM(CASE WHEN fi.rpc_flag   THEN fi.acw_seconds ELSE 0 END) AS acw_rpc_secs,
        COUNT(CASE WHEN fi.rpc_flag THEN 1 ELSE NULL END)           AS acw_rpc_n,
        SUM(CASE WHEN NOT fi.rpc_flag THEN fi.acw_seconds ELSE 0 END) AS acw_nrpc_secs,
        COUNT(CASE WHEN NOT fi.rpc_flag THEN 1 ELSE NULL END)         AS acw_nrpc_n
    FROM fact_interactions fi
    JOIN dim_employees da ON fi.agent_id = da.agent_id

    JOIN dim_calendar dc ON fi.interaction_date = dc.date
    GROUP BY fi.interaction_date, dc.month_num, dc.month_name, da.supervisor_id, da.team_name
),
monthly AS (
    SELECT
        dc.month_num,
        dc.month_name,
        fi.agent_id,
        da.agent_name,
        da.supervisor_id,
        da.team_name,
        SUM(CASE WHEN fi.rpc_flag   THEN fi.aht_seconds ELSE 0 END) AS aht_rpc_secs,
        COUNT(CASE WHEN fi.rpc_flag THEN 1 ELSE NULL END)           AS aht_rpc_n,
        SUM(CASE WHEN NOT fi.rpc_flag THEN fi.aht_seconds ELSE 0 END) AS aht_nrpc_secs,
        COUNT(CASE WHEN NOT fi.rpc_flag THEN 1 ELSE NULL END)         AS aht_nrpc_n,
        SUM(CASE WHEN fi.rpc_flag   THEN fi.acw_seconds ELSE 0 END) AS acw_rpc_secs,
        COUNT(CASE WHEN fi.rpc_flag THEN 1 ELSE NULL END)           AS acw_rpc_n,
        SUM(CASE WHEN NOT fi.rpc_flag THEN fi.acw_seconds ELSE 0 END) AS acw_nrpc_secs,
        COUNT(CASE WHEN NOT fi.rpc_flag THEN 1 ELSE NULL END)         AS acw_nrpc_n
    FROM fact_interactions fi
    JOIN dim_employees da ON fi.agent_id = da.agent_id

    JOIN dim_calendar dc ON fi.interaction_date = dc.date
    GROUP BY dc.month_num, dc.month_name, fi.agent_id, da.agent_name, da.supervisor_id, da.team_name
)
SELECT 'agent' AS granularity, date, month_num, month_name, agent_id, agent_name, supervisor_id, team_name,
       ROUND(aht_rpc_secs::numeric / NULLIF(aht_rpc_n, 0), 2)   AS avg_aht_rpc,
       ROUND(aht_nrpc_secs::numeric / NULLIF(aht_nrpc_n, 0), 2) AS avg_aht_nonrpc,
       ROUND(acw_rpc_secs::numeric / NULLIF(acw_rpc_n, 0), 2)   AS avg_acw_rpc,
       ROUND(acw_nrpc_secs::numeric / NULLIF(acw_nrpc_n, 0), 2) AS avg_acw_nonrpc,
       aht_rpc_secs, aht_rpc_n, aht_nrpc_secs, aht_nrpc_n,
       acw_rpc_secs, acw_rpc_n, acw_nrpc_secs, acw_nrpc_n
FROM agent_daily

UNION ALL

SELECT 'team' AS granularity, date, month_num, month_name, NULL AS agent_id, NULL AS agent_name, supervisor_id, team_name,
       ROUND(aht_rpc_secs::numeric / NULLIF(aht_rpc_n, 0), 2)   AS avg_aht_rpc,
       ROUND(aht_nrpc_secs::numeric / NULLIF(aht_nrpc_n, 0), 2) AS avg_aht_nonrpc,
       ROUND(acw_rpc_secs::numeric / NULLIF(acw_rpc_n, 0), 2)   AS avg_acw_rpc,
       ROUND(acw_nrpc_secs::numeric / NULLIF(acw_nrpc_n, 0), 2) AS avg_acw_nonrpc,
       aht_rpc_secs, aht_rpc_n, aht_nrpc_secs, aht_nrpc_n,
       acw_rpc_secs, acw_rpc_n, acw_nrpc_secs, acw_nrpc_n
FROM team_daily

UNION ALL

SELECT 'monthly' AS granularity, NULL AS date, month_num, month_name, agent_id, agent_name, supervisor_id, team_name,
       ROUND(aht_rpc_secs::numeric / NULLIF(aht_rpc_n, 0), 2)   AS avg_aht_rpc,
       ROUND(aht_nrpc_secs::numeric / NULLIF(aht_nrpc_n, 0), 2) AS avg_aht_nonrpc,
       ROUND(acw_rpc_secs::numeric / NULLIF(acw_rpc_n, 0), 2)   AS avg_acw_rpc,
       ROUND(acw_nrpc_secs::numeric / NULLIF(acw_nrpc_n, 0), 2) AS avg_acw_nonrpc,
       aht_rpc_secs, aht_rpc_n, aht_nrpc_secs, aht_nrpc_n,
       acw_rpc_secs, acw_rpc_n, acw_nrpc_secs, acw_nrpc_n
FROM monthly;

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
    pm.bucket_conversion,
    pm.capped_kp,
    pm.capped_kp_rpc_arrears,
    rm.cure_count,
    rm.cured_amount,
    rm.cure_rate,
    rm.agent_cure_count,
    rm.self_cure_count,
    pr.utilization_pct,
    pr.contacts_per_agent_hour,
    ht.avg_aht_rpc,
    ht.avg_aht_nonrpc,
    ht.avg_acw_rpc,
    ht.avg_acw_nonrpc
FROM (
    SELECT * FROM v_contact_metrics WHERE granularity = 'agent'
) cm
LEFT JOIN (
    SELECT * FROM v_promise_metrics WHERE granularity = 'agent'
) pm ON cm.agent_id = pm.agent_id AND cm.date = pm.date
LEFT JOIN (
    SELECT * FROM v_recovery_metrics WHERE granularity = 'agent'
) rm ON cm.agent_id = rm.agent_id AND cm.date = rm.date
LEFT JOIN (
    SELECT * FROM v_productivity_metrics WHERE granularity = 'agent'
) pr ON cm.agent_id = pr.agent_id AND cm.date = pr.date
LEFT JOIN (
    SELECT * FROM v_handle_time_metrics WHERE granularity = 'agent'
) ht ON cm.agent_id = ht.agent_id AND cm.date = ht.date;

-- ========================================================================
-- 7. v_monthly_summary
-- Purpose: Month-level rollup of all KPIs for dashboard trends and MoM comparisons
-- Single-pass: queries each underlying view once, rolls up via GROUP BY
-- ========================================================================
CREATE OR REPLACE VIEW v_monthly_summary AS
WITH agent_monthly AS (
    SELECT
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
        pm.ptp_count,
        pm.ptp_pct,
        pm.kept_count,
        pm.broken_count,
        pm.kept_pct,
        pm.bucket_conversion,
        pm.capped_kp,
        rm.payment_count,
        rm.cure_count,
        rm.cure_rate,
        rm.agent_cure_count,
        rm.self_cure_count,
        pr.utilization_pct,
        pr.operational_hours,
        pr.tht_hours,
        ht.avg_aht_rpc,
        ht.avg_aht_nonrpc,
        ht.avg_acw_rpc,
        ht.avg_acw_nonrpc,
        ht.aht_rpc_secs,
        ht.aht_rpc_n,
        ht.aht_nrpc_secs,
        ht.aht_nrpc_n,
        ht.acw_rpc_secs,
        ht.acw_rpc_n,
        ht.acw_nrpc_secs,
        ht.acw_nrpc_n
    FROM (SELECT * FROM v_contact_metrics WHERE granularity = 'monthly') cm
    LEFT JOIN (SELECT * FROM v_promise_metrics WHERE granularity = 'monthly') pm 
        ON cm.agent_id = pm.agent_id AND cm.month_num = pm.month_num
    LEFT JOIN (SELECT * FROM v_recovery_metrics WHERE granularity = 'monthly_agent') rm 
        ON cm.agent_id = rm.agent_id AND cm.month_num = rm.month_num
    LEFT JOIN (SELECT * FROM v_productivity_metrics WHERE granularity = 'monthly') pr 
        ON cm.agent_id = pr.agent_id AND cm.month_num = pr.month_num
    LEFT JOIN (SELECT * FROM v_handle_time_metrics WHERE granularity = 'monthly') ht 
        ON cm.agent_id = ht.agent_id AND cm.month_num = ht.month_num
)
SELECT 'agent' AS granularity,
    month_num, month_name, agent_id, agent_name, supervisor_id, team_name,
    total_calls, connected_calls, rpc_count,
    ROUND(rpc_pct, 2) AS avg_rpc_pct,
    ptp_count,
    ROUND(ptp_pct, 2) AS avg_ptp_pct,
    kept_count, broken_count,
    ROUND(kept_pct, 2) AS avg_kept_pct,
    ROUND(bucket_conversion, 2) AS avg_bucket_conversion,
    capped_kp,
    cure_count,
    ROUND(cure_rate, 2) AS avg_cure_rate,
    agent_cure_count, self_cure_count,
    ROUND(utilization_pct, 2) AS avg_utilization_pct,
    ROUND(avg_aht_rpc, 2) AS avg_aht_rpc,
    ROUND(avg_aht_nonrpc, 2) AS avg_aht_nonrpc,
    ROUND(avg_acw_rpc, 2) AS avg_acw_rpc,
    ROUND(avg_acw_nonrpc, 2) AS avg_acw_nonrpc
FROM agent_monthly

UNION ALL

SELECT 'team' AS granularity,
    month_num, month_name,
    NULL AS agent_id, NULL AS agent_name,
    supervisor_id, team_name,
    SUM(total_calls) AS total_calls,
    SUM(connected_calls) AS connected_calls,
    SUM(rpc_count) AS rpc_count,
    ROUND(SUM(rpc_count) * 100.0 / NULLIF(SUM(connected_calls), 0), 2) AS avg_rpc_pct,
    SUM(ptp_count) AS ptp_count,
    ROUND(SUM(ptp_count) * 100.0 / NULLIF(SUM(rpc_count), 0), 2) AS avg_ptp_pct,
    SUM(kept_count) AS kept_count,
    SUM(broken_count) AS broken_count,
    ROUND(SUM(kept_count) * 100.0 / NULLIF(SUM(kept_count) + SUM(broken_count), 0), 2) AS avg_kept_pct,
    ROUND(
        (SUM(kept_count) * 100.0 / NULLIF(SUM(kept_count) + SUM(broken_count), 0))
        * SUM(ptp_count) / NULLIF(SUM(rpc_count), 0),
    2) AS avg_bucket_conversion,
    SUM(capped_kp) AS capped_kp,
    -- C3: ratio-of-sums everywhere — never AVG of per-agent rates
    SUM(cure_count) AS cure_count,
    ROUND(SUM(cure_count) * 100.0 / NULLIF(SUM(payment_count), 0), 2) AS avg_cure_rate,
    SUM(agent_cure_count) AS agent_cure_count,
    SUM(self_cure_count) AS self_cure_count,
    ROUND(SUM(tht_hours) / NULLIF(SUM(operational_hours), 0), 2) AS avg_utilization_pct,
    ROUND(SUM(aht_rpc_secs)::numeric / NULLIF(SUM(aht_rpc_n), 0), 2) AS avg_aht_rpc,
    ROUND(SUM(aht_nrpc_secs)::numeric / NULLIF(SUM(aht_nrpc_n), 0), 2) AS avg_aht_nonrpc,
    ROUND(SUM(acw_rpc_secs)::numeric / NULLIF(SUM(acw_rpc_n), 0), 2) AS avg_acw_rpc,
    ROUND(SUM(acw_nrpc_secs)::numeric / NULLIF(SUM(acw_nrpc_n), 0), 2) AS avg_acw_nonrpc
FROM agent_monthly
GROUP BY month_num, month_name, supervisor_id, team_name

UNION ALL

SELECT 'portfolio' AS granularity,
    month_num, month_name,
    NULL AS agent_id, NULL AS agent_name,
    NULL AS supervisor_id, NULL AS team_name,
    SUM(total_calls) AS total_calls,
    SUM(connected_calls) AS connected_calls,
    SUM(rpc_count) AS rpc_count,
    ROUND(SUM(rpc_count) * 100.0 / NULLIF(SUM(connected_calls), 0), 2) AS avg_rpc_pct,
    SUM(ptp_count) AS ptp_count,
    ROUND(SUM(ptp_count) * 100.0 / NULLIF(SUM(rpc_count), 0), 2) AS avg_ptp_pct,
    SUM(kept_count) AS kept_count,
    SUM(broken_count) AS broken_count,
    ROUND(SUM(kept_count) * 100.0 / NULLIF(SUM(kept_count) + SUM(broken_count), 0), 2) AS avg_kept_pct,
    ROUND(
        (SUM(kept_count) * 100.0 / NULLIF(SUM(kept_count) + SUM(broken_count), 0))
        * SUM(ptp_count) / NULLIF(SUM(rpc_count), 0),
    2) AS avg_bucket_conversion,
    SUM(capped_kp) AS capped_kp,
    SUM(cure_count) AS cure_count,
    ROUND(SUM(cure_count) * 100.0 / NULLIF(SUM(payment_count), 0), 2) AS avg_cure_rate,
    SUM(agent_cure_count) AS agent_cure_count,
    SUM(self_cure_count) AS self_cure_count,
    ROUND(SUM(tht_hours) / NULLIF(SUM(operational_hours), 0), 2) AS avg_utilization_pct,
    ROUND(SUM(aht_rpc_secs)::numeric / NULLIF(SUM(aht_rpc_n), 0), 2) AS avg_aht_rpc,
    ROUND(SUM(aht_nrpc_secs)::numeric / NULLIF(SUM(aht_nrpc_n), 0), 2) AS avg_aht_nonrpc,
    ROUND(SUM(acw_rpc_secs)::numeric / NULLIF(SUM(acw_rpc_n), 0), 2) AS avg_acw_rpc,
    ROUND(SUM(acw_nrpc_secs)::numeric / NULLIF(SUM(acw_nrpc_n), 0), 2) AS avg_acw_nonrpc
FROM agent_monthly
GROUP BY month_num, month_name;

-- ========================================================================
-- 8. v_etl_load_summary
-- Purpose: Summary of latest ETL load per table from etl_load_log
-- Note: etl_load_log table is defined in 001_create_tables.sql (migration order)
-- ========================================================================
CREATE OR REPLACE VIEW v_etl_load_summary AS
WITH ranked AS (
    SELECT
        table_name,
        loaded_at AS last_loaded_at,
        rows_loaded,
        status,
        csv_checksum,
        ROW_NUMBER() OVER (PARTITION BY table_name ORDER BY loaded_at DESC) AS rn
    FROM etl_load_log
)
SELECT
    table_name,
    last_loaded_at,
    rows_loaded,
    status,
    csv_checksum,
    NOW() - last_loaded_at AS data_freshness
FROM ranked
WHERE rn = 1
ORDER BY last_loaded_at DESC;

-- ========================================================================
-- 9. v_data_freshness
-- Purpose: Data freshness check - shows how many days ago each fact table was last updated
-- ========================================================================
CREATE OR REPLACE VIEW v_data_freshness AS
SELECT 'fact_interactions' AS table_name, MAX(interaction_date) AS max_date, CURRENT_DATE - MAX(interaction_date) AS days_ago FROM fact_interactions
UNION ALL
SELECT 'fact_ptp_log' AS table_name, MAX(ptp_date) AS max_date, CURRENT_DATE - MAX(ptp_date) AS days_ago FROM fact_ptp_log
UNION ALL
SELECT 'fact_payments' AS table_name, MAX(payment_date) AS max_date, CURRENT_DATE - MAX(payment_date) AS days_ago FROM fact_payments
UNION ALL
SELECT 'fact_agent_time_log' AS table_name, MAX(log_date) AS max_date, CURRENT_DATE - MAX(log_date) AS days_ago FROM fact_agent_time_log
UNION ALL
SELECT 'fact_eom_snapshot' AS table_name, MAX(snapshot_date) AS max_date, CURRENT_DATE - MAX(snapshot_date) AS days_ago FROM fact_eom_snapshot
UNION ALL
SELECT 'fact_writeoffs' AS table_name, MAX(writeoff_date) AS max_date, CURRENT_DATE - MAX(writeoff_date) AS days_ago FROM fact_writeoffs
ORDER BY days_ago ASC;

-- ========================================================================
-- 10. v_dpd_migration_matrix
-- Purpose: DPD bucket transitions between consecutive months per account
-- Used by: Roll Rate Analysis page (Page 9) + Portfolio Management (Page 4)
-- ========================================================================
CREATE OR REPLACE VIEW v_dpd_migration_matrix AS
WITH ranked_snapshots AS (
    SELECT
        account_id,
        snapshot_date,
        dpd_bucket,
        balance,
        LEAD(dpd_bucket) OVER (PARTITION BY account_id ORDER BY snapshot_date) AS next_bucket,
        LEAD(snapshot_date) OVER (PARTITION BY account_id ORDER BY snapshot_date) AS next_date
    FROM fact_eom_snapshot
),
bucket_ranks AS (
    SELECT
        account_id,
        snapshot_date,
        dpd_bucket,
        next_bucket,
        next_date,
        balance,
        CASE dpd_bucket WHEN 'Current' THEN 0 WHEN '1-30' THEN 1 WHEN '31-60' THEN 2 WHEN '61-90' THEN 3 WHEN '90+' THEN 4 ELSE 5 END AS from_rank,
        CASE next_bucket WHEN 'Current' THEN 0 WHEN '1-30' THEN 1 WHEN '31-60' THEN 2 WHEN '61-90' THEN 3 WHEN '90+' THEN 4 ELSE 5 END AS to_rank
    FROM ranked_snapshots
)
SELECT
    snapshot_date AS from_month,
    next_date AS to_month,
    account_id,
    dpd_bucket AS from_bucket,
    next_bucket AS to_bucket,
    balance,
    CASE
        WHEN next_bucket IS NULL THEN 'Exited'
        WHEN dpd_bucket = next_bucket THEN 'Same'
        WHEN dpd_bucket = 'Current' AND next_bucket != 'Current' THEN 'Deteriorated'
        WHEN dpd_bucket = '90+' AND next_bucket = 'Current' THEN 'Cured'
        WHEN to_rank > from_rank THEN 'Deteriorated'
        ELSE 'Improved'
    END AS migration_direction
FROM bucket_ranks
WHERE next_date IS NOT NULL;

-- ========================================================================
-- 11. v_weekly_agent_summary
-- Purpose: Agent performance aggregated by ISO week for trend analysis
-- Used by: Agent Performance page (Page 2) weekly trend charts
-- ========================================================================
CREATE OR REPLACE VIEW v_weekly_agent_summary AS
SELECT
    DATE_TRUNC('week', i.interaction_date)::date AS week_start,
    i.agent_id,
    a.agent_name,
    a.team_name,
    a.region,
    a.experience_tier,
    a.supervisor_id,
    COUNT(DISTINCT i.interaction_id) AS total_interactions,
    SUM(i.calls_attempted) AS total_calls,
    SUM(i.calls_connected) AS connected_calls,
    SUM(CASE WHEN i.rpc_flag = TRUE THEN 1 ELSE 0 END) AS rpc_count,
    ROUND(
        CASE WHEN SUM(i.calls_connected) > 0
             THEN SUM(CASE WHEN i.rpc_flag = TRUE THEN 1 ELSE 0 END)::decimal / SUM(i.calls_connected) * 100
             ELSE 0 END, 2
    ) AS rpc_pct,
    ROUND(AVG(i.aht_seconds), 0) AS avg_aht,
    ROUND(AVG(i.acw_seconds), 0) AS avg_acw,
    COUNT(DISTINCT i.account_id) AS accounts_contacted
FROM fact_interactions i
JOIN dim_employees a ON i.agent_id = a.agent_id
GROUP BY 1, 2, 3, 4, 5, 6, 7;

-- ========================================================================
-- 12. v_rls_supervisor_map
-- Purpose: RLS mapping table for Power BI Row-Level Security
-- Used by: All dashboard pages with supervisor-level filtering
-- Maps agent_id to supervisor_id so filters propagate correctly
-- ========================================================================
CREATE OR REPLACE VIEW v_rls_supervisor_map AS
SELECT
    a.agent_id,
    a.supervisor_id,
    a.team_name,
    a.region,
    a.experience_tier
FROM dim_employees a
WHERE a.employee_type = 'Agent'
UNION
SELECT
    NULL AS agent_id,
    e.agent_id AS supervisor_id,
    e.team_name,
    e.region,
    NULL AS experience_tier
FROM dim_employees e
WHERE e.employee_type = 'Supervisor';
