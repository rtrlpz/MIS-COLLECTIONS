# MIS Collections v7 — Star Schema Dictionary

## Folder layout

```
01_data_sources/raw_csv/
├── shared/                   ← dimension tables (one copy, no date dependency)
│   ├── Dim_Supervisors.csv
│   ├── Dim_Agents.csv
│   ├── Dim_Clients.csv
│   ├── Dim_Products.csv
│   ├── Dim_Accounts.csv
│   └── Dim_Calendar.csv
├── october_2025/             ← transactional facts, split by month
│   ├── Fact_Interactions.csv
│   ├── Fact_PTP_Log.csv
│   ├── Fact_Payments.csv
│   ├── Fact_Agent_Time_Log.csv
│   └── Fact_EOM_Snapshot.csv
├── november_2025/
└── december_2025/
```

---

## Dimension tables

### Dim_Supervisors

| Column | Type | Description |
|---|---|---|
| supervisor_id | VARCHAR | PK — `SUP-01` … `SUP-08` |
| supervisor_name | VARCHAR | Full name |
| team_name | VARCHAR | e.g. "Team 1" |
| region | VARCHAR | North / South / East / West |

---

### Dim_Agents

| Column | Type | Description |
|---|---|---|
| agent_id | VARCHAR | PK — `EID-001` … `EID-080` |
| agent_name | VARCHAR | Full name |
| supervisor_id | VARCHAR | FK → Dim_Supervisors |
| tenure_cohort | VARCHAR | Low / Mid / High — adjusts base rate ranges within config bounds |
| contact_skill | DECIMAL | 0.700–1.300 — multiplies connection_rate and rpc_rate (Gaussian ~N(1.0, 0.15)) |
| negotiation_skill | DECIMAL | 0.700–1.300 — multiplies ptp_rate and kp_tendency (Gaussian ~N(1.0, 0.15)) |
| efficiency_skill | DECIMAL | 0.800–1.200 — multiplies AHT/ACW inversely (lower = faster handle times, Gaussian ~N(1.0, 0.10)) |

> Three independent skill dimensions replace the old single `skill_score`. Each agent draws from three separate Gaussians, allowing nuanced profiles (e.g., high contact skill but low efficiency). Tenure cohorts stratify base rate ranges into thirds — Low draws from the bottom third, Mid from the middle, High from the top third. Useful as BI slicers for funnel and productivity analysis.

---

### Dim_Clients

| Column | Type | Description |
|---|---|---|
| client_id | VARCHAR | PK — `CLI-0001` … `CLI-9999` |
| full_name | VARCHAR | Faker es_ES name |
| dob | DATE | Age 22–68 at simulation start |
| segment | VARCHAR | Retail / Premium / Tarjeta / Prestamo / Hipoteca |
| risk_score | DECIMAL | 400–850 (Gauss μ=650, σ=80) |

---

### Dim_Products

| Column | Type | Description |
|---|---|---|
| product_id | VARCHAR | PK — `PRD-01` / `PRD-02` / `PRD-03` |
| product_name | VARCHAR | Credit Card Standard / Personal Loan 5yr / Mortgage 30yr |
| product_type | VARCHAR | Tarjeta / Prestamo / Hipoteca |
| annual_rate_pct | DECIMAL | 25.99 / 12.50 / 5.85 |
| grace_days | INT | Days before late fees apply (25 / 0 / 0) |
| min_payment_rule | VARCHAR | "2% of Balance" / "Fixed Monthly Installment" |

---

### Dim_Accounts

| Column | Type | Description |
|---|---|---|
| account_id | VARCHAR | PK — `ACC-00001` … |
| client_id | VARCHAR | FK → Dim_Clients |
| product_id | VARCHAR | FK → Dim_Products |
| open_date | DATE | Date account was opened |
| due_day | INT | Day of month payment is due (1–28) |
| min_payment | DECIMAL | Monthly minimum payment at account creation |
| initial_balance | DECIMAL | Outstanding balance at simulation start |
| initial_status | VARCHAR | Activo / Mora |

> `due_day` is the anchor for DPD rolling. DPD only increments when `sim_date.day == due_day` and arrears > 0 — never randomly each day.

