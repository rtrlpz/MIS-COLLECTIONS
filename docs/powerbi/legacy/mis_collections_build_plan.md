# MSI Collections — Dashboards & Reports Build Plan

> **ARCHIVED (2026-08-31).** Superseded planning doc (5-phase build plan dated 2026-07-21). Current actionable
> build guide is `docs/powerbi/PHASE9_EXECUTION_PLAN.md` (Phase 9) + `docs/powerbi/dashboard_blueprint.md`
> (9-page wireframes) + `docs/PLAN_DASHBOARDS.md` (high-level plan). Historical reference only.
> **Author:** MIS Manager, Scotiabank Collections
> **Status:** Planning Phase
> **Target:** 1 Power BI Dashboard (9 pages) + 1 Excel Daily MIS Workbook
> **Last updated:** 2026-07-21 (Consolidated from 10 to 9 dashboards, merged Executive Scorecard into Executive Collections)

---

## 1. Architecture Overview

### Single Source of Truth
```
┌──────────────────────────────────────────────────────────────────┐
│                    POSTGRESQL (star schema)                       │
│   Dim_Supervisors ← Dim_Agents → Fact_Interactions              │
│   Dim_Clients → Dim_Accounts → Fact_PTP_Log                     │
│   Dim_Products →           → Fact_Payments                      │
│   Dim_Calendar              Fact_Agent_Time_Log                  │
│                              Fact_EOM_Snapshot                   │
│                              Fact_Writeoffs (NEW)                │
│                              v_daily_mis (KPI view)              │
│                              v_monthly_summary (KPI view)        │
│                              v_dpd_migration_matrix (NEW)        │
│                              v_weekly_agent_summary (NEW)        │
│                              v_rls_supervisor_map (NEW)          │
└───────────────────┬──────────────────────────────────────────────┘
                    │  Import
                    ▼
┌──────────────────────────────────────────────────────────────────┐
│              POWER BI DESKTOP — single .pbix file                 │
│                                                                    │
│   Measure tables (13 tables, 256 measures):                           │
│   ├── _Goals & Targets        (31 measures)                          │
│   ├── _Outreach & Activity    (20 measures)                          │
│   ├── _Promise & Conversion   (13 measures)                          │
│   ├── _Recovery & Collection  (16 measures)                          │
│   ├── _Portfolio Health       (23 measures)                          │
│   ├── _Time Intelligence      (120 measures)                         │
│   ├── _Executive               (3 measures)                          │
│   ├── _Agent Performance       (6 measures)                          │
│   ├── _Dialer Performance      (4 measures)                          │
│   ├── _Portfolio Management    (3 measures)                          │
│   ├── _Financial Recovery      (9 measures)                          │
│   ├── _Vintage Analysis        (3 measures)                          │
│   └── _Roll Rate Analysis      (5 measures)                          │
│                                                                    │
│   Pages (9):                                                       │
│   ├── Page 1 — Executive Collections (merged with Scorecard)     │
│   ├── Page 2 — Agent Performance                                 │
│   ├── Page 3 — Dialer Performance                                │
│   ├── Page 4 — Portfolio Management                              │
│   ├── Page 5 — Operations Command Center (limited)               │
│   ├── Page 6 — Credit Risk (limited)                             │
│   ├── Page 7 — Financial Recovery                                │
│   ├── Page 8 — Vintage Analysis                                  │
│   └── Page 9 — Roll Rate Analysis                                │
│                                                                    │
│   Excluded: Executive Scorecard, WFM, QA, Compliance,            │
│             Customer Experience, Recovery Forecast                 │
└───────────┬───────────────────────────────────────────────────────┘
            │  Automated Python script
            ▼
┌──────────────────────────────────────────────────────────────────┐
│              EXCEL WORKBOOK — 3 sheets (attached to email)        │
│   Sheet 1 — Daily MIS Dashboard                                   │
│   Sheet 2 — Agent Deep Dive                                       │
│   Sheet 3 — Methodological Notes                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Key Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Single PBIX vs multiple | **Single PBIX** | All 9 pages share the same star-schema model. One data refresh, one publish. |
| Import vs DirectQuery | **Import** | ~1.5M rows (12 months) — fits easily in memory. Faster DAX performance. |
| Excel generation | **Python (openpyxl)** | Scheduled via batch script. Queries `v_daily_mis` directly. No VBA dependency. |
| Refresh frequency | **Daily** | PBI: scheduled gateway refresh. Excel: triggered after ETL completes. |
| DAX source of truth | **CSV** | `collections_dax_v2.csv` is the source. Import into PBIX, don't author in PBIX. |

---

## 2. Phased Build Plan

### Phase A — Data Foundation + Generator Enhancements (5 days)

**Goal:** Extend generator for 12 months of data with new columns for all 9 dashboards.

| Task | Description | Dependencies | Verification |
|---|---|---|---|
| A1 — Generator G1-G9 | Implement open_date spread, channels, write-offs, cost_per_hour, credit_limit, income_bracket, hire_dates | None | Generator runs without errors, new columns present in CSVs |
| A2 — Schema changes | +8 columns, +1 table (fact_writeoffs), +3 views, +4 constraints, +6 indexes | A1 | DDL runs without errors |
| A3 — Expand calendar | Dim_Calendar seed expanded to 13 months (Jan-Dec 2025) | None | 365 rows in seed file |
| A4 — Regenerate data | Run generator for 12 months (Jan-Dec 2025) with seed 42 | A1, A3 | Row counts within ±5% of expected |
| A5 — Reload PostgreSQL | Run ETL with full truncate + load | A2, A4 | All 12 months loaded, `v_etl_load_summary` shows 12 months per fact table |
| A6 — Update tests | conftest.py + test_qa_validation.py for new columns/tables | A5 | All tests pass (fast + slow) |
| A7 — Verify KPI views | Spot-check all views (9 existing + 3 new) return data | A5 | Views return rows, no NULLs in required columns |
| A8 — DAX expansion | Add 120 time intelligence + 14 dashboard-specific + 2 financial measures to CSV | A5 | CSV has 256 measures across 13 tables |

**Output:** 12 months of data in PostgreSQL, 256 DAX measures in CSV (13 tables), all tests passing.

---

### Phase B — Power BI Data Model (3 days)

**Goal:** Import star schema and build the DAX layer.

| Task | Description | Dependencies | Notes |
|---|---|---|---|
| B1 — Import tables | Power Query: import all 12 tables (6 dim + 6 fact) | Phase A | Disable table load on unused columns |
| B2 — Define relationships | Map all FK relationships between dim → fact | B1 | Ensure cross-filter direction is correct (single: dim → fact) |
| B3 — Create measure tables | 6 empty tables: _Outreach, _Promise, _Recovery, _Portfolio, _Time Intel, _Goals | B2 | Use `Enter Data` with a single dummy row, then hide |
| B4 — Import DAX from CSV | Import ~320 measures from `collections_dax_v2.csv` | B3 | CSV is source of truth |
| B5 — Create calculated tables | Dim_Targets (7 goals), Color Reference (3 RAG hex codes) | B4 | Enter Data with static values |
| B6 — Add RLS | Row-level security by `supervisor_id` (teams see only their agents) | B4 | Role: `TeamLead`, filter: `Dim_Agents[supervisor_id] = USERPRINCIPALNAME()` |
| B7 — Validate DAX | Spot-check against SQL KPI views | B4 | Values should match at month grain |

**Measure table reference (13 tables, 256 measures in CSV):**

| Table | Measures | Key DAX Patterns |
|---|---|---|
| `_Outreach & Activity` | `Total Calls Attempted`, `RPC Rate`, `RPC per Op Hr`, `Avg AHT RPC (sec)`, `Avg Utilization %` | `SUM`, `DIVIDE`, `CALCULATE` with boolean filter |
| `_Promise & Conversion` | `Total PTPs`, `KP Rate`, `BB Conversion Rate`, `Capped KP $`, `Capped KP per RPC Arrears` | `DIVIDE` with `CALCULATE`, `COUNTROWS` with filter, `SUMX` |
| `_Recovery & Collection` | `Total Recovery`, `Total Cures`, `Cured Amount`, `Cures per THT Hr`, `Collection Efficiency` | `CALCULATE` with `DISTINCTCOUNT`, `SUM` with boolean |
| `_Portfolio Health` | `Portfolio Total Arrears`, `Mora Rate`, `Arrears to Balance`, `Roll Rate *` (3 measures), `Avg Credit Limit` | `MAX(snapshot_date)` for EOM, `FILTER` + `CONTAINS` for roll rates |
| `_Goals & Targets` | 7 Goals + 7 Gaps + 7 Status + 7 Color + 2 calc tables = 31 | `LOOKUPVALUE`, `SWITCH`, `DATATABLE` |
| `_Time Intelligence` | 120 (MoM 36 + WoW 21 + DoD 21 + YoY 21 + OTC 21) | `DATEADD`, `DATESINPERIOD`, `SAMEPERIODLASTYEAR`, `ALL` |
| `_Executive` | 3 (`Portfolio Health Score`, `Monthly Recovery Rate`, `Portfolio At-Risk Balance`) | Weighted composite, `DATEADD` |
| `_Agent Performance` | 6 (`Agent Quality Score`, `Agent Performance Tier`, `Coaching Alert`, etc.) | `SWITCH`, `IF`, WoW comparison |
| `_Dialer Performance` | 4 (`Dialer Connection Rate`, `Abandon Rate`, `Efficiency Score`, `Avg AHT by Channel`) | `CALCULATE` with channel filter |
| `_Portfolio Management` | 3 (`Portfolio Concentration Index`, `Mora Balance Rate`, `DPD Migration Rate`) | `FILTER` + `CONTAINS`, HHI formula |
| `_Financial Recovery` | 9 (`Recovery per RPC`, `Cost per Cure`, `Net Recovery`, `Cost to Collect`, `Write-off Amount`, `Cost per Account`, `Cost per Dollar Collected`, etc.) | `DIVIDE`, `SUM`, `CALCULATE` with date filter |
| `_Vintage Analysis` | 3 (`Vintage Age Months`, `Average Vintage Balance`, `Cure Rate by Vintage`) | `DATEDIFF`, `AVERAGE`, `DIVIDE` |
| `_Roll Rate Analysis` | 5 (`Net Roll Rate`, `Roll Rate Trend`, `Skip Path Accounts`, `Deterioration Rate`, `Stuck 90+ Accounts`) | `FILTER` + `CONTAINS`, `LOOKUPVALUE`, `SWITCH` |

**EOM Snapshot filter pattern (critical):**
```
Portfolio Total Arrears =
CALCULATE(
    SUM(Fact_EOM_Snapshot[arrears]),
    Fact_EOM_Snapshot[snapshot_date] = MAX(Fact_EOM_Snapshot[snapshot_date])
)
```
Without this, measures triple-count (3 months × all accounts).

---

### Phase C — Dashboard Pages (5 days)

**Goal:** Build 9 dashboard pages with slicers, navigation, and formatting.

#### Page 1 — Executive Collections (merged with Scorecard)
| Element | Visual Type | Position | Data Source |
|---|---|---|---|
| Total Arrears | Card (new) | Top-left | `[Portfolio Total Arrears]` |
| Mora Rate | Card (new) | Top | `[Mora Rate %]` |
| KP % | Card (new) | Top | `[KP %]` |
| Cured Amount | Card (new) | Top-right | `[Total Amount Paid]` |
| Cost per Account | Card (new) | Top-right | `[Cost to Collect] / [Total Accounts]` |
| MoM KP% + RPC% | Line chart (dual axis) | Middle-left | `[KP %]`, `[RPC %]` × Dim_Calendar[month_name] |
| Arrears Waterfall | Waterfall chart | Middle-right | Fact_EOM_Snapshot[arrears] by month |
| Risk Heat Map | Matrix (conditional) | Bottom-left | Rows=dpd_bucket, Columns=product, Values=SUM(arrears) |
| DPD Bucket Treemap | Treemap | Bottom-right | Fact_EOM_Snapshot[dpd_bucket], size = SUM(arrears) |
| Slicers | Slicer (dropdown) | Top bar | Month, Product, Team |

#### Page 2 — Agent Performance
| Element | Visual Type | Position | Data Source |
|---|---|---|---|
| Slicers | Slicers (dropdown) | Top bar | Team, Agent, Month, Metric |
| Agent Ranking | Table (conditional) | Left | Agent Name, Composite Score, Team Rank, Status |
| Composite Gauge | Gauge | Right-top | `[Composite Score]` |
| Component Bars | Clustered bar | Right-bottom | RPC%, KP%, Util%, AHT Score (4 bars per selected agent) |
| Coaching Alerts | Multi-row card | Bottom | Top 3 agents with WoW drops |

#### Page 3 — Dialer Performance
| Element | Visual Type | Position | Data Source |
|---|---|---|---|
| Total Calls | Card | Top-left | `[Outbound Calls Only]` |
| RPC Rate (Dialer) | Card | Top | `[RPC Rate (Dialer Only)]` |
| Calls by Channel | Bar chart | Middle | Channel (Dialer/FICO/SMS) × Calls Attempted |
| AHT by Channel | Bar chart | Middle-right | Channel × Avg AHT |
| Call Volume Trend | Line chart | Bottom | Calls by day, color=channel |

#### Page 4 — Portfolio Management
| Element | Visual Type | Position | Data Source |
|---|---|---|---|
| Arrears Line | Line chart | Top-left | Fact_EOM_Snapshot[arrears] by month, color=product |
| DPD Migration | Sankey (Deneb) | Top-right | prev_dpd_bucket → dpd_bucket (needs calc column) |
| Product Concentration | Treemap | Bottom-left | product_name, size=SUM(arrears) |
| DPD Migration % | Card | Bottom-right | `[DPD Migration %]` |

#### Page 5 — Operations Command Center (limited)
| Element | Visual Type | Position | Data Source |
|---|---|---|---|
| Calls Offered | Card | Top-left | From v_daily_mis |
| Calls Answered | Card | Top | From v_daily_mis |
| Avg AHT | Card | Top-right | From v_handle_time_metrics |
| Occupancy | Card | Top-right | From v_handle_time_metrics |
| Agent Login/Logout | Table | Bottom | From fact_agent_time_log |

#### Page 6 — Credit Risk (limited)
| Element | Visual Type | Position | Data Source |
|---|---|---|---|
| Delinquency by Segment | Bar chart | Top-left | Segment × SUM(arrears) |
| Roll Rates | Matrix | Top-right | prev_dpd_bucket × curr_dpd_bucket |
| Cure Rates by Product | Bar chart | Bottom-left | Product × `[Cure Rate]` |
| Credit Utilization | Card | Bottom-right | `[Credit Utilization %]` |

#### Page 7 — Financial Recovery
| Element | Visual Type | Position | Data Source |
|---|---|---|---|
| Total Recovery | Card | Top-left | `[Total Recovery]` |
| Write-offs | Card | Top | `[Write-off Amount]` |
| Net Recovery | Card | Top-right | `[Net Recovery]` |
| Cost to Collect | Card | Top-right | `[Cost to Collect]` |
| Recovery vs Cost | Bar chart | Middle | Month × Recovery + Cost |
| Cost per Dollar | Card | Bottom | `[Cost per Dollar Collected]` |

#### Page 8 — Vintage Analysis
| Element | Visual Type | Position | Data Source |
|---|---|---|---|
| DPD by Vintage | Bar chart | Top | Vintage Month × DPD bucket |
| Vintage Curves | Line chart | Middle | Months on Book × DPD bucket % |
| Cure by Vintage | Bar chart | Bottom | Vintage Month × Cure Rate |

#### Page 9 — Roll Rate Analysis
| Element | Visual Type | Position | Data Source |
|---|---|---|---|
| Migration Sankey | Sankey (Deneb) | Top | prev_dpd → curr_dpd |
| Skip Rates | Card | Middle-left | `[Roll Rate 30 to 90 (Skip)]` |
| Deterioration Rate | Card | Middle-right | `[Overall Deterioration Rate]` |
| Stuck 90+ | Card | Bottom-left | `[Roll Rate Stuck 90+]` |
| Improvement Rates | Bar chart | Bottom-right | Various improvement rates |

**Global formatting:**
- Theme: Corporate blue (#005B94 primary, #0078D4 secondary, #E81123 for alerts)
- Font: Segoe UI, 10pt body, 14pt titles
- Background: White (#FFFFFF), alternating row shading (#F5F5F5)
- RAG status: Green (#00B050) pass, Amber (#FFC000) near-target, Red (#FF0000) below-target

---

### Phase D — Excel Daily MIS Report (2 days)

**Goal:** Automated Excel workbook generated from PostgreSQL.

#### Workbook Structure

**Sheet 1 — Daily MIS Dashboard**
```
┌──────────────────────────────────────────────────────────────┐
│  MSI Collections — Daily MIS Report                          │
│  Date: {date}  |  Data Through: {last_loaded}               │
├─────────────────┬──────────┬──────────┬──────────┬──────────┤
│  KPI             │ Actual   │ Target   │ Status   │ MoM Δ   │
├─────────────────┼──────────┼──────────┼──────────┼──────────┤
│  RPC%            │   64.2%  │   ≥65%   │  🟡      │  +1.8pp │
│  PTP%            │   58.7%  │   ≥70%   │  🔴      │  -3.2pp │
│  KP%             │   62.1%  │   ≥60%   │  🟢      │  +0.5pp │
│  BB Conversion   │   36.4%  │   ≥40%   │  🟡      │  -1.1pp │
│  Utilization     │   73.5%  │  70-85%  │  🟢      │  +2.1pp │
│  Mora Rate       │   17.3%  │   <20%   │  🟢      │  -0.8pp │
│  Cures           │     142  │   ≥150   │  🟡      │   -12   │
│  Cure Amount ($) │  $284K   │   $300K  │  🟡      │  -$16K  │
├─────────────────┴──────────┴──────────┴──────────┴──────────┤
│  Agent Performance (Top 10 by Composite Score)               │
│  ┌──────────┬────────┬──────┬──────┬──────┬────────┐       │
│  │ Agent    │  Team  │ RPC% │ KP%  │ Util │ Status │       │
│  ├──────────┼────────┼──────┼──────┼──────┼────────┤       │
│  │ Doe, J   │  TeamA │ 85%  │ 72%  │ 81%  │ 🟢     │       │
│  │ Smith, A │  TeamB │ 78%  │ 68%  │ 76%  │ 🟢     │       │
│  │ ...      │  ...   │ ...  │ ...  │ ...  │ ...    │       │
│  └──────────┴────────┴──────┴──────┴──────┴────────┘       │
├──────────────────────────────────────────────────────────────┤
│  Team Summary                                                │
│  ┌────────────┬──────┬──────┬──────┬──────┬──────────┐     │
│  │ Team       │ Size │ RPC% │ KP%  │ Util │ Cures    │     │
│  ├────────────┼──────┼──────┼──────┼──────┼──────────┤     │
│  │ Collections│  12  │ 72%  │ 64%  │ 78%  │   28     │     │
│  │ Recoveries │  10  │ 68%  │ 59%  │ 74%  │   22     │     │
│  │ ...        │ ...  │ ...  │ ...  │ ...  │ ...      │     │
│  └────────────┴──────┴──────┴──────┴──────┴──────────┘     │
└──────────────────────────────────────────────────────────────┘
```

**Sheet 2 — Agent Deep Dive**
- Row headers: Agent Name (sorted by team, then composite score)
- Column groups:
  - **Contact**: Calls Attempted, Calls Connected, RPC%, RPC/OpHr
  - **Promise**: PTP Count, PTP%, PTP Kept, KP%
  - **Recovery**: Cures, Cured Amount, Self-Cure Rate
  - **Productivity**: Utilization%, Avg AHT RPC (sec), Avg ACW RPC (sec)
  - **Trend**: WoW RPC% Δ, WoW KP% Δ, WoW Util% Δ
- Conditional formatting: Green/Amber/Red for each KPI vs target
- Arrows: ▲ green for improvement, ▼ red for decline

**Sheet 3 — Methodological Notes**
- KPI definitions (reference `docs/kpi_definitions.md`)
- Data sources and refresh schedule
- Exclusions (Team Leads, Managers removed from agent KPIs)
- Contact information
- Version history

#### Python Generator Script Design

```python
# reports/generate_daily_mis.py
# Dependencies: openpyxl, psycopg2, pandas

