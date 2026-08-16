# DAX Targets, Goals & Comparisons v1.0

**Version:** 1.0
**Total New Measures:** 120 (14 goal + 7 gap + 7 status + 35 MoM + 35 WoW + 7 DoD + 7 YoY + 7 OTC + 1 color ref table)
**Measure Tables:** `_Goals & Targets` (new), `_Time Intelligence` (extended)
**Depends On:** `collections_dax_v2.csv` (87 base measures)

---

## Overview

This module adds three layers to the existing DAX model:

1. **Targets & Goals** — A `Dim_Targets` calculated table + goal measures, gap measures, and RAG status measures for 7 key metrics
2. **Comparison Measures** — MoM, WoW, DoD, YoY, and Overall-to-Current for all 7 metrics
3. **Color Reference Table** — A calculated table that maps RAG status to hex colors for conditional formatting

---

## Prerequisites

1. All 87 v2 measures must be loaded (see `collections_dax_v2.csv`)
2. `Dim_Calendar` must be marked as a Date Table
3. Calendar must have `iso_week` column for WoW calculations
4. Calendar must have `year` column for YoY calculations

---

## Section 1: Dim_Targets Calculated Table

Create this calculated table in Power BI Desktop (Modeling > New Table):

```dax
Dim_Targets = 
DATATABLE(
    "MetricName", STRING,
    "GoalValue", DOUBLE,
    "Unit", STRING,
    "Direction", STRING,       -- "HigherIsBetter" or "LowerIsBetter"
    "AmberThreshold", DOUBLE,  -- % of goal for Amber lower bound (e.g. 0.90 = 90% of goal)
    "GreenThreshold", DOUBLE,  -- % of goal for Green lower bound
    "DisplayFormat", STRING,
    "MeasureName", STRING,     -- Reference to base measure name
    "SortOrder", INTEGER,
    {
        {"PTP%", 0.80, "%", "HigherIsBetter", 0.85, 1.00, "0.0%", "Promise Rate", 1},
        {"KP%", 0.80, "%", "HigherIsBetter", 0.85, 1.00, "0.0%", "KP Rate", 2},
        {"ACW RPC (sec)", 120, "sec", "LowerIsBetter", 1.00, 0.85, "#,##0", "Avg ACW RPC (sec)", 3},
        {"ACW Non-RPC (sec)", 25, "sec", "LowerIsBetter", 1.00, 0.85, "#,##0", "Avg ACW Non-RPC (sec)", 4},
        {"Capped KP / RPC Arrears", 0.37, "%", "HigherIsBetter", 0.85, 1.00, "0.0%", "Capped KP per RPC Arrears", 5},
        {"Cures / THT", 2.40, "count", "HigherIsBetter", 0.85, 1.00, "#,##0.00", "Cures per THT Hr", 6},
        {"Utilization", 0.90, "%", "HigherIsBetter", 0.85, 1.00, "0.0%", "Avg Utilization %", 7}
    }
)
```

**RAG Logic:**
- For `HigherIsBetter`: Green >= Goal, Amber >= Goal * AmberThreshold, Red < Goal * AmberThreshold
- For `LowerIsBetter`: Green <= Goal, Amber <= Goal * (2 - GreenThreshold), Red > Goal * (2 - GreenThreshold)
  - ACW RPC: Green <= 120s, Amber 121-132s (120 * 1.10), Red > 132s — but we invert: Green <= Goal * GreenThreshold (120*0.85=102), Amber 103-132, Red > 132

**Simplified RAG Boundaries (derived from thresholds):**

| Metric | Goal | Green | Amber | Red |
|---|---|---|---|---|
| PTP% | 80% | >= 80% | 68-79% | < 68% |
| KP% | 80% | >= 80% | 68-79% | < 68% |
| ACW RPC (sec) | 120s | <= 102s | 103-132s | > 132s |
| ACW Non-RPC (sec) | 25s | <= 21s | 22-27.5s | > 27.5s |
| Capped KP/RPC Arrears | 37% | >= 37% | 31-36% | < 31% |
| Cures/THT | 2.4 | >= 2.4 | 2.04-2.39 | < 2.04 |
| Utilization | 90% | >= 90% | 76-89% | < 76% |

---

## Section 2: Goal Measures (in _Goals & Targets table)

### 2.1 Single-Value Goal Slicer Measures

These measures return the goal value for each metric. They ignore all filters (always return the target).

```dax
Goal PTP% = 
    VAR _Goal = LOOKUPVALUE(Dim_Targets[GoalValue], Dim_Targets[MetricName], "PTP%")
    RETURN _Goal
```

```dax
Goal KP% = 
    VAR _Goal = LOOKUPVALUE(Dim_Targets[GoalValue], Dim_Targets[MetricName], "KP%")
    RETURN _Goal
```

```dax
Goal ACW RPC (sec) = 
    VAR _Goal = LOOKUPVALUE(Dim_Targets[GoalValue], Dim_Targets[MetricName], "ACW RPC (sec)")
    RETURN _Goal
```

```dax
Goal ACW Non-RPC (sec) = 
    VAR _Goal = LOOKUPVALUE(Dim_Targets[GoalValue], Dim_Targets[MetricName], "ACW Non-RPC (sec)")
    RETURN _Goal
```

