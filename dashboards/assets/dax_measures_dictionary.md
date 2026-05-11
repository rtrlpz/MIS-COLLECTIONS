# Power BI DAX Measures: v7 Star Schema

Based on the v7 Star Schema table names (`Fact_Interactions`, `Fact_PTP_Log`, `Fact_Payments`, `Fact_Agent_Time_Log`, `Fact_EOM_Snapshot`).

## _Contact & Volume

| Measure Name | DAX Formula |
|---|---|
| **Calls Attempted** | `SUM('Fact_Interactions'[calls_attempted])` |
| **Calls Connected** | `SUM('Fact_Interactions'[calls_connected])` |
| **Connection Rate %** | `DIVIDE([Calls Connected], [Calls Attempted], 0)` |
| **Total RPCs** | `CALCULATE(COUNTROWS('Fact_Interactions'), 'Fact_Interactions'[rpc_flag] = TRUE())` |
| **Non-RPC Connections** | `[Calls Connected] - [Total RPCs]` |
| **RPC %** | `DIVIDE([Total RPCs], [Calls Connected], 0)` |
| **Total RPC Arrears** | `CALCULATE(SUM('Fact_Interactions'[rpc_arrears]), 'Fact_Interactions'[rpc_flag] = TRUE())` |
| **RPC per Op Hr** | `DIVIDE([Total RPCs], [Total Operational Hours], 0)` |
| **RPC per THT Hr** | `DIVIDE([Total RPCs], [Total THT Hours], 0)` |
| **Total Calls Attempted** | `SUM('Fact_Interactions'[calls_attempted])` |
| **Avg AHT RPC (sec)** | `CALCULATE(AVERAGE('Fact_Interactions'[aht_seconds]), 'Fact_Interactions'[rpc_flag] = TRUE())` |
| **Avg AHT Non-RPC (sec)** | `CALCULATE(AVERAGE('Fact_Interactions'[aht_seconds]), 'Fact_Interactions'[rpc_flag] = FALSE())` |
| **Avg ACW RPC (sec)** | `CALCULATE(AVERAGE('Fact_Interactions'[acw_seconds]), 'Fact_Interactions'[rpc_flag] = TRUE())` |
| **Avg ACW Non-RPC (sec)** | `CALCULATE(AVERAGE('Fact_Interactions'[acw_seconds]), 'Fact_Interactions'[rpc_flag] = FALSE())` |
| **Total Operational Hours** | `SUM('Fact_Agent_Time_Log'[operational_hours])` |
| **Total THT Hours** | `SUM('Fact_Agent_Time_Log'[tht_hours])` |
| **True Occupancy %** | `DIVIDE([Total THT Hours], [Total Operational Hours], 0)` |
| **Avg Utilization %** | `AVERAGE('Fact_Agent_Time_Log'[utilization])` |
| **Agents Below Util Target** | `CALCULATE(DISTINCTCOUNT('Fact_Agent_Time_Log'[agent_id]), 'Fact_Agent_Time_Log'[utilization] < 0.70)` |
| **THT Alignment %** | `DIVIDE([Total THT Hours], [Total Operational Hours], 0)` |

## _Promise & Recovery

