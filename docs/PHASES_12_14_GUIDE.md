# Phases 12-14 — Enterprise Collections Infrastructure

> **Goal:** Evolve from a generic bank collections simulation into a Scotiabank-authentic model with CACS treatment strategies, predictive dialer, WFM, payment arrangements, and CRM contact governance.

---

## Summary

| Phase | System | Focus | New Tables | Effort |
|-------|--------|-------|------------|--------|
| **12** | CACS | Collections strategies, queues, workbins, treatment paths, roll-rate modeling | 4-5 | Large |
| **13** | Dialer + Verint | Predictive dialer, dialer outcomes, WFM schedule adherence, occupancy, shrinkage | 3-4 | Large |
| **14** | PEGA + CRM + Inbound | Payment arrangements, reversals, settlements; contact governance; inbound calls | 4-5 | Very Large |

---

## PHASE 12 — CACS & Collections Treatment Strategy

### Business Justification

CACS (Collections and Customer Strategy) is Scotiabank's core collections system. It manages:
- **Collection strategies** — rules that govern how accounts are treated based on DPD, risk score, product, and past behavior
- **Treatment queues** — accounts flow through Early Stage → Late Stage → Pre-Legal → Legal → Third-Party as they age
- **Collector workbins** — each queue has assigned collectors who work a prioritized list of accounts daily
- **Treatment intensity** — Early Stage gets auto-dialer with SMS; Late Stage gets predictive dialer + manual calls; Pre-Legal gets certified letters + collector calls

The current model has none of this. Accounts exist in a flat "Mora/Activo" state with no concept of treatment path or queue ownership.

### 12.1 Schema Changes

#### New Table: Dim_Collection_Strategy

```sql
CREATE TABLE dim_collection_strategy (
    strategy_id     VARCHAR(15) PRIMARY KEY,
    strategy_name   VARCHAR(50) NOT NULL,  -- 'Early_Stage', 'Late_Stage', 'Pre_Legal', 'Legal', 'Third_Party'
    min_dpd         INT NOT NULL,           -- 1, 31, 91, 121, 181
    max_dpd         INT NOT NULL,           -- 30, 90, 120, 180, 999
    treatment_group VARCHAR(20),            -- 'Auto', 'Hybrid', 'Manual', 'Legal', 'External'
    dialer_mode     VARCHAR(20),            -- 'Auto_Dialer', 'Predictive', 'Progressive', 'None', 'Manual_Outbound'
    sms_enabled     BOOLEAN DEFAULT FALSE,
    email_enabled   BOOLEAN DEFAULT FALSE,
    letter_enabled  BOOLEAN DEFAULT FALSE,
    call_intensity  VARCHAR(20),            -- 'Low', 'Medium', 'High' — drives attempts/account/day
    priority_score  INT                     -- 1-100 for collector workbin sorting
);
```

Seed with:
- Early Stage (1-30, Auto_Dialer, SMS+Email, Low)
- Late Stage (31-60/61-90, Predictive, SMS+Call, Medium)
- Pre-Legal (91-120, Progressive, Call+Letter, High)
- Legal (121-180, Manual_Outbound, Letter, High)
- Third-Party (181+, External, None)

#### New Table: Dim_Queue

```sql
CREATE TABLE dim_queue (
    queue_id      VARCHAR(15) PRIMARY KEY,
    queue_name    VARCHAR(50) NOT NULL,
    strategy_id   VARCHAR(15) NOT NULL REFERENCES dim_collection_strategy(strategy_id),
    owning_team   VARCHAR(50),              -- Team or department that owns this queue
    is_active     BOOLEAN DEFAULT TRUE
);
```

Seed with 1 queue per strategy with some teams owning multiple queues.

#### New Columns in Dim_Accounts

```sql
ALTER TABLE dim_accounts ADD COLUMN current_strategy_id VARCHAR(15) REFERENCES dim_collection_strategy(strategy_id);
ALTER TABLE dim_accounts ADD COLUMN current_queue_id VARCHAR(15) REFERENCES dim_queue(queue_id);
ALTER TABLE dim_accounts ADD COLUMN strategy_assignment_date DATE;
ALTER TABLE dim_accounts ADD COLUMN queue_enter_date DATE;
ALTER TABLE dim_accounts ADD COLUMN total_bucket_entries INT DEFAULT 0;  -- how many times this account rolled to higher bucket
ALTER TABLE dim_accounts ADD COLUMN ever_legal BOOLEAN DEFAULT FALSE;
ALTER TABLE dim_accounts ADD COLUMN ever_third_party BOOLEAN DEFAULT FALSE;
```

#### New Table: Fact_Queue_Transfers (optional, bridge)

```sql
CREATE TABLE fact_queue_transfers (
    transfer_id       VARCHAR(15) PRIMARY KEY,
    account_id        VARCHAR(15) NOT NULL REFERENCES dim_accounts(account_id),
    from_queue_id     VARCHAR(15) REFERENCES dim_queue(queue_id),
    to_queue_id       VARCHAR(15) NOT NULL REFERENCES dim_queue(queue_id),
    transfer_date     DATE NOT NULL REFERENCES dim_calendar(date),
    transfer_reason   VARCHAR(50),   -- 'Bucket_Advance', 'Strategy_Change', 'Manual_Override'
    from_dpd          INT,
    to_dpd            INT
);
```

### 12.2 Config Changes (config.py)

Add to `CFG`:
```python
# Phase 12: CACS Strategy Configuration
"strategy_assignment": {
    "Early_Stage":    {"dpd_range": (1, 30),   "call_intensity": "Low",     "intensity_factor": 0.3},
    "Late_Stage":     {"dpd_range": (31, 90),  "call_intensity": "Medium",   "intensity_factor": 0.6},
    "Pre_Legal":      {"dpd_range": (91, 120), "call_intensity": "High",    "intensity_factor": 1.0},
    "Legal":          {"dpd_range": (121, 180),"call_intensity": "High",    "intensity_factor": 1.2},
    "Third_Party":    {"dpd_range": (181, 999),"call_intensity": "Zero",   "intensity_factor": 0.0},
},
"bucket_advance_prob": 0.85,          # % of accounts that advance to next DPD bucket vs curing
"manual_override_rate": 0.005,        # rare human-override queue transfers
"third_party_recovery_rate": 0.15,    # third-party recovers less than internal
```

