-- ## Task 8 — House rules check: weekends ## -- 

/*

	Our data rules say no calls happen on weekends but payments can. 
	I don't take rules on faith — prove both from the data, one query each.

Background: 
The generator encodes business rules; verifying them from data is how analysts catch broken pipelines early. 
This exact check has caught real bugs in this project's history.

Your job:
	
	1. Count interactions landing on Sat/Sun (any month).
	2. Count weekend payments.
	3. Write one sentence stating each rule as verified true/false.
*/ 

SELECT 
	'weekend_interaction' AS rule_check,
	COUNT(*) AS violations
FROM fact_interactions 
WHERE EXTRACT(ISODOW FROM interaction_date) IN (6, 7)

UNION ALL

SELECT
	'weekend_payments',
	COUNT(*)
FROM fact_payments
WHERE EXTRACT(ISODOW FROM payment_date) IN (6, 7);

/*

Guiding questions: 

1. Which date function gives you weekday without locale tricks? 

	EXTRACT(ISODOW FROM date_column) gives a stable ISO weekday number: 
	Monday = 1 through Sunday = 7. It avoids locale-dependent day-name functions.

2. If weekend interactions were nonzero, what would you do first — doubt the data or doubt the rule?

	I would first validate the unexpected data—not blindly assume either the data or the rule is wrong. 
	I’d confirm the query and source records, then trace whether the generator created weekend interactions or whether the ETL transformed dates incorrectly. 
	Existing validation and tests make a pipeline defect less likely, but they do not rule one out.

*/
