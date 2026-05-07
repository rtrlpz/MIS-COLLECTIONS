-- =========================================================================
-- KPI Views Validation Tests
-- Run these tests to validate KPI view logic and data quality
-- =========================================================================

-- =========================================================================
-- Test 1: v_contact_metrics - Verify RPC% calculation
-- =========================================================================
-- Test: RPC% should be between 0 and 100
SELECT 'v_contact_metrics: rpc_pct out of range' AS test_name, COUNT(*) AS failures
FROM v_contact_metrics
WHERE rpc_pct < 0 OR rpc_pct > 100
HAVING COUNT(*) > 0;

-- Test: Total calls should be >= connected calls
SELECT 'v_contact_metrics: total_calls < connected_calls' AS test_name, COUNT(*) AS failures
FROM v_contact_metrics
WHERE total_calls < connected_calls
HAVING COUNT(*) > 0;

-- Test: RPC count should be <= connected calls
SELECT 'v_contact_metrics: rpc_count > connected_calls' AS test_name, COUNT(*) AS failures
FROM v_contact_metrics
WHERE rpc_count > connected_calls
HAVING COUNT(*) > 0;


-- =========================================================================
-- Test 2: v_promise_metrics - Verify PTP% and Kept% calculations
-- =========================================================================
-- Test: PTP% should be between 0 and 100
SELECT 'v_promise_metrics: ptp_pct out of range' AS test_name, COUNT(*) AS failures
FROM v_promise_metrics
WHERE ptp_pct < 0 OR ptp_pct > 100
HAVING COUNT(*) > 0;

-- Test: Kept% should be between 0 and 100
SELECT 'v_promise_metrics: kept_pct out of range' AS test_name, COUNT(*) AS failures
FROM v_promise_metrics
WHERE kept_pct < 0 OR kept_pct > 100
HAVING COUNT(*) > 0;

-- Test: Kept + Broken should equal PTP count
SELECT 'v_promise_metrics: kept+broken != ptp_count' AS test_name, COUNT(*) AS failures
FROM v_promise_metrics
WHERE (kept_count + broken_count) != ptp_count
HAVING COUNT(*) > 0;


-- =========================================================================
-- Test 3: v_recovery_metrics - Verify cure rate calculation
-- =========================================================================
-- Test: Cure rate should be between 0 and 100
SELECT 'v_recovery_metrics: cure_rate out of range' AS test_name, COUNT(*) AS failures
FROM v_recovery_metrics
WHERE cure_rate < 0 OR cure_rate > 100
HAVING COUNT(*) > 0;

-- Test: Agent cure + Self cure should equal total cures
SELECT 'v_recovery_metrics: agent+self != cure_count' AS test_name, COUNT(*) AS failures
FROM v_recovery_metrics
WHERE (agent_cure_count + self_cure_count) != cure_count
HAVING COUNT(*) > 0;


-- =========================================================================
-- Test 4: v_productivity_metrics - Verify utilization and contact rates
-- =========================================================================
-- Test: Utilization should be between 0 and 100
SELECT 'v_productivity_metrics: utilization out of range' AS test_name, COUNT(*) AS failures
FROM v_productivity_metrics
WHERE utilization_pct < 0 OR utilization_pct > 100
HAVING COUNT(*) > 0;

-- Test: Contacts per hour should be non-negative
SELECT 'v_productivity_metrics: negative contacts_per_agent_hour' AS test_name, COUNT(*) AS failures
FROM v_productivity_metrics
WHERE contacts_per_agent_hour < 0
HAVING COUNT(*) > 0;


-- =========================================================================
-- Test 5: v_handle_time_metrics - Verify AHT/ACW values
-- =========================================================================
-- Test: AHT values should be positive
SELECT 'v_handle_time_metrics: negative avg_aht_rpc' AS test_name, COUNT(*) AS failures
FROM v_handle_time_metrics
WHERE avg_aht_rpc < 0
HAVING COUNT(*) > 0;

SELECT 'v_handle_time_metrics: negative avg_aht_nonrpc' AS test_name, COUNT(*) AS failures
FROM v_handle_time_metrics
WHERE avg_aht_nonrpc < 0
HAVING COUNT(*) > 0;

-- Test: ACW values should be non-negative
SELECT 'v_handle_time_metrics: negative avg_acw_rpc' AS test_name, COUNT(*) AS failures
FROM v_handle_time_metrics
WHERE avg_acw_rpc < 0
HAVING COUNT(*) > 0;

SELECT 'v_handle_time_metrics: negative avg_acw_nonrpc' AS test_name, COUNT(*) AS failures
FROM v_handle_time_metrics
WHERE avg_acw_nonrpc < 0
HAVING COUNT(*) > 0;


-- =========================================================================
-- Test 6: v_daily_mis - Verify consolidated view integrity
-- =========================================================================
-- Test: Should have no null agent_id for agent-level data
SELECT 'v_daily_mis: null agent_id' AS test_name, COUNT(*) AS failures
FROM v_daily_mis
WHERE agent_id IS NULL
HAVING COUNT(*) > 0;

-- Test: RPC% should be in valid range
SELECT 'v_daily_mis: rpc_pct out of range' AS test_name, COUNT(*) AS failures
FROM v_daily_mis
WHERE rpc_pct < 0 OR rpc_pct > 100
HAVING COUNT(*) > 0;


-- =========================================================================
-- Test 7: v_monthly_summary - Verify month-level rollups
-- =========================================================================
-- Test: Should have data for each month in the dataset
SELECT 'v_monthly_summary: missing months' AS test_name, 
       STRING_AGG(DISTINCT month_name, ', ' ORDER BY month_num) AS months_present
FROM v_monthly_summary
WHERE granularity = 'portfolio';

-- Test: Utilization average should be in valid range
SELECT 'v_monthly_summary: avg_utilization out of range' AS test_name, COUNT(*) AS failures
FROM v_monthly_summary
WHERE avg_utilization_pct < 0 OR avg_utilization_pct > 100
HAVING COUNT(*) > 0;


-- =========================================================================
-- Test 8: v_etl_load_summary - Verify ETL logging
-- =========================================================================
-- Test: Should have entries for all tables
SELECT 'v_etl_load_summary: missing tables' AS test_name, 
       COUNT(DISTINCT table_name) AS tables_logged
FROM v_etl_load_summary;

-- Test: Status should be SUCCESS for all loads
SELECT 'v_etl_load_summary: failed loads' AS test_name, COUNT(*) AS failures
FROM v_etl_load_summary
WHERE status != 'SUCCESS'
HAVING COUNT(*) > 0;


-- =========================================================================
-- Test 9: v_data_freshness - Verify data recency
-- =========================================================================
-- Test: All fact tables should have data within the last year
SELECT 'v_data_freshness: stale data' AS test_name, table_name, days_ago
FROM v_data_freshness
WHERE days_ago > 365
ORDER BY days_ago DESC;


-- =========================================================================
-- Summary: Run all tests and show only failures
-- =========================================================================
SELECT 'KPI View Tests Complete' AS status;