Add `QUEUE_CFG` section:
```python
QUEUE_CFG = {
    "num_queues": 8,
    "queues_per_strategy": {
        "Early_Stage": 2,
        "Late_Stage": 3,
        "Pre_Legal": 1,
        "Legal": 1,
        "Third_Party": 1,
    },
    "agents_per_queue": {
        "Early_Stage": (8, 15),    # range of agents assigned to this queue type
        "Late_Stage": (5, 12),
        "Pre_Legal": (3, 6),
        "Legal": (1, 3),
        "Third_Party": (0, 0),     # external, no internal agents
    },
}
```

### 12.3 Generator Changes (data_generator_v8.py)

**Strategy Assignment Engine** (runs monthly, at billing cycle):
- When an account enters Mora, assign to Early_Stage
- When DPD crosses 30/90/120/180 thresholds, advance to next strategy
- On advance: set `strategy_assignment_date`, `queue_enter_date`, increment `total_bucket_entries`

**Workbin Construction** (daily):
- For each agent, build a workbin from accounts in their assigned queue(s)
- Prioritize by strategy priority_score, then by DPD (highest first)
- Give agents accounts proportional to queue size and team capacity
- Apply the `call_intensity` factor to determine max attempts per account per day

**Treatment Intensity** (replaces flat 1-2 attempts):
- Early_Stage: 1-2 dialer attempts/account/day + SMS (if not connected)
- Late_Stage: 2-5 attempts (predictive dialer cycles)
- Pre_Legal: 3-6 attempts (manual + dialer mix)
- Legal: 2-3 manual outbound attempts
- Third_Party: remove from internal dialer pool entirely (track separately)

**Account Roll Modeling**:
- At each month-end, determine which accounts roll forward
- `bucket_advance_prob = 0.85` — 85% of accounts that don't cure advance to next DPD band
- The remaining 15% cure or partially recover
- Accounts that reach Third_Party stay there indefinitely (removed from internal metrics)

### 12.4 ETL Changes

- Add foreign keys for strategy/queue columns to existing tables
- Load `dim_collection_strategy` and `dim_queue` from seed CSVs
- Backfill `current_strategy_id` and `current_queue_id` during EOM load
- Add `fact_queue_transfers` table to ETL load sequence

### 12.5 SQL Views

```sql
-- v_strategy_performance: roll-rate and recovery by strategy
CREATE VIEW v_strategy_performance AS
SELECT
    s.strategy_name,
    s.treatment_group,
    COUNT(DISTINCT a.account_id) AS accounts_in_strategy,
    SUM(CASE WHEN a.initial_status = 'Mora' AND EXISTS(
        SELECT 1 FROM fact_payments p WHERE p.account_id = a.account_id AND p.is_cured = TRUE
    ) THEN 1 ELSE 0 END) AS cured_accounts,
    SUM(f.arrears) AS total_arrears_in_strategy,
    AVG(a.dpd) AS avg_dpd
FROM dim_collection_strategy s
JOIN dim_accounts a ON a.current_strategy_id = s.strategy_id
LEFT JOIN fact_eom_snapshot f ON f.account_id = a.account_id
    AND f.snapshot_date = (SELECT MAX(snapshot_date) FROM fact_eom_snapshot)
GROUP BY s.strategy_name, s.treatment_group;

-- v_queue_performance: collector effectiveness by queue
CREATE VIEW v_queue_performance AS
SELECT
    q.queue_name,
    s.strategy_name,
    COUNT(DISTINCT a.account_id) AS queue_size,
    COUNT(DISTINCT i.interaction_id) AS total_contacts,
    COUNT(DISTINCT CASE WHEN i.rpc_flag THEN i.interaction_id END) AS total_rpcs,
    COUNT(DISTINCT p.account_id) AS accounts_with_payments,
    SUM(p.amount_paid) FILTER (WHERE p.is_cured) AS cured_amount
FROM dim_queue q
JOIN dim_collection_strategy s ON q.strategy_id = s.strategy_id
JOIN dim_accounts a ON a.current_queue_id = q.queue_id
LEFT JOIN fact_interactions i ON i.account_id = a.account_id
LEFT JOIN fact_payments p ON p.account_id = a.account_id
GROUP BY q.queue_name, s.strategy_name;

-- v_roll_rate_transition: accounts advancing between buckets
CREATE VIEW v_roll_rate_transition AS
SELECT
    from_bucket,
    to_bucket,
    COUNT(*) AS account_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY from_bucket), 1) AS transition_pct
FROM (
    SELECT
        LAG(dpd_bucket) OVER (PARTITION BY account_id ORDER BY snapshot_date) AS from_bucket,
        dpd_bucket AS to_bucket
    FROM fact_eom_snapshot
) sub
WHERE from_bucket IS NOT NULL
GROUP BY from_bucket, to_bucket
ORDER BY from_bucket, to_bucket;

-- v_workbin_summary: daily collector view
CREATE VIEW v_workbin_summary AS
SELECT
    e.agent_id,
    e.agent_name,
    q.queue_name,
    s.strategy_name,
    COUNT(a.account_id) AS accounts_in_workbin,
    SUM(CASE WHEN a.initial_status = 'Mora' THEN 1 ELSE 0 END) AS mora_accounts,
    ROUND(AVG(a.dpd), 1) AS avg_dpd,
    COUNT(i.interaction_id) AS call_attempts_today,
    COUNT(CASE WHEN i.rpc_flag THEN 1 END) AS rpcs_today
FROM dim_employees e
JOIN dim_queue q ON q.owning_team = e.team_name
JOIN dim_collection_strategy s ON q.strategy_id = s.strategy_id
LEFT JOIN dim_accounts a ON a.current_queue_id = q.queue_id
LEFT JOIN fact_interactions i ON i.agent_id = e.agent_id AND i.interaction_date = CURRENT_DATE
GROUP BY e.agent_id, e.agent_name, q.queue_name, s.strategy_name;
```

### 12.6 DAX Measures (20 new)

Based on existing patterns in `collections_dax_v2.csv`:

```
_Strategy Performance:
  Strategy Cured Amount     = CALCULATE([Cured Amount], ...strategy filter)
  Strategy Cure Rate        = [Strategy Cured Accounts] / [Strategy Accounts]
  Strategy RPC%             = DIVIDE([Strategy RPCs], [Strategy Connected Calls])
  Strategy Roll Rate        = accounts that advanced / accounts in strategy

_Queue Performance:
  Queue Size                = COUNTROWS(FILTER(Dim_Accounts, ...))
  Queue Conversion Rate     = DIVIDE([Queue Cures], [Queue Accounts])
  Queue RPC per Account     = DIVIDE([Queue RPCs], [Queue Accounts])

_Workbin:
  Workbin Accounts          = COUNTROWS(Dim_Accounts)
  Workbin Coverage %        = DIVIDE([Contacts Today], [Workbin Accounts])
  Workbin Priority Score    = AVERAGE(Dim_Accounts[priority_score])
```