---

### Dim_Calendar

| Column | Type | Description |
|---|---|---|
| date | DATE | PK |
| year | INT | 2025 |
| quarter | INT | 1–4 |
| month_num | INT | 1–12 |
| month_name | VARCHAR | October / November / December |
| iso_week | INT | ISO week number |
| day_of_week | INT | 1=Monday … 7=Sunday |
| day_name | VARCHAR | Monday … Sunday |
| is_weekday | BOOL | Payments only process when TRUE |
| is_month_end | BOOL | TRUE on last day of month |
| is_payday_week | BOOL | TRUE when payday_factor > 1.0 |
| payday_factor | DECIMAL | 1.0 (normal) / 1.55 (mid-month) / 1.75 (month-end) |

---

## Fact tables

### Fact_Interactions

One row per (agent, account, day) contact session. Outcome is the dominant result across all call attempts.

| Column | Type | Description |
|---|---|---|
| interaction_id | VARCHAR | PK — `INT-000001` … |
| interaction_date | DATE | Simulation date |
| interaction_time | TIME | HH:MM:SS — within 08:00–21:00 (business hours) |
| agent_id | VARCHAR | FK → Dim_Agents |
| account_id | VARCHAR | FK → Dim_Accounts |
| calls_attempted | INT | Total dial attempts for this session |
| calls_connected | INT | 0 or 1 — whether any attempt connected |
| rpc_flag | VARCHAR | "true" / "false" (Postgres-compatible boolean string) |
| call_outcome | VARCHAR | RPC / Left_Message / Third_Party / Wrong_Number / No_Answer / Voicemail / Busy |
| aht_seconds | INT | Average handle time (seconds); anomaly-spiked for ~1.8% of rows |
| acw_seconds | INT | After-call work time (seconds) |
| rpc_arrears | DECIMAL | Past-due balance at moment of RPC; 0.0 if rpc_flag=false |
| dpd_at_contact | INT | Account DPD at time of call |

**RPC%** = `COUNT(rpc_flag="true") / SUM(calls_connected)`  
**Total RPC Arrears** = `SUM(rpc_arrears WHERE rpc_flag="true")`

---

### Fact_PTP_Log

One row per promise-to-pay event. Status is resolved at end of simulation.

| Column | Type | Description |
|---|---|---|
| ptp_id | VARCHAR | PK — `PTP-000001` … |
| ptp_date | DATE | Date promise was made (taken date) |
| ptp_time | TIME | HH:MM:SS within business hours |
| agent_id | VARCHAR | FK → Dim_Agents |
| account_id | VARCHAR | FK → Dim_Accounts |
| promised_amount | DECIMAL | Dollar amount client committed to pay |
| promised_date | DATE | Client-stated payment date |
| grace_until_date | DATE | Last day before PTP is marked Broken (promised_date + grace_days) |
| status | VARCHAR | Pending / Kept / Broken |
| rpc_arrears_at_contact | DECIMAL | Account arrears at the moment of the RPC that generated this PTP |

**KP%** = `COUNT(status="Kept") / (COUNT(status="Kept") + COUNT(status="Broken"))`  
**PTP%** = `COUNT(ptp_id) / COUNT(Fact_Interactions WHERE rpc_flag="true")`  
**Capped KP$** = `SUMX(FILTER(Fact_PTP_Log, status="Kept"), MIN(promised_amount, rpc_arrears_at_contact))`  
**Capped KP / RPC Arrears** = `[Capped KP$] / SUM(Fact_Interactions[rpc_arrears])`

---

### Fact_Payments

One row per payment transaction. Covers both PTP-linked payments and self-cures.