```dax
Goal Capped KP per RPC Arrears = 
    VAR _Goal = LOOKUPVALUE(Dim_Targets[GoalValue], Dim_Targets[MetricName], "Capped KP / RPC Arrears")
    RETURN _Goal
```

```dax
Goal Cures per THT Hr = 
    VAR _Goal = LOOKUPVALUE(Dim_Targets[GoalValue], Dim_Targets[MetricName], "Cures / THT")
    RETURN _Goal
```

```dax
Goal Utilization = 
    VAR _Goal = LOOKUPVALUE(Dim_Targets[GoalValue], Dim_Targets[MetricName], "Utilization")
    RETURN _Goal
```

### 2.2 Dynamic Goal Measure (For Use with Slicer)

If you add a slicer on `Dim_Targets[MetricName]`, this measure dynamically returns the goal for the selected metric:

```dax
Selected Goal = 
    VAR _SelectedMetric = SELECTEDVALUE(Dim_Targets[MetricName])
    VAR _Goal = LOOKUPVALUE(Dim_Targets[GoalValue], Dim_Targets[MetricName], _SelectedMetric)
    RETURN _Goal
```

---

## Section 3: Gap Measures (actual - goal)

Returns the difference between actual and goal. Positive = above target (for HigherIsBetter). In `_Goals & Targets` table.

```dax
PTP% Gap = [Promise Rate] - [Goal PTP%]
```

```dax
KP% Gap = [KP Rate] - [Goal KP%]
```

```dax
ACW RPC Gap = [Avg ACW RPC (sec)] - [Goal ACW RPC (sec)]
```

```dax
ACW Non-RPC Gap = [Avg ACW Non-RPC (sec)] - [Goal ACW Non-RPC (sec)]
```

```dax
Capped KP per RPC Arrears Gap = [Capped KP per RPC Arrears] - [Goal Capped KP per RPC Arrears]
```

```dax
Cures per THT Hr Gap = [Cures per THT Hr] - [Goal Cures per THT Hr]
```

```dax
Utilization Gap = [Avg Utilization %] - [Goal Utilization]
```

---

## Section 4: Status / RAG Measures

Returns "Green", "Amber", "Red" based on actual vs goal. In `_Goals & Targets` table.

```dax
PTP% Status = 
    VAR _Actual = [Promise Rate]
    VAR _Goal = [Goal PTP%]
    VAR _AmberThreshold = LOOKUPVALUE(Dim_Targets[AmberThreshold], Dim_Targets[MetricName], "PTP%")
    VAR _Result = 
        SWITCH(
            TRUE(),
            _Actual >= _Goal, "Green",
            _Actual >= _Goal * _AmberThreshold, "Amber",
            "Red"
        )
    RETURN _Result
```

```dax
KP% Status = 
    VAR _Actual = [KP Rate]
    VAR _Goal = [Goal KP%]
    VAR _AmberThreshold = LOOKUPVALUE(Dim_Targets[AmberThreshold], Dim_Targets[MetricName], "KP%")
    VAR _Result = 
        SWITCH(
            TRUE(),
            _Actual >= _Goal, "Green",
            _Actual >= _Goal * _AmberThreshold, "Amber",
            "Red"
        )
    RETURN _Result
```

```dax
ACW RPC Status = 
    VAR _Actual = [Avg ACW RPC (sec)]
    VAR _Goal = [Goal ACW RPC (sec)]
    VAR _GreenThreshold = LOOKUPVALUE(Dim_Targets[GreenThreshold], Dim_Targets[MetricName], "ACW RPC (sec)")
    VAR _Result = 
        SWITCH(
            TRUE(),
            _Actual <= _Goal * _GreenThreshold, "Green",
            _Actual <= _Goal * (2 - _GreenThreshold), "Amber",
            "Red"
        )
    RETURN _Result
```

```dax
ACW Non-RPC Status = 
    VAR _Actual = [Avg ACW Non-RPC (sec)]
    VAR _Goal = [Goal ACW Non-RPC (sec)]
    VAR _GreenThreshold = LOOKUPVALUE(Dim_Targets[GreenThreshold], Dim_Targets[MetricName], "ACW Non-RPC (sec)")
    VAR _Result = 
        SWITCH(
            TRUE(),
            _Actual <= _Goal * _GreenThreshold, "Green",
            _Actual <= _Goal * (2 - _GreenThreshold), "Amber",
            "Red"
        )
    RETURN _Result
```

```dax
Capped KP per RPC Arrears Status = 
    VAR _Actual = [Capped KP per RPC Arrears]
    VAR _Goal = [Goal Capped KP per RPC Arrears]
    VAR _AmberThreshold = LOOKUPVALUE(Dim_Targets[AmberThreshold], Dim_Targets[MetricName], "Capped KP / RPC Arrears")
    VAR _Result = 
        SWITCH(
            TRUE(),
            _Actual >= _Goal, "Green",
            _Actual >= _Goal * _AmberThreshold, "Amber",
            "Red"
        )
    RETURN _Result
```