### 12.7 Test Additions

- `test_strategy_assignment.py`: verify accounts are assigned to correct strategy by DPD
- `test_bucket_advance.py`: verify roll-rate probabilities produce expected transition matrix
- `test_workbin_completeness.py`: verify every agent has accounts assigned

### 12.8 Dashboard Impact

| Dashboard | New Capability |
|-----------|---------------|
| Portfolio Management | Strategy performance comparison, roll-rate Sankey with actual strategy labels |
| Operations Command | Queue size trends, workbin coverage %, collector workbin view |
| Credit Risk | Roll-rate by strategy (Early vs Late stage default patterns) |
| Agent Performance | Agent performance benchmarked against queue peers |

---

## PHASE 13 — Dialer & Workforce Management

### Business Justification

Scotiabank uses a **predictive dialer** (Aspect/Alvaria or Noble) that:
- Calls multiple lines simultaneously per available collector
- Detects answering machines, SIT tones, fast busy
- Passes answered calls to collectors (transfers live calls)
- Abandons calls if no collector becomes available within a threshold
- Paces itself based on collector availability and call history

The current model has a `channel` column with "Dialer" but zero dialer behavior simulated. WFM is equally thin — no adherence, occupancy, or shrinkage.

### 13.1 Schema Changes

#### New Columns in Fact_Interactions

```sql
ALTER TABLE fact_interactions ADD COLUMN dialer_mode VARCHAR(20);
    -- 'Predictive', 'Progressive', 'Preview', 'Manual'
ALTER TABLE fact_interactions ADD COLUMN dialer_disposition VARCHAR(50);
    -- 'Answered_Human', 'Answered_Machine', 'SIT_Tone', 'Fast_Busy',
    -- 'No_Answer_Ring', 'Abandoned', 'Short_Call', 'Transfer_Failed'
ALTER TABLE fact_interactions ADD COLUMN call_direction VARCHAR(10) DEFAULT 'Outbound';
    -- 'Outbound' or 'Inbound'
ALTER TABLE fact_interactions ADD COLUMN attempt_sequence INT;
    -- which attempt this is for the account-day (1, 2, 3...)
ALTER TABLE fact_interactions ADD COLUMN call_length_seconds INT;
    -- might differ from aht_seconds for abandoned/short calls
ALTER TABLE fact_interactions ADD COLUMN is_answered BOOLEAN;
    -- TRUE if human answered, FALSE for machine/no-answer/busy etc.
ALTER TABLE fact_interactions ADD COLUMN abandon_type VARCHAR(20);
    -- NULL unless abandoned: 'Caller_Abandon', 'System_Abandon', NULL
```

#### New Columns in Fact_Agent_Time_Log

```sql
ALTER TABLE fact_agent_time_log ADD COLUMN schedule_login TIME;
    -- When agent was scheduled to log in (Verint scheduled vs actual)
ALTER TABLE fact_agent_time_log ADD COLUMN adherence_status VARCHAR(20);
    -- 'On_Time', 'Late', 'Early_Out', 'Absent', 'Excused'
ALTER TABLE fact_agent_time_log ADD COLUMN late_minutes INT DEFAULT 0;
ALTER TABLE fact_agent_time_log ADD COLUMN early_leave_minutes INT DEFAULT 0;
ALTER TABLE fact_agent_time_log ADD COLUMN occupied_seconds INT;
    -- handle time only (not logged-in time)
ALTER TABLE fact_agent_time_log ADD COLUMN available_seconds INT;
    -- logged in but not on a call (waiting for dialer to connect)
ALTER TABLE fact_agent_time_log ADD COLUMN occupancy DECIMAL(5,2);
    -- occupied_seconds / (occupied_seconds + available_seconds)
ALTER TABLE fact_agent_time_log ADD COLUMN shrinkage_seconds INT;
    -- paid non-productive time (meetings, training, PTO)
ALTER TABLE fact_agent_time_log ADD COLUMN shrinkage_category VARCHAR(30);
    -- 'Meeting', 'Training', 'Coaching', 'PTO', 'Sick', 'Break', 'System_Issue'
ALTER TABLE fact_agent_time_log ADD COLUMN overtime_minutes INT DEFAULT 0;
ALTER TABLE fact_agent_time_log ADD COLUMN overtime_cost DECIMAL(10,2) DEFAULT 0;
```

#### New Table: Fact_Dialer_Call_Detail

One row per dialer event (not per agent-account session). A single Interaction in the current model would be 3-10+ dialer detail rows.

```sql
CREATE TABLE fact_dialer_call_detail (
    dialer_event_id     VARCHAR(15) PRIMARY KEY,
    interaction_id      VARCHAR(15) REFERENCES fact_interactions(interaction_id),
    dialer_session_id   VARCHAR(20),
    call_time           TIME NOT NULL,
    dialer_mode         VARCHAR(20) NOT NULL,
    phone_number        VARCHAR(20),            -- last 4 digits masked for realism
    call_result         VARCHAR(50) NOT NULL,
    call_seconds        INT,
    agent_id            VARCHAR(15) REFERENCES dim_employees(agent_id),
    account_id          VARCHAR(15) REFERENCES dim_accounts(account_id),
    line_group          VARCHAR(20),            -- 'Primary', 'Secondary', 'Cell'
    is_abandoned        BOOLEAN DEFAULT FALSE,
    abandon_seconds     INT,                    -- seconds caller waited before hanging up
    CONSTRAINT fk_dialer_agent FOREIGN KEY (agent_id) REFERENCES dim_employees(agent_id),
    CONSTRAINT fk_dialer_account FOREIGN KEY (account_id) REFERENCES dim_accounts(account_id)
);
```

#### New Table: Dim_Absence_Type (for WFM)

```sql
CREATE TABLE dim_absence_type (
    absence_code    VARCHAR(10) PRIMARY KEY,
    absence_name    VARCHAR(50),
    category        VARCHAR(30),   -- 'Paid', 'Unpaid', 'Excused', 'Unexcused'
    counts_to_shrinkage BOOLEAN DEFAULT TRUE
);
```

### 13.2 Config Changes

