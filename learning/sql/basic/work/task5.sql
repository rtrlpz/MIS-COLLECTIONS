-- ## Task 5 — The 8:40 morning pack ## --

/* 
Same as every morning: 
	yesterday's contacts, 
	connects, 
	promises, 
	payments. 
	Four numbers, 
	sticky-note format. 

Your job:
1. One script taking a single date, returning: 
	interactions, 
	connected calls, 
	promises logged, 
	payments received.
2. Parameterize the date ONCE at the top so tomorrow you change one character.
3. Run it end-to-end in under a minute.
*/


WITH params AS (
	SELECT DATE '2025-01-02' AS report_date
)
SELECT
	p.report_date,

	(
		SELECT COUNT(*)
		FROM fact_interactions AS fi
		WHERE fi.interaction_date = p.report_date
	) AS interactions,

	COALESCE(
		(
			SELECT SUM(fi.calls_connected)
			FROM fact_interactions AS fi
			WHERE fi.interaction_date =  p.report_date 
		), 0
	) AS connected_calls,

	(
		SELECT COUNT(*)
		FROM fact_ptp_log AS fp
		WHERE fp.ptp_date = p.report_date
	) AS promises_logged,

	(
		SELECT COUNT(*)
		FROM fact_payments AS pay
		WHERE pay.payment_date = p.report_date
	) AS payments_received
FROM params AS p;


/*
Guiding questions: 

1. Are these four numbers even in the same table? 
	
   No. Interactions and connected calls come from fact_interactions, while
   promises logged come from fact_ptp_log and payments received come from
   fact_payments.
	
2. What's the cheapest correct way to combine counts from different tables? 

   Use independent scalar subqueries. This calculates each metric from its
   proper fact table without joining event tables and accidentally multiplying
   rows.

3. On the Tuesday after a Monday holiday, does "yesterday" mean what the boss thinks?

   Not necessarily. A simple "current date minus one day" calculation returns
   Monday, even if it was a holiday. Returning Friday instead requires an
   agreed business-calendar or holiday rule.
	
*/