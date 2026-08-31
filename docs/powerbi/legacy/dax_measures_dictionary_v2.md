# Power BI DAX Measures Dictionary v2

> **ARCHIVED (2026-08-31).** STALE — describes a "242 total / 87 base" measure set that predates the v3.2
> consolidation. Contradicts the current `dax_measures_all.md` (148 active measures + 18-item `_Time Intelligence`
> Calculation Group, auto-generated from the CSV). Historical reference only.

**Version:** 2.2
**Schema:** v7 Star Schema (Fact_Interactions, Fact_PTP_Log, Fact_Payments, Fact_Agent_Time_Log, Fact_EOM_Snapshot, Fact_Writeoffs)
**Total Measures:** 87 base + 120 targets/comparisons + 106 new time intelligence + 22 dashboard-specific = **242 total** (136 base + 106 dashboard)
**Import File:** `dashboards/dax/collections_dax_v2.csv`
**Targets & Comparisons Module:** `dashboards/dax/dax_targets_and_comparisons.md`

---

## Prerequisites

Before using these measures, ensure:

1. **Dim_Calendar is marked as a Date Table** in Power BI Desktop (Table tools > Mark as date table). All time intelligence measures (`DATEADD`, `DATESYTD`, `DATESINPERIOD`) silently return BLANK without this.
2. **All tables are imported** with correct relationships (dim -> fact, single direction).
3. **`snapshot_date` column** in `Fact_EOM_Snapshot` is DATE type, not text.

---

## Measure Table Structure

| Table | Measures | Purpose |
|---|---|---|
| `_Outreach & Activity` | 20 | Calls, connections, RPC, AHT, ACW, utilization |
| `_Promise & Conversion` | 13 | PTPs, KP%, BB Conversion, Capped KP |
| `_Recovery & Collection` | 16 | Cures, amounts, payment methods |
| `_Portfolio Health` | 20 | EOM snapshot, DPD buckets, arrears, roll rates |
| `_Time Intelligence` | 120 | MoM, WoW, DoD, YoY, OTC, YTD, rolling calculations |
| `_Goals & Targets` | 31 | Goals, gaps, RAG status, color hex + 2 calculated tables |
| `_Executive` | 3 | Portfolio health score, recovery rate, at-risk balance |
| `_Agent Performance` | 5 | RPC/hr, KP rate, quality score, tier, tenure |
| `_Dialer Performance` | 3 | Connection rate, abandon rate, efficiency score |
| `_Portfolio Management` | 3 | Concentration index, mora balance, DPD migration |
| `_Financial Recovery` | 4 | Recovery/RPC, cost/cure, agent cure rate, collection efficiency |
| `_Vintage Analysis` | 2 | Vintage age, average balance by vintage |
| `_Roll Rate Analysis` | 2 | Net roll rate, roll rate trend |

---

## Measure Naming Conventions