```python
# Phase 13: Predictive Dialer
DIALER_CFG = {
    "predictive_lines_per_agent": (1.2, 1.8),  # predictive dials 1.2-1.8 lines/agent
    "progressive_lines": 1,                      # progressive dials 1 line at a time
    "preview_wait_seconds": (5, 15),            # agent reviews account before dial
    "abandon_rate_target": 0.03,                # target 3% abandon rate
    "abandon_threshold_seconds": 30,            # abandon after 30s ring
    "answer_machine_detect": 0.85,              # 85% detection accuracy
    "call_results": {
        "Answered_Human": 0.25,                  # 25% of dialer events
        "Answered_Machine": 0.20,
        "SIT_Tone": 0.05,
        "Fast_Busy": 0.08,
        "No_Answer_Ring": 0.25,
        "Abandoned": 0.03,
        "Short_Call": 0.02,
        "Transfer_Failed": 0.02,
    },
    "dialer_operating_hours": (8, 21),          # 8am-9pm dialer window
    "max_dialer_attempts_per_day": 10,          # cap per account per day
}

# Phase 13: WFM
WFM_CFG = {
    "late_login_prob": 0.12,                    # 12% of agents log in late
    "late_login_max_minutes": 45,
    "early_leave_prob": 0.08,                   # 8% leave early
    "early_leave_max_minutes": 30,
    "absent_prob": 0.02,                        # 2% absent (PTO/sick)
    "shrinkage_pct": 0.15,                      # 15% shrinkage rate
    "shrinkage_categories": {
        "Meeting": 0.25,
        "Training": 0.15,
        "Coaching": 0.10,
        "PTO": 0.25,
        "Sick": 0.15,
        "System_Issue": 0.10,
    },
    "overtime_prob": 0.05,                      # 5% of agents work OT
    "overtime_max_minutes": 120,
    "overtime_pay_multiplier": 1.5,
    "adherence_tolerance_minutes": 5,           # within 5 min = "On Time"
}
```

### 13.3 Generator Changes

**Dialer Simulation** (replaces current simple channel assignment):

For each agent-day, the dialer simulation:
1. Determines dialer mode based on queue/strategy (Early = Predictive, Late = Predictive, Pre-Legal = Progressive, Legal = Manual)
2. For Predictive mode: calculate lines per agent from config (1.2-1.8x), generate that many dialer events per cycle
3. For each dialer event: pick a random account from the agent's workbin, generate a call result from the weighted distribution
4. If `Answered_Human`: create a connected call (maps to one row in fact_interactions)
5. If `Answered_Machine`, `SIT_Tone`, `Fast_Busy`, `No_Answer`: no connection, write to dialer detail only
6. If `Abandoned`: increment abandon counter, write to dialer detail
7. Repeat dialer cycles throughout the agent's shift (every 30-60 seconds)
8. Track `attempt_sequence` per account per day
9. Apply abandon rate pacing: if abandon rate exceeds 3% target, reduce lines-per-agent

**WFM Simulation** (enhances current basic time log):

For each agent:
1. **Schedule**: assign a scheduled login time (8:00-9:00 range based on team)
2. **Adherence**: roll dice to determine if agent is On_Time, Late, Early_Out, or Absent
3. **Shrinkage**: deduct shrinkage_seconds from operational hours for one of the shrinkage categories
4. **Occupancy**: track occupied_seconds (total handle time) vs available_seconds (waiting for calls)
5. **Overtime**: 5% of agents work 30-120 min overtime at 1.5x pay
6. **Break**: current break model stays but gets shrinkage categorization

### 13.4 ETL Changes

- Fact_Dialer_Call_Detail: new table in load sequence, much larger row volume (5-10x Interactions)
- New columns in Fact_Interactions: backfilled from dialer detail
- New columns in Fact_Agent_Time_Log: populated during agent loop

### 13.5 SQL Views

```sql
-- v_dialer_performance: core dialer KPIs
CREATE VIEW v_dialer_performance AS
SELECT
    i.interaction_date,
    i.agent_id,
    d.dialer_mode,
    COUNT(d.dialer_event_id) AS total_dials,
    SUM(CASE WHEN d.call_result = 'Answered_Human' THEN 1 ELSE 0 END) AS human_answers,
    SUM(CASE WHEN d.is_abandoned THEN 1 ELSE 0 END) AS abandoned,
    ROUND(SUM(CASE WHEN d.call_result = 'Answered_Human' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(d.dialer_event_id), 0), 1) AS answer_rate,
    ROUND(SUM(CASE WHEN d.is_abandoned THEN 1 ELSE 0 END) * 100.0
        / NULLIF(SUM(CASE WHEN d.call_result = 'Answered_Human' THEN 1 ELSE 0 END), 0), 1) AS abandon_rate,
    ROUND(AVG(d.call_seconds), 0) AS avg_call_length
FROM fact_dialer_call_detail d
JOIN fact_interactions i ON i.interaction_id = d.interaction_id
GROUP BY i.interaction_date, i.agent_id, d.dialer_mode;

-- v_wfm_adherence: agent schedule adherence
CREATE VIEW v_wfm_adherence AS
SELECT
    t.log_date,
    e.agent_id,
    e.team_name,
    t.schedule_login,
    t.login_time,
    t.adherence_status,
    t.late_minutes,
    t.early_leave_minutes,
    t.operational_hours,
    t.tht_hours,
    t.occupied_seconds,
    t.available_seconds,
    ROUND(t.occupied_seconds * 100.0 / NULLIF(t.occupied_seconds + t.available_seconds, 0), 1) AS occupancy_pct,
    t.shrinkage_seconds,
    t.shrinkage_category,
    t.overtime_minutes,
    t.overtime_cost
FROM fact_agent_time_log t
JOIN dim_employees e ON e.agent_id = t.agent_id;

-- v_agent_occupancy: agent-level occupancy trend
CREATE VIEW v_agent_occupancy AS
SELECT
    t.agent_id,
    t.log_date,
    SUM(t.occupied_seconds) AS total_occupied_secs,
    SUM(t.available_seconds) AS total_available_secs,
    ROUND(SUM(t.occupied_seconds) * 100.0
        / NULLIF(SUM(t.occupied_seconds + t.available_seconds), 0), 1) AS occupancy_pct
FROM fact_agent_time_log t
GROUP BY t.agent_id, t.log_date;
```

### 13.6 DAX Measures (35 new)

