# Data Dictionary — condensed (live star schema)

> **Source of truth:** `database/migrations/001_create_tables.sql` (DDL), `003_constraints.sql`. The `docs/data_dictionary.md` file describes a **legacy** naming scheme (`dialer_interactions`, `agents`, `cures_log`) — it's history, not the live model. This file is what the `learning/` tracks actually use.
>
> CSV ↔ table name mapping (`data_sources/raw/`): `Dim_Employees.csv` → `dim_employees`, etc. Facts are split month-by-month, so `Fact_Interactions.csv` appears 12 times (one per month folder).

---

## Dimensions (the "description" side)

### `dim_employees` — 88 rows (8 supervisors SUP-01..08 + 80 agents EID-001..080)

| Column | Notes |
|---|---|
| `agent_id` | PK. `SUP-xx` = supervisor, `EID-xxx` = agent |
| `agent_name` | `employee_name` was renamed to `agent_name` (DDL/view mismatch fix) |
| `employee_type` | `'Supervisor'` / `'Agent'` |
| `supervisor_id` | Self-ref FK to `agent_id`. `NULL` for top-level supervisors |
| `team_name` / `region` | Denormalized onto every employee row (avoids a separate dim) |
| `hire_date` | G2: experience spreads |
| `experience_tier` | `senior` / `mid` / `junior` |
| `cost_per_hour` | G9 cost model (hourly rate, ex-overhead) |
| `tenure_cohort` | `Low` / `Mid` / `High` |
| `contact_skill`, `negotiation_skill`, `efficiency_skill` | 0–1 skill scores (replaced old single `skill_score`) |

### `dim_clients` — 10,000 rows

`client_id` PK · `full_name` · `dob` · `segment` · `income_bracket` (G4, 5 brackets) · `risk_score` (0–1000).

### `dim_products` — 3 rows

| product_id | product_name | product_type | annual_rate_pct | grace_days |
|---|---|---|---|---|
| PRD-01 | Tarjeta | Tarjeta | ~25.99 | short |
| PRD-02 | Prestamo | Prestamo | ~12.50 | mid |
| PRD-03 | Hipoteca | Hipoteca | ~7.25 | long |

Note CSV `product_id` format is `PRD-01` (aligned with generator in later commits).

### `dim_calendar` — 365 rows (full year 2025)

`date` PK · `year`, `quarter`, `month_num`, `month_name` · `iso_week`, `day_of_week`, `day_name` · `is_weekday` (Mon–Fri only — **no weekend interactions**) · `is_month_end` · `is_payday_week` · `payday_factor` (drives self-cure/payment spikes).

### `dim_accounts` — ~15,482 rows

`account_id` PK · `client_id` FK · `product_id` FK · **`product_type`** (denormalized — you rarely need to join `dim_products`) · `open_date` (G1: vintage spread) · `credit_limit` (G3: lognormal per product) · `due_day` · `min_payment` · `initial_balance` · `initial_status`.

---

## Facts (the "measurable" side)

### `fact_interactions` — ~1.36M rows (largest table)

`interaction_id` PK · `interaction_date` **Mon–Fri only** · `interaction_time` · `agent_id` FK · `account_id` FK · `calls_attempted` · `calls_connected` · **`rpc_flag`** (bool) · `call_outcome` (`Wrong_Number`, etc.) · `channel` (`Dialer` 65% / `Manual` 15% / `FICO` 10% / `SMS` 10%) · `aht_seconds` · `acw_seconds` · `rpc_arrears` · `dpd_at_contact`.

**Reading `rpc_flag` + `calls_connected`:** `connected=1, rpc=TRUE` → right party reached. `connected=1, rpc=FALSE` → connected but not the account holder (voicemail/family/wrong number). RPC% = `rpc/(connected)`.

### `fact_ptp_log` — ~59K rows

`ptp_id` PK · `ptp_date` · `ptp_time` · `agent_id` FK · `account_id` FK · `promised_amount` · `promised_date` · `grace_until_date` (≥ promised_date) · **`status`** (`Pending`/`Kept`/`Broken`) · `rpc_arrears_at_contact`.

