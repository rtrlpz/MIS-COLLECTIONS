-- ========================================================================
-- team_comparison.sql
-- Purpose: Side-by-side team metrics with mean, std dev, and portfolio deviation highlighting
-- Uses v_monthly_summary (granularity = 'team') for all metrics
-- Includes t-test approximation: mean and standard deviation per metric per team
-- Highlights teams >1 std dev above/below portfolio average
-- Side-by-side monthly metrics (Oct, Nov, Dec) for each KPI
-- ========================================================================

WITH team_monthly AS (
    SELECT
        team_name,
        month_name,
        total_calls,
        avg_rpc_pct AS rpc_pct,
        avg_ptp_pct AS ptp_pct,
        avg_kept_pct AS kept_pct,
        avg_cure_rate AS cure_rate,
        avg_utilization_pct AS avg_utilization
    FROM v_monthly_summary
    WHERE granularity = 'team'
),
-- Pivot monthly data to side-by-side columns
team_pivot AS (
    SELECT
        team_name,
        MAX(CASE WHEN month_name = 'October' THEN total_calls END) AS oct_total_calls,
        MAX(CASE WHEN month_name = 'November' THEN total_calls END) AS nov_total_calls,
        MAX(CASE WHEN month_name = 'December' THEN total_calls END) AS dec_total_calls,
        MAX(CASE WHEN month_name = 'October' THEN rpc_pct END) AS oct_rpc_pct,
        MAX(CASE WHEN month_name = 'November' THEN rpc_pct END) AS nov_rpc_pct,
        MAX(CASE WHEN month_name = 'December' THEN rpc_pct END) AS dec_rpc_pct,
        MAX(CASE WHEN month_name = 'October' THEN ptp_pct END) AS oct_ptp_pct,
        MAX(CASE WHEN month_name = 'November' THEN ptp_pct END) AS nov_ptp_pct,
        MAX(CASE WHEN month_name = 'December' THEN ptp_pct END) AS dec_ptp_pct,
        MAX(CASE WHEN month_name = 'October' THEN kept_pct END) AS oct_kept_pct,
        MAX(CASE WHEN month_name = 'November' THEN kept_pct END) AS nov_kept_pct,
        MAX(CASE WHEN month_name = 'December' THEN kept_pct END) AS dec_kept_pct,
        MAX(CASE WHEN month_name = 'October' THEN cure_rate END) AS oct_cure_rate,
        MAX(CASE WHEN month_name = 'November' THEN cure_rate END) AS nov_cure_rate,
        MAX(CASE WHEN month_name = 'December' THEN cure_rate END) AS dec_cure_rate,
        MAX(CASE WHEN month_name = 'October' THEN avg_utilization END) AS oct_utilization,
        MAX(CASE WHEN month_name = 'November' THEN avg_utilization END) AS nov_utilization,
        MAX(CASE WHEN month_name = 'December' THEN avg_utilization END) AS dec_utilization
    FROM team_monthly
    GROUP BY team_name
),
team_agg AS (
    SELECT
        team_name,
        AVG(total_calls) AS total_calls_mean,
        STDDEV(total_calls) AS total_calls_std_dev,
        AVG(rpc_pct) AS rpc_pct_mean,
        STDDEV(rpc_pct) AS rpc_pct_std_dev,
        AVG(ptp_pct) AS ptp_pct_mean,
        STDDEV(ptp_pct) AS ptp_pct_std_dev,
        AVG(kept_pct) AS kept_pct_mean,
        STDDEV(kept_pct) AS kept_pct_std_dev,
        AVG(cure_rate) AS cure_rate_mean,
        STDDEV(cure_rate) AS cure_rate_std_dev,
        AVG(avg_utilization) AS avg_utilization_mean,
        STDDEV(avg_utilization) AS avg_utilization_std_dev
    FROM team_monthly
    GROUP BY team_name
),
portfolio_agg AS (
    SELECT
        AVG(total_calls) AS portfolio_total_calls_mean,
        STDDEV(total_calls) AS portfolio_total_calls_std_dev,
        AVG(rpc_pct) AS portfolio_rpc_pct_mean,
        STDDEV(rpc_pct) AS portfolio_rpc_pct_std_dev,
        AVG(ptp_pct) AS portfolio_ptp_pct_mean,
        STDDEV(ptp_pct) AS portfolio_ptp_pct_std_dev,
        AVG(kept_pct) AS portfolio_kept_pct_mean,
        STDDEV(kept_pct) AS portfolio_kept_pct_std_dev,
        AVG(cure_rate) AS portfolio_cure_rate_mean,
        STDDEV(cure_rate) AS portfolio_cure_rate_std_dev,
        AVG(avg_utilization) AS portfolio_avg_utilization_mean,
        STDDEV(avg_utilization) AS portfolio_avg_utilization_std_dev
    FROM team_monthly
),
combined AS (
    SELECT
        t.*,
        p.portfolio_total_calls_mean,
        p.portfolio_total_calls_std_dev,
        p.portfolio_rpc_pct_mean,
        p.portfolio_rpc_pct_std_dev,
        p.portfolio_ptp_pct_mean,
        p.portfolio_ptp_pct_std_dev,
        p.portfolio_kept_pct_mean,
        p.portfolio_kept_pct_std_dev,
        p.portfolio_cure_rate_mean,
        p.portfolio_cure_rate_std_dev,
        p.portfolio_avg_utilization_mean,
        p.portfolio_avg_utilization_std_dev
    FROM team_agg t
    CROSS JOIN portfolio_agg p
),
final AS (
    SELECT
        c.*,
        tp.oct_total_calls, tp.nov_total_calls, tp.dec_total_calls,
        tp.oct_rpc_pct, tp.nov_rpc_pct, tp.dec_rpc_pct,
        tp.oct_ptp_pct, tp.nov_ptp_pct, tp.dec_ptp_pct,
        tp.oct_kept_pct, tp.nov_kept_pct, tp.dec_kept_pct,
        tp.oct_cure_rate, tp.nov_cure_rate, tp.dec_cure_rate,
        tp.oct_utilization, tp.nov_utilization, tp.dec_utilization
    FROM combined c
    LEFT JOIN team_pivot tp ON c.team_name = tp.team_name
)
SELECT
    team_name,
    oct_total_calls, nov_total_calls, dec_total_calls,
    ROUND(oct_rpc_pct, 2) AS oct_rpc_pct, ROUND(nov_rpc_pct, 2) AS nov_rpc_pct, ROUND(dec_rpc_pct, 2) AS dec_rpc_pct,
    ROUND(oct_ptp_pct, 2) AS oct_ptp_pct, ROUND(nov_ptp_pct, 2) AS nov_ptp_pct, ROUND(dec_ptp_pct, 2) AS dec_ptp_pct,
    ROUND(oct_kept_pct, 2) AS oct_kept_pct, ROUND(nov_kept_pct, 2) AS nov_kept_pct, ROUND(dec_kept_pct, 2) AS dec_kept_pct,
    ROUND(oct_cure_rate, 2) AS oct_cure_rate, ROUND(nov_cure_rate, 2) AS nov_cure_rate, ROUND(dec_cure_rate, 2) AS dec_cure_rate,
    ROUND(oct_utilization, 2) AS oct_utilization, ROUND(nov_utilization, 2) AS nov_utilization, ROUND(dec_utilization, 2) AS dec_utilization,
    ROUND(total_calls_mean, 2) AS total_calls_mean,
    ROUND(COALESCE(total_calls_std_dev, 0), 2) AS total_calls_std_dev,
    CASE
        WHEN total_calls_mean > (portfolio_total_calls_mean + portfolio_total_calls_std_dev) THEN '>1 Std Dev Above'
        WHEN total_calls_mean < (portfolio_total_calls_mean - portfolio_total_calls_std_dev) THEN '>1 Std Dev Below'
        ELSE 'Normal'
    END AS total_calls_status,
    ROUND(rpc_pct_mean, 2) AS rpc_pct_mean,
    ROUND(COALESCE(rpc_pct_std_dev, 0), 2) AS rpc_pct_std_dev,
    CASE
        WHEN rpc_pct_mean > (portfolio_rpc_pct_mean + portfolio_rpc_pct_std_dev) THEN '>1 Std Dev Above'
        WHEN rpc_pct_mean < (portfolio_rpc_pct_mean - portfolio_rpc_pct_std_dev) THEN '>1 Std Dev Below'
        ELSE 'Normal'
    END AS rpc_pct_status,
    ROUND(ptp_pct_mean, 2) AS ptp_pct_mean,
    ROUND(COALESCE(ptp_pct_std_dev, 0), 2) AS ptp_pct_std_dev,
    CASE
        WHEN ptp_pct_mean > (portfolio_ptp_pct_mean + portfolio_ptp_pct_std_dev) THEN '>1 Std Dev Above'
        WHEN ptp_pct_mean < (portfolio_ptp_pct_mean - portfolio_ptp_pct_std_dev) THEN '>1 Std Dev Below'
        ELSE 'Normal'
    END AS ptp_pct_status,
    ROUND(kept_pct_mean, 2) AS kept_pct_mean,
    ROUND(COALESCE(kept_pct_std_dev, 0), 2) AS kept_pct_std_dev,
    CASE
        WHEN kept_pct_mean > (portfolio_kept_pct_mean + portfolio_kept_pct_std_dev) THEN '>1 Std Dev Above'
        WHEN kept_pct_mean < (portfolio_kept_pct_mean - portfolio_kept_pct_std_dev) THEN '>1 Std Dev Below'
        ELSE 'Normal'
    END AS kept_pct_status,
    ROUND(cure_rate_mean, 2) AS cure_rate_mean,
    ROUND(COALESCE(cure_rate_std_dev, 0), 2) AS cure_rate_std_dev,
    CASE
        WHEN cure_rate_mean > (portfolio_cure_rate_mean + portfolio_cure_rate_std_dev) THEN '>1 Std Dev Above'
        WHEN cure_rate_mean < (portfolio_cure_rate_mean - portfolio_cure_rate_std_dev) THEN '>1 Std Dev Below'
        ELSE 'Normal'
    END AS cure_rate_status,
    ROUND(avg_utilization_mean, 2) AS avg_utilization_mean,
    ROUND(COALESCE(avg_utilization_std_dev, 0), 2) AS avg_utilization_std_dev,
    CASE
        WHEN avg_utilization_mean > (portfolio_avg_utilization_mean + portfolio_avg_utilization_std_dev) THEN '>1 Std Dev Above'
        WHEN avg_utilization_mean < (portfolio_avg_utilization_mean - portfolio_avg_utilization_std_dev) THEN '>1 Std Dev Below'
        ELSE 'Normal'
    END AS avg_utilization_status
FROM final
ORDER BY team_name;