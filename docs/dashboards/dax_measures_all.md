# DAX Measures — Complete Reference

**Total Measures:** 252
**Source:** `dashboards/dax/collections_dax_v2.csv`

---

## Table of Contents

- [_Outreach & Activity](#outreach--activity) (22 measures)
- [_Promise & Recovery](#promise--recovery) (29 measures)
- [_Portfolio Health](#portfolio-health) (25 measures)
- [_Goals & Targets](#goals--targets) (31 measures)
- [_Composites & Strategy](#composites--strategy) (27 measures)
- [_Time Intelligence](#time-intelligence) (118 measures)

---

## _Outreach & Activity

*Base contact metrics, agent productivity, and handle time.*

**Total Calls Attempted**

```dax
SUM('Fact_Interactions'[calls_attempted])
```

**Total Connected**

```dax
SUM('Fact_Interactions'[calls_connected])
```

**Connection Rate**

```dax
DIVIDE([Total Connected], [Total Calls Attempted], 0)
```

**Total RPCs**

```dax
CALCULATE(COUNTROWS('Fact_Interactions'), 'Fact_Interactions'[rpc_flag] = TRUE())
```

**Non-RPC Connections**

```dax
[Total Connected] - [Total RPCs]
```

**RPC Rate**

```dax
DIVIDE([Total RPCs], [Total Connected], 0)
```

**Total RPC Arrears**

```dax
CALCULATE(SUM('Fact_Interactions'[rpc_arrears]), 'Fact_Interactions'[rpc_flag] = TRUE())
```

**Total Op Hours**

```dax
SUM('Fact_Agent_Time_Log'[operational_hours])
```

**Total THT Hours**

```dax
SUM('Fact_Agent_Time_Log'[tht_hours])
```

**RPC per Op Hr**

```dax
DIVIDE([Total RPCs], [Total Op Hours], 0)
```

**RPC per THT Hr**

```dax
DIVIDE([Total RPCs], [Total THT Hours], 0)
```

**Avg AHT RPC (sec)**

```dax
CALCULATE(AVERAGE('Fact_Interactions'[aht_seconds]), 'Fact_Interactions'[rpc_flag] = TRUE())
```

**Avg AHT Non-RPC (sec)**

```dax
CALCULATE(AVERAGE('Fact_Interactions'[aht_seconds]), 'Fact_Interactions'[rpc_flag] = FALSE())
```

**Avg ACW RPC (sec)**

```dax
CALCULATE(AVERAGE('Fact_Interactions'[acw_seconds]), 'Fact_Interactions'[rpc_flag] = TRUE())
```

**Avg ACW Non-RPC (sec)**

```dax
CALCULATE(AVERAGE('Fact_Interactions'[acw_seconds]), 'Fact_Interactions'[rpc_flag] = FALSE())
```

**Avg Total Handle Time RPC (sec)**

```dax
CALCULATE(AVERAGE('Fact_Interactions'[aht_seconds] + 'Fact_Interactions'[acw_seconds]), 'Fact_Interactions'[rpc_flag] = TRUE())
```

**Avg AHT (sec)**

```dax
AVERAGE('Fact_Interactions'[aht_seconds])
```

**Avg ACW (sec)**

```dax
AVERAGE('Fact_Interactions'[acw_seconds])
```

**THT Alignment %**

```dax
DIVIDE([Total THT Hours], [Total Op Hours], 0)
```

**Avg Utilization %**

```dax
AVERAGE('Fact_Agent_Time_Log'[utilization])
```

**Agents Below Util Target**

```dax
CALCULATE(DISTINCTCOUNT('Fact_Agent_Time_Log'[agent_id]), 'Fact_Agent_Time_Log'[utilization] < 0.70)
```

**Contacts per Hour**

```dax
DIVIDE([Total Connected], [Total Op Hours], 0)
```

---

## _Promise & Recovery

*Promise-to-pay pipeline, KP%, BB Conversion, Capped KP, cures, recovery amounts, payment methods.*

**Total PTPs**

```dax
COUNTROWS('Fact_PTP_Log')
```

**PTP Kept**

```dax
CALCULATE(COUNTROWS('Fact_PTP_Log'), 'Fact_PTP_Log'[status] = "Kept")
```

**PTP Broken**

```dax
CALCULATE(COUNTROWS('Fact_PTP_Log'), 'Fact_PTP_Log'[status] = "Broken")
```

**PTP Pending**

```dax
CALCULATE(COUNTROWS('Fact_PTP_Log'), 'Fact_PTP_Log'[status] = "Pending")
```

**Evaluated PTPs**

```dax
[PTP Kept] + [PTP Broken]
```

**Promise Rate**

```dax
DIVIDE([Total PTPs], [Total RPCs], 0)
```

**KP Rate**

```dax
DIVIDE([PTP Kept], [Evaluated PTPs], 0)
```

**Broken Rate**

```dax
DIVIDE([PTP Broken], [Evaluated PTPs], 0)
```

**BB Conversion Rate**

```dax
[Promise Rate] * [KP Rate]
```

**Amount Promised**

```dax
SUM('Fact_PTP_Log'[promised_amount])
```

**Capped KP $**

```dax
SUMX(FILTER('Fact_PTP_Log', 'Fact_PTP_Log'[status] = "Kept"), MIN('Fact_PTP_Log'[promised_amount], 'Fact_PTP_Log'[rpc_arrears_at_contact]))
```

**Capped KP per RPC Arrears**

```dax
DIVIDE([Capped KP $], [Total RPC Arrears], 0)
```

**Capped KP per Op Hr**

```dax
DIVIDE([Capped KP $], [Total Op Hours], 0)
```

**Total Recovery**

```dax
SUM('Fact_Payments'[amount_paid])
```

**Cured Amount**

```dax
CALCULATE(SUM('Fact_Payments'[amount_paid]), 'Fact_Payments'[is_cured] = TRUE())
```

**Non-Cured Amount**

```dax
[Total Recovery] - [Cured Amount]
```

**Total Cures**

```dax
CALCULATE(DISTINCTCOUNT('Fact_Payments'[account_id]), 'Fact_Payments'[is_cured] = TRUE())
```

**Agent-Assisted Cures $**

```dax
CALCULATE(SUM('Fact_Payments'[amount_paid]), 'Fact_Payments'[cure_flag] = "Agent_Cure")
```

**Self-Cures $**

```dax
CALCULATE(SUM('Fact_Payments'[amount_paid]), 'Fact_Payments'[cure_flag] = "Self_Cure")
```

**Agent Cure Count**

```dax
CALCULATE(DISTINCTCOUNT('Fact_Payments'[account_id]), 'Fact_Payments'[cure_flag] = "Agent_Cure")
```

**Self-Cure Count**

```dax
CALCULATE(DISTINCTCOUNT('Fact_Payments'[account_id]), 'Fact_Payments'[cure_flag] = "Self_Cure")
```

**Agent Cure Rate**

```dax
DIVIDE([Agent Cure Count], [Total Cures], 0)
```

**Self-Cure Rate**

```dax
DIVIDE([Self-Cure Count], [Total Cures], 0)
```

**Cures per THT Hr**

```dax
DIVIDE([Total Cures], [Total THT Hours], 0)
```

**Cures per Op Hr**

```dax
DIVIDE([Total Cures], [Total Op Hours], 0)
```

**Collection Efficiency**

```dax
DIVIDE([Total Recovery], [Total RPC Arrears], 0)
```

**Online Payment %**

```dax
DIVIDE(CALCULATE(COUNTROWS('Fact_Payments'), 'Fact_Payments'[payment_method] = "Online"), COUNTROWS('Fact_Payments'), 0)
```

**Branch/ATM Payment %**

```dax
DIVIDE(CALCULATE(COUNTROWS('Fact_Payments'), 'Fact_Payments'[payment_method] = "Branch/ATM"), COUNTROWS('Fact_Payments'), 0)
```

**OFI Payment %**

```dax
DIVIDE(CALCULATE(COUNTROWS('Fact_Payments'), 'Fact_Payments'[payment_method] = "OFI"), COUNTROWS('Fact_Payments'), 0)
```

---

## _Portfolio Health

*EOM snapshot, DPD buckets, arrears, roll rates, migration, skip-path analysis.*

**Portfolio Total Balance**

```dax
CALCULATE(SUM('Fact_EOM_Snapshot'[balance]), 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))
```

**Portfolio Total Arrears**

```dax
CALCULATE(SUM('Fact_EOM_Snapshot'[arrears]), 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))
```

**Total Accounts**

```dax
CALCULATE(COUNTROWS('Fact_EOM_Snapshot'), 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))
```

**Accounts in Mora**

```dax
CALCULATE(COUNTROWS('Fact_EOM_Snapshot'), 'Fact_EOM_Snapshot'[status] = "Mora", 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))
```

**Mora Rate**

```dax
DIVIDE([Accounts in Mora], [Total Accounts], 0)
```

**Arrears to Balance**

```dax
DIVIDE([Portfolio Total Arrears], [Portfolio Total Balance], 0)
```

**Avg Balance per Account**

```dax
DIVIDE([Portfolio Total Balance], [Total Accounts], 0)
```

**Avg Arrears per Mora Account**

```dax
DIVIDE([Portfolio Total Arrears], [Accounts in Mora], 0)
```

**Accounts DPD Current**

```dax
CALCULATE(COUNTROWS('Fact_EOM_Snapshot'), 'Fact_EOM_Snapshot'[dpd_bucket] = "Current", 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))
```

**Accounts DPD 1-30**

```dax
CALCULATE(COUNTROWS('Fact_EOM_Snapshot'), 'Fact_EOM_Snapshot'[dpd_bucket] = "1-30", 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))
```

**Accounts DPD 31-60**

```dax
CALCULATE(COUNTROWS('Fact_EOM_Snapshot'), 'Fact_EOM_Snapshot'[dpd_bucket] = "31-60", 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))
```

**Accounts DPD 61-90**

```dax
CALCULATE(COUNTROWS('Fact_EOM_Snapshot'), 'Fact_EOM_Snapshot'[dpd_bucket] = "61-90", 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))
```

**Accounts DPD 90+**

```dax
CALCULATE(COUNTROWS('Fact_EOM_Snapshot'), 'Fact_EOM_Snapshot'[dpd_bucket] = "90+", 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))
```

**Mora Rate by DPD 1-30**

```dax
DIVIDE([Accounts DPD 1-30], [Total Accounts], 0)
```

**Mora Rate by DPD 31-60**

```dax
DIVIDE([Accounts DPD 31-60], [Total Accounts], 0)
```

**Mora Rate by DPD 61-90**

```dax
DIVIDE([Accounts DPD 61-90], [Total Accounts], 0)
```

**Mora Rate by DPD 90+**

```dax
DIVIDE([Accounts DPD 90+], [Total Accounts], 0)
```

**Roll Rate Current to Delinquent**

```dax
VAR _CurrentMonth = MAX('Fact_EOM_Snapshot'[snapshot_date]) VAR _PriorMonth = EOMONTH(_CurrentMonth, -1) VAR _AccountsInPriorBucket = CALCULATE(DISTINCTCOUNT('Fact_EOM_Snapshot'[account_id]), 'Fact_EOM_Snapshot'[snapshot_date] = _PriorMonth, 'Fact_EOM_Snapshot'[dpd_bucket] = "Current") VAR _AccountsRolled = COUNTROWS(FILTER('Fact_EOM_Snapshot', 'Fact_EOM_Snapshot'[snapshot_date] = _CurrentMonth && 'Fact_EOM_Snapshot'[dpd_bucket] <> "Current" && CONTAINS(CALCULATETABLE(FILTER('Fact_EOM_Snapshot', 'Fact_EOM_Snapshot'[dpd_bucket] = "Current"), 'Fact_EOM_Snapshot'[snapshot_date] = _PriorMonth), 'Fact_EOM_Snapshot'[account_id], 'Fact_EOM_Snapshot'[account_id]))) RETURN DIVIDE(_AccountsRolled, _AccountsInPriorBucket, 0)
```

**Roll Rate 30 to 60**

```dax
VAR _CurrentMonth = MAX('Fact_EOM_Snapshot'[snapshot_date]) VAR _PriorMonth = EOMONTH(_CurrentMonth, -1) VAR _AccountsInPriorBucket = CALCULATE(DISTINCTCOUNT('Fact_EOM_Snapshot'[account_id]), 'Fact_EOM_Snapshot'[snapshot_date] = _PriorMonth, 'Fact_EOM_Snapshot'[dpd_bucket] = "1-30") VAR _AccountsRolled = COUNTROWS(FILTER('Fact_EOM_Snapshot', 'Fact_EOM_Snapshot'[snapshot_date] = _CurrentMonth && 'Fact_EOM_Snapshot'[dpd_bucket] = "31-60" && CONTAINS(CALCULATETABLE(FILTER('Fact_EOM_Snapshot', 'Fact_EOM_Snapshot'[dpd_bucket] = "1-30"), 'Fact_EOM_Snapshot'[snapshot_date] = _PriorMonth), 'Fact_EOM_Snapshot'[account_id], 'Fact_EOM_Snapshot'[account_id]))) RETURN DIVIDE(_AccountsRolled, _AccountsInPriorBucket, 0)
```

**Roll Rate 60 to 90**

```dax
VAR _CurrentMonth = MAX('Fact_EOM_Snapshot'[snapshot_date]) VAR _PriorMonth = EOMONTH(_CurrentMonth, -1) VAR _AccountsInPriorBucket = CALCULATE(DISTINCTCOUNT('Fact_EOM_Snapshot'[account_id]), 'Fact_EOM_Snapshot'[snapshot_date] = _PriorMonth, 'Fact_EOM_Snapshot'[dpd_bucket] = "61-90") VAR _AccountsRolled = COUNTROWS(FILTER('Fact_EOM_Snapshot', 'Fact_EOM_Snapshot'[snapshot_date] = _CurrentMonth && 'Fact_EOM_Snapshot'[dpd_bucket] = "90+" && CONTAINS(CALCULATETABLE(FILTER('Fact_EOM_Snapshot', 'Fact_EOM_Snapshot'[dpd_bucket] = "61-90"), 'Fact_EOM_Snapshot'[snapshot_date] = _PriorMonth), 'Fact_EOM_Snapshot'[account_id], 'Fact_EOM_Snapshot'[account_id]))) RETURN DIVIDE(_AccountsRolled, _AccountsInPriorBucket, 0)
```

**Net Roll Rate**

```dax
[Roll Rate Current to Delinquent] - [Roll Rate 30 to 60]
```

**Roll Rate Trend**

```dax
VAR _CurrentMonth = MAX('Fact_EOM_Snapshot'[snapshot_date]) VAR _PriorMonth = EOMONTH(_CurrentMonth, -1) VAR _CurrentRoll = [Roll Rate Current to Delinquent] VAR _PriorRoll = CALCULATE([Roll Rate Current to Delinquent], FILTER(ALL('Fact_EOM_Snapshot'), 'Fact_EOM_Snapshot'[snapshot_date] = _PriorMonth)) RETURN _CurrentRoll - _PriorRoll
```

**Skip Path Accounts**

```dax
VAR _CurrentMonth = MAX('Fact_EOM_Snapshot'[snapshot_date]) VAR _PriorMonth = EOMONTH(_CurrentMonth, -1) VAR _SkipPaths = COUNTROWS(FILTER('Fact_EOM_Snapshot', 'Fact_EOM_Snapshot'[snapshot_date] = _CurrentMonth && 'Fact_EOM_Snapshot'[dpd_bucket] = "90+" && CONTAINS(CALCULATETABLE(FILTER('Fact_EOM_Snapshot', 'Fact_EOM_Snapshot'[dpd_bucket] = "Current"), 'Fact_EOM_Snapshot'[snapshot_date] = _PriorMonth), 'Fact_EOM_Snapshot'[account_id], 'Fact_EOM_Snapshot'[account_id]))) RETURN _SkipPaths
```

**Deterioration Rate**

```dax
VAR _CurrentMonth = MAX('Fact_EOM_Snapshot'[snapshot_date]) VAR _PriorMonth = EOMONTH(_CurrentMonth, -1) VAR _Deteriorated = COUNTROWS(FILTER(FILTER('Fact_EOM_Snapshot', 'Fact_EOM_Snapshot'[snapshot_date] = _CurrentMonth), VAR _AcctID = 'Fact_EOM_Snapshot'[account_id] VAR _CurrBucket = SWITCH('Fact_EOM_Snapshot'[dpd_bucket], "Current", 0, "1-30", 1, "31-60", 2, "61-90", 3, "90+", 4, 0) VAR _PriorBucket = LOOKUPVALUE('Fact_EOM_Snapshot'[dpd_bucket], 'Fact_EOM_Snapshot'[account_id], _AcctID, 'Fact_EOM_Snapshot'[snapshot_date], _PriorMonth) VAR _PriorNum = SWITCH(_PriorBucket, "Current", 0, "1-30", 1, "31-60", 2, "61-90", 3, "90+", 4, 0) RETURN _CurrBucket > _PriorNum)) RETURN DIVIDE(_Deteriorated, [Total Accounts], 0)
```

**Stuck 90+ Accounts**

```dax
CALCULATE(DISTINCTCOUNT('Fact_EOM_Snapshot'[account_id]), 'Fact_EOM_Snapshot'[dpd_bucket] = "90+", 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))
```

---

## _Goals & Targets

*Goal values, gaps, RAG status, color hex for 7 key KPI metrics.*

### Calculated Tables

**Dim_Targets**

```dax
DATATABLE("MetricName", STRING, "GoalValue", DOUBLE, "Unit", STRING, "Direction", STRING, "AmberThreshold", DOUBLE, "GreenThreshold", DOUBLE, "DisplayFormat", STRING, "MeasureName", STRING, "SortOrder", INTEGER, {{"PTP%", 0.80, "%", "HigherIsBetter", 0.85, 1.00, "0.0%", "Promise Rate", 1}, {"KP%", 0.80, "%", "HigherIsBetter", 0.85, 1.00, "0.0%", "KP Rate", 2}, {"ACW RPC (sec)", 120, "sec", "LowerIsBetter", 1.00, 0.85, "#,##0", "Avg ACW RPC (sec)", 3}, {"ACW Non-RPC (sec)", 25, "sec", "LowerIsBetter", 1.00, 0.85, "#,##0", "Avg ACW Non-RPC (sec)", 4}, {"Capped KP / RPC Arrears", 0.37, "%", "HigherIsBetter", 0.85, 1.00, "0.0%", "Capped KP per RPC Arrears", 5}, {"Cures / THT", 2.40, "count", "HigherIsBetter", 0.85, 1.00, "#,##0.00", "Cures per THT Hr", 6}, {"Utilization", 0.90, "%", "HigherIsBetter", 0.85, 1.00, "0.0%", "Avg Utilization %", 7}})
```

**Color Reference**

```dax
DATATABLE("Status", STRING, "HexColor", STRING, "RGB", STRING, "SortOrder", INTEGER, {{"Green", "#00B050", "RGB(0, 176, 80)", 1}, {"Amber", "#FFC000", "RGB(255, 192, 0)", 2}, {"Red", "#FF0000", "RGB(255, 0, 0)", 3}})
```

### Measures

**Goal PTP%**

```dax
VAR _Goal = LOOKUPVALUE(Dim_Targets[GoalValue], Dim_Targets[MetricName], "PTP%") RETURN _Goal
```

**Goal KP%**

```dax
VAR _Goal = LOOKUPVALUE(Dim_Targets[GoalValue], Dim_Targets[MetricName], "KP%") RETURN _Goal
```

**Goal ACW RPC (sec)**

```dax
VAR _Goal = LOOKUPVALUE(Dim_Targets[GoalValue], Dim_Targets[MetricName], "ACW RPC (sec)") RETURN _Goal
```

**Goal ACW Non-RPC (sec)**

```dax
VAR _Goal = LOOKUPVALUE(Dim_Targets[GoalValue], Dim_Targets[MetricName], "ACW Non-RPC (sec)") RETURN _Goal
```

**Goal Capped KP per RPC Arrears**

```dax
VAR _Goal = LOOKUPVALUE(Dim_Targets[GoalValue], Dim_Targets[MetricName], "Capped KP / RPC Arrears") RETURN _Goal
```

**Goal Cures per THT Hr**

```dax
VAR _Goal = LOOKUPVALUE(Dim_Targets[GoalValue], Dim_Targets[MetricName], "Cures / THT") RETURN _Goal
```

**Goal Utilization**

```dax
VAR _Goal = LOOKUPVALUE(Dim_Targets[GoalValue], Dim_Targets[MetricName], "Utilization") RETURN _Goal
```

**Selected Goal**

```dax
VAR _SelectedMetric = SELECTEDVALUE(Dim_Targets[MetricName]) VAR _Goal = LOOKUPVALUE(Dim_Targets[GoalValue], Dim_Targets[MetricName], _SelectedMetric) RETURN _Goal
```

**PTP% Gap**

```dax
[Promise Rate] - [Goal PTP%]
```

**KP% Gap**

```dax
[KP Rate] - [Goal KP%]
```

**ACW RPC Gap**

```dax
[Avg ACW RPC (sec)] - [Goal ACW RPC (sec)]
```

**ACW Non-RPC Gap**

```dax
[Avg ACW Non-RPC (sec)] - [Goal ACW Non-RPC (sec)]
```

**Capped KP per RPC Arrears Gap**

```dax
[Capped KP per RPC Arrears] - [Goal Capped KP per RPC Arrears]
```

**Cures per THT Hr Gap**

```dax
[Cures per THT Hr] - [Goal Cures per THT Hr]
```

**Utilization Gap**

```dax
[Avg Utilization %] - [Goal Utilization]
```

**PTP% Status**

```dax
VAR _Actual = [Promise Rate] VAR _Goal = [Goal PTP%] VAR _AmberThreshold = LOOKUPVALUE(Dim_Targets[AmberThreshold], Dim_Targets[MetricName], "PTP%") VAR _Result = SWITCH(TRUE(), _Actual >= _Goal, "Green", _Actual >= _Goal * _AmberThreshold, "Amber", "Red") RETURN _Result
```

**KP% Status**

```dax
VAR _Actual = [KP Rate] VAR _Goal = [Goal KP%] VAR _AmberThreshold = LOOKUPVALUE(Dim_Targets[AmberThreshold], Dim_Targets[MetricName], "KP%") VAR _Result = SWITCH(TRUE(), _Actual >= _Goal, "Green", _Actual >= _Goal * _AmberThreshold, "Amber", "Red") RETURN _Result
```

**ACW RPC Status**

```dax
VAR _Actual = [Avg ACW RPC (sec)] VAR _Goal = [Goal ACW RPC (sec)] VAR _GreenThreshold = LOOKUPVALUE(Dim_Targets[GreenThreshold], Dim_Targets[MetricName], "ACW RPC (sec)") VAR _Result = SWITCH(TRUE(), _Actual <= _Goal * _GreenThreshold, "Green", _Actual <= _Goal * (2 - _GreenThreshold), "Amber", "Red") RETURN _Result
```

**ACW Non-RPC Status**

```dax
VAR _Actual = [Avg ACW Non-RPC (sec)] VAR _Goal = [Goal ACW Non-RPC (sec)] VAR _GreenThreshold = LOOKUPVALUE(Dim_Targets[GreenThreshold], Dim_Targets[MetricName], "ACW Non-RPC (sec)") VAR _Result = SWITCH(TRUE(), _Actual <= _Goal * _GreenThreshold, "Green", _Actual <= _Goal * (2 - _GreenThreshold), "Amber", "Red") RETURN _Result
```

**Capped KP per RPC Arrears Status**

```dax
VAR _Actual = [Capped KP per RPC Arrears] VAR _Goal = [Goal Capped KP per RPC Arrears] VAR _AmberThreshold = LOOKUPVALUE(Dim_Targets[AmberThreshold], Dim_Targets[MetricName], "Capped KP / RPC Arrears") VAR _Result = SWITCH(TRUE(), _Actual >= _Goal, "Green", _Actual >= _Goal * _AmberThreshold, "Amber", "Red") RETURN _Result
```

**Cures per THT Hr Status**

```dax
VAR _Actual = [Cures per THT Hr] VAR _Goal = [Goal Cures per THT Hr] VAR _AmberThreshold = LOOKUPVALUE(Dim_Targets[AmberThreshold], Dim_Targets[MetricName], "Cures / THT") VAR _Result = SWITCH(TRUE(), _Actual >= _Goal, "Green", _Actual >= _Goal * _AmberThreshold, "Amber", "Red") RETURN _Result
```

**Utilization Status**

```dax
VAR _Actual = [Avg Utilization %] VAR _Goal = [Goal Utilization] VAR _AmberThreshold = LOOKUPVALUE(Dim_Targets[AmberThreshold], Dim_Targets[MetricName], "Utilization") VAR _Result = SWITCH(TRUE(), _Actual >= _Goal, "Green", _Actual >= _Goal * _AmberThreshold, "Amber", "Red") RETURN _Result
```

**PTP% Color**

```dax
VAR _Status = [PTP% Status] RETURN LOOKUPVALUE('Color Reference'[HexColor], 'Color Reference'[Status], _Status)
```

**KP% Color**

```dax
VAR _Status = [KP% Status] RETURN LOOKUPVALUE('Color Reference'[HexColor], 'Color Reference'[Status], _Status)
```

**ACW RPC Color**

```dax
VAR _Status = [ACW RPC Status] RETURN LOOKUPVALUE('Color Reference'[HexColor], 'Color Reference'[Status], _Status)
```

**ACW Non-RPC Color**

```dax
VAR _Status = [ACW Non-RPC Status] RETURN LOOKUPVALUE('Color Reference'[HexColor], 'Color Reference'[Status], _Status)
```

**Capped KP per RPC Arrears Color**

```dax
VAR _Status = [Capped KP per RPC Arrears Status] RETURN LOOKUPVALUE('Color Reference'[HexColor], 'Color Reference'[Status], _Status)
```

**Cures per THT Hr Color**

```dax
VAR _Status = [Cures per THT Hr Status] RETURN LOOKUPVALUE('Color Reference'[HexColor], 'Color Reference'[Status], _Status)
```

**Utilization Color**

```dax
VAR _Status = [Utilization Status] RETURN LOOKUPVALUE('Color Reference'[HexColor], 'Color Reference'[Status], _Status)
```

---

## _Composites & Strategy

*Composite scores, agent metrics, dialer performance, financial efficiency, vintage analysis, credit risk.*

**Portfolio Health Score**

```dax
VAR _PTP = [Promise Rate] * 25 VAR _KP = [KP Rate] * 25 VAR _Cures = DIVIDE([Cures per THT Hr], 3, 0) * 25 VAR _Util = [Avg Utilization %] * 25 RETURN _PTP + _KP + _Cures + _Util
```

**Portfolio At-Risk Balance**

```dax
CALCULATE(SUM('Fact_EOM_Snapshot'[arrears]), 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]), 'Fact_EOM_Snapshot'[status] = "Mora")
```

**Agent Quality Score**

```dax
VAR _KPScore = [KP Rate] * 40 VAR _AHTScore = IF([Avg AHT RPC (sec)] <= 180, 30, IF([Avg AHT RPC (sec)] <= 240, 20, 10)) VAR _UtilScore = [Avg Utilization %] * 30 RETURN _KPScore + _AHTScore + _UtilScore
```

**Agent Performance Tier**

```dax
VAR _Score = [Agent Quality Score] RETURN SWITCH(TRUE(), _Score >= 80, "High", _Score >= 60, "Medium", "Low")
```

**Agent Tenure Months**

```dax
DATEDIFF(LOOKUPVALUE('Dim_Employees'[hire_date], 'Dim_Employees'[agent_id], SELECTEDVALUE('Fact_Agent_Time_Log'[agent_id])), TODAY(), MONTH)
```

**Coaching Alert**

```dax
VAR _PriorWeekScore = CALCULATE([Agent Quality Score], FILTER(ALL('Dim_Calendar'), 'Dim_Calendar'[iso_week] = SELECTEDVALUE('Dim_Calendar'[iso_week]) - 1)) VAR _WoWDrop = DIVIDE([Agent Quality Score] - _PriorWeekScore, _PriorWeekScore, 0) RETURN IF(_WoWDrop < -0.10, "Alert", "OK")
```

**Dialer Abandon Rate**

```dax
VAR _Abandoned = CALCULATE(COUNTROWS('Fact_Interactions'), 'Fact_Interactions'[channel] = "Dialer", 'Fact_Interactions'[rpc_flag] = FALSE()) RETURN DIVIDE(_Abandoned, [Total Connected], 0)
```

**Dialer Efficiency Score**

```dax
VAR _ConnRate = [Connection Rate] * 40 VAR _RPCRate = [RPC Rate] * 35 VAR _Util = [Avg Utilization %] * 25 RETURN _ConnRate + _RPCRate + _Util
```

**Avg AHT by Channel**

```dax
CALCULATE([Avg AHT RPC (sec)], 'Fact_Interactions'[channel] = "Dialer")
```

**Portfolio Concentration Index**

```dax
VAR _TotalBalance = [Portfolio Total Balance] VAR _Tarjeta = CALCULATE(SUM('Fact_EOM_Snapshot'[balance]), 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]), 'Fact_EOM_Snapshot'[product_id] = 1) VAR _Prestamo = CALCULATE(SUM('Fact_EOM_Snapshot'[balance]), 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]), 'Fact_EOM_Snapshot'[product_id] = 2) VAR _Hipoteca = CALCULATE(SUM('Fact_EOM_Snapshot'[balance]), 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]), 'Fact_EOM_Snapshot'[product_id] = 3) VAR _HTarjeta = DIVIDE(_Tarjeta, _TotalBalance, 0) VAR _HPrestamo = DIVIDE(_Prestamo, _TotalBalance, 0) VAR _HHipoteca = DIVIDE(_Hipoteca, _TotalBalance, 0) RETURN (_HTarjeta * _HTarjeta) + (_HPrestamo * _HPrestamo) + (_HHipoteca * _HHipoteca)
```

**DPD Migration Rate**

```dax
VAR _CurrentMonth = MAX('Fact_EOM_Snapshot'[snapshot_date]) VAR _PriorMonth = EOMONTH(_CurrentMonth, -1) VAR _MigratedUp = COUNTROWS(FILTER('Fact_EOM_Snapshot', 'Fact_EOM_Snapshot'[snapshot_date] = _CurrentMonth && CONTAINS(CALCULATETABLE(FILTER('Fact_EOM_Snapshot', 'Fact_EOM_Snapshot'[snapshot_date] = _PriorMonth), 'Fact_EOM_Snapshot'[account_id], 'Fact_EOM_Snapshot'[account_id]), 'Fact_EOM_Snapshot'[account_id], 'Fact_EOM_Snapshot'[account_id]))) VAR _PriorTotal = CALCULATE(DISTINCTCOUNT('Fact_EOM_Snapshot'[account_id]), 'Fact_EOM_Snapshot'[snapshot_date] = _PriorMonth) RETURN DIVIDE(_MigratedUp, _PriorTotal, 0)
```

**Recovery per RPC**

```dax
DIVIDE([Total Recovery], [Total RPCs], 0)
```

**Cost per Cure**

```dax
VAR _TotalCost = SUM('Fact_Agent_Time_Log'[total_cost]) RETURN DIVIDE(_TotalCost, [Total Cures], 0)
```

**Collection Efficiency Ratio**

```dax
DIVIDE([Total Recovery], [Portfolio Total Arrears], 0)
```

**Net Recovery**

```dax
[Total Recovery] - [Write-off Amount]
```

**Cost to Collect**

```dax
SUM('Fact_Agent_Time_Log'[total_cost])
```

**Write-off Amount**

```dax
CALCULATE(SUM('Fact_Writeoffs'[writeoff_amount]), 'Fact_Writeoffs'[writeoff_date] <= MAX('Fact_EOM_Snapshot'[snapshot_date]))
```

**Cost per Account**

```dax
DIVIDE([Cost to Collect], [Total Accounts], 0)
```

**Cost per Dollar Collected**

```dax
DIVIDE([Cost to Collect], [Total Recovery], 0)
```

**Vintage Age Months**

```dax
DATEDIFF(MAX('Fact_EOM_Snapshot'[open_date]), MAX('Fact_EOM_Snapshot'[snapshot_date]), MONTH)
```

**Average Vintage Balance**

```dax
AVERAGE('Fact_EOM_Snapshot'[balance])
```

**Cure Rate by Vintage**

```dax
DIVIDE([Total Cures], CALCULATE(DISTINCTCOUNT('Fact_EOM_Snapshot'[account_id]), ALL('Dim_Calendar')), 0)
```

**Avg Credit Limit**

```dax
AVERAGEX(FILTER(Fact_EOM_Snapshot, Fact_EOM_Snapshot[snapshot_date] = MAX(Fact_EOM_Snapshot[snapshot_date])), RELATED(Dim_Accounts[credit_limit]))
```

**Credit Utilization %**

```dax
DIVIDE([Portfolio Total Arrears], SUMX(FILTER(Fact_EOM_Snapshot, Fact_EOM_Snapshot[snapshot_date] = MAX(Fact_EOM_Snapshot[snapshot_date])), RELATED(Dim_Accounts[credit_limit])), 0)
```

**Income Segment**

```dax
CALCULATE(SELECTEDVALUE(Dim_Clients[income_bracket], "Multiple"), RELATEDTABLE(Dim_Accounts), Dim_Accounts[account_id] = SELECTEDVALUE(Fact_EOM_Snapshot[account_id]))
```

**Rolling 3M KP Rate**

```dax
CALCULATE([KP Rate], DATESINPERIOD('Dim_Calendar'[date], LASTDATE('Dim_Calendar'[date]), -3, MONTH))
```

**Portfolio Balance Prior Month**

```dax
CALCULATE(SUM('Fact_EOM_Snapshot'[balance]), 'Fact_EOM_Snapshot'[snapshot_date] = EOMONTH(MAX('Fact_EOM_Snapshot'[snapshot_date]), -1))
```

---

## _Time Intelligence

*Calculation Group — MoM, WoW, DoD, YoY, OTC, YTD, Rolling 3M (18 items). Apply as slicer to any base measure.*

> **Note:** These 118 legacy measures are preserved for backward compatibility.
> They are **replaced** by the `_Time Intelligence` Calculation Group (18 items).
> Once the CG is verified, delete these individual measures from the model.

### Legacy Measures (118)

**RPC Rate Prior Month**

```dax
CALCULATE([RPC Rate], DATEADD('Dim_Calendar'[date], -1, MONTH))
```

**RPC Rate MoM Change**

```dax
[RPC Rate] - [RPC Rate Prior Month]
```

**Promise Rate Prior Month**

```dax
CALCULATE([Promise Rate], DATEADD('Dim_Calendar'[date], -1, MONTH))
```

**KP Rate Prior Month**

```dax
CALCULATE([KP Rate], DATEADD('Dim_Calendar'[date], -1, MONTH))
```

**KP Rate MoM Change**

```dax
[KP Rate] - [KP Rate Prior Month]
```

**BB Conversion Prior Month**

```dax
CALCULATE([BB Conversion Rate], DATEADD('Dim_Calendar'[date], -1, MONTH))
```

**BB Conversion MoM Change**

```dax
[BB Conversion Rate] - [BB Conversion Prior Month]
```

**Total Cures Prior Month**

```dax
CALCULATE([Total Cures], DATEADD('Dim_Calendar'[date], -1, MONTH))
```

**Cures MoM Change**

```dax
[Total Cures] - [Total Cures Prior Month]
```

**Cured Amount Prior Month**

```dax
CALCULATE([Cured Amount], DATEADD('Dim_Calendar'[date], -1, MONTH))
```

**Cured Amount MoM %**

```dax
DIVIDE([Cured Amount] - [Cured Amount Prior Month], [Cured Amount Prior Month], 0)
```

**Mora Rate Prior Month**

```dax
CALCULATE([Mora Rate], DATEADD('Dim_Calendar'[date], -1, MONTH))
```

**Mora Rate MoM Change**

```dax
[Mora Rate] - [Mora Rate Prior Month]
```

**Cured Amount YTD**

```dax
CALCULATE([Cured Amount], DATESYTD('Dim_Calendar'[date]))
```

**KP Rate YTD**

```dax
CALCULATE([KP Rate], DATESYTD('Dim_Calendar'[date]))
```

**Total Cures YTD**

```dax
CALCULATE([Total Cures], DATESYTD('Dim_Calendar'[date]))
```

**Promise Rate MoM Change**

```dax
[Promise Rate] - [Promise Rate Prior Month]
```

**Capped KP per RPC Arrears Prior Month**

```dax
CALCULATE([Capped KP per RPC Arrears], DATEADD('Dim_Calendar'[date], -1, MONTH))
```

**Capped KP per RPC Arrears MoM Change**

```dax
[Capped KP per RPC Arrears] - [Capped KP per RPC Arrears Prior Month]
```

**Avg ACW RPC (sec) Prior Month**

```dax
CALCULATE([Avg ACW RPC (sec)], DATEADD('Dim_Calendar'[date], -1, MONTH))
```

**Avg ACW RPC (sec) MoM Change**

```dax
[Avg ACW RPC (sec)] - [Avg ACW RPC (sec) Prior Month]
```

**Avg ACW Non-RPC (sec) Prior Month**

```dax
CALCULATE([Avg ACW Non-RPC (sec)], DATEADD('Dim_Calendar'[date], -1, MONTH))
```

**Avg ACW Non-RPC (sec) MoM Change**

```dax
[Avg ACW Non-RPC (sec)] - [Avg ACW Non-RPC (sec) Prior Month]
```

**Cures per THT Hr Prior Month**

```dax
CALCULATE([Cures per THT Hr], DATEADD('Dim_Calendar'[date], -1, MONTH))
```

**Cures per THT Hr MoM Change**

```dax
[Cures per THT Hr] - [Cures per THT Hr Prior Month]
```

**Avg Utilization % Prior Month**

```dax
CALCULATE([Avg Utilization %], DATEADD('Dim_Calendar'[date], -1, MONTH))
```

**Avg Utilization % MoM Change**

```dax
[Avg Utilization %] - [Avg Utilization % Prior Month]
```

**Promise Rate MoM %**

```dax
VAR _Prior = [Promise Rate Prior Month] RETURN DIVIDE([Promise Rate] - _Prior, _Prior, 0)
```

**KP Rate MoM %**

```dax
VAR _Prior = [KP Rate Prior Month] RETURN DIVIDE([KP Rate] - _Prior, _Prior, 0)
```

**Avg ACW RPC MoM %**

```dax
VAR _Prior = [Avg ACW RPC (sec) Prior Month] RETURN DIVIDE([Avg ACW RPC (sec)] - _Prior, _Prior, 0)
```

**Avg ACW Non-RPC MoM %**

```dax
VAR _Prior = [Avg ACW Non-RPC (sec) Prior Month] RETURN DIVIDE([Avg ACW Non-RPC (sec)] - _Prior, _Prior, 0)
```

**Capped KP per RPC Arrears MoM %**

```dax
VAR _Prior = [Capped KP per RPC Arrears Prior Month] RETURN DIVIDE([Capped KP per RPC Arrears] - _Prior, _Prior, 0)
```

**Cures per THT Hr MoM %**

```dax
VAR _Prior = [Cures per THT Hr Prior Month] RETURN DIVIDE([Cures per THT Hr] - _Prior, _Prior, 0)
```

**Avg Utilization % MoM %**

```dax
VAR _Prior = [Avg Utilization % Prior Month] RETURN DIVIDE([Avg Utilization %] - _Prior, _Prior, 0)
```

**Promise Rate Prior Week**

```dax
VAR _CurrentISOWeek = SELECTEDVALUE('Dim_Calendar'[iso_week]) VAR _PriorISOWeek = _CurrentISOWeek - 1 VAR _PriorDates = CALCULATETABLE(VALUES('Dim_Calendar'[date]), 'Dim_Calendar'[iso_week] = _PriorISOWeek) RETURN CALCULATE([Promise Rate], _PriorDates)
```

**Promise Rate WoW Change**

```dax
[Promise Rate] - [Promise Rate Prior Week]
```

**Promise Rate WoW %**

```dax
VAR _Prior = [Promise Rate Prior Week] RETURN DIVIDE([Promise Rate] - _Prior, _Prior, 0)
```

**KP Rate Prior Week**

```dax
VAR _CurrentISOWeek = SELECTEDVALUE('Dim_Calendar'[iso_week]) VAR _PriorISOWeek = _CurrentISOWeek - 1 VAR _PriorDates = CALCULATETABLE(VALUES('Dim_Calendar'[date]), 'Dim_Calendar'[iso_week] = _PriorISOWeek) RETURN CALCULATE([KP Rate], _PriorDates)
```

**KP Rate WoW Change**

```dax
[KP Rate] - [KP Rate Prior Week]
```

**KP Rate WoW %**

```dax
VAR _Prior = [KP Rate Prior Week] RETURN DIVIDE([KP Rate] - _Prior, _Prior, 0)
```

**Avg ACW RPC (sec) Prior Week**

```dax
VAR _CurrentISOWeek = SELECTEDVALUE('Dim_Calendar'[iso_week]) VAR _PriorISOWeek = _CurrentISOWeek - 1 VAR _PriorDates = CALCULATETABLE(VALUES('Dim_Calendar'[date]), 'Dim_Calendar'[iso_week] = _PriorISOWeek) RETURN CALCULATE([Avg ACW RPC (sec)], _PriorDates)
```

**Avg ACW RPC (sec) WoW Change**

```dax
[Avg ACW RPC (sec)] - [Avg ACW RPC (sec) Prior Week]
```

**Avg ACW RPC (sec) WoW %**

```dax
VAR _Prior = [Avg ACW RPC (sec) Prior Week] RETURN DIVIDE([Avg ACW RPC (sec)] - _Prior, _Prior, 0)
```

**Avg ACW Non-RPC (sec) Prior Week**

```dax
VAR _CurrentISOWeek = SELECTEDVALUE('Dim_Calendar'[iso_week]) VAR _PriorISOWeek = _CurrentISOWeek - 1 VAR _PriorDates = CALCULATETABLE(VALUES('Dim_Calendar'[date]), 'Dim_Calendar'[iso_week] = _PriorISOWeek) RETURN CALCULATE([Avg ACW Non-RPC (sec)], _PriorDates)
```

**Avg ACW Non-RPC (sec) WoW Change**

```dax
[Avg ACW Non-RPC (sec)] - [Avg ACW Non-RPC (sec) Prior Week]
```

**Avg ACW Non-RPC (sec) WoW %**

```dax
VAR _Prior = [Avg ACW Non-RPC (sec) Prior Week] RETURN DIVIDE([Avg ACW Non-RPC (sec)] - _Prior, _Prior, 0)
```

**Capped KP per RPC Arrears Prior Week**

```dax
VAR _CurrentISOWeek = SELECTEDVALUE('Dim_Calendar'[iso_week]) VAR _PriorISOWeek = _CurrentISOWeek - 1 VAR _PriorDates = CALCULATETABLE(VALUES('Dim_Calendar'[date]), 'Dim_Calendar'[iso_week] = _PriorISOWeek) RETURN CALCULATE([Capped KP per RPC Arrears], _PriorDates)
```

**Capped KP per RPC Arrears WoW Change**

```dax
[Capped KP per RPC Arrears] - [Capped KP per RPC Arrears Prior Week]
```

**Capped KP per RPC Arrears WoW %**

```dax
VAR _Prior = [Capped KP per RPC Arrears Prior Week] RETURN DIVIDE([Capped KP per RPC Arrears] - _Prior, _Prior, 0)
```

**Cures per THT Hr Prior Week**

```dax
VAR _CurrentISOWeek = SELECTEDVALUE('Dim_Calendar'[iso_week]) VAR _PriorISOWeek = _CurrentISOWeek - 1 VAR _PriorDates = CALCULATETABLE(VALUES('Dim_Calendar'[date]), 'Dim_Calendar'[iso_week] = _PriorISOWeek) RETURN CALCULATE([Cures per THT Hr], _PriorDates)
```

**Cures per THT Hr WoW Change**

```dax
[Cures per THT Hr] - [Cures per THT Hr Prior Week]
```

**Cures per THT Hr WoW %**

```dax
VAR _Prior = [Cures per THT Hr Prior Week] RETURN DIVIDE([Cures per THT Hr] - _Prior, _Prior, 0)
```

**Avg Utilization % Prior Week**

```dax
VAR _CurrentISOWeek = SELECTEDVALUE('Dim_Calendar'[iso_week]) VAR _PriorISOWeek = _CurrentISOWeek - 1 VAR _PriorDates = CALCULATETABLE(VALUES('Dim_Calendar'[date]), 'Dim_Calendar'[iso_week] = _PriorISOWeek) RETURN CALCULATE([Avg Utilization %], _PriorDates)
```

**Avg Utilization % WoW Change**

```dax
[Avg Utilization %] - [Avg Utilization % Prior Week]
```

**Avg Utilization % WoW %**

```dax
VAR _Prior = [Avg Utilization % Prior Week] RETURN DIVIDE([Avg Utilization %] - _Prior, _Prior, 0)
```

**Promise Rate Prior Day**

```dax
CALCULATE([Promise Rate], DATEADD('Dim_Calendar'[date], -1, DAY))
```

**Promise Rate DoD Change**

```dax
[Promise Rate] - [Promise Rate Prior Day]
```

**Promise Rate DoD %**

```dax
VAR _Prior = [Promise Rate Prior Day] RETURN DIVIDE([Promise Rate] - _Prior, _Prior, 0)
```

**KP Rate Prior Day**

```dax
CALCULATE([KP Rate], DATEADD('Dim_Calendar'[date], -1, DAY))
```

**KP Rate DoD Change**

```dax
[KP Rate] - [KP Rate Prior Day]
```

**KP Rate DoD %**

```dax
VAR _Prior = [KP Rate Prior Day] RETURN DIVIDE([KP Rate] - _Prior, _Prior, 0)
```

**Avg ACW RPC (sec) Prior Day**

```dax
CALCULATE([Avg ACW RPC (sec)], DATEADD('Dim_Calendar'[date], -1, DAY))
```

**Avg ACW RPC (sec) DoD Change**

```dax
[Avg ACW RPC (sec)] - [Avg ACW RPC (sec) Prior Day]
```

**Avg ACW RPC (sec) DoD %**

```dax
VAR _Prior = [Avg ACW RPC (sec) Prior Day] RETURN DIVIDE([Avg ACW RPC (sec)] - _Prior, _Prior, 0)
```

**Avg ACW Non-RPC (sec) Prior Day**

```dax
CALCULATE([Avg ACW Non-RPC (sec)], DATEADD('Dim_Calendar'[date], -1, DAY))
```

**Avg ACW Non-RPC (sec) DoD Change**

```dax
[Avg ACW Non-RPC (sec)] - [Avg ACW Non-RPC (sec) Prior Day]
```

**Avg ACW Non-RPC (sec) DoD %**

```dax
VAR _Prior = [Avg ACW Non-RPC (sec) Prior Day] RETURN DIVIDE([Avg ACW Non-RPC (sec)] - _Prior, _Prior, 0)
```

**Capped KP per RPC Arrears Prior Day**

```dax
CALCULATE([Capped KP per RPC Arrears], DATEADD('Dim_Calendar'[date], -1, DAY))
```

**Capped KP per RPC Arrears DoD Change**

```dax
[Capped KP per RPC Arrears] - [Capped KP per RPC Arrears Prior Day]
```

**Capped KP per RPC Arrears DoD %**

```dax
VAR _Prior = [Capped KP per RPC Arrears Prior Day] RETURN DIVIDE([Capped KP per RPC Arrears] - _Prior, _Prior, 0)
```

**Cures per THT Hr Prior Day**

```dax
CALCULATE([Cures per THT Hr], DATEADD('Dim_Calendar'[date], -1, DAY))
```

**Cures per THT Hr DoD Change**

```dax
[Cures per THT Hr] - [Cures per THT Hr Prior Day]
```

**Cures per THT Hr DoD %**

```dax
VAR _Prior = [Cures per THT Hr Prior Day] RETURN DIVIDE([Cures per THT Hr] - _Prior, _Prior, 0)
```

**Avg Utilization % Prior Day**

```dax
CALCULATE([Avg Utilization %], DATEADD('Dim_Calendar'[date], -1, DAY))
```

**Avg Utilization % DoD Change**

```dax
[Avg Utilization %] - [Avg Utilization % Prior Day]
```

**Avg Utilization % DoD %**

```dax
VAR _Prior = [Avg Utilization % Prior Day] RETURN DIVIDE([Avg Utilization %] - _Prior, _Prior, 0)
```

**Promise Rate Prior Year**

```dax
CALCULATE([Promise Rate], SAMEPERIODLASTYEAR('Dim_Calendar'[date]))
```

**Promise Rate YoY Change**

```dax
[Promise Rate] - [Promise Rate Prior Year]
```

**Promise Rate YoY %**

```dax
VAR _Prior = [Promise Rate Prior Year] RETURN DIVIDE([Promise Rate] - _Prior, _Prior, 0)
```

**KP Rate Prior Year**

```dax
CALCULATE([KP Rate], SAMEPERIODLASTYEAR('Dim_Calendar'[date]))
```

**KP Rate YoY Change**

```dax
[KP Rate] - [KP Rate Prior Year]
```

**KP Rate YoY %**

```dax
VAR _Prior = [KP Rate Prior Year] RETURN DIVIDE([KP Rate] - _Prior, _Prior, 0)
```

**Avg ACW RPC (sec) Prior Year**

```dax
CALCULATE([Avg ACW RPC (sec)], SAMEPERIODLASTYEAR('Dim_Calendar'[date]))
```

**Avg ACW RPC (sec) YoY Change**

```dax
[Avg ACW RPC (sec)] - [Avg ACW RPC (sec) Prior Year]
```

**Avg ACW RPC (sec) YoY %**

```dax
VAR _Prior = [Avg ACW RPC (sec) Prior Year] RETURN DIVIDE([Avg ACW RPC (sec)] - _Prior, _Prior, 0)
```

**Avg ACW Non-RPC (sec) Prior Year**

```dax
CALCULATE([Avg ACW Non-RPC (sec)], SAMEPERIODLASTYEAR('Dim_Calendar'[date]))
```

**Avg ACW Non-RPC (sec) YoY Change**

```dax
[Avg ACW Non-RPC (sec)] - [Avg ACW Non-RPC (sec) Prior Year]
```

**Avg ACW Non-RPC (sec) YoY %**

```dax
VAR _Prior = [Avg ACW Non-RPC (sec) Prior Year] RETURN DIVIDE([Avg ACW Non-RPC (sec)] - _Prior, _Prior, 0)
```

**Capped KP per RPC Arrears Prior Year**

```dax
CALCULATE([Capped KP per RPC Arrears], SAMEPERIODLASTYEAR('Dim_Calendar'[date]))
```

**Capped KP per RPC Arrears YoY Change**

```dax
[Capped KP per RPC Arrears] - [Capped KP per RPC Arrears Prior Year]
```

**Capped KP per RPC Arrears YoY %**

```dax
VAR _Prior = [Capped KP per RPC Arrears Prior Year] RETURN DIVIDE([Capped KP per RPC Arrears] - _Prior, _Prior, 0)
```

**Cures per THT Hr Prior Year**

```dax
CALCULATE([Cures per THT Hr], SAMEPERIODLASTYEAR('Dim_Calendar'[date]))
```

**Cures per THT Hr YoY Change**

```dax
[Cures per THT Hr] - [Cures per THT Hr Prior Year]
```

**Cures per THT Hr YoY %**

```dax
VAR _Prior = [Cures per THT Hr Prior Year] RETURN DIVIDE([Cures per THT Hr] - _Prior, _Prior, 0)
```

**Avg Utilization % Prior Year**

```dax
CALCULATE([Avg Utilization %], SAMEPERIODLASTYEAR('Dim_Calendar'[date]))
```

**Avg Utilization % YoY Change**

```dax
[Avg Utilization %] - [Avg Utilization % Prior Year]
```

**Avg Utilization % YoY %**

```dax
VAR _Prior = [Avg Utilization % Prior Year] RETURN DIVIDE([Avg Utilization %] - _Prior, _Prior, 0)
```

**Promise Rate Overall**

```dax
CALCULATE([Promise Rate], ALL('Dim_Calendar'))
```

**Promise Rate OTC Change**

```dax
[Promise Rate] - [Promise Rate Overall]
```

**Promise Rate OTC %**

```dax
VAR _Overall = [Promise Rate Overall] RETURN DIVIDE([Promise Rate] - _Overall, _Overall, 0)
```

**KP Rate Overall**

```dax
CALCULATE([KP Rate], ALL('Dim_Calendar'))
```

**KP Rate OTC Change**

```dax
[KP Rate] - [KP Rate Overall]
```

**KP Rate OTC %**

```dax
VAR _Overall = [KP Rate Overall] RETURN DIVIDE([KP Rate] - _Overall, _Overall, 0)
```

**Avg ACW RPC (sec) Overall**

```dax
CALCULATE([Avg ACW RPC (sec)], ALL('Dim_Calendar'))
```

**Avg ACW RPC (sec) OTC Change**

```dax
[Avg ACW RPC (sec)] - [Avg ACW RPC (sec) Overall]
```

**Avg ACW RPC (sec) OTC %**

```dax
VAR _Overall = [Avg ACW RPC (sec) Overall] RETURN DIVIDE([Avg ACW RPC (sec)] - _Overall, _Overall, 0)
```

**Avg ACW Non-RPC (sec) Overall**

```dax
CALCULATE([Avg ACW Non-RPC (sec)], ALL('Dim_Calendar'))
```

**Avg ACW Non-RPC (sec) OTC Change**

```dax
[Avg ACW Non-RPC (sec)] - [Avg ACW Non-RPC (sec) Overall]
```

**Avg ACW Non-RPC (sec) OTC %**

```dax
VAR _Overall = [Avg ACW Non-RPC (sec) Overall] RETURN DIVIDE([Avg ACW Non-RPC (sec)] - _Overall, _Overall, 0)
```

**Capped KP per RPC Arrears Overall**

```dax
CALCULATE([Capped KP per RPC Arrears], ALL('Dim_Calendar'))
```

**Capped KP per RPC Arrears OTC Change**

```dax
[Capped KP per RPC Arrears] - [Capped KP per RPC Arrears Overall]
```

**Capped KP per RPC Arrears OTC %**

```dax
VAR _Overall = [Capped KP per RPC Arrears Overall] RETURN DIVIDE([Capped KP per RPC Arrears] - _Overall, _Overall, 0)
```

**Cures per THT Hr Overall**

```dax
CALCULATE([Cures per THT Hr], ALL('Dim_Calendar'))
```

**Cures per THT Hr OTC Change**

```dax
[Cures per THT Hr] - [Cures per THT Hr Overall]
```

**Cures per THT Hr OTC %**

```dax
VAR _Overall = [Cures per THT Hr Overall] RETURN DIVIDE([Cures per THT Hr] - _Overall, _Overall, 0)
```

**Avg Utilization % Overall**

```dax
CALCULATE([Avg Utilization %], ALL('Dim_Calendar'))
```

**Avg Utilization % OTC Change**

```dax
[Avg Utilization %] - [Avg Utilization % Overall]
```

**Avg Utilization % OTC %**

```dax
VAR _Overall = [Avg Utilization % Overall] RETURN DIVIDE([Avg Utilization %] - _Overall, _Overall, 0)
```

---

### Calculation Group (18 items)

Apply `_Time Intelligence[Calculation Item]` as a slicer/filter to any base measure.

**0. Current Period** — Format: ``

```dax
SELECTEDMEASURE()
```

**1. Prior Month** — Format: `inherit`

```dax
CALCULATE(SELECTEDMEASURE(), DATEADD('Dim_Calendar'[date], -1, MONTH))
```

**2. MoM Change** — Format: `+0.0%;-0.0%`

```dax
SELECTEDMEASURE() - CALCULATE(SELECTEDMEASURE(), DATEADD('Dim_Calendar'[date], -1, MONTH))
```

**3. MoM % Change** — Format: `+0.0%;-0.0%`

```dax
VAR _Prior = CALCULATE(SELECTEDMEASURE(), DATEADD('Dim_Calendar'[date], -1, MONTH)) RETURN DIVIDE(SELECTEDMEASURE() - _Prior, _Prior)
```

**4. Prior Week** — Format: `inherit`

```dax
VAR _ISO = SELECTEDVALUE('Dim_Calendar'[iso_week]) VAR _Dates = CALCULATETABLE(VALUES('Dim_Calendar'[date]), 'Dim_Calendar'[iso_week] = _ISO - 1) RETURN CALCULATE(SELECTEDMEASURE(), _Dates)
```

**5. WoW Change** — Format: `+0.0%;-0.0%`

```dax
VAR _ISO = SELECTEDVALUE('Dim_Calendar'[iso_week]) VAR _Dates = CALCULATETABLE(VALUES('Dim_Calendar'[date]), 'Dim_Calendar'[iso_week] = _ISO - 1) VAR _Prior = CALCULATE(SELECTEDMEASURE(), _Dates) RETURN SELECTEDMEASURE() - _Prior
```

**6. WoW % Change** — Format: `+0.0%;-0.0%`

```dax
VAR _ISO = SELECTEDVALUE('Dim_Calendar'[iso_week]) VAR _Dates = CALCULATETABLE(VALUES('Dim_Calendar'[date]), 'Dim_Calendar'[iso_week] = _ISO - 1) VAR _Prior = CALCULATE(SELECTEDMEASURE(), _Dates) RETURN DIVIDE(SELECTEDMEASURE() - _Prior, _Prior)
```

**7. Prior Day** — Format: `inherit`

```dax
CALCULATE(SELECTEDMEASURE(), DATEADD('Dim_Calendar'[date], -1, DAY))
```

**8. DoD Change** — Format: `+0.0%;-0.0%`

```dax
SELECTEDMEASURE() - CALCULATE(SELECTEDMEASURE(), DATEADD('Dim_Calendar'[date], -1, DAY))
```

**9. DoD % Change** — Format: `+0.0%;-0.0%`

```dax
VAR _Prior = CALCULATE(SELECTEDMEASURE(), DATEADD('Dim_Calendar'[date], -1, DAY)) RETURN DIVIDE(SELECTEDMEASURE() - _Prior, _Prior)
```

**10. Prior Year** — Format: `inherit`

```dax
CALCULATE(SELECTEDMEASURE(), SAMEPERIODLASTYEAR('Dim_Calendar'[date]))
```

**11. YoY Change** — Format: `+0.0%;-0.0%`

```dax
SELECTEDMEASURE() - CALCULATE(SELECTEDMEASURE(), SAMEPERIODLASTYEAR('Dim_Calendar'[date]))
```

**12. YoY % Change** — Format: `+0.0%;-0.0%`

```dax
VAR _Prior = CALCULATE(SELECTEDMEASURE(), SAMEPERIODLASTYEAR('Dim_Calendar'[date])) RETURN DIVIDE(SELECTEDMEASURE() - _Prior, _Prior)
```

**13. Overall Avg** — Format: `inherit`

```dax
CALCULATE(SELECTEDMEASURE(), ALL('Dim_Calendar'))
```

**14. OTC Change** — Format: `+0.0%;-0.0%`

```dax
SELECTEDMEASURE() - CALCULATE(SELECTEDMEASURE(), ALL('Dim_Calendar'))
```

**15. OTC % Change** — Format: `+0.0%;-0.0%`

```dax
VAR _Overall = CALCULATE(SELECTEDMEASURE(), ALL('Dim_Calendar')) RETURN DIVIDE(SELECTEDMEASURE() - _Overall, _Overall)
```

**16. YTD** — Format: `inherit`

```dax
CALCULATE(SELECTEDMEASURE(), DATESYTD('Dim_Calendar'[date]))
```

**17. Rolling 3M** — Format: `inherit`

```dax
CALCULATE(SELECTEDMEASURE(), DATESINPERIOD('Dim_Calendar'[date], LASTDATE('Dim_Calendar'[date]), -3, MONTH))
```

---