```
_Dialer:
  Total Dials            = COUNTROWS(Fact_Dialer_Call_Detail)
  Answer Rate            = DIVIDE([Human Answers], [Total Dials])
  Abandon Rate           = DIVIDE([Abandoned Calls], [Human Answers])
  Dialer RPC%            = DIVIDE([Dialer RPCs], [Dialer Connected Calls])
  Predictive Efficiency  = DIVIDE([Human Answers], [Total Dials Predictive Mode])
  Lines Per Agent        = AVERAGE(Fact_Dialer_Call_Detail[lines_per_agent])
  Avg Call Length (sec)  = AVERAGE(Fact_Dialer_Call_Detail[call_seconds])
  Short Call %           = DIVIDE([Short Calls], [Total Dials])
  Answer Machine %       = DIVIDE([Answer Machine Detects], [Total Dials])
  Dialer-to-RPC Conv %   = DIVIDE([RPCs], [Human Answers])
  Abandons Over Target   = [Abandon Rate] - 0.03 (negative = good)

_WFM:
  Schedule Adherence %   = DIVIDE([On Time Agents], [Total Scheduled Agents])
  Late %                 = DIVIDE([Late Agents], [Total Scheduled Agents])
  Absenteeism %          = DIVIDE([Absent Agents], [Total Scheduled Agents])
  Occupancy %            = DIVIDE([Occupied Seconds], [Occupied Secs] + [Available Secs])
  Shrinkage %            = DIVIDE([Shrinkage Seconds], [Scheduled Seconds])
  Overtime %             = DIVIDE([Overtime Hours], [Scheduled Hours])
  Overtime Cost          = SUM(Fact_Agent_Time_Log[overtime_cost])
  Adherence by Team      = ...with ALLEXCEPT(team_name)
  Occupancy by Hour      = ...with HOUR dimension
```

### 13.7 Test Additions

- `test_dialer_call_results.py`: verify call result distribution matches config
- `test_dialer_abandon_rate.py`: verify abandon rate stays near 3% target
- `test_wfm_adherence.py`: verify late/absent rates match config probabilities
- `test_occupancy_range.py`: verify occupancy stays within 70-95%
- `test_shrinkage_categories.py`: verify shrinkage breakdown matches config weights

### 13.8 Dashboard Impact

| Dashboard | New Capability |
|-----------|---------------|
| Dialer Performance | **Fully enabled** — abandon rate, answer rate, predictive efficiency, lines-per-agent, dialer-to-RPC conversion |
| Operations Command | **Fully enabled** — occupancy, schedule adherence, shrinkage, real-time adherence, intraday trends |
| Agent Performance | Occupancy and adherence added to agent scorecard |
| Executive | Operational health score (adherence + occupancy + abandon rate composite) |

---

## PHASE 14 — PEGA Payments, CRM, & Inbound

### Business Justification

Scotiabank uses **PEGA** for payment processing and arrangements. Real collections payment management includes:
- **Payment Arrangements** — structured multi-installment plans (e.g., "pay $150 on the 1st and 15th for 4 months")
- **Payment Reversals** — NSF returns, chargebacks, stop payments that reverse cure status
- **Settlements** — accepting less than full balance to close an account
- **Auto-Pay** — recurring card/ACH authorizations

The CRM layer governs:
- **Contact Preferences** — how, when, and whether a customer can be contacted
- **Contact Prohibitions** — bankruptcy, deceased, legal representation, DNC
- **Soft-Touch/No-Touch** — accounts that receive automated-only treatment

Inbound calls are a major metric gap. In real collections:
- 30-50% of payments come through inbound calls (customer calling in)
- Inbound calls have different handling (no dialer, shorter AHT, higher payment conversion)
- Inbound call volume is a critical capacity planning metric

### 14.1 Schema Changes

#### New Table: Fact_Payment_Arrangements

```sql
CREATE TABLE fact_payment_arrangements (
    arrangement_id        VARCHAR(15) PRIMARY KEY,
    account_id            VARCHAR(15) NOT NULL REFERENCES dim_accounts(account_id),
    agent_id              VARCHAR(15) REFERENCES dim_employees(agent_id),
    arrangement_date      DATE NOT NULL REFERENCES dim_calendar(date),
    total_arranged_amount DECIMAL(12,2) NOT NULL,
    installment_count     INT NOT NULL,           -- 2, 3, 4, 6, 12
    installment_amount    DECIMAL(12,2) NOT NULL,
    frequency             VARCHAR(10) NOT NULL,   -- 'Weekly', 'Biweekly', 'Monthly'
    first_due_date        DATE NOT NULL,
    status                VARCHAR(20) NOT NULL,   -- 'Active', 'Completed', 'Defaulted', 'Cancelled'
    default_date          DATE,                   -- when arrangement defaulted
    completed_date        DATE,                   -- when fully paid
    amount_collected      DECIMAL(12,2) DEFAULT 0,
    outstanding_balance   DECIMAL(12,2),          -- remaining on arrangement
    CONSTRAINT fk_arr_account FOREIGN KEY (account_id) REFERENCES dim_accounts(account_id),
    CONSTRAINT fk_arr_agent FOREIGN KEY (agent_id) REFERENCES dim_employees(agent_id),
    CONSTRAINT fk_arr_date FOREIGN KEY (arrangement_date) REFERENCES dim_calendar(date)
);
```

#### New Table: Fact_Payment_Reversals

```sql
CREATE TABLE fact_payment_reversals (
    reversal_id       VARCHAR(15) PRIMARY KEY,
    payment_id        VARCHAR(15) NOT NULL REFERENCES fact_payments(payment_id),
    reversal_date     DATE NOT NULL REFERENCES dim_calendar(date),
    reversal_type     VARCHAR(30) NOT NULL,  -- 'NSF', 'Chargeback', 'Stop_Payment', 'Error_Correction'
    reversal_amount   DECIMAL(12,2) NOT NULL,
    original_payment_date DATE,
    reason_code       VARCHAR(50),
    net_impact_on_arrears DECIMAL(12,2),     -- how much arrears increased after reversal
    reversed_cure     BOOLEAN DEFAULT FALSE   -- TRUE if this reversal reversed a cure
);
```

#### New Columns in Dim_Clients (CRM)

