-- ## Task 9 — Freshness check before you hit send ## --

/*

New house rule: 
	
	Before ANY number leaves your desk, you run a freshness check — newest date per fact table, 
	oldest gap flagged. Build the script once; run it forever."

Background: 
	
	Stale-data embarrassments end careers faster than wrong formulas. 
	The project even ships a view for this idea; your job is to build your own and then compare.

Your job:

	1. Newest date per fact table, labeled, one result set.
	2. Add days-since-that-date relative to the latest of all of them.
	3. Compare your output to the official freshness view.
	
*/

WITH maxima AS (
	SELECT 'fact_interactions' AS table_name, MAX(interaction_date) AS max_date FROM fact_interactions
	UNION ALL SELECT 'fact_ptp_log', 		MAX(ptp_date)		FROM fact_ptp_log
	UNION ALL SELECT 'fact_payments',		MAX(payment_date) 	FROM fact_payments
	UNION ALL SELECT 'fact_agent_time_log', MAX(log_date) 		FROM fact_agent_time_log
	UNION ALL SELECT 'fact_eom_snapshot', 	MAX(snapshot_date) 	FROM fact_eom_snapshot
	UNION ALL SELECT 'fact_writeoffs', 		MAX(writeoff_date)	FROM fact_writeoffs
	UNION ALL SELECT 'fact_recoveries', 	MAX(recovery_date)	FROM fact_recoveries
)
SELECT
	table_name,
	max_date,
	(MAX(max_date) OVER() - max_date) AS days_behind_newest
FROM maxima
ORDER BY max_date DESC;


-- Official implementations to compare agains:
SELECT * FROM v_data_freshness ORDER BY max_date DESC;

/*

Guiding questions: 

1. Which table will always lag the others, and why is that normal?

   fact_eom_snapshot will normally lag because it is a monthly periodic
   snapshot. It records account position only at month-end, while operational
   fact tables can receive activity daily.

2. Which two tables should move together day by day — and if they ever diverge,
   what does that suggest?

   fact_interactions and fact_agent_time_log should normally move together on
   working days because agent time supports collection activity. If their latest
   dates diverge, it may indicate that one source was not loaded, a pipeline
   failed, or operational activity and time logging are out of sync.
   
*/