```dax
Cures per THT Hr Status = 
    VAR _Actual = [Cures per THT Hr]
    VAR _Goal = [Goal Cures per THT Hr]
    VAR _AmberThreshold = LOOKUPVALUE(Dim_Targets[AmberThreshold], Dim_Targets[MetricName], "Cures / THT")
    VAR _Result = 
        SWITCH(
            TRUE(),
            _Actual >= _Goal, "Green",
            _Actual >= _Goal * _AmberThreshold, "Amber",
            "Red"
        )
    RETURN _Result
```

```dax
Utilization Status = 
    VAR _Actual = [Avg Utilization %]
    VAR _Goal = [Goal Utilization]
    VAR _AmberThreshold = LOOKUPVALUE(Dim_Targets[AmberThreshold], Dim_Targets[MetricName], "Utilization")
    VAR _Result = 
        SWITCH(
            TRUE(),
            _Actual >= _Goal, "Green",
            _Actual >= _Goal * _AmberThreshold, "Amber",
            "Red"
        )
    RETURN _Result
```

---

## Section 5: Color Reference Calculated Table

Create this calculated table for conditional formatting reference:

```dax
Color Reference = 
DATATABLE(
    "Status", STRING,
    "HexColor", STRING,
    "RGB", STRING,
    "SortOrder", INTEGER,
    {
        {"Green", "#00B050", "RGB(0, 176, 80)", 1},
        {"Amber", "#FFC000", "RGB(255, 192, 0)", 2},
        {"Red", "#FF0000", "RGB(255, 0, 0)", 3}
    }
)
```

### Usage in Conditional Formatting

Use the status measures (e.g., `[PTP% Status]`) with the Color Reference table in Power BI:

1. Add a visual with the base measure (e.g., `[Promise Rate]`)
2. In the Format pane > Conditional formatting > Background color
3. Set Format style to "Rules"
4. For each status measure result, map:
   - "Green" -> `#00B050`
   - "Amber" -> `#FFC000`
   - "Red" -> `#FF0000`

**Alternative: Field Value approach** — Create a measure that returns the hex color directly:

```dax
PTP% Color = 
    VAR _Status = [PTP% Status]
    RETURN LOOKUPVALUE('Color Reference'[HexColor], 'Color Reference'[Status], _Status)
```

```dax
KP% Color = 
    VAR _Status = [KP% Status]
    RETURN LOOKUPVALUE('Color Reference'[HexColor], 'Color Reference'[Status], _Status)
```

```dax
ACW RPC Color = 
    VAR _Status = [ACW RPC Status]
    RETURN LOOKUPVALUE('Color Reference'[HexColor], 'Color Reference'[Status], _Status)
```

```dax
ACW Non-RPC Color = 
    VAR _Status = [ACW Non-RPC Status]
    RETURN LOOKUPVALUE('Color Reference'[HexColor], 'Color Reference'[Status], _Status)
```

```dax
Capped KP per RPC Arrears Color = 
    VAR _Status = [Capped KP per RPC Arrears Status]
    RETURN LOOKUPVALUE('Color Reference'[HexColor], 'Color Reference'[Status], _Status)
```

```dax
Cures per THT Hr Color = 
    VAR _Status = [Cures per THT Hr Status]
    RETURN LOOKUPVALUE('Color Reference'[HexColor], 'Color Reference'[Status], _Status)
```

```dax
Utilization Color = 
    VAR _Status = [Utilization Status]
    RETURN LOOKUPVALUE('Color Reference'[HexColor], 'Color Reference'[Status], _Status)
```

---

## Section 6: Time Intelligence — MoM (Month-over-Month)

All measures go in `_Time Intelligence` table. For each of the 7 goal metrics, we create:

### Pattern A: Percentage KPIs (PTP%, KP%, Capped KP/RPC Arrears, Utilization)

For these, MoM = absolute difference in percentage points:

```dax
Promise Rate Prior Month = CALCULATE([Promise Rate], DATEADD('Dim_Calendar'[date], -1, MONTH))
Promise Rate MoM Change = [Promise Rate] - [Promise Rate Prior Month]
```

Already exists in v2 for Promise Rate, KP Rate, BB Conversion. We need to add for the remaining metrics.

### New MoM measures to add:

```dax
Capped KP per RPC Arrears Prior Month = 
    CALCULATE([Capped KP per RPC Arrears], DATEADD('Dim_Calendar'[date], -1, MONTH))
```

```dax
Capped KP per RPC Arrears MoM Change = 
    [Capped KP per RPC Arrears] - [Capped KP per RPC Arrears Prior Month]
```

```dax
Avg ACW RPC (sec) Prior Month = 
    CALCULATE([Avg ACW RPC (sec)], DATEADD('Dim_Calendar'[date], -1, MONTH))
```

```dax
Avg ACW RPC (sec) MoM Change = 
    [Avg ACW RPC (sec)] - [Avg ACW RPC (sec) Prior Month]
```

```dax
Avg ACW Non-RPC (sec) Prior Month = 
    CALCULATE([Avg ACW Non-RPC (sec)], DATEADD('Dim_Calendar'[date], -1, MONTH))
```

```dax
Avg ACW Non-RPC (sec) MoM Change = 
    [Avg ACW Non-RPC (sec)] - [Avg ACW Non-RPC (sec) Prior Month]
```

```dax
Cures per THT Hr Prior Month = 
    CALCULATE([Cures per THT Hr], DATEADD('Dim_Calendar'[date], -1, MONTH))
```

