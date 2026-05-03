What does seeds/ mean?

Seed files are static lookup data you load into tables that never (or rarely) change. In your case:

- Dim_Products — only 3 rows (Credit Card, Personal Loan, Mortgage). That data is fixed.

- Dim_Calendar — date dimension. Generated once, rarely changes.
- Supervisor data — could be a seed if it's stable.

The idea: you don't run a Python generator for 3 rows of product data. You have a SQL INSERT script or CSV you load directly. seeds/ is where those files live.

It separates "data I generate dynamically" (accounts, clients, interactions) from "data that's just reference tables."