```sql
ALTER TABLE dim_clients ADD COLUMN contact_preference VARCHAR(20);
    -- 'Phone', 'Email', 'SMS', 'Mail', 'Do_Not_Contact'
ALTER TABLE dim_clients ADD COLUMN dnc_phone BOOLEAN DEFAULT FALSE;
ALTER TABLE dim_clients ADD COLUMN dnc_email BOOLEAN DEFAULT FALSE;
ALTER TABLE dim_clients ADD COLUMN dnc_sms BOOLEAN DEFAULT FALSE;
ALTER TABLE dim_clients ADD COLUMN contact_prohibition VARCHAR(50);
    -- NULL, 'Bankruptcy', 'Deceased', 'Legal_Representation', 'Consumer_Proposal'
ALTER TABLE dim_clients ADD COLUMN prohibition_date DATE;
ALTER TABLE dim_clients ADD COLUMN soft_touch_only BOOLEAN DEFAULT FALSE;
ALTER TABLE dim_clients ADD COLUMN auto_pay_enrolled BOOLEAN DEFAULT FALSE;
ALTER TABLE dim_clients ADD COLUMN auto_pay_method VARCHAR(20);
    -- NULL, 'ACH', 'Credit_Card', 'Debit_Card'
ALTER TABLE dim_clients ADD COLUMN auto_pay_amount DECIMAL(12,2) DEFAULT 0;
ALTER TABLE dim_clients ADD COLUMN preferred_language VARCHAR(10) DEFAULT 'English';
    -- 'English', 'French', 'Spanish', 'Mandarin', etc.
```

#### New Table: Fact_Inbound_Interaction

```sql
CREATE TABLE fact_inbound_interaction (
    inbound_id         VARCHAR(15) PRIMARY KEY,
    inbound_date       DATE NOT NULL REFERENCES dim_calendar(date),
    inbound_time       TIME NOT NULL,
    agent_id           VARCHAR(15) REFERENCES dim_employees(agent_id),
    account_id         VARCHAR(15) REFERENCES dim_accounts(account_id),
    client_id          VARCHAR(15) REFERENCES dim_clients(client_id),
    ivr_path           VARCHAR(50),          -- 'Collections', 'Payments', 'General', 'Retention'
    wait_seconds       INT,                   -- time in IVR queue
    aht_seconds        INT,
    acw_seconds        INT,
    call_outcome       VARCHAR(50),           -- 'Paid', 'PTP_Booked', 'Info_Request', 'Complaint', 'Dispute', 'Transferred'
    payment_made       BOOLEAN DEFAULT FALSE,
    payment_amount     DECIMAL(12,2),
    ptp_booked         BOOLEAN DEFAULT FALSE,
    is_transferred     BOOLEAN DEFAULT FALSE,
    transferred_to     VARCHAR(50),
    CONSTRAINT fk_inbound_agent FOREIGN KEY (agent_id) REFERENCES dim_employees(agent_id),
    CONSTRAINT fk_inbound_account FOREIGN KEY (account_id) REFERENCES dim_accounts(account_id),
    CONSTRAINT fk_inbound_client FOREIGN KEY (client_id) REFERENCES dim_clients(client_id),
    CONSTRAINT fk_inbound_date FOREIGN KEY (inbound_date) REFERENCES dim_calendar(date)
);
```

#### New Table: Dim_IVR_Node

```sql
CREATE TABLE dim_ivr_node (
    node_id     VARCHAR(15) PRIMARY KEY,
    node_name   VARCHAR(50),    -- 'Main_Menu', 'Collections_Queue', 'Payment_Processing'...
    node_type   VARCHAR(30),    -- 'Menu', 'Queue', 'Self_Service', 'Agent_Route'
    avg_wait_seconds INT       -- baseline wait time for this node
);
```

### 14.2 Config Changes

```python
# Phase 14: Payment Arrangements (PEGA)
PAYMENT_ARRANGEMENT_CFG = {
    "arrangement_prob": 0.15,                      # 15% of PTPs become arrangements
    "installment_counts": [2, 3, 4, 6, 12],
    "installment_weights": [0.10, 0.20, 0.35, 0.25, 0.10],
    "frequency_options": ["Weekly", "Biweekly", "Monthly"],
    "frequency_weights": [0.10, 0.20, 0.70],
    "default_rate": 0.20,                          # 20% of arrangements default
    "default_after_installments": (1, 3),          # defaults after 1-3 missed installments
    "completed_rate": 0.65,                        # 65% complete successfully
    "cancelled_rate": 0.15,                        # 15% cancelled (customer request)
}

# Phase 14: Payment Reversals
REVERSAL_CFG = {
    "reversal_prob": 0.03,                         # 3% of payments reverse
    "reversal_types": {
        "NSF": 0.45,                               # 45% of reversals
        "Chargeback": 0.25,
        "Stop_Payment": 0.20,
        "Error_Correction": 0.10,
    },
    "nsf_prob_by_income": {                        # lower income = higher NSF
        "<30K": 0.07, "30K-50K": 0.04, "50K-75K": 0.02, "75K-100K": 0.01, "100K+": 0.005,
    },
    "reversal_delay_days": (3, 14),               # reversal happens 3-14 days after payment
}

# Phase 14: CRM Contact Profile
CRM_CFG = {
    "dnc_phone_prob": 0.05,                        # 5% on DNC list
    "dnc_email_prob": 0.03,
    "dnc_sms_prob": 0.08,
    "contact_prohibition_prob": 0.02,              # 2% bankruptcy/deceased/legal
    "prohibition_types": {
        "Bankruptcy": 0.35,
        "Deceased": 0.15,
        "Legal_Representation": 0.30,
        "Consumer_Proposal": 0.20,
    },
    "soft_touch_prob": 0.08,                       # 8% soft-touch only
    "auto_pay_prob": 0.12,                         # 12% enrolled in auto-pay
    "auto_pay_methods": {"ACH": 0.60, "Credit_Card": 0.30, "Debit_Card": 0.10},
    "contact_preferences": {
        "Phone": 0.50, "Email": 0.20, "SMS": 0.20, "Mail": 0.05, "Do_Not_Contact": 0.05,
    },
}

# Phase 14: Inbound Call Center
INBOUND_CFG = {
    "inbound_volume_pct": 0.08,                    # inbound = 8% of outbound interaction volume
    "ivr_distribution": {
        "Collections": 0.40,
        "Payments": 0.35,
        "General": 0.15,
        "Retention": 0.10,
    },
    "avg_wait_seconds": (30, 180),
    "inbound_aht_rpc": {"mu": 180, "sigma": 40},   # shorter AHT for inbound
    "inbound_aht_nonrpc": {"mu": 45, "sigma": 12},
    "inbound_acw": {"mu": 15, "sigma": 5},
    "inbound_payment_conversion": 0.45,            # 45% of inbound calls result in payment
    "inbound_ptp_conversion": 0.20,                # 20% of inbound calls book a PTP
    "inbound_transfer_rate": 0.08,
}
```

### 14.3 Generator Changes