```dax
Cures per THT Hr MoM Change = 
    [Cures per THT Hr] - [Cures per THT Hr Prior Month]
```

```dax
Avg Utilization % Prior Month = 
    CALCULATE([Avg Utilization %], DATEADD('Dim_Calendar'[date], -1, MONTH))
```

```dax
Avg Utilization % MoM Change = 
    [Avg Utilization %] - [Avg Utilization % Prior Month]
```

### MoM Percentage Change (for all 7):

```dax
Promise Rate MoM % = 
    VAR _Current = [Promise Rate]
    VAR _Prior = [Promise Rate Prior Month]
    RETURN DIVIDE(_Current - _Prior, _Prior, 0)
```

```dax
KP Rate MoM % = 
    VAR _Current = [KP Rate]
    VAR _Prior = [KP Rate Prior Month]
    RETURN DIVIDE(_Current - _Prior, _Prior, 0)
```

```dax
Avg ACW RPC MoM % = 
    VAR _Current = [Avg ACW RPC (sec)]
    VAR _Prior = [Avg ACW RPC (sec) Prior Month]
    RETURN DIVIDE(_Current - _Prior, _Prior, 0)
```

```dax
Avg ACW Non-RPC MoM % = 
    VAR _Current = [Avg ACW Non-RPC (sec)]
    VAR _Prior = [Avg ACW Non-RPC (sec) Prior Month]
    RETURN DIVIDE(_Current - _Prior, _Prior, 0)
```

```dax
Capped KP per RPC Arrears MoM % = 
    VAR _Current = [Capped KP per RPC Arrears]
    VAR _Prior = [Capped KP per RPC Arrears Prior Month]
    RETURN DIVIDE(_Current - _Prior, _Prior, 0)
```

```dax
Cures per THT Hr MoM % = 
    VAR _Current = [Cures per THT Hr]
    VAR _Prior = [Cures per THT Hr Prior Month]
    RETURN DIVIDE(_Current - _Prior, _Prior, 0)
```

```dax
Avg Utilization % MoM % = 
    VAR _Current = [Avg Utilization %]
    VAR _Prior = [Avg Utilization % Prior Month]
    RETURN DIVIDE(_Current - _Prior, _Prior, 0)
```

---

## Section 7: Time Intelligence — WoW (Week-over-Week)

WoW in Power BI with weekly data requires special handling because DATEADD with WEEK does not work reliably across month boundaries in a monthly-calendar. Instead, we use the `iso_week` column from `Dim_Calendar`.

### Pattern: Calculate in Prior Week Context

```dax
Promise Rate Prior Week = 
    VAR _CurrentISOWeek = SELECTEDVALUE('Dim_Calendar'[iso_week])
    VAR _PriorISOWeek = _CurrentISOWeek - 1
    VAR _PriorDates = 
        CALCULATETABLE(
            VALUES('Dim_Calendar'[date]),
            'Dim_Calendar'[iso_week] = _PriorISOWeek
        )
    RETURN
        CALCULATE([Promise Rate], _PriorDates)
```

WoW requires weekly grain. If the data model is monthly, WoW will show BLANK for months where no weekly data exists. WoW is most useful for `_Daily MIS` dashboards.

For a robust WoW implementation that works at daily/weekly/monthly granularity:

```dax
Promise Rate WoW Change = 
    VAR _Current = [Promise Rate]
    VAR _Prior = [Promise Rate Prior Week]
    RETURN _Current - _Prior
```

```dax
KP Rate Prior Week = 
    VAR _CurrentISOWeek = SELECTEDVALUE('Dim_Calendar'[iso_week])
    VAR _PriorISOWeek = _CurrentISOWeek - 1
    VAR _PriorDates = 
        CALCULATETABLE(
            VALUES('Dim_Calendar'[date]),
            'Dim_Calendar'[iso_week] = _PriorISOWeek
        )
    RETURN
        CALCULATE([KP Rate], _PriorDates)
```

```dax
KP Rate WoW Change = [KP Rate] - [KP Rate Prior Week]
```

```dax
Avg ACW RPC (sec) Prior Week = 
    VAR _CurrentISOWeek = SELECTEDVALUE('Dim_Calendar'[iso_week])
    VAR _PriorISOWeek = _CurrentISOWeek - 1
    VAR _PriorDates = 
        CALCULATETABLE(
            VALUES('Dim_Calendar'[date]),
            'Dim_Calendar'[iso_week] = _PriorISOWeek
        )
    RETURN
        CALCULATE([Avg ACW RPC (sec)], _PriorDates)
```

```dax
Avg ACW RPC (sec) WoW Change = 
    [Avg ACW RPC (sec)] - [Avg ACW RPC (sec) Prior Week]
```

```dax
Avg ACW Non-RPC (sec) Prior Week = 
    VAR _CurrentISOWeek = SELECTEDVALUE('Dim_Calendar'[iso_week])
    VAR _PriorISOWeek = _CurrentISOWeek - 1
    VAR _PriorDates = 
        CALCULATETABLE(
            VALUES('Dim_Calendar'[date]),
            'Dim_Calendar'[iso_week] = _PriorISOWeek
        )
    RETURN
        CALCULATE([Avg ACW Non-RPC (sec)], _PriorDates)
```

