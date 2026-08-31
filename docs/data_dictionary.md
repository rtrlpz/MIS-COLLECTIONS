# Data dictionary — MIS_CollectionsDB

All tables, columns, data types, constraints, and descriptions for the collections database.
Data covers October 2025. Generated synthetically to simulate a real bank collections environment.

---

## Table of contents

1. [supervisors](#supervisors)
2. [agents](#agents)
3. [clients](#clients)
4. [products](#products)
5. [accounts](#accounts)
6. [payment_schedule](#payment_schedule)
7. [dialer_interactions](#dialer_interactions)
8. [ptp_log](#ptp_log)
9. [cures_log](#cures_log)
10. [agent_time_log](#agent_time_log)
11. [Relationships summary](#relationships-summary)
12. [Load order](#load-order)

---

## supervisors

Stores the team leaders who manage collections agents. Each supervisor oversees a regional team.

| Column | Type | Constraints | Description |
|---|---|---|---|
| supervisor_id | SERIAL | PRIMARY KEY | Auto-incremented unique identifier |
| name | VARCHAR(100) | NOT NULL | Full name of the supervisor |
| team_name | VARCHAR(50) | | Team label, e.g. "Team 1", "Team 2" |
| region | VARCHAR(50) | | Geographic region: North, South, East, West |

**Row count:** 8  
**Notes:** In production, supervisors would be sourced from HR/WFM systems. The `region` field drives regional slicing in Power BI.

---

## agents

Collections agents who handle calls, log PTPs, and record payments. Each agent belongs to one supervisor.

| Column | Type | Constraints | Description |
|---|---|---|---|
| agent_id | SERIAL | PRIMARY KEY | Auto-incremented unique identifier |
| agent_name | VARCHAR(100) | NOT NULL | Full name of the agent |
| supervisor_id | INT | FK → supervisors(supervisor_id) | The supervisor this agent reports to |

**Row count:** 80  
**Notes:** Agent IDs are used as the join key across all transactional tables. In a real environment this would include hire date, channel assignment, and status (active/inactive).

---

## clients

Individual customers who hold one or more accounts with the bank.

| Column | Type | Constraints | Description |
|---|---|---|---|
| client_id | SERIAL | PRIMARY KEY | Auto-incremented unique identifier |
| name | VARCHAR(100) | NOT NULL | Full name of the client |
| dob | DATE | | Date of birth |
| segment | VARCHAR(50) | | Client segment: Tarjeta, Premium, Prestamo, Hipoteca |
| risk_score | DECIMAL(5,2) | | Internal credit risk score (0–1000) |

**Row count:** 10,000  
**Notes:** `segment` reflects the client's primary product relationship. `risk_score` is used to prioritize dialer campaigns — higher-risk accounts are typically assigned to outbound campaigns.

---

## products

Defines the financial products available in the portfolio. Each account is tied to one product.

| Column | Type | Constraints | Description |
|---|---|---|---|
| product_id | SERIAL | PRIMARY KEY | Auto-incremented unique identifier |
| product_name | VARCHAR(100) | NOT NULL | Human-readable product name |
| product_type | VARCHAR(50) | NOT NULL | Category: Tarjeta, Prestamo, Hipoteca |
| interest_rate | DECIMAL(5,2) | | Annual interest rate (%) |
| grace_period_days | INT | | Number of days before late fees apply |
| default_min_payment_rule | VARCHAR(100) | | Rule description for minimum payment calculation |

**Row count:** 3  

| product_id | product_name | product_type | interest_rate |
|---|---|---|---|
| 1 | Credit Card Standard | Tarjeta | 25.99% |
| 2 | Personal Loan 5yr | Prestamo | 12.50% |
| 3 | Mortgage 20yr | Hipoteca | 7.25% |

**Notes:** Product type drives campaign strategy. Tarjeta accounts have the highest delinquency rate and are prioritized for outbound dialer. Hipoteca accounts tend to have larger balances and are handled by senior agents.

---

## accounts

The core entity of the portfolio. One client can have multiple accounts, each for a different product.

| Column | Type | Constraints | Description |
|---|---|---|---|
| account_id | SERIAL | PRIMARY KEY | Auto-incremented unique identifier |
| client_id | INT | NOT NULL, FK → clients(client_id) | The client who owns this account |
| product_id | INT | NOT NULL, FK → products(product_id) | The product type of this account |
| open_date | DATE | NOT NULL | Date the account was opened |
| due_date | DATE | | Monthly payment due date |
| min_payment | DECIMAL(12,2) | NOT NULL | Minimum payment amount required |
| balance | DECIMAL(12,2) | NOT NULL | Current outstanding balance |
| status | VARCHAR(20) | CHECK IN ('Activo', 'Mora', 'Cerrado') | Current account standing |

**Row count:** ~20,000  
**Status values:**
- `Activo` — account is current, no delinquency
- `Mora` — account is delinquent, active collections target
- `Cerrado` — account is closed

**Notes:** The `balance` field represents total outstanding, not just arrears. For arrears, refer to `payment_schedule` where `status = 'Overdue'`. Accounts in `Mora` are the primary target for all dialer campaigns.

---

## payment_schedule

Expected monthly payment records per account. Compared against `cures_log` to determine if accounts have been brought current.

| Column | Type | Constraints | Description |
|---|---|---|---|
| schedule_id | BIGSERIAL | PRIMARY KEY | Auto-incremented unique identifier |
| account_id | INT | NOT NULL, FK → accounts(account_id) | The account this payment belongs to |
| due_date | DATE | NOT NULL | Date the payment was expected |
| expected_amount | DECIMAL(12,2) | NOT NULL | Amount that was due |
| status | VARCHAR(20) | CHECK IN ('Pending', 'Paid', 'Overdue') | Payment outcome |

**Row count:** ~20,000  
**Status values:**
- `Pending` — due date has not passed yet
- `Paid` — payment was received
- `Overdue` — due date passed without payment — this is the arrears amount

**Notes:** `SUM(expected_amount) WHERE status = 'Overdue'` per account gives total arrears. This is used in `v_account_delinquency` and for calculating capped KP amounts.

---

## dialer_interactions

Call records from the dialer system (POM). One row per agent–account interaction per day. This is the highest-volume table.

| Column | Type | Constraints | Description |
|---|---|---|---|
| interaction_id | BIGSERIAL | PRIMARY KEY | Auto-incremented unique identifier |
| date | DATE | NOT NULL | Date the interaction occurred |
| agent_id | INT | NOT NULL, FK → agents(agent_id) | Agent who made/received the call |
| account_id | INT | NOT NULL, FK → accounts(account_id) | Account that was contacted |
| calls_attempted | INT | NOT NULL | Total dial attempts for this interaction |
| calls_connected | INT | NOT NULL | Number of calls that connected |
| rpc_flag | BOOLEAN | NOT NULL | TRUE if the call reached the right party |
| aht_seconds | INT | | Average handle time in seconds (RPC calls) |
| acw_seconds | INT | | After call work time in seconds |

**Row count:** ~29,000  
**Notes:**
- `rpc_flag = TRUE` means a Right Party Contact was made — the agent spoke with the actual account holder, not a third party.
- `calls_connected > 0` but `rpc_flag = FALSE` means the call connected but was not an RPC (answered by family member, voicemail, third party).
- AHT and ACW are only meaningful when `rpc_flag = TRUE`. For reporting, always filter by RPC status when calculating these metrics.
- Channel distribution in the data: Outbound 50%, Inbound 30%, FICO (automated SMS) 20%.

---

## ptp_log

Promise-to-pay records logged by agents during RPC calls. Sourced from the CRM/CACS system.

| Column | Type | Constraints | Description |
|---|---|---|---|
| ptp_id | BIGSERIAL | PRIMARY KEY | Auto-incremented unique identifier |
| date_of_interaction | DATE | NOT NULL | Date the promise was made |
| agent_id | INT | NOT NULL, FK → agents(agent_id) | Agent who recorded the promise |
| account_id | INT | NOT NULL, FK → accounts(account_id) | Account that made the promise |
| amount_promised | DECIMAL(12,2) | NOT NULL | Amount the client committed to paying |
| status | VARCHAR(20) | CHECK IN ('Pending', 'Kept', 'Broken') | Outcome of the promise |

**Row count:** ~64,500  
**Status values:**
- `Pending` — promise was made, evaluation window has not closed
- `Kept` — payment matching the promise was received within 30 days
- `Broken` — no matching payment was received within 30 days

**Notes:** A PTP can only be created after an RPC (`rpc_flag = TRUE` in `dialer_interactions`). The matching logic between `ptp_log` and `cures_log` is: same `account_id`, `payment_date` within 30 days of `date_of_interaction`, and `amount_paid >= amount_promised`. The capped KP amount is `LEAST(amount_promised, account.balance)` to avoid overcounting.

---

## cures_log

Actual payment records. A "cure" means a delinquent account made a payment, reducing or eliminating its arrears balance. Sourced from the core banking system.

| Column | Type | Constraints | Description |
|---|---|---|---|
| cure_id | BIGSERIAL | PRIMARY KEY | Auto-incremented unique identifier |
| payment_date | DATE | NOT NULL | Date the payment was received |
| agent_id | INT | NOT NULL, FK → agents(agent_id) | Agent credited for the cure |
| account_id | INT | NOT NULL, FK → accounts(account_id) | Account that made the payment |
| amount_paid | DECIMAL(12,2) | NOT NULL | Amount received |
| payment_method | VARCHAR(50) | CHECK IN ('Online', 'Branch/ATM', 'OFI') | How the payment was made |

**Row count:** ~3,300  
**Payment method values:**
- `Online` — digital payment through the bank's app or website
- `Branch/ATM` — in-person payment at a branch or ATM
- `OFI` — other financial institution transfer

**Notes:** Agent attribution in cures is based on the last agent who had an RPC with the account before the payment was made. This is a simplified attribution model — real environments often use more complex attribution logic. A "Cure" for KPI purposes means an account's delinquent balance was brought to ≤ $0.

---

## agent_time_log

Daily schedule and time-on-task records per agent. Used for all productivity and utilization calculations. Sourced from WFM (Workforce Management) system.

| Column | Type | Constraints | Description |
|---|---|---|---|
| time_id | BIGSERIAL | PRIMARY KEY | Auto-incremented unique identifier |
| date | DATE | NOT NULL | The working date |
| agent_id | INT | NOT NULL, FK → agents(agent_id) | The agent this log belongs to |
| login_time | TIME | NOT NULL | Time the agent logged into the dialer |
| logout_time | TIME | NOT NULL | Time the agent logged out |
| break_minutes | INT | | Total break time taken (minutes) |
| operational_hours | DECIMAL(5,2) | | Actual hours actively working (logged in minus breaks) |
| tht_hours | DECIMAL(5,2) | | Total Handle Time — inbound + outbound call time (hours) |
| schedule_time | TIMESTAMP | | Planned schedule start datetime from WFM |
| utilization | DECIMAL(5,2) | | `operational_hours / scheduled_hours` as a decimal (e.g. 0.73 = 73%) |

**Row count:** ~2,480 (80 agents × ~31 days)  
**Notes:**
- `tht_hours` is the key denominator for several KPIs (Cures/THT, RPC/Op Hr).
- `utilization` is pre-calculated in the source data but can also be derived as `tht_hours / operational_hours`.
- Agents with `utilization < 0.60` are typically flagged for coaching.

---

## Relationships summary

```
supervisors (1) ──── (N) agents
agents      (1) ──── (N) dialer_interactions
agents      (1) ──── (N) ptp_log
agents      (1) ──── (N) cures_log
agents      (1) ──── (N) agent_time_log
clients     (1) ──── (N) accounts
products    (1) ──── (N) accounts
accounts    (1) ──── (N) payment_schedule
accounts    (1) ──── (N) dialer_interactions
accounts    (1) ──── (N) ptp_log
accounts    (1) ──── (N) cures_log
```

---

## Load order

Tables must be loaded in this order to satisfy foreign key constraints:

1. `supervisors`
2. `agents`
3. `clients`
4. `products`
5. `accounts`
6. `payment_schedule`
7. `dialer_interactions`
8. `ptp_log`
9. `cures_log`
10. `agent_time_log`

> In a real environment these tables would live under a dedicated schema (e.g. `collections.agents`) to separate concerns by source system and manage role-based access permissions.