| Measure Name | DAX Formula |
|---|---|
| **Total PTPs** | `COUNTROWS('Fact_PTP_Log')` |
| **PTP Kept** | `CALCULATE(COUNTROWS('Fact_PTP_Log'), 'Fact_PTP_Log'[status] = "Kept")` |
| **PTP Broken** | `CALCULATE(COUNTROWS('Fact_PTP_Log'), 'Fact_PTP_Log'[status] = "Broken")` |
| **PTP Pending** | `CALCULATE(COUNTROWS('Fact_PTP_Log'), 'Fact_PTP_Log'[status] = "Pending")` |
| **Evaluated PTPs** | `[PTP Kept] + [PTP Broken]` |
| **KP %** | `DIVIDE([PTP Kept], [Evaluated PTPs], 0)` |
| **Broken Rate %** | `DIVIDE([PTP Broken], [Evaluated PTPs], 0)` |
| **PTP %** | `DIVIDE([Total PTPs], [Total RPCs], 0)` |
| **BB Conversion Rate** | `[PTP %] * [KP %]` |
| **Amount Promised** | `SUM('Fact_PTP_Log'[promised_amount])` |
| **Capped KP $** | `SUMX(FILTER('Fact_PTP_Log', 'Fact_PTP_Log'[status] = "Kept"), MIN('Fact_PTP_Log'[promised_amount], 'Fact_PTP_Log'[rpc_arrears_at_contact]))` |
| **Capped KP / RPC Arrears** | `DIVIDE([Capped KP $], [Total RPC Arrears], 0)` |
| **Capped KP per Op Hr** | `DIVIDE([Capped KP $], [Total Operational Hours], 0)` |
| **Total Amount Paid** (all payments) | `SUM('Fact_Payments'[amount_paid])` |
| **Cured Amounts** (cured payments only) | `CALCULATE(SUM('Fact_Payments'[amount_paid]), 'Fact_Payments'[is_cured] = TRUE())` |
| **Non-Cured Amount** (non-cured payments) | `[Total Amount Paid] - [Cured Amounts]` |
| **Total Cures** | `CALCULATE(DISTINCTCOUNT('Fact_Payments'[account_id]), 'Fact_Payments'[is_cured] = TRUE())` |
| **Agent-Assisted Cures $** | `CALCULATE(SUM('Fact_Payments'[amount_paid]), 'Fact_Payments'[cure_flag] = "Agent_Cure")` |
| **Self-Cures $** | `CALCULATE(SUM('Fact_Payments'[amount_paid]), 'Fact_Payments'[cure_flag] = "Self_Cure")` |
| **Agent Cure Count** | `CALCULATE(DISTINCTCOUNT('Fact_Payments'[account_id]), 'Fact_Payments'[cure_flag] = "Agent_Cure")` |
| **Self-Cure Count** | `CALCULATE(DISTINCTCOUNT('Fact_Payments'[account_id]), 'Fact_Payments'[cure_flag] = "Self_Cure")` |
| **Self-Cure Rate %** | `DIVIDE([Self-Cure Count], [Total Cures], 0)` |
| **Cures per THT** | `DIVIDE([Total Cures], [Total THT Hours], 0)` |
| **Cures per Op Hr** | `DIVIDE([Total Cures], [Total Operational Hours], 0)` |
| **Collection Efficiency %** | `DIVIDE([Total Amount Paid], [Total RPC Arrears], 0)` |
| **Online Payments %** | `DIVIDE(CALCULATE(COUNTROWS('Fact_Payments'), 'Fact_Payments'[payment_method] = "Online"), COUNTROWS('Fact_Payments'), 0)` |
| **Branch ATM Payments %** | `DIVIDE(CALCULATE(COUNTROWS('Fact_Payments'), 'Fact_Payments'[payment_method] = "Branch_ATM"), COUNTROWS('Fact_Payments'), 0)` |
| **OFI Payments %** | `DIVIDE(CALCULATE(COUNTROWS('Fact_Payments'), 'Fact_Payments'[payment_method] = "OFI"), COUNTROWS('Fact_Payments'), 0)` |

## _Portfolio & Trends

> ⚠ **Note:** All EOM measures must filter to one snapshot date. Without this filter, they triple-count (3 month-ends × all accounts).

