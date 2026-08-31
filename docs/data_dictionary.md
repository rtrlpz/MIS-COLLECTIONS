# Data Dictionary — MIS_CollectionsDB

All tables, columns, data types, constraints, and descriptions for the collections database.
Data covers January–December 2025 (12 months). Generated synthetically to simulate a real bank collections environment.
**Current schema version:** 16 tables (8 dim + 7 fact + etl_load_log) — see `database/migrations/001_create_tables.sql`

---

## Table of contents

1. [dim_employees](#dim_employees)
2. [dim_employee_history](#dim_employee_history)
3. [dim_strategy](#dim_strategy)
4. [dim_clients](#dim_clients)
5. [dim_products](#dim_products)
6. [dim_delinquency_bucket](#dim_delinquency_bucket)
7. [dim_calendar](#dim_calendar)
8. [dim_accounts](#dim_accounts)
9. [fact_interactions](#fact_interactions)
10. [fact_ptp_log](#fact_ptp_log)
11. [fact_payments](#fact_payments)
12. [fact_agent_time_log](#fact_agent_time_log)
13. [fact_eom_snapshot](#fact_eom_snapshot)
14. [fact_writeoffs](#fact_writeoffs)
15. [fact_recoveries](#fact_recoveries)
16. [etl_load_log](#etl_load_log)
17. [Relationships summary](#relationships-summary)
18. [Load order](#load-order)

---

## dim_employees

Unified table for supervisors and agents (self-referencing FK). Denormalized team/region/skills for star-schema performance.

| Column | Type | Constraints | Description |
|---|---|---|---|
| agent_id | VARCHAR(20) | PRIMARY KEY | Unique identifier (SUP-01..08, EID-001..080) |
| agent_name | VARCHAR(100) | NOT NULL | Full name |
| supervisor_id | VARCHAR(20) | FK → dim_employees(agent_id) | Supervisor's agent_id (NULL for supervisors) |
| team_name | VARCHAR(50) | NOT NULL | Team label (e.g., "Team Alpha") |
| region | VARCHAR(50) | NOT NULL | Geographic region: North, South, East, West |
| hire_date | DATE | NOT NULL | Employment start date |
| experience_tier | VARCHAR(20) | CHECK IN ('Senior','Mid','Junior') | Tenure-based tier |
| cost_per_hour | DECIMAL(8,2) | NOT NULL | Hourly cost including 1.25× overhead |
| tenure_cohort | VARCHAR(20) | CHECK IN ('Low','Mid','High') | Tenure bucket for drift calibration |
| contact_skill | DECIMAL(4,3) | NOT NULL | Contact rate skill multiplier (0.8–1.2) |
| negotiation_skill | DECIMAL(4,3) | NOT NULL | PTP/KP rate skill multiplier (0.8–1.2) |
| efficiency_skill | DECIMAL(4,3) | NOT NULL | AHT/ACW inverse skill multiplier (0.8–1.2) |
| is_supervisor | BOOLEAN | NOT NULL | TRUE for 8 supervisors, FALSE for 80 agents |
| valid_from | DATE | NOT NULL | SCD2 validity start |
| valid_to | DATE | | SCD2 validity end (NULL = current) |
| is_current | BOOLEAN | NOT NULL | TRUE for current version |

**Row count:** 88 (8 supervisors + 80 agents)  
**Notes:** Self-ref FK enables supervisor↔agent hierarchy. Denormalized fields avoid joins to dim_supervisors (legacy). SCD2 tracked in dim_employee_history for 6 Jul-1 transfers.

---

## dim_employee_history

SCD Type 2 history of organizational attributes (team, supervisor, region). One row per version.

| Column | Type | Constraints | Description |
|---|---|---|---|
| history_id | BIGSERIAL | PRIMARY KEY | Surrogate key |
| agent_id | VARCHAR(20) | NOT NULL, FK → dim_employees(agent_id) | Employee reference |
| team_name | VARCHAR(50) | NOT NULL | Team at this version |
| supervisor_id | VARCHAR(20) | FK → dim_employees(agent_id) | Supervisor at this version |
| region | VARCHAR(50) | NOT NULL | Region at this version |
| valid_from | DATE | NOT NULL | Version start date |
| valid_to | DATE | | Version end date (NULL = current) |
| is_current | BOOLEAN | NOT NULL | TRUE for current version |

**Row count:** 94 (88 current + 6 historical from Jul-1 transfers)  
**Notes:** Enables point-in-time team attribution. Generator creates 6 mid-year transfers effective 2025-07-01.

---

## dim_strategy

Champion-challenger strategy arms for attribution analysis.

| Column | Type | Constraints | Description |
|---|---|---|---|
| strategy_id | VARCHAR(20) | PRIMARY KEY | STG-01, STG-02, STG-03 |
| strategy_name | VARCHAR(50) | NOT NULL | Champion_Dialer, Challenger_SMS_First, Challenger_FICO_Priority |
| allocation_pct | DECIMAL(5,2) | NOT NULL | Target split: 60 / 25 / 15 |
| conn_multiplier | DECIMAL(4,3) | NOT NULL | Connection rate multiplier |
| rpc_multiplier | DECIMAL(4,3) | NOT NULL | RPC rate multiplier |

**Row count:** 3  
**Notes:** Each account gets ONE stable arm (hash of account_id). Arm drives channel mix AND efficacy multipliers. Actual split: 58.9/26.2/14.9.

---

## dim_clients

Individual customers holding accounts.

| Column | Type | Constraints | Description |
|---|---|---|---|
| client_id | VARCHAR(20) | PRIMARY KEY | CLI-00001..CLI-10000 |
| client_name | VARCHAR(100) | NOT NULL | Full name |
| dob | DATE | NOT NULL | Date of birth |
| segment | VARCHAR(50) | NOT NULL | Retail, Mass Affluent, Affluent, Small Business, Corporate |
| risk_score | DECIMAL(5,2) | NOT NULL | Internal credit risk score (0–1000) |
| income_bracket | VARCHAR(50) | NOT NULL | Income segment (5 weighted brackets) |

**Row count:** 10,000  
**Notes:** Segment renamed in P4 to avoid product-name collision. Income bracket added in G4.

---

## dim_products

Financial products in the portfolio.

| Column | Type | Constraints | Description |
|---|---|---|---|
| product_id | VARCHAR(20) | PRIMARY KEY | PRD-01, PRD-02, PRD-03 |
| product_name | VARCHAR(100) | NOT NULL | Credit Card, Personal Loan, Mortgage |
| product_type | VARCHAR(50) | NOT NULL | Tarjeta, Prestamo, Hipoteca |
| interest_rate | DECIMAL(5,2) | NOT NULL | Annual rate (%) |
| grace_period_days | INT | NOT NULL | Days before late fees |

**Row count:** 3  
**Notes:** Product_type denormalized to dim_accounts for query performance.

---

## dim_delinquency_bucket

Ordered DPD buckets for migration analysis.

| Column | Type | Constraints | Description |
|---|---|---|---|
| bucket_key | INT | PRIMARY KEY | 1=Current, 2=1-30, 3=31-60, 4=61-90, 5=90+ |
| bucket_label | VARCHAR(20) | NOT NULL | Current, 1-30, 31-60, 61-90, 90+ |
| sort_order | INT | NOT NULL | 1..5 for ordering |
| days_from | INT | NOT NULL | Lower DPD bound |
| days_to | INT | | Upper DPD bound (NULL for 90+) |

**Row count:** 5  
**Notes:** Replaces inline CASE maps in migration matrix. FK on fact_eom_snapshot.bucket_key.

---

## dim_calendar

Date dimension with fiscal attributes.

| Column | Type | Constraints | Description |
|---|---|---|---|
| date | DATE | PRIMARY KEY | Calendar date |
| year | INT | NOT NULL | Year |
| month | INT | NOT NULL | 1–12 |
| month_name | VARCHAR(20) | NOT NULL | January–December |
| day | INT | NOT NULL | 1–31 |
| day_of_week | INT | NOT NULL | 1=Mon..7=Sun |
| is_weekend | BOOLEAN | NOT NULL | Sat/Sun |
| is_holiday | BOOLEAN | NOT NULL | Public holidays |
| iso_week | INT | NOT NULL | ISO week number |
| iso_year | INT | NOT NULL | ISO year |
| fiscal_month | INT | NOT NULL | Fiscal month (aligned to calendar) |
| fiscal_quarter | INT | NOT NULL | Fiscal quarter |
| payday_flag | BOOLEAN | NOT NULL | Payday window (days 13-17 + last 3 days) |

**Row count:** 486 (Dec 2024 → Mar 2026)  
**Notes:** Prepended Dec 2024 + 90-day tail for PTP/grace spill-over FKs. Extended in seed 004.

---

## dim_accounts

Core portfolio entity with denormalized product_type.

| Column | Type | Constraints | Description |
|---|---|---|---|
| account_id | VARCHAR(20) | PRIMARY KEY | ACC-00001.. |
| client_id | VARCHAR(20) | NOT NULL, FK → dim_clients(client_id) | Account owner |
| product_id | VARCHAR(20) | NOT NULL, FK → dim_products(product_id) | Product FK |
| product_type | VARCHAR(50) | NOT NULL, CHECK IN ('Tarjeta','Prestamo','Hipoteca') | Denormalized from dim_products |
| open_date | DATE | NOT NULL | Account origination date (23-month spread) |
| credit_limit | DECIMAL(12,2) | NOT NULL | Lognormal per product (Tarjeta ~$4.9K, Prestamo ~$13K, Hipoteca ~$268K) |
| balance | DECIMAL(12,2) | NOT NULL | Current outstanding principal |
| dpd | INT | NOT NULL | Days past due at snapshot |
| status | VARCHAR(20) | CHECK IN ('Activo','Mora','WrittenOff') | Current standing |
| ever_mora | BOOLEAN | NOT NULL | TRUE if ever entered Mora (for monitoring pool) |
| cure_count | INT | NOT NULL DEFAULT 0 | Times cured from Mora (progressive severity) |
| strategy_id | VARCHAR(20) | FK → dim_strategy(strategy_id) | Assigned strategy arm |

**Row count:** ~15,480  
**Notes:** product_type avoids snowflake join. ever_mora restricts monitoring pool. cure_count drives progressive severity decay.

---

## fact_interactions

Dialer call records (weekdays only). Highest-volume fact table.

| Column | Type | Constraints | Description |
|---|---|---|---|
| interaction_id | BIGSERIAL | PRIMARY KEY | Surrogate key |
| interaction_date | DATE | NOT NULL, FK → dim_calendar(date) | Call date (Mon–Fri only) |
| agent_id | VARCHAR(20) | NOT NULL, FK → dim_employees(agent_id) | Handling agent |
| account_id | VARCHAR(20) | NOT NULL, FK → dim_accounts(account_id) | Contacted account |
| strategy_id | VARCHAR(20) | FK → dim_strategy(strategy_id) | Strategy arm for this interaction |
| channel | VARCHAR(20) | CHECK IN ('Dialer','Manual','FICO','SMS') | Contact channel |
| calls_attempted | INT | NOT NULL | Dial attempts |
| calls_connected | INT | NOT NULL | Connected calls |
| rpc_flag | BOOLEAN | NOT NULL | Right Party Contact |
| aht_seconds | INT | | Average Handle Time (RPC only) |
| acw_seconds | INT | | After Call Work (RPC only) |
| dpd_at_contact | INT | NOT NULL | Account DPD at interaction |

**Row count:** ~1.34M (12 months)  
**Notes:** Weekday-only (bug fixed). Channel mix: 65% Dialer, 15% Manual, 10% FICO, 10% SMS. Monthly drift ±8% per agent.

---

## fact_ptp_log

Promise-to-pay events. ~35% are multi-part installment plans.

| Column | Type | Constraints | Description |
|---|---|---|---|
| ptp_id | BIGSERIAL | PRIMARY KEY | Surrogate key |
| ptp_date | DATE | NOT NULL, FK → dim_calendar(date) | Date promise made |
| agent_id | VARCHAR(20) | NOT NULL, FK → dim_employees(agent_id) | Recording agent |
| account_id | VARCHAR(20) | NOT NULL, FK → dim_accounts(account_id) | Promising account |
| strategy_id | VARCHAR(20) | FK → dim_strategy(strategy_id) | Strategy arm at PTP |
| promised_amount | DECIMAL(12,2) | NOT NULL | Committed amount |
| promised_date | DATE | NOT NULL | Due date for payment |
| grace_until_date | DATE | NOT NULL | Grace period end |
| installment_seq | INT | NOT NULL DEFAULT 1 | Part number (1, 2, ...) |
| installment_total | INT | NOT NULL DEFAULT 1 | Total parts in plan |
| status | VARCHAR(20) | CHECK IN ('Pending','Kept','Broken') | Outcome (cumulative ≥95% = Kept) |

**Row count:** ~106K (12 months)  
**Notes:** Multi-part plans resolve on cumulative paid ≥95% within grace. installment_seq/total track parts.

---

## fact_payments

Payment transactions (weekends allowed). Links to PTP via ptp_id for installments.

| Column | Type | Constraints | Description |
|---|---|---|---|
| payment_id | BIGSERIAL | PRIMARY KEY | Surrogate key |
| payment_date | DATE | NOT NULL, FK → dim_calendar(date) | Date payment made (any day) |
| agent_id | VARCHAR(20) | FK → dim_employees(agent_id) | Credited agent (NULL for self-cure) |
| account_id | VARCHAR(20) | NOT NULL, FK → dim_accounts(account_id) | Paying account |
| ptp_id | BIGINT | | Link to fact_ptp_log (informational, no FK) |
| amount_paid | DECIMAL(12,2) | NOT NULL | Amount received |
| is_cured | BOOLEAN | NOT NULL | TRUE if payment brought DPD to 0 |
| cure_flag | VARCHAR(20) | CHECK IN ('Agent-Assisted','Self-Cure','None') | Cure attribution |
| dpd_at_payment | INT | NOT NULL | True DPD before payment (I6 fix) |

**Row count:** ~121K (12 months)  
**Notes:** Weekends allowed. ptp_id has NO FK constraint (avoids fact-to-fact chain). Self-cure payday boost 2.5×.

---

## fact_agent_time_log

Daily agent time, utilization, and cost.

| Column | Type | Constraints | Description |
|---|---|---|---|
| log_id | BIGSERIAL | PRIMARY KEY | Surrogate key |
| log_date | DATE | NOT NULL, FK → dim_calendar(date) | Working date |
| agent_id | VARCHAR(20) | NOT NULL, FK → dim_employees(agent_id) | Agent |
| login_time | TIME | NOT NULL | Shift start |
| logout_time | TIME | NOT NULL | Shift end |
| break_minutes | INT | NOT NULL | Break time |
| operational_hours | DECIMAL(5,2) | NOT NULL | login→logout minus breaks |
| tht_hours | DECIMAL(5,2) | NOT NULL | Σ(AHT+ACW) from interactions |
| total_cost | DECIMAL(10,2) | NOT NULL | operational_hours × cost_per_hour |
| utilization | DECIMAL(5,4) | NOT NULL | tht_seconds / (op_hours × 3600), capped 0.95 |

**Row count:** ~21K (12 months)  
**Notes:** THT from actual interactions (not synthetic). Utilization capped at 0.95. Cost model: Senior $38, Mid $32, Junior $26/hr + 1.25× overhead.

---

## fact_eom_snapshot

End-of-month account snapshots. Written-off accounts exit the book.

| Column | Type | Constraints | Description |
|---|---|---|---|
| snapshot_date | DATE | NOT NULL, FK → dim_calendar(date) | Month-end date |
| account_id | VARCHAR(20) | NOT NULL, FK → dim_accounts(account_id) | Account |
| bucket_key | INT | NOT NULL, FK → dim_delinquency_bucket(bucket_key) | Delinquency bucket |
| balance | DECIMAL(12,2) | NOT NULL | Outstanding principal |
| arrears | DECIMAL(12,2) | NOT NULL | Past-due amount |
| dpd | INT | NOT NULL | Days past due |

**Row count:** ~183K (12 months)  
**Notes:** Composite PK (snapshot_date, account_id). Post-writeoff snapshots removed (migration 007, −1,574 rows). Semi-additive: balance sums across accounts, not time.

---

## fact_writeoffs

Write-off events at 91+ DPD (5% rate).

| Column | Type | Constraints | Description |
|---|---|---|---|
| writeoff_id | BIGSERIAL | PRIMARY KEY | Surrogate key |
| writeoff_date | DATE | NOT NULL, FK → dim_calendar(date) | Write-off date |
| account_id | VARCHAR(20) | NOT NULL, FK → dim_accounts(account_id) | Written-off account |
| balance_before | DECIMAL(12,2) | NOT NULL | Principal at write-off |
| recoverable_balance | DECIMAL(12,2) | NOT NULL | Balance eligible for recovery (10–35% of balance_before) |

**Row count:** ~441 (12 months)  
**Notes:** Created in G6. Generator emits at 91+ DPD. recoverable_balance seeds fact_recoveries.

---

## fact_recoveries

Post-charge-off partial collections.

| Column | Type | Constraints | Description |
|---|---|---|---|
| recovery_id | BIGSERIAL | PRIMARY KEY | Surrogate key |
| recovery_date | DATE | NOT NULL, FK → dim_calendar(date) | Collection date |
| account_id | VARCHAR(20) | NOT NULL, FK → dim_accounts(account_id) | Recovered account |
| writeoff_id | BIGINT | NOT NULL, FK → fact_writeoffs(writeoff_id) | Source write-off |
| amount_recovered | DECIMAL(12,2) | NOT NULL | Partial amount collected |
| recoverable_remaining | DECIMAL(12,2) | NOT NULL | Balance left to recover |

**Row count:** ~323 (Feb–Dec 2025)  
**Notes:** Created in P4/N4. Daily probability 0.004, collects 10–35% of remainder. Drains recoverable_balance.

---

## etl_load_log

ETL metadata: one row per table per load.

| Column | Type | Constraints | Description |
|---|---|---|---|
| load_id | BIGSERIAL | PRIMARY KEY | Surrogate key |
| table_name | VARCHAR(50) | NOT NULL | Target table |
| loaded_at | TIMESTAMPTZ | NOT NULL | Load timestamp |
| rows_loaded | BIGINT | NOT NULL | Row count |
| status | VARCHAR(20) | CHECK IN ('SUCCESS','PARTIAL','FAILED') | Load outcome |
| csv_checksum | CHAR(64) | | SHA256 of source CSV |
| elapsed_seconds | DECIMAL(8,2) | | Load duration |

**Row count:** Variable (per ETL run)  
**Notes:** Supports --incremental mode (skips unchanged months via checksum).

---

## Relationships summary

```
dim_employees (1) ──── (N) dim_employees        [self-ref: supervisor_id]
dim_employees (1) ──── (N) dim_employee_history [agent_id]
dim_strategy  (1) ──── (N) dim_accounts         [strategy_id]
dim_clients   (1) ──── (N) dim_accounts         [client_id]
dim_products  (1) ──── (N) dim_accounts         [product_id]
dim_delinquency_bucket (1) ── (N) fact_eom_snapshot [bucket_key]
dim_calendar  (1) ──── (N) fact_interactions    [interaction_date]
dim_calendar  (1) ──── (N) fact_ptp_log         [ptp_date]
dim_calendar  (1) ──── (N) fact_payments        [payment_date]
dim_calendar  (1) ──── (N) fact_agent_time_log  [log_date]
dim_calendar  (1) ──── (N) fact_eom_snapshot    [snapshot_date]
dim_calendar  (1) ──── (N) fact_writeoffs       [writeoff_date]
dim_calendar  (1) ──── (N) fact_recoveries      [recovery_date]
dim_employees (1) ──── (N) fact_interactions    [agent_id]
dim_employees (1) ──── (N) fact_ptp_log         [agent_id]
dim_employees (1) ──── (N) fact_payments        [agent_id]
dim_employees (1) ──── (N) fact_agent_time_log  [agent_id]
dim_accounts  (1) ──── (N) fact_interactions    [account_id]
dim_accounts  (1) ──── (N) fact_ptp_log         [account_id]
dim_accounts  (1) ──── (N) fact_payments        [account_id]
dim_accounts  (1) ──── (N) fact_eom_snapshot    [account_id]
dim_accounts  (1) ──── (N) fact_writeoffs       [account_id]
dim_accounts  (1) ──── (N) fact_recoveries      [account_id]
fact_writeoffs (1) ── (N) fact_recoveries       [writeoff_id]
```

---

## Load order

Tables must be loaded in this order to satisfy foreign key constraints:

1. `dim_products` (seed)
2. `dim_delinquency_bucket` (seed)
3. `dim_calendar` (seed + extension)
4. `dim_strategy` (seed)
5. `dim_clients` (generated)
6. `dim_employees` (generated)
7. `dim_accounts` (generated)
8. `dim_employee_history` (generated)
9. `fact_interactions` (generated)
10. `fact_ptp_log` (generated)
11. `fact_payments` (generated)
12. `fact_agent_time_log` (generated)
13. `fact_eom_snapshot` (generated)
14. `fact_writeoffs` (generated)
15. `fact_recoveries` (generated)
16. `etl_load_log` (auto-created by ETL)

> The ETL (`etl/data_to_pg.py`) handles truncation and loading in dependency order. Seeds use `ON CONFLICT DO NOTHING` for idempotency.