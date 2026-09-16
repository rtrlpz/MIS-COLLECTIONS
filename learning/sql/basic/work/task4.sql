-- ## Task 4 — Biggest overdue accounts at month-end ## -- 

/*
Give me the ugliest 25 accounts at March month-end: 
	most arrears first, 
	with product, 
	bucket, 
	and balance. 
That's who we hand to senior collectors on Friday.

Your job:

	1. March 31 snapshot rows only.
	2. Delinquent book only, worst arrears first, cap at 25.
	3. Add product type and balance for context.
*/

-- SELECT * FROM fact_eom_snapshot;
-- SELECT * FROM dim_accounts;
SELECT 
	da.account_id AS account_number,
	da.product_type AS product,
	fe.arrears AS arrears,
	fe.balance AS balance,
	fe.dpd_bucket AS bucket
FROM fact_eom_snapshot AS fe
JOIN dim_accounts AS da
	ON da.account_id = fe.account_id
WHERE fe.snapshot_date = DATE '2025-03-31'
	AND fe.status = 'Mora'
	-- AND da.product_type = 'Tarjeta'
ORDER BY fe.arrears DESC, balance DES
LIMIT 25;


/*
Guiding questions: 

1. Why filter to the snapshot date instead of "latest data"? 
	
	A month-end snapshot shows every account's portfolio position at the same
	point in time: March 31. "Latest data" could refer to different dates or 
	include changes after month-end, making the allocation comparison unfair.
	
2. Arrears vs balance — which one ranks collection urgency, and why?

	Arrears ranks collections urgency because it is the overdue amount requiring
	immediate collection actions. Balance if the account's total outstanding debt. 
	Which can include amounts that are not yet past due.
*/