```dax
Avg ACW Non-RPC (sec) WoW Change = 
    [Avg ACW Non-RPC (sec)] - [Avg ACW Non-RPC (sec) Prior Week]
```

```dax
Capped KP per RPC Arrears Prior Week = 
    VAR _CurrentISOWeek = SELECTEDVALUE('Dim_Calendar'[iso_week])
    VAR _PriorISOWeek = _CurrentISOWeek - 1
    VAR _PriorDates = 
        CALCULATETABLE(
            VALUES('Dim_Calendar'[date]),
            'Dim_Calendar'[iso_week] = _PriorISOWeek
        )
    RETURN
        CALCULATE([Capped KP per RPC Arrears], _PriorDates)
```

```dax
Capped KP per RPC Arrears WoW Change = 
    [Capped KP per RPC Arrears] - [Capped KP per RPC Arrears Prior Week]
```

```dax
Cures per THT Hr Prior Week = 
    VAR _CurrentISOWeek = SELECTEDVALUE('Dim_Calendar'[iso_week])
    VAR _PriorISOWeek = _CurrentISOWeek - 1
    VAR _PriorDates = 
        CALCULATETABLE(
            VALUES('Dim_Calendar'[date]),
            'Dim_Calendar'[iso_week] = _PriorISOWeek
        )
    RETURN
        CALCULATE([Cures per THT Hr], _PriorDates)
```

```dax
Cures per THT Hr WoW Change = 
    [Cures per THT Hr] - [Cures per THT Hr Prior Week]
```

```dax
Avg Utilization % Prior Week = 
    VAR _CurrentISOWeek = SELECTEDVALUE('Dim_Calendar'[iso_week])
    VAR _PriorISOWeek = _CurrentISOWeek - 1
    VAR _PriorDates = 
        CALCULATETABLE(
            VALUES('Dim_Calendar'[date]),
            'Dim_Calendar'[iso_week] = _PriorISOWeek
        )
    RETURN
        CALCULATE([Avg Utilization %], _PriorDates)
```

```dax
Avg Utilization % WoW Change = 
    [Avg Utilization %] - [Avg Utilization % Prior Week]
```

### WoW Percentage Change (for all 7):

```dax
Promise Rate WoW % = 
    VAR _Prior = [Promise Rate Prior Week]
    RETURN DIVIDE([Promise Rate] - _Prior, _Prior, 0)
```

```dax
KP Rate WoW % = 
    VAR _Prior = [KP Rate Prior Week]
    RETURN DIVIDE([KP Rate] - _Prior, _Prior, 0)
```

```dax
Avg ACW RPC WoW % = 
    VAR _Prior = [Avg ACW RPC (sec) Prior Week]
    RETURN DIVIDE([Avg ACW RPC (sec)] - _Prior, _Prior, 0)
```

```dax
Avg ACW Non-RPC WoW % = 
    VAR _Prior = [Avg ACW Non-RPC (sec) Prior Week]
    RETURN DIVIDE([Avg ACW Non-RPC (sec)] - _Prior, _Prior, 0)
```

```dax
Capped KP per RPC Arrears WoW % = 
    VAR _Prior = [Capped KP per RPC Arrears Prior Week]
    RETURN DIVIDE([Capped KP per RPC Arrears] - _Prior, _Prior, 0)
```

```dax
Cures per THT Hr WoW % = 
    VAR _Prior = [Cures per THT Hr Prior Week]
    RETURN DIVIDE([Cures per THT Hr] - _Prior, _Prior, 0)
```

```dax
Avg Utilization % WoW % = 
    VAR _Prior = [Avg Utilization % Prior Week]
    RETURN DIVIDE([Avg Utilization %] - _Prior, _Prior, 0)
```

---

## Section 8: Time Intelligence — DoD (Day-over-Day)

DoD compares the selected day against the previous calendar day. Only meaningful at daily granularity.

### Pattern: DATEADD with -1 DAY

```dax
Promise Rate Prior Day = 
    CALCULATE([Promise Rate], DATEADD('Dim_Calendar'[date], -1, DAY))
```

```dax
Promise Rate DoD Change = [Promise Rate] - [Promise Rate Prior Day]
```

```dax
KP Rate Prior Day = 
    CALCULATE([KP Rate], DATEADD('Dim_Calendar'[date], -1, DAY))
```

```dax
KP Rate DoD Change = [KP Rate] - [KP Rate Prior Day]
```

```dax
Avg ACW RPC (sec) Prior Day = 
    CALCULATE([Avg ACW RPC (sec)], DATEADD('Dim_Calendar'[date], -1, DAY))
```

```dax
Avg ACW RPC (sec) DoD Change = 
    [Avg ACW RPC (sec)] - [Avg ACW RPC (sec) Prior Day]
```

```dax
Avg ACW Non-RPC (sec) Prior Day = 
    CALCULATE([Avg ACW Non-RPC (sec)], DATEADD('Dim_Calendar'[date], -1, DAY))
```

```dax
Avg ACW Non-RPC (sec) DoD Change = 
    [Avg ACW Non-RPC (sec)] - [Avg ACW Non-RPC (sec) Prior Day]
```