| Pattern | Example | Rule |
|---|---|---|
| Pascal Case | `Total Recovery` | All measures |
| `_Prefix` | `_Outreach & Activity` | Measure table names only (forces sort to top) |
| `Rate` | `RPC Rate` | Percentage measures (format: 0.0%) |
| `Count` | `Agent Cure Count` | Integer counts (format: #,##0) |
| `$` suffix | `Capped KP $` | Currency amounts (format: $#,##0) |
| `per` | `RPC per Op Hr` | Ratio measures |
| `MoM Change` | `KP Rate MoM Change` | Month-over-month difference |

---

## Table 1: _Outreach & Activity

Base contact metrics, agent productivity, and handle time.

| # | Measure | Formula | Format | Dependencies |
|---|---|---|---|---|
| 1 | `Total Calls Attempted` | `SUM('Fact_Interactions'[calls_attempted])` | #,##0 | — |
| 2 | `Total Connected` | `SUM('Fact_Interactions'[calls_connected])` | #,##0 | — |
| 3 | `Connection Rate` | `DIVIDE([Total Connected], [Total Calls Attempted], 0)` | 0.0% | Total Connected, Total Calls Attempted |
| 4 | `Total RPCs` | `CALCULATE(COUNTROWS('Fact_Interactions'), 'Fact_Interactions'[rpc_flag] = TRUE())` | #,##0 | — |
| 5 | `Non-RPC Connections` | `[Total Connected] - [Total RPCs]` | #,##0 | Total Connected, Total RPCs |
| 6 | `RPC Rate` | `DIVIDE([Total RPCs], [Total Connected], 0)` | 0.0% | Total RPCs, Total Connected |
| 7 | `Total RPC Arrears` | `CALCULATE(SUM('Fact_Interactions'[rpc_arrears]), 'Fact_Interactions'[rpc_flag] = TRUE())` | $#,##0 | — |
| 8 | `Total Op Hours` | `SUM('Fact_Agent_Time_Log'[operational_hours])` | #,##0.0 | — |
| 9 | `Total THT Hours` | `SUM('Fact_Agent_Time_Log'[tht_hours])` | #,##0.0 | — |
| 10 | `RPC per Op Hr` | `DIVIDE([Total RPCs], [Total Op Hours], 0)` | #,##0.0 | Total RPCs, Total Op Hours |
| 11 | `RPC per THT Hr` | `DIVIDE([Total RPCs], [Total THT Hours], 0)` | #,##0.0 | Total RPCs, Total THT Hours |
| 12 | `Avg AHT RPC (sec)` | `CALCULATE(AVERAGE('Fact_Interactions'[aht_seconds]), 'Fact_Interactions'[rpc_flag] = TRUE())` | #,##0 | — |
| 13 | `Avg AHT Non-RPC (sec)` | `CALCULATE(AVERAGE('Fact_Interactions'[aht_seconds]), 'Fact_Interactions'[rpc_flag] = FALSE())` | #,##0 | — |
| 14 | `Avg ACW RPC (sec)` | `CALCULATE(AVERAGE('Fact_Interactions'[acw_seconds]), 'Fact_Interactions'[rpc_flag] = TRUE())` | #,##0 | — |
| 15 | `Avg ACW Non-RPC (sec)` | `CALCULATE(AVERAGE('Fact_Interactions'[acw_seconds]), 'Fact_Interactions'[rpc_flag] = FALSE())` | #,##0 | — |
| 16 | `Avg Total Handle Time RPC (sec)` | `CALCULATE(AVERAGE('Fact_Interactions'[aht_seconds] + 'Fact_Interactions'[acw_seconds]), 'Fact_Interactions'[rpc_flag] = TRUE())` | #,##0 | — |
| 17 | `Avg AHT (sec)` | `AVERAGE('Fact_Interactions'[aht_seconds])` | #,##0 | — |
| 18 | `Avg ACW (sec)` | `AVERAGE('Fact_Interactions'[acw_seconds])` | #,##0 | — |
| 19 | `THT Alignment %` | `DIVIDE([Total THT Hours], [Total Op Hours], 0)` | 0.0% | Total THT Hours, Total Op Hours |
| 20 | `Avg Utilization %` | `AVERAGE('Fact_Agent_Time_Log'[utilization])` | 0.0% | — |
| 21 | `Agents Below Util Target` | `CALCULATE(DISTINCTCOUNT('Fact_Agent_Time_Log'[agent_id]), 'Fact_Agent_Time_Log'[utilization] < 0.70)` | #,##0 | — |
| 22 | `Contacts per Hour` | `DIVIDE([Total Connected], [Total Op Hours], 0)` | #,##0.0 | Total Connected, Total Op Hours |

**Notes:**
- `RPC Rate` = RPCs / Connected calls (not attempts). This is the standard collections definition.
- `Avg Total Handle Time RPC` = AHT + ACW combined. Use this for the full handle time metric.
- `Avg AHT (sec)` and `Avg ACW (sec)` are overall averages across all calls (RPC + Non-RPC). These match the real ScotiaBank `Dialer AHT` / `Dialer ACW` metrics.
- `THT Alignment %` = THT / Operational Hours. Measures how much of available time was spent on actual call work.
- `Avg Utilization %` is stored as decimal (0.0-0.95) in the source data. The format string displays it as percentage.

---

## Table 2: _Promise & Conversion

Promise-to-pay pipeline, KP%, BB Conversion, Capped KP.

| # | Measure | Formula | Format | Dependencies |
|---|---|---|---|---|
| 1 | `Total PTPs` | `COUNTROWS('Fact_PTP_Log')` | #,##0 | — |
| 2 | `PTP Kept` | `CALCULATE(COUNTROWS('Fact_PTP_Log'), 'Fact_PTP_Log'[status] = "Kept")` | #,##0 | — |
| 3 | `PTP Broken` | `CALCULATE(COUNTROWS('Fact_PTP_Log'), 'Fact_PTP_Log'[status] = "Broken")` | #,##0 | — |
| 4 | `PTP Pending` | `CALCULATE(COUNTROWS('Fact_PTP_Log'), 'Fact_PTP_Log'[status] = "Pending")` | #,##0 | — |
| 5 | `Evaluated PTPs` | `[PTP Kept] + [PTP Broken]` | #,##0 | PTP Kept, PTP Broken |
| 6 | `Promise Rate` | `DIVIDE([Total PTPs], [Total RPCs], 0)` | 0.0% | Total PTPs, Total RPCs |
| 7 | `KP Rate` | `DIVIDE([PTP Kept], [Evaluated PTPs], 0)` | 0.0% | PTP Kept, Evaluated PTPs |
| 8 | `Broken Rate` | `DIVIDE([PTP Broken], [Evaluated PTPs], 0)` | 0.0% | PTP Broken, Evaluated PTPs |
| 9 | `BB Conversion Rate` | `[Promise Rate] * [KP Rate]` | 0.0% | Promise Rate, KP Rate |
| 10 | `Amount Promised` | `SUM('Fact_PTP_Log'[promised_amount])` | $#,##0 | — |
| 11 | `Capped KP $` | `SUMX(FILTER('Fact_PTP_Log', 'Fact_PTP_Log'[status] = "Kept"), MIN('Fact_PTP_Log'[promised_amount], 'Fact_PTP_Log'[rpc_arrears_at_contact]))` | $#,##0 | — |
| 12 | `Capped KP per RPC Arrears` | `DIVIDE([Capped KP $], [Total RPC Arrears], 0)` | 0.00% | Capped KP $, Total RPC Arrears |
| 13 | `Capped KP per Op Hr` | `DIVIDE([Capped KP $], [Total Op Hours], 0)` | $#,##0.00 | Capped KP $, Total Op Hours |

**Notes:**
- `Evaluated PTPs` = Kept + Broken only. Pending promises are excluded from KP% and Broken Rate denominators.
- `BB Conversion Rate` = Promise Rate * KP Rate. This is the end-to-end conversion metric (RPC -> PTP -> Kept).
- `Capped KP $` caps each kept promise at the account's arrears balance at time of contact. Prevents over-counting.
- `Capped KP per RPC Arrears` answers: "Of all the money we discussed, how much did we actually collect through promises?"

**Thresholds:**
| KPI | Green | Amber | Red |
|---|---|---|---|
| Promise Rate | >= 50% | 40-49% | < 40% |
| KP Rate | >= 60% | 50-59% | < 50% |
| BB Conversion | >= 35% | 25-34% | < 25% |

---

## Table 3: _Recovery & Collection

Cures, collection amounts, payment method breakdown.

| # | Measure | Formula | Format | Dependencies |
|---|---|---|---|---|
| 1 | `Total Recovery` | `SUM('Fact_Payments'[amount_paid])` | $#,##0 | — |
| 2 | `Cured Amount` | `CALCULATE(SUM('Fact_Payments'[amount_paid]), 'Fact_Payments'[is_cured] = TRUE())` | $#,##0 | — |
| 3 | `Non-Cured Amount` | `[Total Recovery] - [Cured Amount]` | $#,##0 | Total Recovery, Cured Amount |
| 4 | `Total Cures` | `CALCULATE(DISTINCTCOUNT('Fact_Payments'[account_id]), 'Fact_Payments'[is_cured] = TRUE())` | #,##0 | — |
| 5 | `Agent-Assisted Cures $` | `CALCULATE(SUM('Fact_Payments'[amount_paid]), 'Fact_Payments'[cure_flag] = "Agent_Cure")` | $#,##0 | — |
| 6 | `Self-Cures $` | `CALCULATE(SUM('Fact_Payments'[amount_paid]), 'Fact_Payments'[cure_flag] = "Self_Cure")` | $#,##0 | — |
| 7 | `Agent Cure Count` | `CALCULATE(DISTINCTCOUNT('Fact_Payments'[account_id]), 'Fact_Payments'[cure_flag] = "Agent_Cure")` | #,##0 | — |
| 8 | `Self-Cure Count` | `CALCULATE(DISTINCTCOUNT('Fact_Payments'[account_id]), 'Fact_Payments'[cure_flag] = "Self_Cure")` | #,##0 | — |
| 9 | `Agent Cure Rate` | `DIVIDE([Agent Cure Count], [Total Cures], 0)` | 0.0% | Agent Cure Count, Total Cures |
| 10 | `Self-Cure Rate` | `DIVIDE([Self-Cure Count], [Total Cures], 0)` | 0.0% | Self-Cure Count, Total Cures |
| 11 | `Cures per THT Hr` | `DIVIDE([Total Cures], [Total THT Hours], 0)` | #,##0.00 | Total Cures, Total THT Hours |
| 12 | `Cures per Op Hr` | `DIVIDE([Total Cures], [Total Op Hours], 0)` | #,##0.00 | Total Cures, Total Op Hours |
| 13 | `Collection Efficiency` | `DIVIDE([Total Recovery], [Total RPC Arrears], 0)` | 0.0% | Total Recovery, Total RPC Arrears |
| 14 | `Online Payment %` | `DIVIDE(CALCULATE(COUNTROWS('Fact_Payments'), 'Fact_Payments'[payment_method] = "Online"), COUNTROWS('Fact_Payments'), 0)` | 0.0% | — |
| 15 | `Branch/ATM Payment %` | `DIVIDE(CALCULATE(COUNTROWS('Fact_Payments'), 'Fact_Payments'[payment_method] = "Branch/ATM"), COUNTROWS('Fact_Payments'), 0)` | 0.0% | — |
| 16 | `OFI Payment %` | `DIVIDE(CALCULATE(COUNTROWS('Fact_Payments'), 'Fact_Payments'[payment_method] = "OFI"), COUNTROWS('Fact_Payments'), 0)` | 0.0% | — |

**Notes:**
- `Total Cures` uses `DISTINCTCOUNT(account_id)` to avoid double-counting accounts cured multiple times in a period.
- `Agent Cure Count` vs `Self-Cure Count`: Agent cures are PTP-linked (agent had RPC, client made payment). Self-cures are spontaneous payments (online/ATM) with no agent interaction.
- `Agent Cure Rate` + `Self-Cure Rate` should sum to 100%.
- `Collection Efficiency` = Total Recovery / Total RPC Arrears. Answers: "Of all arrears we touched via RPC, how much did we collect?"
- Payment method strings must match exactly: `"Online"`, `"Branch/ATM"`, `"OFI"`. The generator produces `"Branch/ATM"` (with slash).

**Thresholds:**
| KPI | Green | Amber | Red |
|---|---|---|---|
| Collection Efficiency | >= 15% | 10-14% | < 10% |
| Cures per THT Hr | >= 0.15 | 0.08-0.15 | < 0.08 |

---

## Table 4: _Portfolio Health

EOM snapshot metrics, DPD bucket distribution, arrears composition, roll rates.

| # | Measure | Formula | Format | Dependencies |
|---|---|---|---|---|
| 1 | `Portfolio Total Balance` | `CALCULATE(SUM('Fact_EOM_Snapshot'[balance]), 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))` | $#,##0 | — |
| 2 | `Portfolio Total Arrears` | `CALCULATE(SUM('Fact_EOM_Snapshot'[arrears]), 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))` | $#,##0 | — |
| 3 | `Total Accounts` | `CALCULATE(COUNTROWS('Fact_EOM_Snapshot'), 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))` | #,##0 | — |
| 4 | `Accounts in Mora` | `CALCULATE(COUNTROWS('Fact_EOM_Snapshot'), 'Fact_EOM_Snapshot'[status] = "Mora", 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))` | #,##0 | — |
| 5 | `Mora Rate` | `DIVIDE([Accounts in Mora], [Total Accounts], 0)` | 0.0% | Accounts in Mora, Total Accounts |
| 6 | `Arrears to Balance` | `DIVIDE([Portfolio Total Arrears], [Portfolio Total Balance], 0)` | 0.0% | Portfolio Total Arrears, Portfolio Total Balance |
| 7 | `Avg Balance per Account` | `DIVIDE([Portfolio Total Balance], [Total Accounts], 0)` | $#,##0 | Portfolio Total Balance, Total Accounts |
| 8 | `Avg Arrears per Mora Account` | `DIVIDE([Portfolio Total Arrears], [Accounts in Mora], 0)` | $#,##0 | Portfolio Total Arrears, Accounts in Mora |
| 9 | `Accounts DPD Current` | `CALCULATE(COUNTROWS('Fact_EOM_Snapshot'), 'Fact_EOM_Snapshot'[dpd_bucket] = "Current", 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))` | #,##0 | — |
| 10 | `Accounts DPD 1-30` | `CALCULATE(COUNTROWS('Fact_EOM_Snapshot'), 'Fact_EOM_Snapshot'[dpd_bucket] = "1-30", 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))` | #,##0 | — |
| 11 | `Accounts DPD 31-60` | `CALCULATE(COUNTROWS('Fact_EOM_Snapshot'), 'Fact_EOM_Snapshot'[dpd_bucket] = "31-60", 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))` | #,##0 | — |
| 12 | `Accounts DPD 61-90` | `CALCULATE(COUNTROWS('Fact_EOM_Snapshot'), 'Fact_EOM_Snapshot'[dpd_bucket] = "61-90", 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))` | #,##0 | — |
| 13 | `Accounts DPD 90+` | `CALCULATE(COUNTROWS('Fact_EOM_Snapshot'), 'Fact_EOM_Snapshot'[dpd_bucket] = "90+", 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]))` | #,##0 | — |
| 14 | `Mora Rate by DPD 1-30` | `DIVIDE([Accounts DPD 1-30], [Total Accounts], 0)` | 0.0% | Accounts DPD 1-30, Total Accounts |
| 15 | `Mora Rate by DPD 31-60` | `DIVIDE([Accounts DPD 31-60], [Total Accounts], 0)` | 0.0% | Accounts DPD 31-60, Total Accounts |
| 16 | `Mora Rate by DPD 61-90` | `DIVIDE([Accounts DPD 61-90], [Total Accounts], 0)` | 0.0% | Accounts DPD 61-90, Total Accounts |
| 17 | `Mora Rate by DPD 90+` | `DIVIDE([Accounts DPD 90+], [Total Accounts], 0)` | 0.0% | Accounts DPD 90+, Total Accounts |
| 18 | `Roll Rate Current to Delinquent` | See below | 0.0% | Fact_EOM_Snapshot |
| 19 | `Roll Rate 30 to 60` | See below | 0.0% | Fact_EOM_Snapshot |
| 20 | `Roll Rate 60 to 90` | See below | 0.0% | Fact_EOM_Snapshot |

**Notes:**
- All EOM measures use `snapshot_date = MAX(snapshot_date)` to filter to the latest snapshot only. Without this filter, measures triple-count (3 months x all accounts).
- `Mora Rate by DPD` measures show the composition of delinquency. All4 should sum to the overall `Mora Rate`.
- DPD bucket values in the data: `"Current"`, `"1-30"`, `"31-60"`, `"61-90"`, `"90+"`.

**Thresholds:**
| KPI | Green | Amber | Red |
|---|---|---|---|
| Mora Rate | < 15% | 15-20% | > 20% |
| Arrears to Balance | < 8% | 8-12% | > 12% |
| Roll Rate (Current->Delinquent) | < 10% | 10-20% | > 20% |

---

### Roll Rate Measures — DAX Detail

Roll Rate measures track accounts migrating from one DPD bucket to a worse bucket month-over-month. They require comparing the same account across two EOM snapshots.

**Recommended: Calculated Column Approach (Performant)**

For best performance, add a calculated column to `Fact_EOM_Snapshot`:

```dax
PriorMonthDPDBucket =
    VAR CurrentAccount = 'Fact_EOM_Snapshot'[account_id]
    VAR CurrentDate = 'Fact_EOM_Snapshot'[snapshot_date]
    VAR PriorDate = EOMONTH(CurrentDate, -1)
    RETURN
        CALCULATE(
            SELECTEDVALUE('Fact_EOM_Snapshot'[dpd_bucket]),
            FILTER(
                'Fact_EOM_Snapshot',
                'Fact_EOM_Snapshot'[account_id] = CurrentAccount
                    && 'Fact_EOM_Snapshot'[snapshot_date] = PriorDate
            )
        )
```

Then simplify each Roll Rate measure to:

```dax
Roll Rate Current to Delinquent =
    VAR _CurrentMonth = MAX('Fact_EOM_Snapshot'[snapshot_date])
    VAR _PriorMonth = EOMONTH(_CurrentMonth, -1)
    VAR _AccountsInPriorBucket =
        CALCULATE(
            DISTINCTCOUNT('Fact_EOM_Snapshot'[account_id]),
            'Fact_EOM_Snapshot'[snapshot_date] = _PriorMonth,
            'Fact_EOM_Snapshot'[dpd_bucket] = "Current"
        )
    VAR _AccountsRolled =
        CALCULATE(
            COUNTROWS('Fact_EOM_Snapshot'),
            'Fact_EOM_Snapshot'[snapshot_date] = _CurrentMonth,
            'Fact_EOM_Snapshot'[dpd_bucket] <> "Current",
            'Fact_EOM_Snapshot'[PriorMonthDPDBucket] = "Current"
        )
    RETURN
        DIVIDE(_AccountsRolled, _AccountsInPriorBucket, 0)
```

**Fallback: FILTER Pattern (No calculated column needed)**

The CSV uses this pattern, which works without schema changes but is slower on large datasets:

```dax
Roll Rate Current to Delinquent =
    VAR _CurrentMonth = MAX('Fact_EOM_Snapshot'[snapshot_date])
    VAR _PriorMonth = EOMONTH(_CurrentMonth, -1)
    VAR _AccountsInPriorBucket =
        CALCULATE(
            DISTINCTCOUNT('Fact_EOM_Snapshot'[account_id]),
            'Fact_EOM_Snapshot'[snapshot_date] = _PriorMonth,
            'Fact_EOM_Snapshot'[dpd_bucket] = "Current"
        )
    VAR _AccountsRolled =
        COUNTROWS(
            FILTER(
                'Fact_EOM_Snapshot',
                'Fact_EOM_Snapshot'[snapshot_date] = _CurrentMonth
                    && 'Fact_EOM_Snapshot'[dpd_bucket] <> "Current"
                    && CONTAINS(
                        CALCULATETABLE(
                            FILTER('Fact_EOM_Snapshot', 'Fact_EOM_Snapshot'[dpd_bucket] = "Current"),
                            'Fact_EOM_Snapshot'[snapshot_date] = _PriorMonth
                        ),
                        'Fact_EOM_Snapshot'[account_id],
                        'Fact_EOM_Snapshot'[account_id]
                    )
            )
        )
    RETURN
        DIVIDE(_AccountsRolled, _AccountsInPriorBucket, 0)
```

**Roll Rate Logic:**
- `Roll Rate Current to Delinquent`: % of accounts that were "Current" last month but moved to any delinquent bucket (1-30, 31-60, 61-90, 90+) this month
- `Roll Rate 30 to 60`: % of accounts that were in "1-30" last month but moved to "31-60" this month
- `Roll Rate 60 to 90`: % of accounts that were in "61-90" last month but moved to "90+" this month

---

## Table 5: _Time Intelligence

All MoM, WoW, DoD, YoY, OTC, YTD, and rolling window calculations. **120 measures total.**

### 5.1 MoM (Month-over-Month) — 36 measures

| # | Measure | Formula | Format | Dependencies |
|---|---|---|---|---|
| 1 | `RPC Rate Prior Month` | `CALCULATE([RPC Rate], DATEADD('Dim_Calendar'[date], -1, MONTH))` | 0.0% | RPC Rate |
| 2 | `RPC Rate MoM Change` | `[RPC Rate] - [RPC Rate Prior Month]` | +0.0%;-0.0% | RPC Rate, RPC Rate Prior Month |
| 3 | `Promise Rate Prior Month` | `CALCULATE([Promise Rate], DATEADD('Dim_Calendar'[date], -1, MONTH))` | 0.0% | Promise Rate |
| 4 | `Promise Rate MoM Change` | `[Promise Rate] - [Promise Rate Prior Month]` | +0.0%;-0.0% | Promise Rate, Promise Rate Prior Month |
| 5 | `Promise Rate MoM %` | `VAR _Prior = [Promise Rate Prior Month] RETURN DIVIDE([Promise Rate] - _Prior, _Prior, 0)` | +0.0%;-0.0% | Promise Rate, Promise Rate Prior Month |
| 6 | `KP Rate Prior Month` | `CALCULATE([KP Rate], DATEADD('Dim_Calendar'[date], -1, MONTH))` | 0.0% | KP Rate |
| 7 | `KP Rate MoM Change` | `[KP Rate] - [KP Rate Prior Month]` | +0.0%;-0.0% | KP Rate, KP Rate Prior Month |
| 8 | `KP Rate MoM %` | `VAR _Prior = [KP Rate Prior Month] RETURN DIVIDE([KP Rate] - _Prior, _Prior, 0)` | +0.0%;-0.0% | KP Rate, KP Rate Prior Month |
| 9 | `BB Conversion Prior Month` | `CALCULATE([BB Conversion Rate], DATEADD('Dim_Calendar'[date], -1, MONTH))` | 0.0% | BB Conversion Rate |
| 10 | `BB Conversion MoM Change` | `[BB Conversion Rate] - [BB Conversion Prior Month]` | +0.0%;-0.0% | BB Conversion Rate, BB Conversion Prior Month |
| 11 | `Total Cures Prior Month` | `CALCULATE([Total Cures], DATEADD('Dim_Calendar'[date], -1, MONTH))` | #,##0 | Total Cures |
| 12 | `Cures MoM Change` | `[Total Cures] - [Total Cures Prior Month]` | +#,##0;-#,##0 | Total Cures, Total Cures Prior Month |
| 13 | `Cured Amount Prior Month` | `CALCULATE([Cured Amount], DATEADD('Dim_Calendar'[date], -1, MONTH))` | $#,##0 | Cured Amount |
| 14 | `Cured Amount MoM %` | `DIVIDE([Cured Amount] - [Cured Amount Prior Month], [Cured Amount Prior Month], 0)` | +0.0%;-0.0% | Cured Amount, Cured Amount Prior Month |
| 15 | `Mora Rate Prior Month` | `CALCULATE([Mora Rate], DATEADD('Dim_Calendar'[date], -1, MONTH))` | 0.0% | Mora Rate |
| 16 | `Mora Rate MoM Change` | `[Mora Rate] - [Mora Rate Prior Month]` | +0.0%;-0.0% | Mora Rate, Mora Rate Prior Month |
| 17 | `Avg ACW RPC (sec) Prior Month` | `CALCULATE([Avg ACW RPC (sec)], DATEADD('Dim_Calendar'[date], -1, MONTH))` | #,##0 | Avg ACW RPC (sec) |
| 18 | `Avg ACW RPC (sec) MoM Change` | `[Avg ACW RPC (sec)] - [Avg ACW RPC (sec) Prior Month]` | +#,##0;-#,##0 | Avg ACW RPC (sec), Prior Month |
| 19 | `Avg ACW RPC MoM %` | `VAR _Prior = [Avg ACW RPC (sec) Prior Month] RETURN DIVIDE([Avg ACW RPC (sec)] - _Prior, _Prior, 0)` | +0.0%;-0.0% | Avg ACW RPC (sec), Prior Month |
| 20 | `Avg ACW Non-RPC (sec) Prior Month` | `CALCULATE([Avg ACW Non-RPC (sec)], DATEADD('Dim_Calendar'[date], -1, MONTH))` | #,##0 | Avg ACW Non-RPC (sec) |
| 21 | `Avg ACW Non-RPC (sec) MoM Change` | `[Avg ACW Non-RPC (sec)] - [Avg ACW Non-RPC (sec) Prior Month]` | +#,##0;-#,##0 | Avg ACW Non-RPC (sec), Prior Month |
| 22 | `Avg ACW Non-RPC MoM %` | `VAR _Prior = [Avg ACW Non-RPC (sec) Prior Month] RETURN DIVIDE([Avg ACW Non-RPC (sec)] - _Prior, _Prior, 0)` | +0.0%;-0.0% | Avg ACW Non-RPC (sec), Prior Month |
| 23 | `Capped KP per RPC Arrears Prior Month` | `CALCULATE([Capped KP per RPC Arrears], DATEADD('Dim_Calendar'[date], -1, MONTH))` | 0.0% | Capped KP per RPC Arrears |
| 24 | `Capped KP per RPC Arrears MoM Change` | `[Capped KP per RPC Arrears] - [Capped KP per RPC Arrears Prior Month]` | +0.0%;-0.0% | Capped KP per RPC Arrears, Prior Month |
| 25 | `Capped KP per RPC Arrears MoM %` | `VAR _Prior = [Capped KP per RPC Arrears Prior Month] RETURN DIVIDE([Capped KP per RPC Arrears] - _Prior, _Prior, 0)` | +0.0%;-0.0% | Capped KP per RPC Arrears, Prior Month |
| 26 | `Cures per THT Hr Prior Month` | `CALCULATE([Cures per THT Hr], DATEADD('Dim_Calendar'[date], -1, MONTH))` | #,##0.00 | Cures per THT Hr |
| 27 | `Cures per THT Hr MoM Change` | `[Cures per THT Hr] - [Cures per THT Hr Prior Month]` | +#,##0.00;-#,##0.00 | Cures per THT Hr, Prior Month |
| 28 | `Cures per THT Hr MoM %` | `VAR _Prior = [Cures per THT Hr Prior Month] RETURN DIVIDE([Cures per THT Hr] - _Prior, _Prior, 0)` | +0.0%;-0.0% | Cures per THT Hr, Prior Month |
| 29 | `Avg Utilization % Prior Month` | `CALCULATE([Avg Utilization %], DATEADD('Dim_Calendar'[date], -1, MONTH))` | 0.0% | Avg Utilization % |
| 30 | `Avg Utilization % MoM Change` | `[Avg Utilization %] - [Avg Utilization % Prior Month]` | +0.0%;-0.0% | Avg Utilization %, Prior Month |
| 31 | `Avg Utilization % MoM %` | `VAR _Prior = [Avg Utilization % Prior Month] RETURN DIVIDE([Avg Utilization %] - _Prior, _Prior, 0)` | +0.0%;-0.0% | Avg Utilization %, Prior Month |
| 32 | `Cured Amount YTD` | `CALCULATE([Cured Amount], DATESYTD('Dim_Calendar'[date]))` | $#,##0 | Cured Amount |
| 33 | `KP Rate YTD` | `CALCULATE([KP Rate], DATESYTD('Dim_Calendar'[date]))` | 0.0% | KP Rate |
| 34 | `Total Cures YTD` | `CALCULATE([Total Cures], DATESYTD('Dim_Calendar'[date]))` | #,##0 | Total Cures |
| 35 | `Rolling 3M KP Rate` | `CALCULATE([KP Rate], DATESINPERIOD('Dim_Calendar'[date], LASTDATE('Dim_Calendar'[date]), -3, MONTH))` | 0.0% | KP Rate |
| 36 | `Portfolio Balance Prior Month` | `CALCULATE(SUM('Fact_EOM_Snapshot'[balance]), 'Fact_EOM_Snapshot'[snapshot_date] = EOMONTH(MAX('Fact_EOM_Snapshot'[snapshot_date]), -1))` | $#,##0 | — |

### 5.2 WoW (Week-over-Week) — 21 measures

WoW uses `iso_week` from `Dim_Calendar`. Pattern: `SELECTEDVALUE('Dim_Calendar'[iso_week])` → prior week → `CALCULATE` with prior dates. Only meaningful at daily/weekly granularity.

| # | Measure | Formula | Format |
|---|---|---|---|
| 37 | `Promise Rate Prior Week` | `VAR _CurrentISOWeek = SELECTEDVALUE('Dim_Calendar'[iso_week]) VAR _PriorISOWeek = _CurrentISOWeek - 1 VAR _PriorDates = CALCULATETABLE(VALUES('Dim_Calendar'[date]), 'Dim_Calendar'[iso_week] = _PriorISOWeek) RETURN CALCULATE([Promise Rate], _PriorDates)` | 0.0% |
| 38 | `Promise Rate WoW Change` | `[Promise Rate] - [Promise Rate Prior Week]` | +0.0%;-0.0% |
| 39 | `Promise Rate WoW %` | `VAR _Prior = [Promise Rate Prior Week] RETURN DIVIDE([Promise Rate] - _Prior, _Prior, 0)` | +0.0%;-0.0% |
| 40 | `KP Rate Prior Week` | Same pattern as above with `[KP Rate]` | 0.0% |
| 41 | `KP Rate WoW Change` | `[KP Rate] - [KP Rate Prior Week]` | +0.0%;-0.0% |
| 42 | `KP Rate WoW %` | `VAR _Prior = [KP Rate Prior Week] RETURN DIVIDE([KP Rate] - _Prior, _Prior, 0)` | +0.0%;-0.0% |
| 43 | `Avg ACW RPC (sec) Prior Week` | Same pattern as above with `[Avg ACW RPC (sec)]` | #,##0 |
| 44 | `Avg ACW RPC (sec) WoW Change` | `[Avg ACW RPC (sec)] - [Avg ACW RPC (sec) Prior Week]` | +#,##0;-#,##0 |
| 45 | `Avg ACW RPC WoW %` | `VAR _Prior = [Avg ACW RPC (sec) Prior Week] RETURN DIVIDE([Avg ACW RPC (sec)] - _Prior, _Prior, 0)` | +0.0%;-0.0% |
| 46 | `Avg ACW Non-RPC (sec) Prior Week` | Same pattern as above with `[Avg ACW Non-RPC (sec)]` | #,##0 |
| 47 | `Avg ACW Non-RPC (sec) WoW Change` | `[Avg ACW Non-RPC (sec)] - [Avg ACW Non-RPC (sec) Prior Week]` | +#,##0;-#,##0 |
| 48 | `Avg ACW Non-RPC WoW %` | `VAR _Prior = [Avg ACW Non-RPC (sec) Prior Week] RETURN DIVIDE([Avg ACW Non-RPC (sec)] - _Prior, _Prior, 0)` | +0.0%;-0.0% |
| 49 | `Capped KP per RPC Arrears Prior Week` | Same pattern as above with `[Capped KP per RPC Arrears]` | 0.0% |
| 50 | `Capped KP per RPC Arrears WoW Change` | `[Capped KP per RPC Arrears] - [Capped KP per RPC Arrears Prior Week]` | +0.0%;-0.0% |
| 51 | `Capped KP per RPC Arrears WoW %` | `VAR _Prior = [Capped KP per RPC Arrears Prior Week] RETURN DIVIDE([Capped KP per RPC Arrears] - _Prior, _Prior, 0)` | +0.0%;-0.0% |
| 52 | `Cures per THT Hr Prior Week` | Same pattern as above with `[Cures per THT Hr]` | #,##0.00 |
| 53 | `Cures per THT Hr WoW Change` | `[Cures per THT Hr] - [Cures per THT Hr Prior Week]` | +#,##0.00;-#,##0.00 |
| 54 | `Cures per THT Hr WoW %` | `VAR _Prior = [Cures per THT Hr Prior Week] RETURN DIVIDE([Cures per THT Hr] - _Prior, _Prior, 0)` | +0.0%;-0.0% |
| 55 | `Avg Utilization % Prior Week` | Same pattern as above with `[Avg Utilization %]` | 0.0% |
| 56 | `Avg Utilization % WoW Change` | `[Avg Utilization %] - [Avg Utilization % Prior Week]` | +0.0%;-0.0% |
| 57 | `Avg Utilization % WoW %` | `VAR _Prior = [Avg Utilization % Prior Week] RETURN DIVIDE([Avg Utilization %] - _Prior, _Prior, 0)` | +0.0%;-0.0% |

### 5.3 DoD (Day-over-Day) — 21 measures

DoD uses `DATEADD('Dim_Calendar'[date], -1, DAY)`. Only meaningful at daily granularity.

| # | Measure | Formula | Format |
|---|---|---|---|
| 58 | `Promise Rate Prior Day` | `CALCULATE([Promise Rate], DATEADD('Dim_Calendar'[date], -1, DAY))` | 0.0% |
| 59 | `Promise Rate DoD Change` | `[Promise Rate] - [Promise Rate Prior Day]` | +0.0%;-0.0% |
| 60 | `Promise Rate DoD %` | `VAR _Prior = [Promise Rate Prior Day] RETURN DIVIDE([Promise Rate] - _Prior, _Prior, 0)` | +0.0%;-0.0% |
| 61 | `KP Rate Prior Day` | `CALCULATE([KP Rate], DATEADD('Dim_Calendar'[date], -1, DAY))` | 0.0% |
| 62 | `KP Rate DoD Change` | `[KP Rate] - [KP Rate Prior Day]` | +0.0%;-0.0% |
| 63 | `KP Rate DoD %` | `VAR _Prior = [KP Rate Prior Day] RETURN DIVIDE([KP Rate] - _Prior, _Prior, 0)` | +0.0%;-0.0% |
| 64 | `Avg ACW RPC (sec) Prior Day` | `CALCULATE([Avg ACW RPC (sec)], DATEADD('Dim_Calendar'[date], -1, DAY))` | #,##0 |
| 65 | `Avg ACW RPC (sec) DoD Change` | `[Avg ACW RPC (sec)] - [Avg ACW RPC (sec) Prior Day]` | +#,##0;-#,##0 |
| 66 | `Avg ACW RPC DoD %` | `VAR _Prior = [Avg ACW RPC (sec) Prior Day] RETURN DIVIDE([Avg ACW RPC (sec)] - _Prior, _Prior, 0)` | +0.0%;-0.0% |
| 67 | `Avg ACW Non-RPC (sec) Prior Day` | `CALCULATE([Avg ACW Non-RPC (sec)], DATEADD('Dim_Calendar'[date], -1, DAY))` | #,##0 |
| 68 | `Avg ACW Non-RPC (sec) DoD Change` | `[Avg ACW Non-RPC (sec)] - [Avg ACW Non-RPC (sec) Prior Day]` | +#,##0;-#,##0 |
| 69 | `Avg ACW Non-RPC DoD %` | `VAR _Prior = [Avg ACW Non-RPC (sec) Prior Day] RETURN DIVIDE([Avg ACW Non-RPC (sec)] - _Prior, _Prior, 0)` | +0.0%;-0.0% |
| 70 | `Capped KP per RPC Arrears Prior Day` | `CALCULATE([Capped KP per RPC Arrears], DATEADD('Dim_Calendar'[date], -1, DAY))` | 0.0% |
| 71 | `Capped KP per RPC Arrears DoD Change` | `[Capped KP per RPC Arrears] - [Capped KP per RPC Arrears Prior Day]` | +0.0%;-0.0% |
| 72 | `Capped KP per RPC Arrears DoD %` | `VAR _Prior = [Capped KP per RPC Arrears Prior Day] RETURN DIVIDE([Capped KP per RPC Arrears] - _Prior, _Prior, 0)` | +0.0%;-0.0% |
| 73 | `Cures per THT Hr Prior Day` | `CALCULATE([Cures per THT Hr], DATEADD('Dim_Calendar'[date], -1, DAY))` | #,##0.00 |
| 74 | `Cures per THT Hr DoD Change` | `[Cures per THT Hr] - [Cures per THT Hr Prior Day]` | +#,##0.00;-#,##0.00 |
| 75 | `Cures per THT Hr DoD %` | `VAR _Prior = [Cures per THT Hr Prior Day] RETURN DIVIDE([Cures per THT Hr] - _Prior, _Prior, 0)` | +0.0%;-0.0% |
| 76 | `Avg Utilization % Prior Day` | `CALCULATE([Avg Utilization %], DATEADD('Dim_Calendar'[date], -1, DAY))` | 0.0% |
| 77 | `Avg Utilization % DoD Change` | `[Avg Utilization %] - [Avg Utilization % Prior Day]` | +0.0%;-0.0% |
| 78 | `Avg Utilization % DoD %` | `VAR _Prior = [Avg Utilization % Prior Day] RETURN DIVIDE([Avg Utilization %] - _Prior, _Prior, 0)` | +0.0%;-0.0% |

### 5.4 YoY (Year-over-Year) — 21 measures

YoY uses `SAMEPERIODLASTYEAR('Dim_Calendar'[date])`. Returns BLANK until 2026 data is loaded (pattern included for future compatibility).

| # | Measure | Formula | Format |
|---|---|---|---|
| 79 | `Promise Rate Prior Year` | `CALCULATE([Promise Rate], SAMEPERIODLASTYEAR('Dim_Calendar'[date]))` | 0.0% |
| 80 | `Promise Rate YoY Change` | `[Promise Rate] - [Promise Rate Prior Year]` | +0.0%;-0.0% |
| 81 | `Promise Rate YoY %` | `VAR _Prior = [Promise Rate Prior Year] RETURN DIVIDE([Promise Rate] - _Prior, _Prior, 0)` | +0.0%;-0.0% |
| 82 | `KP Rate Prior Year` | `CALCULATE([KP Rate], SAMEPERIODLASTYEAR('Dim_Calendar'[date]))` | 0.0% |
| 83 | `KP Rate YoY Change` | `[KP Rate] - [KP Rate Prior Year]` | +0.0%;-0.0% |
| 84 | `KP Rate YoY %` | `VAR _Prior = [KP Rate Prior Year] RETURN DIVIDE([KP Rate] - _Prior, _Prior, 0)` | +0.0%;-0.0% |
| 85 | `Avg ACW RPC (sec) Prior Year` | `CALCULATE([Avg ACW RPC (sec)], SAMEPERIODLASTYEAR('Dim_Calendar'[date]))` | #,##0 |
| 86 | `Avg ACW RPC (sec) YoY Change` | `[Avg ACW RPC (sec)] - [Avg ACW RPC (sec) Prior Year]` | +#,##0;-#,##0 |
| 87 | `Avg ACW RPC YoY %` | `VAR _Prior = [Avg ACW RPC (sec) Prior Year] RETURN DIVIDE([Avg ACW RPC (sec)] - _Prior, _Prior, 0)` | +0.0%;-0.0% |
| 88 | `Avg ACW Non-RPC (sec) Prior Year` | `CALCULATE([Avg ACW Non-RPC (sec)], SAMEPERIODLASTYEAR('Dim_Calendar'[date]))` | #,##0 |
| 89 | `Avg ACW Non-RPC (sec) YoY Change` | `[Avg ACW Non-RPC (sec)] - [Avg ACW Non-RPC (sec) Prior Year]` | +#,##0;-#,##0 |
| 90 | `Avg ACW Non-RPC YoY %` | `VAR _Prior = [Avg ACW Non-RPC (sec) Prior Year] RETURN DIVIDE([Avg ACW Non-RPC (sec)] - _Prior, _Prior, 0)` | +0.0%;-0.0% |
| 91 | `Capped KP per RPC Arrears Prior Year` | `CALCULATE([Capped KP per RPC Arrears], SAMEPERIODLASTYEAR('Dim_Calendar'[date]))` | 0.0% |
| 92 | `Capped KP per RPC Arrears YoY Change` | `[Capped KP per RPC Arrears] - [Capped KP per RPC Arrears Prior Year]` | +0.0%;-0.0% |
| 93 | `Capped KP per RPC Arrears YoY %` | `VAR _Prior = [Capped KP per RPC Arrears Prior Year] RETURN DIVIDE([Capped KP per RPC Arrears] - _Prior, _Prior, 0)` | +0.0%;-0.0% |
| 94 | `Cures per THT Hr Prior Year` | `CALCULATE([Cures per THT Hr], SAMEPERIODLASTYEAR('Dim_Calendar'[date]))` | #,##0.00 |
| 95 | `Cures per THT Hr YoY Change` | `[Cures per THT Hr] - [Cures per THT Hr Prior Year]` | +#,##0.00;-#,##0.00 |
| 96 | `Cures per THT Hr YoY %` | `VAR _Prior = [Cures per THT Hr Prior Year] RETURN DIVIDE([Cures per THT Hr] - _Prior, _Prior, 0)` | +0.0%;-0.0% |
| 97 | `Avg Utilization % Prior Year` | `CALCULATE([Avg Utilization %], SAMEPERIODLASTYEAR('Dim_Calendar'[date]))` | 0.0% |
| 98 | `Avg Utilization % YoY Change` | `[Avg Utilization %] - [Avg Utilization % Prior Year]` | +0.0%;-0.0% |
| 99 | `Avg Utilization % YoY %` | `VAR _Prior = [Avg Utilization % Prior Year] RETURN DIVIDE([Avg Utilization %] - _Prior, _Prior, 0)` | +0.0%;-0.0% |

### 5.5 OTC (Overall-to-Current) — 21 measures

OTC uses `ALL('Dim_Calendar')` to remove date filters. Compares current period against full-period overall average.

| # | Measure | Formula | Format |
|---|---|---|---|
| 100 | `Promise Rate Overall` | `CALCULATE([Promise Rate], ALL('Dim_Calendar'))` | 0.0% |
| 101 | `Promise Rate OTC Change` | `[Promise Rate] - [Promise Rate Overall]` | +0.0%;-0.0% |
| 102 | `Promise Rate OTC %` | `VAR _Overall = [Promise Rate Overall] RETURN DIVIDE([Promise Rate] - _Overall, _Overall, 0)` | +0.0%;-0.0% |
| 103 | `KP Rate Overall` | `CALCULATE([KP Rate], ALL('Dim_Calendar'))` | 0.0% |
| 104 | `KP Rate OTC Change` | `[KP Rate] - [KP Rate Overall]` | +0.0%;-0.0% |
| 105 | `KP Rate OTC %` | `VAR _Overall = [KP Rate Overall] RETURN DIVIDE([KP Rate] - _Overall, _Overall, 0)` | +0.0%;-0.0% |
| 106 | `Avg ACW RPC (sec) Overall` | `CALCULATE([Avg ACW RPC (sec)], ALL('Dim_Calendar'))` | #,##0 |
| 107 | `Avg ACW RPC (sec) OTC Change` | `[Avg ACW RPC (sec)] - [Avg ACW RPC (sec) Overall]` | +#,##0;-#,##0 |
| 108 | `Avg ACW RPC OTC %` | `VAR _Overall = [Avg ACW RPC (sec) Overall] RETURN DIVIDE([Avg ACW RPC (sec)] - _Overall, _Overall, 0)` | +0.0%;-0.0% |
| 109 | `Avg ACW Non-RPC (sec) Overall` | `CALCULATE([Avg ACW Non-RPC (sec)], ALL('Dim_Calendar'))` | #,##0 |
| 110 | `Avg ACW Non-RPC (sec) OTC Change` | `[Avg ACW Non-RPC (sec)] - [Avg ACW Non-RPC (sec) Overall]` | +#,##0;-#,##0 |
| 111 | `Avg ACW Non-RPC OTC %` | `VAR _Overall = [Avg ACW Non-RPC (sec) Overall] RETURN DIVIDE([Avg ACW Non-RPC (sec)] - _Overall, _Overall, 0)` | +0.0%;-0.0% |
| 112 | `Capped KP per RPC Arrears Overall` | `CALCULATE([Capped KP per RPC Arrears], ALL('Dim_Calendar'))` | 0.0% |
| 113 | `Capped KP per RPC Arrears OTC Change` | `[Capped KP per RPC Arrears] - [Capped KP per RPC Arrears Overall]` | +0.0%;-0.0% |
| 114 | `Capped KP per RPC Arrears OTC %` | `VAR _Overall = [Capped KP per RPC Arrears Overall] RETURN DIVIDE([Capped KP per RPC Arrears] - _Overall, _Overall, 0)` | +0.0%;-0.0% |
| 115 | `Cures per THT Hr Overall` | `CALCULATE([Cures per THT Hr], ALL('Dim_Calendar'))` | #,##0.00 |
| 116 | `Cures per THT Hr OTC Change` | `[Cures per THT Hr] - [Cures per THT Hr Overall]` | +#,##0.00;-#,##0.00 |
| 117 | `Cures per THT Hr OTC %` | `VAR _Overall = [Cures per THT Hr Overall] RETURN DIVIDE([Cures per THT Hr] - _Overall, _Overall, 0)` | +0.0%;-0.0% |
| 118 | `Avg Utilization % Overall` | `CALCULATE([Avg Utilization %], ALL('Dim_Calendar'))` | 0.0% |
| 119 | `Avg Utilization % OTC Change` | `[Avg Utilization %] - [Avg Utilization % Overall]` | +0.0%;-0.0% |
| 120 | `Avg Utilization % OTC %` | `VAR _Overall = [Avg Utilization % Overall] RETURN DIVIDE([Avg Utilization %] - _Overall, _Overall, 0)` | +0.0%;-0.0% |

**Notes:**
- All `DATEADD` measures require `Dim_Calendar` to be marked as a Date Table.
- MoM `Change` measures return absolute difference (percentage points for % KPIs). Use `MoM %` for relative change.
- WoW requires `iso_week` column in `Dim_Calendar`. Only meaningful at daily/weekly granularity.
- DoD uses `DATEADD(..., -1, DAY)`. Only meaningful at daily granularity.
- YoY uses `SAMEPERIODLASTYEAR`. Returns BLANK until 2026 data is loaded.
- OTC uses `ALL('Dim_Calendar')` to remove all date filters. Shows full-period average.
- `Rolling 3M KP Rate` uses `DATESINPERIOD` with `-3, MONTH` from the last date in context.
- YTD measures reset at the start of each calendar year.
- `Portfolio Balance Prior Month` uses `EOMONTH` against `snapshot_date` (not calendar date) because EOM snapshots are monthly.

---

## Table 6: _Executive (3 measures)

VP-level portfolio health metrics for Executive Collections dashboard.

| # | Measure | Formula | Format | Dependencies |
|---|---|---|---|---|
| 1 | `Portfolio Health Score` | `VAR _PTP = [Promise Rate] * 25 VAR _KP = [KP Rate] * 25 VAR _Cures = DIVIDE([Cures per THT Hr], 3, 0) * 25 VAR _Util = [Avg Utilization %] * 25 RETURN _PTP + _KP + _Cures + _Util` | #,##0 | Promise Rate, KP Rate, Cures per THT Hr, Avg Utilization % |
| 2 | `Monthly Recovery Rate` | `VAR _CurrentMonth = SUM('Fact_Payments'[amount_paid]) VAR _PriorMonth = CALCULATE(SUM('Fact_Payments'[amount_paid]), DATEADD('Dim_Calendar'[date], -1, MONTH)) RETURN DIVIDE(_CurrentMonth - _PriorMonth, _PriorMonth, 0)` | +0.0%;-0.0% | Fact_Payments, Dim_Calendar |
| 3 | `Portfolio At-Risk Balance` | `CALCULATE(SUM('Fact_EOM_Snapshot'[arrears]), 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]), 'Fact_EOM_Snapshot'[status] = "Mora")` | $#,##0 | Fact_EOM_Snapshot |

**Notes:**
- `Portfolio Health Score` is a weighted composite (0-100): PTP% 25 + KP% 25 + Cures/THT (normalized to 3) 25 + Utilization 25.
- `Monthly Recovery Rate` shows MoM change in total recovery amount.
- `Portfolio At-Risk Balance` = total arrears for accounts currently in Mora status.

---

## Table 7: _Agent Performance (5 measures)

Individual agent metrics for Agent Performance leaderboard and coaching.

| # | Measure | Formula | Format | Dependencies |
|---|---|---|---|---|
| 1 | `Agent RPC per Hour` | `DIVIDE([Total RPCs], [Total Op Hours], 0)` | #,##0.0 | Total RPCs, Total Op Hours |
| 2 | `Agent KP Rate` | `DIVIDE([PTP Kept], [Evaluated PTPs], 0)` | 0.0% | PTP Kept, Evaluated PTPs |
| 3 | `Agent Quality Score` | `VAR _KPScore = [KP Rate] * 40 VAR _AHTScore = IF([Avg AHT RPC (sec)] <= 180, 30, IF([Avg AHT RPC (sec)] <= 240, 20, 10)) VAR _UtilScore = [Avg Utilization %] * 30 RETURN _KPScore + _AHTScore + _UtilScore` | #,##0 | KP Rate, Avg AHT RPC (sec), Avg Utilization % |
| 4 | `Agent Performance Tier` | `VAR _Score = [Agent Quality Score] RETURN SWITCH(TRUE(), _Score >= 80, "High", _Score >= 60, "Medium", "Low")` | Text | Agent Quality Score |
| 5 | `Agent Tenure Months` | `DATEDIFF(LOOKUPVALUE('Dim_Agents'[hire_date], 'Dim_Agents'[agent_id], SELECTEDVALUE('Fact_Agent_Time_Log'[agent_id])), TODAY(), MONTH)` | #,##0 | Dim_Agents, Fact_Agent_Time_Log |

**Notes:**
- `Agent Quality Score` is a weighted composite (0-100): KP% 40 + AHT score (30/20/10 by threshold) + Utilization 30.
- `Agent Performance Tier`: High (>=80), Medium (>=60), Low (<60).
- `Agent Tenure Months` uses `LOOKUPVALUE` to get hire date from `Dim_Agents` based on current agent context.

---

## Table 8: _Dialer Performance (3 measures)

Dialer campaign efficiency metrics.

| # | Measure | Formula | Format | Dependencies |
|---|---|---|---|---|
| 1 | `Dialer Connection Rate` | `DIVIDE([Total Connected], [Total Calls Attempted], 0)` | 0.0% | Total Connected, Total Calls Attempted |
| 2 | `Dialer Abandon Rate` | `VAR _Abandoned = CALCULATE(COUNTROWS('Fact_Interactions'), 'Fact_Interactions'[channel] = "Dialer", 'Fact_Interactions'[rpc_flag] = FALSE()) RETURN DIVIDE(_Abandoned, [Total Connected], 0)` | 0.0% | Fact_Interactions, Total Connected |
| 3 | `Dialer Efficiency Score` | `VAR _ConnRate = [Dialer Connection Rate] * 40 VAR _RPCRate = [RPC Rate] * 35 VAR _Util = [Avg Utilization %] * 25 RETURN _ConnRate + _RPCRate + _Util` | #,##0 | Dialer Connection Rate, RPC Rate, Avg Utilization % |

**Notes:**
- `Dialer Abandon Rate` counts non-RPC connections on the Dialer channel as "abandoned" (no live person reached).
- `Dialer Efficiency Score` is a weighted composite (0-100): Connection Rate 40 + RPC Rate 35 + Utilization 25.

---

## Table 9: _Portfolio Management (3 measures)

Portfolio-level risk and concentration metrics.

| # | Measure | Formula | Format | Dependencies |
|---|---|---|---|---|
| 1 | `Portfolio Concentration Index` | `VAR _TotalBalance = [Portfolio Total Balance] VAR _Tarjeta = CALCULATE(SUM('Fact_EOM_Snapshot'[balance]), 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]), 'Dim_Accounts'[product_type] = "Tarjeta") VAR _Prestamo = CALCULATE(SUM('Fact_EOM_Snapshot'[balance]), 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]), 'Dim_Accounts'[product_type] = "Prestamo") VAR _Hipoteca = CALCULATE(SUM('Fact_EOM_Snapshot'[balance]), 'Fact_EOM_Snapshot'[snapshot_date] = MAX('Fact_EOM_Snapshot'[snapshot_date]), 'Dim_Accounts'[product_type] = "Hipoteca") VAR _HTarjeta = DIVIDE(_Tarjeta, _TotalBalance, 0) VAR _HPrestamo = DIVIDE(_Prestamo, _TotalBalance, 0) VAR _HHipoteca = DIVIDE(_Hipoteca, _TotalBalance, 0) RETURN (_HTarjeta * _HTarjeta) + (_HPrestamo * _HPrestamo) + (_HHipoteca * _HHipoteca)` | 0.000 | Portfolio Total Balance, Fact_EOM_Snapshot |
| 2 | `Mora Balance Rate` | `DIVIDE([Portfolio Total Arrears], [Portfolio Total Balance], 0)` | 0.0% | Portfolio Total Arrears, Portfolio Total Balance |
| 3 | `DPD Migration Rate` | `VAR _CurrentMonth = MAX('Fact_EOM_Snapshot'[snapshot_date]) VAR _PriorMonth = EOMONTH(_CurrentMonth, -1) VAR _MigratedUp = COUNTROWS(FILTER('Fact_EOM_Snapshot', 'Fact_EOM_Snapshot'[snapshot_date] = _CurrentMonth && CONTAINS(CALCULATETABLE(FILTER('Fact_EOM_Snapshot', 'Fact_EOM_Snapshot'[snapshot_date] = _PriorMonth), 'Fact_EOM_Snapshot'[account_id], 'Fact_EOM_Snapshot'[account_id]), 'Fact_EOM_Snapshot'[account_id], 'Fact_EOM_Snapshot'[account_id]))) VAR _PriorTotal = CALCULATE(DISTINCTCOUNT('Fact_EOM_Snapshot'[account_id]), 'Fact_EOM_Snapshot'[snapshot_date] = _PriorMonth) RETURN DIVIDE(_MigratedUp, _PriorTotal, 0)` | 0.0% | Fact_EOM_Snapshot |

**Notes:**
- `Portfolio Concentration Index` is a Herfindahl-Hirschman Index (HHI) for product balance concentration. Range: 0.33 (perfectly diversified) to 1.0 (single product).
- `Mora Balance Rate` = total arrears / total balance. Similar to `Arrears to Balance` in `_Portfolio Health`.
- `DPD Migration Rate` = % of accounts that were in any DPD bucket last month and are still in the snapshot this month (survived).

---

## Table 10: _Financial Recovery (4 measures)

Financial recovery efficiency and cost metrics.

| # | Measure | Formula | Format | Dependencies |
|---|---|---|---|---|
| 1 | `Recovery per RPC` | `DIVIDE([Total Recovery], [Total RPCs], 0)` | $#,##0.00 | Total Recovery, Total RPCs |
| 2 | `Cost per Cure` | `VAR _TotalCost = SUM('Fact_Agent_Time_Log'[total_cost]) RETURN DIVIDE(_TotalCost, [Total Cures], 0)` | $#,##0.00 | Fact_Agent_Time_Log, Total Cures |
| 3 | `Agent-Assisted Cure Rate` | `DIVIDE([Agent Cure Count], [Total Cures], 0)` | 0.0% | Agent Cure Count, Total Cures |
| 4 | `Collection Efficiency Ratio` | `DIVIDE([Total Recovery], [Portfolio Total Arrears], 0)` | 0.0% | Total Recovery, Portfolio Total Arrears |

**Notes:**
- `Recovery per RPC` = total recovery / total RPCs. Answers: "How much do we collect per live contact?"
- `Cost per Cure` = total agent labor cost / total cures. Answers: "What does it cost us to cure one account?"
- `Agent-Assisted Cure Rate` = agent cures / total cures. Complement of `Self-Cure Rate`.
- `Collection Efficiency Ratio` = total recovery / total arrears. Broader than `Collection Efficiency` (which uses RPC Arrears only).

---

## Table 11: _Vintage Analysis (2 measures)

Vintage (open_date) age and balance metrics.

| # | Measure | Formula | Format | Dependencies |
|---|---|---|---|---|
| 1 | `Vintage Age Months` | `DATEDIFF(MAX('Dim_Accounts'[open_date]), MAX('Fact_EOM_Snapshot'[snapshot_date]), MONTH)` | #,##0 | Fact_EOM_Snapshot |
| 2 | `Average Vintage Balance` | `AVERAGE('Fact_EOM_Snapshot'[balance])` | $#,##0 | Fact_EOM_Snapshot |

**Notes:**
- `Vintage Age Months` = months between account open date and current snapshot. Use with slicers to analyze by vintage bucket.
- `Average Vintage Balance` = average balance across accounts in the current filter context.

---

## Table 12: _Roll Rate Analysis (2 measures)

Roll rate trend and net migration metrics.

| # | Measure | Formula | Format | Dependencies |
|---|---|---|---|---|
| 1 | `Net Roll Rate` | `[Roll Rate Current to Delinquent] - [Roll Rate 30 to 60]` | 0.0% | Roll Rate Current to Delinquent, Roll Rate 30 to 60 |
| 2 | `Roll Rate Trend` | `VAR _CurrentMonth = MAX('Fact_EOM_Snapshot'[snapshot_date]) VAR _PriorMonth = EOMONTH(_CurrentMonth, -1) VAR _CurrentRoll = [Roll Rate Current to Delinquent] VAR _PriorRoll = CALCULATE([Roll Rate Current to Delinquent], FILTER(ALL('Fact_EOM_Snapshot'), 'Fact_EOM_Snapshot'[snapshot_date] = _PriorMonth)) RETURN _CurrentRoll - _PriorRoll` | +0.0%;-0.0% | Roll Rate Current to Delinquent, Fact_EOM_Snapshot |

**Notes:**
- `Net Roll Rate` = Current→Delinquent roll rate minus 30→60 roll rate. Positive = more new delinquencies than worsening.
- `Roll Rate Trend` = change in Current→Delinquent roll rate vs prior month. Positive = deterioration.

---

## Quick Reference

| KPI | Measure | Table | Format |
|---|---|---|---|
| **Contact Rate** | `[Connection Rate]` | _Outreach & Activity | 0.0% |
| **RPC%** | `[RPC Rate]` | _Outreach & Activity | 0.0% |
| **RPC per Hour** | `[RPC per Op Hr]` | _Outreach & Activity | #,##0.0 |
| **Avg AHT (RPC)** | `[Avg AHT RPC (sec)]` | _Outreach & Activity | #,##0 |
| **Utilization** | `[Avg Utilization %]` | _Outreach & Activity | 0.0% |
| **PTP%** | `[Promise Rate]` | _Promise & Conversion | 0.0% |
| **KP%** | `[KP Rate]` | _Promise & Conversion | 0.0% |
| **BB Conversion** | `[BB Conversion Rate]` | _Promise & Conversion | 0.0% |
| **Capped KP$** | `[Capped KP $]` | _Promise & Conversion | $#,##0 |
| **Total Cures** | `[Total Cures]` | _Recovery & Collection | #,##0 |
| **Cured Amount** | `[Cured Amount]` | _Recovery & Collection | $#,##0 |
| **Collection Efficiency** | `[Collection Efficiency]` | _Recovery & Collection | 0.0% |
| **Mora Rate** | `[Mora Rate]` | _Portfolio Health | 0.0% |
| **Total Arrears** | `[Portfolio Total Arrears]` | _Portfolio Health | $#,##0 |
| **DPD Distribution** | `[Accounts DPD *]` | _Portfolio Health | #,##0 |
| **Roll Rate** | `[Roll Rate *]` | _Portfolio Health | 0.0% |
| **MoM Changes** | `[* MoM Change]` | _Time Intelligence | +0.0%;-0.0% |
| **WoW Changes** | `[* WoW Change]` | _Time Intelligence | +0.0%;-0.0% |
| **DoD Changes** | `[* DoD Change]` | _Time Intelligence | +0.0%;-0.0% |
| **YoY Changes** | `[* YoY Change]` | _Time Intelligence | +0.0%;-0.0% |
| **OTC Changes** | `[* OTC Change]` | _Time Intelligence | +0.0%;-0.0% |
| **YTD** | `[* YTD]` | _Time Intelligence | varies |
| **Rolling 3M** | `[Rolling 3M KP Rate]` | _Time Intelligence | 0.0% |
| **Health Score** | `[Portfolio Health Score]` | _Executive | #,##0 |
| **At-Risk Balance** | `[Portfolio At-Risk Balance]` | _Executive | $#,##0 |
| **Quality Score** | `[Agent Quality Score]` | _Agent Performance | #,##0 |
| **Agent Tier** | `[Agent Performance Tier]` | _Agent Performance | Text |
| **Concentration** | `[Portfolio Concentration Index]` | _Portfolio Management | 0.000 |
| **Cost per Cure** | `[Cost per Cure]` | _Financial Recovery | $#,##0.00 |
| **Recovery per RPC** | `[Recovery per RPC]` | _Financial Recovery | $#,##0.00 |
| **Vintage Age** | `[Vintage Age Months]` | _Vintage Analysis | #,##0 |
| **Net Roll Rate** | `[Net Roll Rate]` | _Roll Rate Analysis | 0.0% |

---

## Power BI Model Notes

### 1. EOM Snapshot — Single Consolidated Table
Import `Fact_EOM_Snapshot` as **one consolidated table**, not3 separate month tables. The `MAX(snapshot_date)` pattern handles month selection automatically.

### 2. Calendar — Extended Range
`Dim_Calendar` must include September 2025 so `DATEADD(..., -1, MONTH)` resolves correctly for October. The generator creates this range automatically.

### 3. Cross-Filter Direction
All relationships should use **Single** direction (dim -> fact). No bidirectional cross-filtering needed.

### 4. Date Table Marking
Mark `Dim_Calendar` as the Date Table in Power BI Desktop. This is required for all time intelligence functions.

### 5. Format Strings
Apply format strings from the Format column in this dictionary to each measure in Power BI Desktop (Measure tools > Format string). Without explicit formats, DAX returns unformatted numbers.

---

## Changelog

### v2.2 (Current)
- Added 84 time intelligence measures: WoW (21), DoD (21), YoY (21), OTC (21) for all7 key metrics
- Added22 dashboard-specific measures across7 new tables: _Executive (3), _Agent Performance (5), _Dialer Performance (3), _Portfolio Management (3), _Financial Recovery (4), _Vintage Analysis (2), _Roll Rate Analysis (2)
- Updated `_Time Intelligence` from18 to120 measures
- Added5 MoM % measures (Promise Rate, KP Rate, ACW RPC, ACW Non-RPC, Capped KP, Cures/THT, Utilization)
- Total stock: 242 measures across13 measure tables
- Updated Quick Reference with all new dashboard measures

### v2.1
- Added `_Goals & Targets` measure table (29 measures: 7 goals, 7 gaps, 7 RAG status, 7 hex colors, 1 dynamic goal)
- Added `dax_targets_and_comparisons.md` — full documentation for all 120 new DAX measures
- 6 new MoM Prior/MoM Change measures added to `_Time Intelligence`
- Added 7 MoM %, 35 WoW, 7 DoD, 7 YoY, 7 OTC comparison measures
- 2 new calculated tables: `Dim_Targets` (7 goal definitions), `Color Reference` (RAG hex colors)
- Total stock: 87 v2 + 120 new = 207 measures

### v2.0
- Reorganized into5 measure tables by business flow
- Fixed `RPC Rate` denominator (connected calls, not total RPCs)
- Fixed `BB Conversion Rate` scale (0-1, not 0-10000)
- Fixed `Branch/ATM` string match (slash, not underscore)
- Added `Avg Total Handle Time RPC` (AHT + ACW combined)
- Added `Agent Cure Rate` measure
- Added `Accounts DPD Current` measure
- Added4 `Mora Rate by DPD` composition measures
- Added3 Roll Rate measures (Current->Delinquent, 30->60, 60->90)
- Added MoM changes for RPC Rate, BB Conversion
- Added `Total Cures YTD` measure
- Added format specifications for all measures
- Added dependencies column for every measure
- Removed duplicate `Calls Attempted` and `True Occupancy %`
- Removed 5 broken cross-table measures (Schedule Paid Full/Partial/Broken, Total Expected, Schedule Fulfillment Rate)

### v1.0 (Legacy)
- Original73 measures in3 tables
- Available as `collections_dax.csv` and `dax_measures_dictionary.md`