| Measure Name | DAX Formula |
|---|---|
| **Portfolio Total Balance** | `CALCULATE(SUM('Fact_EOM_Snapshot'[balance]), 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))` |
| **Portfolio Total Arrears** | `CALCULATE(SUM('Fact_EOM_Snapshot'[arrears]), 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))` |
| **Accounts in Mora** | `CALCULATE(COUNTROWS('Fact_EOM_Snapshot'), 'Fact_EOM_Snapshot'[status] = "Mora", 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))` |
| **Total Accounts** | `CALCULATE(COUNTROWS('Fact_EOM_Snapshot'), 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))` |
| **Mora Rate %** | `DIVIDE([Accounts in Mora], [Total Accounts], 0)` |
| **Arrears / Balance %** | `DIVIDE([Portfolio Total Arrears], [Portfolio Total Balance], 0)` |
| **Avg Balance per Account** | `DIVIDE([Portfolio Total Balance], [Total Accounts], 0)` |
| **Avg Arrears per Mora Account** | `DIVIDE([Portfolio Total Arrears], [Accounts in Mora], 0)` |
| **Accounts DPD 1-30** | `CALCULATE(COUNTROWS('Fact_EOM_Snapshot'), 'Fact_EOM_Snapshot'[dpd_bucket] = "1-30", 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))` |
| **Accounts DPD 31-60** | `CALCULATE(COUNTROWS('Fact_EOM_Snapshot'), 'Fact_EOM_Snapshot'[dpd_bucket] = "31-60", 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))` |
| **Accounts DPD 61-90** | `CALCULATE(COUNTROWS('Fact_EOM_Snapshot'), 'Fact_EOM_Snapshot'[dpd_bucket] = "61-90", 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))` |
| **Accounts DPD 90+** | `CALCULATE(COUNTROWS('Fact_EOM_Snapshot'), 'Fact_EOM_Snapshot'[dpd_bucket] = "90+", 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))` |
| **KP % Prior Month** | `CALCULATE([KP %], DATEADD('Dim_Calendar'[date], -1, MONTH))` |
| **KP % MoM Change** | `[KP %] - [KP % Prior Month]` |
| **Cured Amount Prior Month** | `CALCULATE([Cured Amounts], DATEADD('Dim_Calendar'[date], -1, MONTH))` |
| **Cured Amount MoM %** | `DIVIDE([Cured Amounts] - [Cured Amount Prior Month], [Cured Amount Prior Month], 0)` |
| **RPC % Prior Month** | `CALCULATE([RPC %], DATEADD('Dim_Calendar'[date], -1, MONTH))` |
| **BB Conversion Prior Month** | `CALCULATE([BB Conversion Rate], DATEADD('Dim_Calendar'[date], -1, MONTH))` |
| **Total Cures Prior Month** | `CALCULATE([Total Cures], DATEADD('Dim_Calendar'[date], -1, MONTH))` |
| **Cures MoM Change** | `[Total Cures] - [Total Cures Prior Month]` |
| **Cured Amount YTD** | `CALCULATE([Cured Amounts], DATESYTD('Dim_Calendar'[date]))` |
| **KP % YTD** | `CALCULATE([KP %], DATESYTD('Dim_Calendar'[date]))` |
| **Rolling 3M KP %** | `CALCULATE([KP %], DATESINPERIOD('Dim_Calendar'[date], LASTDATE('Dim_Calendar'[date]), -3, MONTH))` |
| **Portfolio Balance Prior Month** | `CALCULATE(SUM('Fact_EOM_Snapshot'[balance]), 'Fact_EOM_Snapshot'[snapshot_date] = EOMONTH(MAX('Fact_EOM_Snapshot'[snapshot_date]), -1))` |
| **Mora Rate Prior Month** | `CALCULATE([Mora Rate %], DATEADD('Dim_Calendar'[date], -1, MONTH))` |
| **Mora Rate MoM Change** | `[Mora Rate %] - [Mora Rate Prior Month]` |

---

## Quick Reference

| KPI | Table |
|---|---|
| **RPC%, Connection Rate%, AHT, ACW, Utilization, Occupancy** | `_Contact & Volume` |
| **KP%, PTP%, BB Conversion, Capped KP$, Capped KP/Arrears, Cures, Cured Amount, Self-Cure, Agent-Cure, Payment methods** | `_Promise & Recovery` |
| **Portfolio Balance, Arrears, Mora Rate, DPD buckets, all MoM/YTD trends** | `_Portfolio & Trends` |