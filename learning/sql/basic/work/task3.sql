-- ## Task 3 — RPC% by channel, done properly ## --

/* 
	The vendor claims our FICO-sourced accounts connect worse than dialer ones. 
	Before tomorrow's QBR I need RPC% split by channel. 
	Careful with the denominator — the last intern divided by attempts and made us look terrible.

Quick one: 
    - Q1 2025: connected calls, RPCs, RPC% per channel.
    - Make division NULL-safe — one empty group must not crash the query. 
    - Reconcile against the project's official contact view.
*/

-- a. Q1 2025: connected calls, RPCs, RPC% per channel (Division NULL-safe)
SELECT * FROM fact_interactions
LIMIT 10;

SELECT 
	fi.channel AS "Channel",
	COUNT(*) AS "Interactions",
	SUM(fi.calls_connected) AS "Calls Connected",
	SUM(
		CASE 
			WHEN fi.rpc_flag = TRUE THEN 1
			ELSE 0
		END
	) AS "RPCs",
	ROUND(100.0 *
		SUM(
			CASE
				WHEN fi.rpc_flag = TRUE THEN 1
				ELSE 0
			END
		)
		/ NULLIF(SUM(fi.calls_connected), 0),
		2
	) AS "RPC %"
FROM fact_interactions AS fi
WHERE fi.interaction_date >= DATE '2025-01-01'
	AND fi.interaction_date < DATE '2025-04-01'
GROUP BY fi.channel
ORDER BY COUNT(*) DESC;

-- Reconciliation confirmed: 
SELECT
    SUM(connected_calls) AS connected_calls,
    SUM(rpc_count) AS rpcs,
    ROUND(
        SUM(rpc_count) * 100.0
        / NULLIF(SUM(connected_calls), 0),
        2
    ) AS rpc_pct
FROM v_contact_metrics
WHERE granularity = 'agent'
  AND date >= DATE '2025-01-01'
  AND date <  DATE '2025-04-01';

/*
Reconciliation confirmed: the raw fact-table calculation matches
v_contact_metrics for Q1 2025.

Connected calls: 205,524
RPCs: 106,916
Overall RPC%: 52.02%

The view does not include channel, so it validates the Q1 overall totals
across all channels rather than each individual channel split.

Guiding questions: 
1. Why 100.0 * instead of 100 *?
	
	100.0 makes the calculation use decimal arithmetic. In PostgreSQL, if both
	values in a division are integers, SQL truncates the decimal portion.

	For example, 1 / 3 return 0 with integer division, while 1.0 / 3 returns 0.333...
	Using 100.0 preserves the decimal precision needed for RPC%. This is important 
	because the query rounds the final percentage to two decimal places.

2. Which official view already computes this — do your numbers match it exactly?
	
	v_contact_metrics computes connected calls, RPC count, RPC%. The Q1 totals
	from the raw-table query match the view exactly: 205,524 connected calls, 
	106,916 RPCs, and an overall RPC% of 52.02

	The view does not include channel, so it validates the Q1 total across all channels
	rather than each individual channel result.
*/     


