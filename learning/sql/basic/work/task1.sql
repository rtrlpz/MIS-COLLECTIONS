-- Task 1 — Take inventory of the database

/*
Welcome aboard. 
Before you touch any report, show me you know the lay of the land: 
    - list every table we own, 
    - tell me which are facts and which are dimensions, 
    - and give me a one-line description of what each one is for. 
This becomes your cheat sheet.

A strong repeatable RDBMS “discovery checklist” is:
	1. List schemas.
	2. List base tables and views in the target schema.
	3. Inspect each table’s columns, data types, nullability, and defaults.
	4. Identify primary keys.
	5. Identify foreign keys and draw the relationships.
	6. List indexes and unique constraints.
	7. Count rows and compare table sizes.
	8. Sample a few rows from each table.
	9. Check date coverage: minimum and maximum dates.
	10. Profile important fields: null rates, distinct counts, duplicates, invalid values.
	11. Compare the physical schema against the data dictionary/business definitions.
	12. Document table grain: exactly what one row represents.
*/

-- a. List all tables from the system catalog (don't type them from memory).
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
	AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- b. Count rows in every  known table
SELECT 'fact_interactions' AS t, COUNT(*) AS rows FROM fact_interactions
UNION ALL SELECT 'fact_ptp_log', COUNT(*) FROM fact_ptp_log
UNION ALL SELECT 'fact_agent_time_log', COUNT(*) FROM fact_agent_time_log
UNION ALL SELECT 'fact_recoveries', COUNT(*) FROM fact_recoveries
UNION ALL SELECT 'fact_payments', COUNT(*) FROM fact_payments
UNION ALL SELECT 'fact_writeoffs', COUNT(*) FROM fact_writeoffs
UNION ALL SELECT 'fact_eom_snapshot', COUNT(*) FROM fact_eom_snapshot
UNION ALL SELECT 'dim_accounts', COUNT(*) FROM dim_accounts
UNION ALL SELECT 'dim_products', COUNT(*) FROM dim_products
UNION ALL SELECT 'dim_employees', COUNT(*) FROM dim_employees
UNION ALL SELECT 'dim_strategy', COUNT(*) FROM dim_strategy
UNION ALL SELECT 'dim_employee_history', COUNT(*) FROM dim_employee_history
UNION ALL SELECT 'dim_delinquency_bucket', COUNT(*) FROM dim_delinquency_bucket
UNION ALL SELECT 'dim_calendar', COUNT(*) FROM dim_calendar
UNION ALL SELECT 'dim_clients', COUNT(*) FROM dim_clients
UNION ALL SELECT 'etl_load_log', COUNT(*) FROM etl_load_log
ORDER BY rows DESC;

-- c. Classify each: fact vs dimension, plus the grain (what one row is).
/*
Dimension
	- dim_employees: one row per employees.
	- dim_employee_history: one row per employee effective-dated assignment/history period.
	- dim_clients: one row per client.
	- dim_products: one row per product.
	- dim_accounts: one row per account.
	- dim_calendar: one row per calendar date.
	- dim_delinquency_bucket: one row per ordered delinquency range.
	- dim_strategy: one row per collections strategy definition. 

Facts
	- fact_interactions: one row per collection interaction; joins to employee, account,
	calendar, and strategy.
	- fact_ptp_log: one row per promise-to-pay event/plan; joins to employee, account, 
	calendar.
	- fact_payments: one row pera payment transaction; joins to account, employee,
	calendar, and may logically link to a promise to pay.
	- fact_agent_time_log: one row per agent workday/time-log entry; joins to employee,
	and calendar.
	- fact_eom_snapshot: one row per account at each month-end snapshot; joins to
  	account, calendar, and delinquency bucket.
	- fact_writeoffs: one row per post-write-off event; joins to account, calendar, and product/
	delinquency context as modeled.
	- fact_recoveries: one row per post-write-off recovery event; joins to calendar.

Operational
	- etl_load_log: one row per ETL load/run, 
	recording pipeline audit details.

The repeatable workflow for any unfamiliar database is: 
	→ discover tables from the catalog 
	→ discover columns and constraints from the catalog 
	→ use row counts as a sanity check 
	→ use documentation/sample data to determine the true business grain.
*/

-- d. For each fact, name its join keys back to dimensions.
SELECT 
	tc.table_name AS fact_table,
	kcu.column_name AS fact_key_column,
	ccu.table_name AS dimension_table,
	ccu.column_name AS dimension_key_column
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
	ON tc.constraint_catalog = kcu.constraint_catalog
	AND tc.constraint_schema = kcu.constraint_schema
	AND tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
	ON tc.constraint_catalog = ccu.constraint_catalog
	AND tc.constraint_schema = ccu.constraint_schema
	AND tc.constraint_name = ccu.constraint_name
WHERE tc.table_schema = 'public'
	AND tc.constraint_type = 'FOREIGN KEY'
	AND tc.table_name LIKE 'fact_%'
ORDER BY tc.table_name, fact_key_column;

/* 
Guiding questions:
1. Why are facts big and dims small? 
	Fact tables capture day-to-day business activity, such as customer interactions, payments,
	promises to pay, and month-end account snapshots. Because these events happen repeatedly over time,
	fact_tables grow quickly.
	
	Dimension tables hold descriptive information, such as employees, accounts, products, and dates.
	These tables contain reusable descriptive context instead.
	
2. Which fact looks suspiciously small?, and what does that say about its grain? 
	fact_recoveries is the smallest tfact able, with 323 records. 
	This makes sense because a recovery is a relatively rare event that happens only after
	an account has been written off. Its grain is one row per post-write-off recovery event,
	so it is still a fact table even though it has few rows.

3. Which table exists so every other date has a home?
	dim_calendar is the shared date dimension. Facts such as interactions, payments, promises to pay,
	snapshots, and write-offs link to it through their date fields. This lets reports use the same
	definitions for days, weeks, months, quarters, and years across the entire model.
*/