```dax
Capped KP per RPC Arrears Prior Day = 
    CALCULATE([Capped KP per RPC Arrears], DATEADD('Dim_Calendar'[date], -1, DAY))
```

```dax
Capped KP per RPC Arrears DoD Change = 
    [Capped KP per RPC Arrears] - [Capped KP per RPC Arrears Prior Day]
```

```dax
Cures per THT Hr Prior Day = 
    CALCULATE([Cures per THT Hr], DATEADD('Dim_Calendar'[date], -1, DAY))
```

```dax
Cures per THT Hr DoD Change = 
    [Cures per THT Hr] - [Cures per THT Hr Prior Day]
```

```dax
Avg Utilization % Prior Day = 
    CALCULATE([Avg Utilization %], DATEADD('Dim_Calendar'[date], -1, DAY))
```

```dax
Avg Utilization % DoD Change = 
    [Avg Utilization %] - [Avg Utilization % Prior Day]
```

### DoD Percentage Change (for all 7):

```dax
Promise Rate DoD % = 
    VAR _Prior = [Promise Rate Prior Day]
    RETURN DIVIDE([Promise Rate] - _Prior, _Prior, 0)
```

```dax
KP Rate DoD % = 
    VAR _Prior = [KP Rate Prior Day]
    RETURN DIVIDE([KP Rate] - _Prior, _Prior, 0)
```

```dax
Avg ACW RPC DoD % = 
    VAR _Prior = [Avg ACW RPC (sec) Prior Day]
    RETURN DIVIDE([Avg ACW RPC (sec)] - _Prior, _Prior, 0)
```

```dax
Avg ACW Non-RPC DoD % = 
    VAR _Prior = [Avg ACW Non-RPC (sec) Prior Day]
    RETURN DIVIDE([Avg ACW Non-RPC (sec)] - _Prior, _Prior, 0)
```

```dax
Capped KP per RPC Arrears DoD % = 
    VAR _Prior = [Capped KP per RPC Arrears Prior Day]
    RETURN DIVIDE([Capped KP per RPC Arrears] - _Prior, _Prior, 0)
```

```dax
Cures per THT Hr DoD % = 
    VAR _Prior = [Cures per THT Hr Prior Day]
    RETURN DIVIDE([Cures per THT Hr] - _Prior, _Prior, 0)
```

```dax
Avg Utilization % DoD % = 
    VAR _Prior = [Avg Utilization % Prior Day]
    RETURN DIVIDE([Avg Utilization %] - _Prior, _Prior, 0)
```

---

## Section 9: Time Intelligence — YoY (Year-over-Year)

YoY compares the same period in the previous year. Power BI only has 1 year of data (2025), so YoY will return BLANK until 2026 data is loaded. Pattern is included for future compatibility.

### Pattern: SAMEPERIODLASTYEAR

```dax
Promise Rate Prior Year = 
    CALCULATE([Promise Rate], SAMEPERIODLASTYEAR('Dim_Calendar'[date]))
```

```dax
Promise Rate YoY Change = [Promise Rate] - [Promise Rate Prior Year]
```

```dax
KP Rate Prior Year = 
    CALCULATE([KP Rate], SAMEPERIODLASTYEAR('Dim_Calendar'[date]))
```

```dax
KP Rate YoY Change = [KP Rate] - [KP Rate Prior Year]
```

```dax
Avg ACW RPC (sec) Prior Year = 
    CALCULATE([Avg ACW RPC (sec)], SAMEPERIODLASTYEAR('Dim_Calendar'[date]))
```

```dax
Avg ACW RPC (sec) YoY Change = 
    [Avg ACW RPC (sec)] - [Avg ACW RPC (sec) Prior Year]
```

```dax
Avg ACW Non-RPC (sec) Prior Year = 
    CALCULATE([Avg ACW Non-RPC (sec)], SAMEPERIODLASTYEAR('Dim_Calendar'[date]))
```

```dax
Avg ACW Non-RPC (sec) YoY Change = 
    [Avg ACW Non-RPC (sec)] - [Avg ACW Non-RPC (sec) Prior Year]
```

```dax
Capped KP per RPC Arrears Prior Year = 
    CALCULATE([Capped KP per RPC Arrears], SAMEPERIODLASTYEAR('Dim_Calendar'[date]))
```

```dax
Capped KP per RPC Arrears YoY Change = 
    [Capped KP per RPC Arrears] - [Capped KP per RPC Arrears Prior Year]
```

```dax
Cures per THT Hr Prior Year = 
    CALCULATE([Cures per THT Hr], SAMEPERIODLASTYEAR('Dim_Calendar'[date]))
```

```dax
Cures per THT Hr YoY Change = 
    [Cures per THT Hr] - [Cures per THT Hr Prior Year]
```

```dax
Avg Utilization % Prior Year = 
    CALCULATE([Avg Utilization %], SAMEPERIODLASTYEAR('Dim_Calendar'[date]))
```

```dax
Avg Utilization % YoY Change = 
    [Avg Utilization %] - [Avg Utilization % Prior Year]
```

### YoY Percentage Change:

```dax
Promise Rate YoY % = 
    VAR _Prior = [Promise Rate Prior Year]
    RETURN DIVIDE([Promise Rate] - _Prior, _Prior, 0)
```