def generate_daily_mis(output_path, db_connection_string):
    """Query v_daily_mis + v_monthly_summary → formatted .xlsx"""
    # 1. Connect to PostgreSQL
    # 2. Query portfolio KPIs from v_monthly_summary (granularity='portfolio')
    # 3. Query agent KPIs from v_daily_mis
    # 4. Query team summary from v_monthly_summary (granularity='team')
    # 5. Open template (or create new workbook)
    # 6. Write Sheet 1 — Dashboard (KPI cards, agent table, team table)
    # 7. Write Sheet 2 — Agent Deep Dive (pivot table with conditional formatting)
    # 8. Write Sheet 3 — Notes (static text)
    # 9. Save to output_path / {date}_MSI_Daily_MIS.xlsx
    pass
```

**Schedule:** Triggered by `run_pipeline.bat` as the final step after ETL completes.

---

### Phase E — Publishing & Governance (1 day)

| Task | Description | Owner |
|---|---|---|
| E1 — Publish PBIX to Service | Upload to Power BI Service, configure dataset | MIS Manager |
| E2 — Schedule gateway refresh | PostgreSQL → on-premises gateway, daily at 6 AM | IT |
| E3 — Distribute Excel | Email to distribution list or save to SharePoint | MIS Manager |
| E4 — RLS testing | Verify Team Leads see only their agents | MIS Manager |
| E5 — Documentation | User guide for each dashboard page | MIS Manager |
| E6 — Handoff | Demo to supervisors, managers, directors | MIS Manager |

---

## 3. Requirements Matrix

### Data Requirements

| # | Requirement | Source | SQL View | Status |
|---|---|---|---|---|
| DR1 | 12 months (Jan-Dec 2025) interaction data | data_generator_v7.py (G1-G9) | fact_interactions | ❌ Needs generator update |
| DR2 | Agent dimension with supervisor mapping + hire_date + cost_per_hour | data_generator_v7.py (G2, G9) | dim_agents | ❌ Needs generator update |
| DR3 | EOM account snapshots with DPD buckets + prev_dpd_bucket | data_generator_v7.py (G7) | fact_eom_snapshot | ❌ Needs generator update |
| DR4 | PTP log with status (Kept/Broken/Pending) + resolved_date | data_generator_v7.py | fact_ptp_log | ❌ Needs generator update |
| DR5 | Payment / cure transactions | data_generator_v7.py | fact_payments | ❌ Needs generator update |
| DR6 | Agent time log (login/logout/utilization) | data_generator_v7.py | fact_agent_time_log | ❌ Needs generator update |
| DR7 | Calendar dimension with flags (13 months) | data_generator_v7.py (G7) | dim_calendar | ❌ Needs generator update |
| DR8 | Dim_Accounts with open_date spread + credit_limit | data_generator_v7.py (G1, G3) | dim_accounts | ❌ Needs generator update |
| DR9 | Dim_Clients with income_bracket | data_generator_v7.py (G4) | dim_clients | ❌ Needs generator update |
| DR10 | Fact_Interactions with channel (Dialer/FICO/SMS) | data_generator_v7.py (G5) | fact_interactions | ❌ Needs generator update |
| DR11 | Fact_Writeoffs table | data_generator_v7.py (G6) | fact_writeoffs | ❌ Needs generator update |
| DR12 | Dim_Supervisors with hire_date | data_generator_v7.py (G8) | dim_supervisors | ❌ Needs generator update |

### KPI Requirements

| # | KPI | Category | Must-have? | Page |
|---|---|---|---|---|
| KR1 | Total Calls Attempted | Contact | Yes | 1, 2, 3 |
| KR2 | Total RPCs | Contact | Yes | 1, 2, 3 |
| KR3 | RPC% | Contact | Yes | 1, 2, 3 |
| KR4 | RPC per Operating Hour | Contact | Yes | 3 |
| KR5 | Avg AHT RPC (sec) | Contact | Yes | 2, 3, 5 |
| KR6 | Avg ACW RPC (sec) | Contact | Yes | 2, 3, 5 |
| KR7 | Total PTPs | Promise | Yes | 1, 2 |
| KR8 | PTP% | Promise | Yes | 1, 2 |
| KR9 | PTP Kept | Promise | Yes | 1, 2 |
| KR10 | KP% | Promise | Yes | 1, 2 |
| KR11 | BB Conversion Rate | Promise | Yes | 1 |
| KR12 | Capped KP$ | Promise | Yes | 1 |
| KR13 | Capped KP / RPC Arrears | Promise | Yes | 1 |
| KR14 | Total Cures | Recovery | Yes | 1, 6, 7 |
| KR15 | Agent Cures | Recovery | Yes | 2, 7 |
| KR16 | Self-Cures | Recovery | Yes | 7 |
| KR17 | Self-Cure Rate % | Recovery | Yes | 7 |
| KR18 | Total Amount Paid | Recovery | Yes | 1, 7 |
| KR19 | Cures per THT | Recovery | Yes | 1 |
| KR20 | Utilization % | Productivity | Yes | 1, 2, 5 |
| KR21 | Portfolio Total Arrears | Portfolio | Yes | 1, 4 |
| KR22 | Mora Rate % | Portfolio | Yes | 1, 4 |
| KR23 | DPD Bucket Distribution | Portfolio | Yes | 1, 4, 9 |
| KR24 | Arrears / Balance % | Portfolio | Yes | 4 |
| KR25 | KP% MoM Change | Portfolio | Yes | 1 |
| KR26 | Mora Rate MoM Change | Portfolio | Yes | 1, 4 |
| KR27 | Rolling 3M KP% | Portfolio | Nice-to-have | 1 |
| KR28 | Portfolio Balance (current) | Portfolio | Yes | 4, 6 |
| KR29 | Accounts in Mora | Portfolio | Yes | 4 |
| KR30 | Roll Rates (30→Current, 30→90, Stuck 90+) | Roll Rate | Yes | 6, 9 |
| KR31 | Credit Utilization % | Credit Risk | Yes | 6 |
| KR32 | Avg Credit Limit | Credit Risk | Yes | 6 |
| KR33 | Income Segment Distribution | Credit Risk | Yes | 6 |
| KR34 | Account Vintage Month | Vintage | Yes | 8 |
| KR35 | Months on Book | Vintage | Yes | 8 |
| KR36 | Write-off Amount | Recovery | Yes | 7 |
| KR37 | Net Recovery | Recovery | Yes | 7 |
| KR38 | Cost to Collect | Recovery | Yes | 7 |
| KR39 | Cost per Dollar Collected | Recovery | Yes | 7 |
| KR40 | Outbound Calls Only | Dialer | Yes | 3 |
| KR41 | RPC Rate (Dialer Only) | Dialer | Yes | 3 |
| KR42 | DPD Migration % | Portfolio | Yes | 4, 9 |

### Technical Requirements

| # | Requirement | Specification | Notes |
|---|---|---|---|
| TR1 | Power BI Desktop | v2.130+ (Feb 2026 or later) | For new card visual |
| TR2 | PostgreSQL | 15.x | Docker container |
| TR3 | Python | 3.10+ | openpyxl, psycopg2, pandas |
| TR4 | Gateway | On-premises data gateway | For scheduled refresh |
| TR5 | Power BI license | Pro or Premium Per User | For publishing |
| TR6 | Excel | 2019+ or Office 365 | For .xlsx compatibility |
| TR7 | RLS | Implemented via Power BI roles | No database-level RLS needed |

### Business Requirements

| # | Requirement | Priority | Rationale |
|---|---|---|---|
| BR1 | VP/Directors see portfolio health at a glance | Critical | Page 1 (Executive Collections) + Page 4 (Portfolio) |
| BR2 | Supervisors identify bottom performers daily | Critical | Page 2 (Agent Performance) + Excel Sheet 1 |
| BR3 | Managers compare dialer effectiveness | High | Page 3 (Dialer Performance) |
| BR4 | Risk team assesses credit risk and delinquency | High | Page 6 (Credit Risk) |
| BR5 | Finance tracks recovery vs cost | High | Page 7 (Financial Recovery) |
| BR6 | Analysts investigate account vintage patterns | Medium | Page 8 (Vintage Analysis) |
| BR7 | Analysts understand DPD migration patterns | Medium | Page 9 (Roll Rate Analysis) |
| BR8 | Operations monitors real-time call center | Medium | Page 5 (Operations Command Center) |
| BR9 | Daily MIS distributed to all managers by 9 AM | Critical | Excel report |
| BR10 | RLS prevents cross-team visibility | High | Supervisors should not see other teams |
| BR11 | Red/Amber/Green status for every KPI | Critical | Drives action without data expertise |
| BR12 | MoM trend on every KPI | High | "Are we improving?" |
| BR13 | Coaching alerts surfaced automatically | Medium | Page 2 bottom section |
| BR14 | Fixed Excel template (branded, locked formulas) | Medium | Audit trail |

---

## 4. Timeline

| Phase | Days | Start | End | Dependencies |
|---|---|---|---|---|
| A — Data Foundation + Generator | 5 | Day 1 | Day 5 | None |
| B — Power BI Model | 3 | Day 6 | Day 8 | Phase A |
| C — Dashboard Pages | 5 | Day 9 | Day 13 | Phase B |
| D — Excel MIS Report | 2 | Day 14 | Day 15 | Phase A (needs data) |
| E — Publishing | 1 | Day 16 | Day 16 | Phase C, D |
| **Total** | **16 business days** | | | |

### Parallel Paths
- Phase A (generator) must complete before Phase B (model)
- Phase C (dashboards) and Phase D (Excel) can be built simultaneously
- Generator enhancements (G1-G9) are the critical path — everything depends on new data

---

## 5. Key Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Generator enhancements take longer than expected | Medium | High | Start with G1 (open_date spread) as it blocks Vintage/Cohort; defer G6 (write-offs) if needed |
| 12 months of data too large for Import mode | Low | Medium | ~1.5M rows fits easily; worst case use aggregations |
| PBIX file crashes with 9 pages | Low | High | Build fresh .pbix from scratch; import model only |
| RLS not supported (no Power BI Pro) | Medium | High | Fallback: publish separate team-level PBIX files (one per team) |
| Excel template formatting breaks with large data | Low | Low | Test with full 12-month dataset; add data validation |
| Stakeholders request endless changes | High | Medium | Lock scope after Phase C; document change request process |
| Vintage/Cohort analysis needs 12+ months of varied open_dates | Medium | Medium | G1 spreads open_dates across 12-24 months; may need to extend if curves aren't smooth |

---

## 6. Deliverables Checklist

- [ ] `dashboards/pbix/collections_dashboard_v3.pbix` — Power BI dashboard (9 pages)
- [ ] `reports/generate_daily_mis.py` — Python script for Excel generation
- [ ] `reports/output/*_MSI_Daily_MIS.xlsx` — Daily MIS Excel reports
- [ ] `docs/dashboards/user_guide.md` — End-user documentation
- [ ] `data_sources/config.py` — Updated with G1-G9 parameters
- [ ] `data_sources/data_generator_v7.py` — Updated with 9 new sections
- [ ] `database/migrations/001_create_tables.sql` — Updated with new columns/tables
- [ ] `database/migrations/002_kpi_views.sql` — Updated with new/modified views
- [ ] `dashboards/dax/collections_dax_v2.csv` — 256 measures (13 tables)
- [ ] `docs/dashboards/dax_measures_all.md` — Complete DAX reference (auto-generated from CSV)
- [ ] README update with build plan reference

---

## 7. Decision Log

| Date | Decision | Option Chosen | Rationale |
|---|---|---|---|
| 2026-07-21 | Dashboard count | 9 pages (from 10) | Merged Executive Collections + Executive Scorecard — audience overlap too high |
| 2026-07-21 | Excluded dashboards | WFM, QA, Compliance, Customer Experience, Recovery Forecast | No data for WFM/QA/Compliance; CX duplicate of Executive; Recovery Forecast needs real forecasting |
| 2026-07-21 | Operations Command Center | Limited version | Only metrics available (no inbound queue data for Service Level, ASA, Shrinkage) |
| 2026-07-21 | Credit Risk | Limited version | Only available metrics (no Loss Forecast, PD/LGD/EAD models) |
| 2026-07-21 | Data months | 12 months (Jan-Dec 2025) | Full year for YoY capability; cleaner than Oct 2024 start |
| 2026-07-21 | DAX measures target | ~320 measures | 207 existing + 91 from markdown + 22 new dashboard-specific |
| 2026-07-21 | Connection mode | Import (not DirectQuery) | ~1.5M rows fits in memory; faster DAX |
| 2026-07-21 | PBIX starting point | Build fresh (not modify existing) | Avoid inheriting unknown model issues |
