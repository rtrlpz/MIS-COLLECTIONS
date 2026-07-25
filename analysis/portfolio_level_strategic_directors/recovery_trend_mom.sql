-- ========================================================================
-- recovery_trend_mom.sql
-- Purpose: Month-over-month recovery trends with seasonal pattern detection
-- Tracks cures, cure rate, cured amounts, and cost-to-collect proxy
-- Uses LAG() for MoM comparison and shows % change
-- Compares Oct vs Nov vs Dec for seasonal patterns
-- Cost-to-collect proxy = avg_aht_rpc * (wage_rate/3600) * total_calls
-- ========================================================================

-- Wage rate constant: $15/hour assumed for cost calculations
WITH monthly_recovery AS (
    SELECT 
        rm.month_num,
        rm.month_name,
        SUM(rm.cure_count) AS total_cures,
        ROUND(AVG(rm.cure_rate), 2) AS avg_cure_rate,
        SUM(rm.cured_amount) AS total_cured_amount,
        SUM(rm.agent_cure_count) AS agent_cures,
        SUM(rm.self_cure_count) AS self_cures,
        COUNT(DISTINCT rm.agent_id) AS active_agents
    FROM v_recovery_metrics rm
    WHERE rm.granularity = 'monthly_agent'
    GROUP BY rm.month_num, rm.month_name
),
monthly_aht AS (
    SELECT 
        month_num,
        ROUND(AVG(avg_aht_rpc), 2) AS portfolio_avg_aht_rpc
    FROM v_handle_time_metrics 
    WHERE granularity = 'monthly'
    GROUP BY month_num
),
monthly_calls AS (
    SELECT 
        month_num,
        SUM(total_calls) AS portfolio_total_calls
    FROM v_contact_metrics
    WHERE granularity = 'monthly'
    GROUP BY month_num
),
combined AS (
    SELECT 
        mr.month_num,
        mr.month_name,
        mr.total_cures,
        mr.avg_cure_rate,
        mr.total_cured_amount,
        mr.agent_cures,
        mr.self_cures,
        mr.active_agents,
        COALESCE(ma.portfolio_avg_aht_rpc, 0) AS portfolio_avg_aht_rpc,
        COALESCE(mc.portfolio_total_calls, 0) AS portfolio_total_calls
    FROM monthly_recovery mr
    LEFT JOIN monthly_aht ma ON mr.month_num = ma.month_num
    LEFT JOIN monthly_calls mc ON mr.month_num = mc.month_num
),
with_costs AS (
    SELECT 
        *,
        -- Cost-to-collect proxy: AHT (seconds) * ($15/hour / 3600) * total_calls
        ROUND(portfolio_avg_aht_rpc * (15.0 / 3600) * portfolio_total_calls, 2) AS cost_to_collect,
        -- Cost per cured dollar
        ROUND(
            (portfolio_avg_aht_rpc * (15.0 / 3600) * portfolio_total_calls)::numeric / 
            NULLIF(total_cured_amount, 0), 2
        ) AS cost_per_cured_dollar
    FROM combined
),
with_mom AS (
    SELECT 
        *,
        LAG(total_cures) OVER (ORDER BY month_num) AS prev_total_cures,
        LAG(avg_cure_rate) OVER (ORDER BY month_num) AS prev_avg_cure_rate,
        LAG(total_cured_amount) OVER (ORDER BY month_num) AS prev_cured_amount,
        LAG(cost_to_collect) OVER (ORDER BY month_num) AS prev_cost_to_collect,
        LAG(portfolio_total_calls) OVER (ORDER BY month_num) AS prev_total_calls
    FROM with_costs
)

SELECT 
    month_name,
    total_cures,
    ROUND((total_cures - prev_total_cures)::numeric / NULLIF(prev_total_cures, 0) * 100, 2) AS cures_mom_pct_change,
    avg_cure_rate,
    ROUND(avg_cure_rate - prev_avg_cure_rate, 2) AS cure_rate_mom_change,
    total_cured_amount,
    ROUND((total_cured_amount - prev_cured_amount)::numeric / NULLIF(prev_cured_amount, 0) * 100, 2) AS cured_amt_mom_pct_change,
    agent_cures,
    self_cures,
    ROUND(agent_cures::numeric / NULLIF(total_cures, 0) * 100, 2) AS agent_cure_pct,
    portfolio_total_calls,
    ROUND((portfolio_total_calls - prev_total_calls)::numeric / NULLIF(prev_total_calls, 0) * 100, 2) AS calls_mom_pct_change,
    cost_to_collect,
    ROUND((cost_to_collect - prev_cost_to_collect)::numeric / NULLIF(prev_cost_to_collect, 0) * 100, 2) AS cost_mom_pct_change,
    cost_per_cured_dollar,
    active_agents,
    -- Seasonal pattern flag
    CASE 
        WHEN month_num = 10 THEN 'Baseline (Oct)'
        WHEN total_cures > prev_total_cures AND total_cured_amount > prev_cured_amount THEN 'Growth vs Previous'
        WHEN total_cures < prev_total_cures AND total_cured_amount < prev_cured_amount THEN 'Decline vs Previous'
        ELSE 'Mixed Pattern'
    END AS seasonal_pattern
FROM with_mom
ORDER BY month_num;