**Payment Arrangement Engine**:
- When a PTP is created, 15% chance it becomes a payment arrangement instead
- Generate installment_count, frequency, installment_amount from config
- Track arrangement status over time: Active → (Completed | Defaulted | Cancelled)
- On each installment due date, process the installment payment (or mark missed)
- If 1-3 installments missed consecutively, mark as Defaulted
- If all installments paid, mark as Completed

**Payment Reversal Engine**:
- 3% of payments reverse 3-14 days after the original payment
- When reversed: create a reversal record, add the amount back to account arrears
- If the original payment cured the account, mark `reversed_cure = TRUE` and put account back in Mora
- NSF probability varies by income bracket (configurable)

**CRM Profile Generator** (runs during Dim_Clients creation):
- Assign contact preferences per client
- 5% on DNC phone, 3% DNC email, 8% DNC SMS
- 2% have a contact prohibition (bankruptcy, deceased, legal)
- 8% are soft-touch only (auto-dialer only, no manual calls)
- 12% enrolled in auto-pay with preferred method and amount
- Client `segment` influences income bracket and DNC probability

**Contact Governance** (runs during dialer pool construction):
- Skip accounts with `dnc_phone = TRUE` when building dialer pools
- If `soft_touch_only = TRUE`: only use auto-dialer mode, skip manual/progressive
- If `contact_prohibition` is set: skip entirely, generate a "Contact Prohibited" interaction instead
- If `auto_pay_enrolled = TRUE`: auto-pay amount automatically applied on due date (reduces manual collection need)

**Inbound Call Simulation** (generates 8% of outbound interaction volume):
- For each simulated day, generate inbound calls based on volume factor
- 40% Collections path, 35% Payments path, 15% General, 10% Retention
- Assign random wait_seconds (30-180s) based on IVR node
- If Collections: agent handles with inbound-specific AHT (shorter than outbound)
- 45% of inbound calls result in a payment (much higher than outbound conversion)
- 20% book a PTP (higher than outbound)
- 8% transferred to another department
- Write to `fact_inbound_interaction` and cross-reference to `fact_payments` if a payment was made

### 14.4 ETL Changes

- Add 3 new fact tables to load sequence
- Add 1 new dimension table (Dim_IVR_Node)
- Updated Dim_Clients load with new CRM columns
- Payment reversal ETL: after loading payments, generate and load reversals
- Payment arrangement ETL: load arrangements table from arrangement events in generator output

### 14.5 SQL Views

```sql
-- v_payment_arrangement_performance: arrangement success rates
CREATE VIEW v_payment_arrangement_performance AS
SELECT
    a.agent_id,
    e.agent_name,
    COUNT(pa.arrangement_id) AS total_arrangements,
    SUM(CASE WHEN pa.status = 'Completed' THEN 1 ELSE 0 END) AS completed_arrangements,
    SUM(CASE WHEN pa.status = 'Defaulted' THEN 1 ELSE 0 END) AS defaulted_arrangements,
    ROUND(SUM(CASE WHEN pa.status = 'Completed' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(pa.arrangement_id), 0), 1) AS arrangement_success_rate,
    SUM(pa.amount_collected) AS total_collected_via_arrangements
FROM fact_payment_arrangements pa
JOIN dim_employees e ON e.agent_id = a.agent_id
GROUP BY a.agent_id, e.agent_name;

-- v_payment_reversal_impact: financial impact of reversals
CREATE VIEW v_payment_reversal_impact AS
SELECT
    pr.reversal_type,
    COUNT(*) AS reversal_count,
    SUM(pr.reversal_amount) AS total_reversed_amount,
    COUNT(CASE WHEN pr.reversed_cure THEN 1 END) AS cures_reversed,
    ROUND(AVG(pr.net_impact_on_arrears), 2) AS avg_arrears_reinstated
FROM fact_payment_reversals pr
GROUP BY pr.reversal_type;

-- v_contact_prohibition_impact: accounts restricted from contact
CREATE VIEW v_contact_prohibition_impact AS
SELECT
    c.contact_prohibition,
    COUNT(DISTINCT a.account_id) AS affected_accounts,
    SUM(CASE WHEN a.initial_status = 'Mora' THEN f.arrears ELSE 0 END) AS unreachable_arrears
FROM dim_clients c
JOIN dim_accounts a ON a.client_id = c.client_id
LEFT JOIN fact_eom_snapshot f ON f.account_id = a.account_id
    AND f.snapshot_date = (SELECT MAX(snapshot_date) FROM fact_eom_snapshot)
WHERE c.contact_prohibition IS NOT NULL OR c.dnc_phone = TRUE
GROUP BY c.contact_prohibition;

-- v_inbound_vs_outbound: channel comparison
CREATE VIEW v_inbound_vs_outbound AS
SELECT
    'Inbound' AS channel,
    i.inbound_date AS date,
    COUNT(*) AS total_calls,
    SUM(CASE WHEN i.payment_made THEN 1 ELSE 0 END) AS payments_made,
    ROUND(SUM(CASE WHEN i.payment_made THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0), 1) AS payment_conversion,
    AVG(i.aht_seconds) AS avg_aht,
    AVG(i.wait_seconds) AS avg_wait
FROM fact_inbound_interaction i
GROUP BY i.inbound_date
UNION ALL
SELECT
    'Outbound' AS channel,
    i.interaction_date,
    COUNT(*),
    -- No direct payment link; approximate via PTP-to-payment conversion
    COUNT(DISTINCT p.payment_id),
    ROUND(COUNT(DISTINCT p.payment_id) * 100.0 / NULLIF(COUNT(*), 0), 1),
    AVG(i.aht_seconds + i.acw_seconds),
    NULL AS avg_wait
FROM fact_interactions i
LEFT JOIN fact_ptp_log ptp ON ptp.account_id = i.account_id AND ptp.ptp_date = i.interaction_date
LEFT JOIN fact_payments p ON p.ptp_id = ptp.ptp_id
GROUP BY i.interaction_date;

-- v_auto_pay_effectiveness: auto-pay vs manual payment comparison
CREATE VIEW v_auto_pay_effectiveness AS
SELECT
    CASE WHEN c.auto_pay_enrolled THEN 'Auto_Pay' ELSE 'Manual' END AS payment_type,
    COUNT(DISTINCT a.account_id) AS accounts,
    SUM(p.amount_paid) AS total_collected,
    AVG(a.dpd) AS avg_dpd,
    COUNT(CASE WHEN p.is_cured THEN 1 END) * 100.0 / NULLIF(COUNT(DISTINCT a.account_id), 0) AS cure_rate
FROM dim_clients c
JOIN dim_accounts a ON a.client_id = c.client_id
LEFT JOIN fact_payments p ON p.account_id = a.account_id
GROUP BY c.auto_pay_enrolled;
```