| Column | Type | Description |
|---|---|---|
| payment_id | VARCHAR | PK — `PAY-000001` … |
| payment_date | DATE | Date payment was received; weekdays only |
| payment_time | TIME | HH:MM:SS within 08:00–17:00 (bank processing hours) |
| account_id | VARCHAR | FK → Dim_Accounts |
| ptp_id | VARCHAR | FK → Fact_PTP_Log; NULL for self-cures |
| agent_id | VARCHAR | FK → Dim_Agents; NULL for self-cures |
| amount_paid | DECIMAL | Actual amount received |
| payment_method | VARCHAR | Online / Branch_ATM / OFI |
| is_cured | BOOL | TRUE if this payment brought arrears to exactly $0 |
| cure_flag | VARCHAR | `None` (partial) / `Self_Cure` (spontaneous, no PTP) / `Agent_Cure` (within active PTP grace window) |
| dpd_at_payment | INT | Account DPD at time of payment (0 if is_cured=TRUE) |

**Cured Amount** = `SUM(amount_paid WHERE is_cured=TRUE)`  
**Total Cures** = `DISTINCTCOUNT(account_id WHERE is_cured=TRUE)`  
**Self-Cure Rate** = `COUNT(cure_flag="Self_Cure") / COUNT(is_cured=TRUE)`

---

### Fact_Agent_Time_Log

One row per agent per day.

| Column | Type | Description |
|---|---|---|
| log_id | VARCHAR | PK — `TML-000001` … |
| log_date | DATE | Working date |
| agent_id | VARCHAR | FK → Dim_Agents |
| login_time | TIME | HH:MM:00 (08:00–09:30 range) |
| logout_time | TIME | HH:MM:00 (login + 8 hours) |
| break_minutes | INT | Total break time (45–90 min) |
| operational_hours | DECIMAL | schedule_hours × utilization |
| tht_hours | DECIMAL | Total Handle Time in hours (AHT+ACW across all calls ÷ 3600) |
| utilization | DECIMAL | Ratio 0.0–1.0 (multiply × 100 for % display in Power BI) |
| schedule_hours | DECIMAL | Contracted shift length (8.0) |

**Utilization%** = `AVERAGE(utilization)` × 100  
**THT Alignment** = `SUM(tht_hours) / SUM(operational_hours)`  
**Cures / THT** = `[Total Cures] / SUM(tht_hours)`

---

### Fact_EOM_Snapshot

One row per account per month-end. Captures portfolio health at a point in time.

| Column | Type | Description |
|---|---|---|
| snapshot_date | DATE | Last calendar day of the month |
| snapshot_month | VARCHAR | e.g. "October_2025" — useful as a BI slicer |
| account_id | VARCHAR | FK → Dim_Accounts |
| status | VARCHAR | Activo / Mora at snapshot time |
| balance | DECIMAL | Outstanding principal balance |
| arrears | DECIMAL | Past-due amount (0 if status=Activo) |
| dpd | INT | Exact days past due at month-end |
| dpd_bucket | VARCHAR | Current / 1-30 / 31-60 / 61-90 / 90+ |
| min_payment | DECIMAL | Minimum payment as of month-end (may have been recalculated) |

**Mora Rate** = `COUNT(status="Mora") / COUNT(account_id)` — filter to snapshot_date  
**DPD Aging** = Use `dpd_bucket` as X axis, `COUNT(account_id)` as Y — one visual tells the whole portfolio health story  
**MoM Balance Change** = Compare `SUM(balance)` across snapshot_months

---

## DPD rolling logic

```
On sim_date where sim_date.day == account.due_day
    AND (year, month) not yet processed for this account:

    IF account.status == "Mora" AND account.arrears > 0:
        account.dpd    += 30
        account.arrears += min(account.min_payment, headroom)
    MARK period as processed

When a payment clears arrears to $0:
    account.dpd    = 0
    account.status = "Activo"
```

DPD is never incremented daily. It only moves on billing cycle misses — one increment per calendar month per account.

---

## Cure classification decision tree

```
Payment arrives on sim_date
│
├── account.arrears → 0?
│   │
│   ├── YES: is_cured = True
│   │   │
│   │   ├── active PTP exists for account?
│   │   │   ├── YES: cure_flag = "Agent_Cure"
│   │   │   └── NO:  cure_flag = "Self_Cure"
│   │
│   └── NO: is_cured = False, cure_flag = "None"
│
└── PTP resolution (if PTP exists):
    ├── sim_date <= grace_until AND applied >= promised × 0.95 → "Kept"
    └── otherwise → "Broken"
```
