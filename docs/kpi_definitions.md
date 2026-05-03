# KPI definitions — MSI Collections
 
Every metric used in reporting, with its formula, data source, calculation notes, and benchmark context.
All KPIs are calculated at the agent/day grain in `v_agent_daily_kpis` and rolled up monthly in `v_agent_monthly_kpis`.
 
---
 
## Table of contents
 
1. [Contact metrics](#1-contact-metrics)
2. [Promise metrics](#2-promise-metrics)
3. [Recovery metrics](#3-recovery-metrics)
4. [Productivity metrics](#4-productivity-metrics)
5. [Handle time metrics](#5-handle-time-metrics)
6. [Calculation notes](#calculation-notes)
 
---
 
## 1. Contact metrics
 
### Total connections
 
| | |
|---|---|
| **Definition** | Total number of calls that connected — inbound and outbound |
| **Formula** | `SUM(calls_connected)` |
| **Source table** | `dialer_interactions` |
| **View** | `v_agent_daily_kpis.calls_connected` |
| **Notes** | A "connection" means the call was answered. It does not mean the right party was reached. Includes inbound calls picked up by the agent and outbound calls answered by any party. |
 
---
 
### RPC (Right Party Contact)
 
| | |
|---|---|
| **Definition** | A call that connected and confirmed the account holder was on the line |
| **Formula** | `COUNT(*) WHERE rpc_flag = TRUE` |
| **Source table** | `dialer_interactions` |
| **View** | `v_agent_daily_kpis.rpc_count` |
| **Notes** | RPC is the single most important contact quality metric. A non-RPC connection (third party, voicemail, wrong number) has no collections value and cannot generate a PTP. FICO/SMS channel contacts are counted separately and not included in RPC rate. |
 
---
 
### RPC%
 
| | |
|---|---|
| **Definition** | The proportion of connected calls that were Right Party Contacts |
| **Formula** | `SUM(rpc_flag = TRUE) / SUM(calls_connected)` |
| **Source table** | `dialer_interactions` |
| **View** | `v_agent_monthly_kpis.rpc_pct` |
| **Benchmark** | 40–60% is typical depending on portfolio age and dialer list quality |
| **Notes** | Low RPC% can indicate a stale or poorly segmented dialer list. High RPC% with low PTP% suggests agents are reaching clients but not converting. Always exclude FICO channel from RPC% calculation. |
 
---
 
### RPC / Op Hr
 
| | |
|---|---|
| **Definition** | Number of RPCs per operational hour — measures dialer efficiency per hour worked |
| **Formula** | `SUM(rpc_count) / SUM(operational_hours)` |
| **Source tables** | `dialer_interactions`, `agent_time_log` |
| **View** | Derived from `v_agent_monthly_kpis` |
| **Notes** | This metric tells you how productive an agent's time is, regardless of call volume. An agent with high connections but low operational hours will score well here — useful for identifying efficient workers vs. those padding time. |
 
---
 
### RPC arrears
 
| | |
|---|---|
| **Definition** | The total outstanding arrears balance on accounts where an RPC occurred |
| **Formula** | `SUM(account.balance) WHERE rpc_flag = TRUE` (distinct accounts) |
| **Source tables** | `dialer_interactions`, `accounts`, `payment_schedule` |
| **Notes** | This is the total collectible pool exposed through RPC activity. Used as the denominator for Capped KP / RPC Arrears. A large RPC arrears figure with low Capped KP indicates poor promise conversion on high-value accounts. |
 
---
 
## 2. Promise metrics
 
### # PTP (Promise to Pay)
 
| | |
|---|---|
| **Definition** | The number of promises made by clients during RPC calls |
| **Formula** | `COUNT(ptp_id)` where `date_of_interaction` is in the reporting period |
| **Source table** | `ptp_log` |
| **View** | `v_agent_daily_kpis.ptp_count` |
| **Notes** | PTPs are logged by the agent in the CRM (CACS) during or immediately after an RPC. A single account can have multiple PTPs in a period if previous promises were broken and the client was re-contacted. Only RPCs can generate PTPs. |
 
---
 
### PTP%
 
| | |
|---|---|
| **Definition** | The proportion of RPCs that resulted in a promise to pay |
| **Formula** | `COUNT(ptp_id) / COUNT(rpc_flag = TRUE)` |
| **Source tables** | `ptp_log`, `dialer_interactions` |
| **View** | `v_agent_monthly_kpis.ptp_pct` |
| **Benchmark** | 50–70% is a healthy range; below 40% suggests agents struggle to convert contacts |
| **Notes** | PTP% measures agent persuasion effectiveness. It should be read alongside KP% — a high PTP% with low KP% means agents are getting unrealistic commitments or the client base is non-committal. Filters applied: Advisors with titles of Team Leader, Operations Senior Manager, or Manager are excluded. |
 
---
 
### # Kept (KP)
 
| | |
|---|---|
| **Definition** | Number of promises where a matching payment was received within 30 days |
| **Formula** | `COUNT(ptp_id) WHERE status = 'Kept'` |
| **Source table** | `ptp_log` |
| **View** | `v_agent_daily_kpis.kept_count` |
| **Notes** | A promise is `Kept` when `cures_log` has a record for the same account with `payment_date` within 30 days of `date_of_interaction` and `amount_paid >= amount_promised`. The evaluation date is the promise result date, not the interaction date. |
 
---
 
### # Broken
 
| | |
|---|---|
| **Definition** | Number of promises where no matching payment was received within 30 days |
| **Formula** | `COUNT(ptp_id) WHERE status = 'Broken'` |
| **Source table** | `ptp_log` |
| **View** | `v_agent_daily_kpis.broken_count` |
| **Notes** | High broken count relative to kept count on a specific agent often indicates overpromising during calls — the agent is logging PTPs to hit PTP% targets without generating real commitment. This pattern is worth flagging in coaching sessions. |
 
---
 
### KP% (Kept Promise Rate)
 
| | |
|---|---|
| **Definition** | The proportion of evaluated promises that were honored |
| **Formula** | `COUNT(status = 'Kept') / (COUNT(status = 'Kept') + COUNT(status = 'Broken'))` |
| **Source table** | `ptp_log` |
| **View** | `v_agent_monthly_kpis.kp_pct` |
| **Benchmark** | 60–75% is standard; below 50% is a red flag at team level |
| **Notes** | Pending promises are excluded from the denominator — KP% is only calculated on resolved promises. This is important: early in the month, KP% can appear inflated if most promises are still Pending. Always report KP% on promises with a resolution date in the reporting window. |
 
---
 
### BB Conversion Rate
 
| | |
|---|---|
| **Definition** | Combined effectiveness of converting contacts into honored promises |
| **Formula** | `PTP% × KP%` |
| **Source tables** | `ptp_log`, `dialer_interactions` |
| **View** | `v_agent_monthly_kpis.bb_conversion_rate` |
| **Example** | PTP% = 60%, KP% = 65% → BB Conversion = 39% |
| **Notes** | BB Conversion is the single best summary metric for an agent's end-to-end collections effectiveness. An agent with high PTP% but low KP% and an agent with low PTP% but high KP% can arrive at the same BB Conversion — but they need different coaching interventions. Always decompose before acting on the combined number. |
 
---
 
### Capped KP $
 
| | |
|---|---|
| **Definition** | Total value of kept promises, capped at the account's arrears balance |
| **Formula** | `SUM(LEAST(amount_promised, account.balance)) WHERE ptp_status = 'Kept'` |
| **Source tables** | `ptp_log`, `accounts` |
| **View** | `v_ptp_performance.capped_kept_amount` |
| **Notes** | Capping prevents a kept promise from being counted above the actual collectible amount. For example, if a client owes $500 but promises $800, only $500 is counted. This is the financially accurate version of KP$ and should be used for revenue reporting. |
 
---
 
### Capped KP / RPC Arrears
 
| | |
|---|---|
| **Definition** | What percentage of exposed arrears was actually collected through kept promises |
| **Formula** | `SUM(capped_kept_amount) / SUM(rpc_arrears)` |
| **Source tables** | `ptp_log`, `accounts`, `dialer_interactions` |
| **Notes** | This is the most senior-level collections effectiveness metric. It answers: "Of all the money we had a conversation about, how much did we actually get?" Low values indicate the dialer is reaching clients but not moving money. |
 
---
 
## 3. Recovery metrics
 
### Cures
 
| | |
|---|---|
| **Definition** | Number of distinct delinquent accounts that made a payment, bringing their balance to ≤ $0 |
| **Formula** | `COUNT(DISTINCT account_id)` in `cures_log` for the reporting period |
| **Source table** | `cures_log` |
| **View** | `v_agent_daily_kpis.cured_accounts` |
| **Notes** | A "cure" is not just any payment — it specifically means the delinquent balance was eliminated or brought current. Multiple payments on the same account in a period count as one cure. |
 
---
 
### Cured amount
 
| | |
|---|---|
| **Definition** | Total dollar value of payments received across all cured accounts |
| **Formula** | `SUM(amount_paid)` in `cures_log` |
| **Source table** | `cures_log` |
| **View** | `v_agent_daily_kpis.cured_amount` |
| **Notes** | This is the gross collections revenue figure. It differs from Capped KP$ because it includes all payments, not just those tied to a PTP. Payments can come in spontaneously (online, ATM) without an agent interaction. |
 
---
 
### Cures / THT
 
| | |
|---|---|
| **Definition** | Number of accounts cured per Total Handle Time hour — the core collections productivity metric |
| **Formula** | `COUNT(DISTINCT cured_accounts) / SUM(tht_hours)` |
| **Source tables** | `cures_log`, `agent_time_log` |
| **View** | `v_agent_monthly_kpis.cures_per_tht` |
| **Benchmark** | Target varies by portfolio; used for relative ranking rather than absolute thresholds |
| **Notes** | THT (Total Handle Time) includes inbound and outbound call time. It is a more precise denominator than operational hours because it isolates actual working time on calls. An agent who is logged in but idle will have high operational hours but low THT. |
 
---
 
## 4. Productivity metrics
 
### Utilization
 
| | |
|---|---|
| **Definition** | Ratio of actual working time to scheduled working time |
| **Formula** | `operational_hours / schedule_hours` |
| **Source table** | `agent_time_log` |
| **View** | `v_agent_daily_kpis.utilization` |
| **Benchmark** | 70–85% is the standard target range; below 65% triggers a review |
| **Notes** | Already pre-calculated in the source data. An agent below 70% consistently may have adherence issues (late logins, extended breaks, early logouts). This should be reviewed alongside `login_time` and `logout_time` for pattern detection. The `utilization` column stores the decimal form (e.g. `0.73`), not percentage. Multiply by 100 for display. |
 
---
 
### No TL (No Team Lead)
 
| | |
|---|---|
| **Definition** | Agents who were not assigned to a supervisor at a specific reporting time |
| **Formula** | `COUNT(agent_id) WHERE supervisor_id IS NULL` |
| **Source table** | `agents` |
| **Notes** | In the synthetic data all agents have supervisors. In production, this flag captures agents between team reassignments or new hires pending assignment. Agents without a supervisor should be excluded from team-level KPI rollups to avoid skewing supervisor scores. |
 
---
 
## 5. Handle time metrics
 
### Dialer AHT — RPC
 
| | |
|---|---|
| **Definition** | Average handle time in seconds for calls where RPC occurred |
| **Formula** | `AVG(aht_seconds) WHERE rpc_flag = TRUE` |
| **Source table** | `dialer_interactions` |
| **View** | `v_agent_monthly_kpis.avg_aht_rpc_seconds` |
| **Notes** | RPC calls are longer by nature — the agent must verify identity, explain the situation, negotiate, and log the outcome. Typical RPC AHT is 180–480 seconds. Very short RPC AHT (<120s) may indicate agents are rushing through calls and not fully working the account. |
 
---
 
### Dialer AHT — Non-RPC
 
| | |
|---|---|
| **Definition** | Average handle time for connected calls that were not RPCs |
| **Formula** | `AVG(aht_seconds) WHERE rpc_flag = FALSE` |
| **Source table** | `dialer_interactions` |
| **View** | `v_agent_monthly_kpis.avg_aht_non_rpc_seconds` |
| **Notes** | Non-RPC calls should be short (30–90 seconds) — just enough to confirm the wrong party and disconnect. Long non-RPC AHT suggests agents are spending too long on unproductive calls. |
 
---
 
### Dialer ACW — RPC
 
| | |
|---|---|
| **Definition** | Average after-call work time in seconds for RPC calls |
| **Formula** | `AVG(acw_seconds) WHERE rpc_flag = TRUE` |
| **Source table** | `dialer_interactions` |
| **View** | `v_agent_monthly_kpis.avg_acw_rpc_seconds` |
| **Notes** | ACW includes the time to log the PTP in CACS, update account notes, and wrap the disposition. High ACW (>120s) may indicate agents need better CACS training or that the system is slow. Reducing ACW has a direct productivity impact — every 30 seconds saved per call is ~16 extra calls per agent per day at typical volumes. |
 
---
 
### Dialer ACW — Non-RPC
 
| | |
|---|---|
| **Definition** | Average after-call work for non-RPC connected calls |
| **Formula** | `AVG(acw_seconds) WHERE rpc_flag = FALSE` |
| **Source table** | `dialer_interactions` |
| **View** | `v_agent_monthly_kpis.avg_acw_non_rpc_seconds` |
| **Notes** | Should be very low (10–30 seconds). Mostly just a disposition click. If this is high, agents may be logging extensive notes on non-productive calls, which is an inefficiency to address in coaching. |
 
---
 
## Calculation notes
 
### Pending PTP exclusion
When calculating KP%, only promises with `status IN ('Kept', 'Broken')` are included in the denominator. Pending promises have not yet been evaluated and must not dilute the rate.
 
### Attribution window for cures
A cure is attributed to an agent if they had the last RPC with the account in the 30 days preceding the payment. In `v_ptp_performance`, the matching window is `payment_date BETWEEN date_of_interaction AND date_of_interaction + 30 days`.
 
### Monthly rollup vs. averaged averages
Rate KPIs (RPC%, PTP%, KP%) in `v_agent_monthly_kpis` are recalculated from summed totals, not averaged from daily rates. This is the correct approach — averaging daily percentages produces distorted results when daily volumes vary significantly.
 
### Capped KP vs. collected amount
These are different:
- **Capped KP$** — value of kept promises, capped at account arrears. Measures promise quality.
- **Cured amount** — actual cash received. Includes spontaneous payments not tied to any PTP.
 
### Filters applied to all KPI views
Per standard collections reporting practice, the following roles are excluded from agent-level KPI views:
- Collections Team Leader
- Operations Senior Manager
- Team Lead Collections
- Manager Collections
 
These positions appear in staffing data but do not have collections production targets.