-- ## Task 7 — What do we collect? Products 101 ## --

/*

You know this DB, right? One query: accounts per product plus average credit limit. 
And tell me if the denormalized product column makes the join unnecessary — I keep forgetting its name.

Background: 
Three retail products: 
	Tarjeta (credit card), 
	Prestamo (personal loan), 
	Hipoteca (mortgage). 
The accounts table carries product_type directly — a deliberate design choice you should understand.

Your job:

	1. Accounts per product + average credit limit.
	2. Answer the favor: prove whether joining the products dimension would change anything.
*/

-- SELECT * FROM dim_accounts;
SELECT 
	da.product_type AS product,
	COUNT(*) AS accounts,
	ROUND(AVG(da.credit_limit), 2)
FROM dim_accounts AS da
GROUP BY da.product_typer
ORDER BY accounts DESC; 

/*
Guiding questions: 

1. If product_type on the account can disagree with the product table's name, which would you trust — and how would you check?

   I would treat dim_products as the canonical product reference because it is
   the normalized product dimension. I would join dim_accounts to dim_products
   by product_id and check whether product_type values differ. Any mismatch
   should be investigated against the source system or data-governance owner.	
   
2. What does average credit limit tell you that count alone doesn't?

   Account count shows how many accounts each product has. Average credit limit
   shows the typical credit capacity and potential exposure per account. It is
   not the same as actual portfolio balance, but it adds context about the
   relative size of each product's customers.
   
*/ 