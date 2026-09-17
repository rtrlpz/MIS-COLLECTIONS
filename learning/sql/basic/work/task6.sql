-- ## Task 6 — How are clients actually paying? ## --
/*

"I need May payments split by method — Online vs Branch/ATM vs OFI — count and dollars. OFI is supposedly growing; prove it or kill it."

Background: 

Payment method shows where to push digital adoption. 
Counts alone lie: two methods can tie on volume while one triples in dollars.

Your job:

1. May 2025 payments by payment_method: count + total dollars.
2. Add each method's share of dollars.
3. Sort by dollar share descending.

*/ 


SELECT
	fp.payment_method AS payment_method,
	COUNT(*) AS payments_received,
	SUM(fp.amount_paid) AS amount_paid,
	ROUND(
		100.0 * SUM(fp.amount_paid)
		/ NULLIF(SUM(SUM(fp.amount_paid)) OVER(), 0), 
		2
	) AS dollar_share_pct,
	ROUND(
		100.0 * COUNT(*)
		/ NULLIF(SUM(COUNT(*)) OVER(), 0),
		2
	) AS count_share_pct
FROM fact_payments AS fp
WHERE fp.payment_date >= DATE '2025-01-01'
	AND fp.payment_date < DATE '2025-04-01'
GROUP BY fp.payment_method
ORDER BY dollar_share_pct DESC;

/*
Note: This query shows OFI's May payment count, dollars, and shares.
Determining whether OFI is growing requires comparison with earlier months.
*/

/*
Guiding questions:

1. When do count-share and dollar-share disagree strongly?

   They disagree when payment methods have very different average payment sizes.
   A method may process many small payments and have a high count share but a
   low dollar share. Another method may process fewer, larger payments and have
   a low count share but a high dollar share.
   
2. What does that mean business-wise? 

   Payment volume and payment value tell different stories. A method with high
   count share may be convenient and widely used, while a method with high
   dollar share may be more important for cash collection. Management should
   consider both before deciding where to invest, promote digital adoption, or
   change channel strategy.

3. Why cast before dividing for the percentage?

   Casting, or using 100.0 instead of 100, makes SQL use decimal arithmetic.
   If both sides of a division are integers, PostgreSQL removes the decimal
   portion. Decimal arithmetic preserves the precision needed to calculate and
   display an accurate percentage.

*/