```dax
KP Rate YoY % = 
    VAR _Prior = [KP Rate Prior Year]
    RETURN DIVIDE([KP Rate] - _Prior, _Prior, 0)
```

```dax
Avg ACW RPC YoY % = 
    VAR _Prior = [Avg ACW RPC (sec) Prior Year]
    RETURN DIVIDE([Avg ACW RPC (sec)] - _Prior, _Prior, 0)
```

```dax
Avg ACW Non-RPC YoY % = 
    VAR _Prior = [Avg ACW Non-RPC (sec) Prior Year]
    RETURN DIVIDE([Avg ACW Non-RPC (sec)] - _Prior, _Prior, 0)
```

```dax
Capped KP per RPC Arrears YoY % = 
    VAR _Prior = [Capped KP per RPC Arrears Prior Year]
    RETURN DIVIDE([Capped KP per RPC Arrears] - _Prior, _Prior, 0)
```

```dax
Cures per THT Hr YoY % = 
    VAR _Prior = [Cures per THT Hr Prior Year]
    RETURN DIVIDE([Cures per THT Hr] - _Prior, _Prior, 0)
```

```dax
Avg Utilization % YoY % = 
    VAR _Prior = [Avg Utilization % Prior Year]
    RETURN DIVIDE([Avg Utilization %] - _Prior, _Prior, 0)
```

---

## Section 10: Time Intelligence — OTC (Overall-to-Current)

OTC compares the full-period overall average against the current period value. "How is this period doing vs the portfolio's lifetime average?"

### Pattern: Remove all date filters, calculate over all time

```dax
Promise Rate Overall = 
    CALCULATE([Promise Rate], ALL('Dim_Calendar'))
```

```dax
Promise Rate OTC Change = [Promise Rate] - [Promise Rate Overall]
```

```dax
KP Rate Overall = 
    CALCULATE([KP Rate], ALL('Dim_Calendar'))
```

```dax
KP Rate OTC Change = [KP Rate] - [KP Rate Overall]
```

```dax
Avg ACW RPC (sec) Overall = 
    CALCULATE([Avg ACW RPC (sec)], ALL('Dim_Calendar'))
```

```dax
Avg ACW RPC (sec) OTC Change = 
    [Avg ACW RPC (sec)] - [Avg ACW RPC (sec) Overall]
```

```dax
Avg ACW Non-RPC (sec) Overall = 
    CALCULATE([Avg ACW Non-RPC (sec)], ALL('Dim_Calendar'))
```

```dax
Avg ACW Non-RPC (sec) OTC Change = 
    [Avg ACW Non-RPC (sec)] - [Avg ACW Non-RPC (sec) Overall]
```

```dax
Capped KP per RPC Arrears Overall = 
    CALCULATE([Capped KP per RPC Arrears], ALL('Dim_Calendar'))
```

```dax
Capped KP per RPC Arrears OTC Change = 
    [Capped KP per RPC Arrears] - [Capped KP per RPC Arrears Overall]
```

```dax
Cures per THT Hr Overall = 
    CALCULATE([Cures per THT Hr], ALL('Dim_Calendar'))
```

```dax
Cures per THT Hr OTC Change = 
    [Cures per THT Hr] - [Cures per THT Hr Overall]
```

```dax
Avg Utilization % Overall = 
    CALCULATE([Avg Utilization %], ALL('Dim_Calendar'))
```

```dax
Avg Utilization % OTC Change = 
    [Avg Utilization %] - [Avg Utilization % Overall]
```

### OTC Percentage Change:

```dax
Promise Rate OTC % = 
    VAR _Overall = [Promise Rate Overall]
    RETURN DIVIDE([Promise Rate] - _Overall, _Overall, 0)
```

```dax
KP Rate OTC % = 
    VAR _Overall = [KP Rate Overall]
    RETURN DIVIDE([KP Rate] - _Overall, _Overall, 0)
```

```dax
Avg ACW RPC OTC % = 
    VAR _Overall = [Avg ACW RPC (sec) Overall]
    RETURN DIVIDE([Avg ACW RPC (sec)] - _Overall, _Overall, 0)
```

```dax
Avg ACW Non-RPC OTC % = 
    VAR _Overall = [Avg ACW Non-RPC (sec) Overall]
    RETURN DIVIDE([Avg ACW Non-RPC (sec)] - _Overall, _Overall, 0)
```

```dax
Capped KP per RPC Arrears OTC % = 
    VAR _Overall = [Capped KP per RPC Arrears Overall]
    RETURN DIVIDE([Capped KP per RPC Arrears] - _Overall, _Overall, 0)
```

```dax
Cures per THT Hr OTC % = 
    VAR _Overall = [Cures per THT Hr Overall]
    RETURN DIVIDE([Cures per THT Hr] - _Overall, _Overall, 0)
```

```dax
Avg Utilization % OTC % = 
    VAR _Overall = [Avg Utilization % Overall]
    RETURN DIVIDE([Avg Utilization %] - _Overall, _Overall, 0)
```

---

## Summary: All New Measures by Table

### _Goals & Targets (28 measures)