### 14.6 DAX Measures (40 new)

```
_Payment Arrangements:
  Active Arrangements       = COUNTROWS(FILTER(Fact_Payment_Arrangements, status = "Active"))
  Arrangement Success Rate  = DIVIDE([Completed Arrangements], [Total Arrangements])
  Arrangement Default Rate  = DIVIDE([Defaulted Arrangements], [Total Arrangements])
  Avg Installments          = AVERAGE(Fact_Payment_Arrangements[installment_count])
  Amt Collected via Arrangmts = SUM(Fact_Payment_Arrangements[amount_collected])
  Arrangement $ per Account = DIVIDE([Amt Collected via Arrangmts], [Accounts with Arrangements])

_Payment Reversals:
  Reversal Rate             = DIVIDE([Reversal Count], [Payment Count])
  Reversal Amount           = SUM(Fact_Payment_Reversals[reversal_amount])
  Net Collections           = [Cured Amount] - [Reversal Amount]
  NSF Rate                  = DIVIDE([NSF Count], [Payment Count])
  Cure Reversal Rate        = DIVIDE([Cures Reversed], [Total Cures])
  Net Recovery Rate         = DIVIDE([Net Collections], [Total Arrears])

_CRM & Contact Governance:
  DNC Accounts              = COUNTROWS(FILTER(Dim_Clients, dnc_phone = TRUE))
  Prohibited Accounts       = COUNTROWS(FILTER(Dim_Clients, contact_prohibition <> BLANK()))
  Unreachable Arrears $     = SUMX(FILTER(Dim_Accounts, ...), [Current Arrears])
  Soft Touch Accounts       = COUNTROWS(FILTER(Dim_Clients, soft_touch_only = TRUE))
  Auto-Pay Enrollment Rate  = DIVIDE([Auto-Pay Accounts], [Total Clients])
  Auto-Pay Cure Rate        = DIVIDE([Auto-Pay Cures], [Auto-Pay Accounts])
  Contact Preference Dist   = VALUES(Dim_Clients[contact_preference])

_Inbound:
  Inbound Call Volume       = COUNTROWS(Fact_Inbound_Interaction)
  Inbound Payment Conv %    = DIVIDE([Inbound Payments], [Inbound Calls])
  Inbound PTP Conv %        = DIVIDE([Inbound PTPs Booked], [Inbound Calls])
  Avg Inbound Wait (sec)    = AVERAGE(Fact_Inbound_Interaction[wait_seconds])
  Avg Inbound AHT (sec)     = AVERAGE(Fact_Inbound_Interaction[aht_seconds])
  Inbound Transfer Rate     = DIVIDE([Inbound Transfers], [Inbound Calls])
  Inbound vs Outbound Conv  = DIVIDE([Inbound Payment Conv %], [Outbound Payment Conv %]) - 1
  IVR Path Distribution     = VALUES(Fact_Inbound_Interaction[ivr_path])
  Inbound $ per Call        = DIVIDE([Inbound Payment Amount], [Inbound Calls])
  Service Level %           = DIVIDE(Calls Answered < 60s, Total Inbound Calls) * 100
```

### 14.7 Test Additions

- `test_payment_arrangements.py`: verify arrangement creation, status transitions, installment processing
- `test_payment_reversals.py`: verify reversal generation matches 3% rate, cure reversal logic
- `test_crm_contact_rules.py`: verify DNC/prohibition/soft-touch filtering works correctly
- `test_inbound_volume.py`: verify inbound volume ~8% of outbound
- `test_inbound_conversion.py`: verify inbound payment conversion ~45%
- `test_auto_pay.py`: verify auto-pay accounts generate payments automatically

### 14.8 Dashboard Impact

| Dashboard | New Capability |
|-----------|---------------|
| Financial Recovery | Net collections (after reversals), arrangement success vs default, cost-to-collect with arrangement cost |
| Credit Risk | Contact-prohibited account exposure, auto-pay effectiveness by segment |
| Agent Performance | Arrangement booking rate, arrangement success %, inbound AHT benchmark |
| Portfolio Management | Unreachable arrears (contact-prohibited accounts), soft-touch portfolio segment |
| **New: Operations Command** | Inbound call volume trends, service level %, IVR path analysis, inbound vs outbound conversion |

---

## Implementation Order & Dependencies

```
Phase 12 (CACS)
  ├── 12.1 Schema (Dim_Collection_Strategy, Dim_Queue, column changes)
  ├── 12.2 Config changes
  ├── 12.3 Generator: strategy assignment, workbin construction, queue transfers
  ├── 12.4 ETL: new tables
  ├── 12.5 SQL Views
  ├── 12.6 DAX Measures
  └── 12.7 Tests

Phase 13 (Dialer + WFM)
  Depends on: Phase 12 (workbin feeds dialer)
  ├── 13.1 Schema (dialer columns, dialer detail table, WFM columns)
  ├── 13.2 Config changes (DIALER_CFG, WFM_CFG)
  ├── 13.3 Generator: predictive dialer simulation, WFM adherence/occupancy
  ├── 13.4 ETL: dialer detail table, WFM column backfill
  ├── 13.5 SQL Views
  ├── 13.6 DAX Measures
  └── 13.7 Tests

Phase 14 (PEGA + CRM + Inbound)
  Depends on: Phase 12 (inbound accounts need strategy context)
  Depends on: Phase 13 (inbound AHT benchmarks against outbound)
  ├── 14.1 Schema (arrangements, reversals, inbound, CRM columns)
  ├── 14.2 Config changes
  ├── 14.3 Generator: arrangement engine, reversal engine, CRM profile, inbound sim
  ├── 14.4 ETL
  ├── 14.5 SQL Views
  ├── 14.6 DAX Measures
  └── 14.7 Tests
```

## Summary Cost (new artifacts)

| Phase | Tables | Columns | Config Params | Generator Changes | SQL Views | DAX Meas | Tests |
|-------|--------|---------|---------------|-------------------|-----------|----------|-------|
| 12 | 4-5 | 7 | ~20 | Major (strategy engine, workbin, queue transfers) | 4 | ~20 | 3 |
| 13 | 1-2 | ~15 | ~40 | Major (dialer sim, WFM engine) | 3 | ~35 | 5 |
| 14 | 4-5 | ~15 | ~45 | Major (arrangements, reversals, CRM, inbound) | 5 | ~40 | 6 |
| **Total** | **9-12** | **~37** | **~105** | **3 new engines** | **12** | **~95** | **14** |