PTP can only follow an RPC. A promise counts `Kept` when a payment ≥ promised lands within the eval window.

### `fact_payments` — ~49K rows

`payment_id` PK · `payment_date` **weekends allowed** · `payment_time` · `account_id` FK · `ptp_id` (nullable, **no FK** — informational only) · `agent_id` (nullable → self-cure) · `amount_paid` · `payment_method` (`Online`/`Branch/ATM`/`OFI`) · **`is_cured`** (bool) · **`cure_flag`** (`Agent_Cure` / `Self_Cure`) · `dpd_at_payment` · `balance_before/after` · `arrears_before/after` · `amount_to_arrears` · `amount_to_principal` · `dpd_after_payment`.

### `fact_agent_time_log` — ~21K rows

`log_id` PK · `log_date` · `agent_id` FK · `login_time` · `logout_time` · `break_minutes` · **`operational_hours`** · **`tht_hours`** (computed from SUM(aht+acw), real ratio) · **`utilization`** (decimal 0–1, capped at 0.95) · `schedule_hours` · `cost_per_hour` · `total_cost`.

### `fact_eom_snapshot` — ~186K rows (1 row per account per month)

Composite PK (`snapshot_date`, `account_id`). Columns: `snapshot_date` (month-end) · `snapshot_month` (`January_2025`… `December_2025`) · `account_id` FK · `status` (`Activo`/`Mora`) · `balance` · `arrears` · `dpd` · **`dpd_bucket`** (`Current`, `1-30`, `31-60`, `61-90`, `90+`) · `min_payment`.

### `fact_writeoffs` — ~222 rows

`writeoff_id` PK · `writeoff_date` · `account_id` FK · `product_type` · `writeoff_amount` · `balance_before` · `dpd_at_writeoff` (≥91, 5% rate).

---

## Star-schema relationships (live)

```
dim_calendar   1 ──── N  fact_interactions / fact_ptp_log / fact_payments / fact_agent_time_log / fact_eom_snapshot / fact_writeoffs   (by date)
dim_employees  1 ──── N  fact_interactions / fact_ptp_log / fact_payments (nullable) / fact_agent_time_log                              (by agent_id)
dim_accounts   1 ──── N  fact_interactions / fact_ptp_log / fact_payments / fact_eom_snapshot / fact_writeoffs                          (by account_id)
dim_clients    1 ──── N  dim_accounts                                                                                                   (by client_id)
dim_products   1 ──── N  dim_accounts  (join rarely needed: dim_accounts.product_type is denormalized)                                    (by product_id)
```

---

## Status / flag value cheat sheet

| Column | Values | Meaning |
|---|---|---|
| `dim_accounts.initial_status` / `fact_eom_snapshot.status` | `Activo`, `Mora` | current vs delinquent target |
| `fact_payments.cure_flag` | `Agent_Cure`, `Self_Cure` | agent-driven vs automatic recovery |
| `fact_ptp_log.status` | `Pending`, `Kept`, `Broken` | promise state machine |
| `fact_interactions.channel` | `Dialer`, `Manual`, `FICO`, `SMS` | contact channel mix |
| `fact_interactions.call_outcome` | `Wrong_Number`, `Connected`, … | disposition |
| `fact_eom_snapshot.dpd_bucket` | `Current`, `1-30`, `31-60`, `61-90`, `90+` | delinquency band |

## Trap list (things that WILL bite you)

1. `utilization` is a **decimal 0–1**, not a percentage. Multiply by 100 to display.
2. `fact_payments.agent_id` can be **NULL** (self-cure). Filter on `cure_flag`, not on agent_id existence.
3. Join `fact_interactions` to `dim_employees` by `agent_id`, but only Count RPCs on `rpc_flag = TRUE` — never on outcome wording.
4. `dim_products` is nearly always redundant because `dim_accounts.product_type` exists.
5. EOM snapshot is account-month grain → joining it to agent-level facts without dedup duplicates rows.