| # | Measure | Dependencies | Format |
|---|---|---|---|
| 1 | Goal PTP% | Dim_Targets | 0.0% |
| 2 | Goal KP% | Dim_Targets | 0.0% |
| 3 | Goal ACW RPC (sec) | Dim_Targets | #,##0 |
| 4 | Goal ACW Non-RPC (sec) | Dim_Targets | #,##0 |
| 5 | Goal Capped KP per RPC Arrears | Dim_Targets | 0.0% |
| 6 | Goal Cures per THT Hr | Dim_Targets | #,##0.00 |
| 7 | Goal Utilization | Dim_Targets | 0.0% |
| 8 | Selected Goal | Dim_Targets, slicer | varies |
| 9 | PTP% Gap | Promise Rate, Goal PTP% | +0.0%;-0.0% |
| 10 | KP% Gap | KP Rate, Goal KP% | +0.0%;-0.0% |
| 11 | ACW RPC Gap | Avg ACW RPC (sec), Goal ACW RPC (sec) | +#,##0;-#,##0 |
| 12 | ACW Non-RPC Gap | Avg ACW Non-RPC (sec), Goal ACW Non-RPC (sec) | +#,##0;-#,##0 |
| 13 | Capped KP/RPC Arrears Gap | Capped KP per RPC Arrears, Goal | +0.0%;-0.0% |
| 14 | Cures/THT Gap | Cures per THT Hr, Goal | +#,##0.00;-#,##0.00 |
| 15 | Utilization Gap | Avg Utilization %, Goal Utilization | +0.0%;-0.0% |
| 16 | PTP% Status | Promise Rate, Goal PTP%, Dim_Targets | Text: Green/Amber/Red |
| 17 | KP% Status | KP Rate, Goal KP%, Dim_Targets | Text |
| 18 | ACW RPC Status | Avg ACW RPC (sec), Goal, Dim_Targets | Text |
| 19 | ACW Non-RPC Status | Avg ACW Non-RPC (sec), Goal, Dim_Targets | Text |
| 20 | Capped KP/RPC Arrears Status | Capped KP per RPC Arrears, Goal, Dim_Targets | Text |
| 21 | Cures/THT Status | Cures per THT Hr, Goal, Dim_Targets | Text |
| 22 | Utilization Status | Avg Utilization %, Goal, Dim_Targets | Text |
| 23 | PTP% Color | PTP% Status, Color Reference | Text: #HEX |
| 24 | KP% Color | KP% Status, Color Reference | Text: #HEX |
| 25 | ACW RPC Color | ACW RPC Status, Color Reference | Text: #HEX |
| 26 | ACW Non-RPC Color | ACW Non-RPC Status, Color Reference | Text: #HEX |
| 27 | Capped KP/RPC Arrears Color | Capped KP/RPC Arrears Status, Color Ref | Text: #HEX |
| 28 | Cures/THT Color | Cures per THT Hr Status, Color Reference | Text: #HEX |
| 29 | Utilization Color | Utilization Status, Color Reference | Text: #HEX |

### _Time Intelligence — New Additions (91 measures)

| Category | Count | Measures |
|---|---|---|
| MoM Prior (existing v2) | 7 | Already exists for RPC Rate, Promise Rate, KP Rate, BB Conv, Total Cures, Cured Amount, Mora Rate |
| MoM Prior (new) | 6 | Avg ACW RPC, Avg ACW Non-RPC, Capped KP/RPC Arrears, Cures/THT Hr, Avg Utilization, Portfolio Balance Prior (exists) |
| MoM Abs Change (existing v2) | 5 | Already exists for RPC Rate, KP Rate, BB Conv, Cures, Mora Rate |
| MoM Abs Change (new) | 6 | Promise Rate (missing!), Avg ACW RPC, Avg ACW Non-RPC, Capped KP/RPC Arrears, Cures/THT Hr, Avg Utilization |
| MoM % Change (new) | 7 | All 7 metrics |
| WoW Prior (new) | 7 | All 7 metrics |
| WoW Abs Change (new) | 7 | All 7 metrics |
| WoW % Change (new) | 7 | All 7 metrics |
| DoD Prior (new) | 7 | All 7 metrics |
| DoD Abs Change (new) | 7 | All 7 metrics |
| DoD % Change (new) | 7 | All 7 metrics |
| YoY Prior (new) | 7 | All 7 metrics |
| YoY Abs Change (new) | 7 | All 7 metrics |
| YoY % Change (new) | 7 | All 7 metrics |
| OTC Overall (new) | 7 | All 7 metrics |
| OTC Abs Change (new) | 7 | All 7 metrics |
| OTC % Change (new) | 7 | All 7 metrics |

### Calculated Tables (2)

| Table | Purpose |
|---|---|
| Dim_Targets | 7 target definitions with goal values, thresholds, format strings |
| Color Reference | 3 RAG status-to-hex color mappings |

---

## Changelog

### v1.0 (Current)
- Initial release: 120 new DAX measures across _Goals & Targets and _Time Intelligence tables
- 2 new calculated tables: Dim_Targets and Color Reference
- 7 goal metrics with full RAG status framework
- 5 comparison types: MoM, WoW, DoD, YoY, OTC
- Each comparison type has Prior Period, Absolute Change, and % Change variants
- Color measures return hex strings for direct conditional formatting via Field Value
