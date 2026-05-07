# MSI Collections — Dashboards & Reports Build Plan

> **Author:** MIS Manager, Scotiabank Collections
> **Status:** Planning Phase
> **Target:** 1 Power BI Dashboard (5 pages) + 1 Excel Daily MIS Workbook

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
│                              v_daily_mis (KPI view)              │
│                              v_monthly_summary (KPI view)        │
└───────────────────┬──────────────────────────────────────────────┘
                    │  DirectQuery or Import
                    ▼
┌──────────────────────────────────────────────────────────────────┐
│              POWER BI DESKTOP — single .pbix file                 │
│                                                                    │
│   Measure tables:                                                  │
│   ├── _Contact & Volume   (19 measures)                           │
│   ├── _Promise & Recovery (26 measures)                           │
│   └── _Portfolio & Trends (25 measures)                           │
│                                                                    │
│   Pages (5):                                                       │
│   ├── Page 1 — Executive Overview                                 │
│   ├── Page 2 — Agent Scorecard                                    │
│   ├── Page 3 — Team Leaderboard                                   │
│   ├── Page 4 — Portfolio Health                                   │
│   └── Page 5 — Promise Intelligence                               │
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
| Single PBIX vs multiple | **Single PBIX** | All pages share the same star-schema model. One data refresh, one publish. |
| Import vs DirectQuery | **Import** | ~500K interactions, ~31K PTPs, ~21K payments — fits easily in memory. Faster DAX performance. |
| Excel generation | **Python (openpyxl)** | Scheduled via batch script. Queries `v_daily_mis` directly. No VBA dependency. |
| Refresh frequency | **Daily** | PBI: scheduled gateway refresh. Excel: triggered after ETL completes. |

---

## 2. Phased Build Plan

### Phase A — Data Foundation (2 days)

**Goal:** Ensure the database has clean, complete data for all 3 months.

| Task | Description | Dependencies | Verification |
|---|---|---|---|
| A1 — Fix weekend bug | Filter weekend dates in `data_generator_v7.py` (removes ~25,786 rows) | None | `SELECT COUNT(*) FROM fact_interactions JOIN dim_calendar ON date WHERE is_weekday = FALSE` returns 0 |
| A2 — Regenerate data | Run generator for Oct-Dec 2025 with fixed code | A1 | `anomaly_report.csv` has ~9,117 anomalies; row counts match expected |
| A3 — Reload PostgreSQL | Run ETL with `--incremental` or full truncate | A2 | `v_etl_load_summary` shows 3 months per fact table |
| A4 — Verify KPI views | Spot-check all 9 views return data for all months | A3 | `SELECT * FROM v_monthly_summary WHERE granularity = 'portfolio'` returns 3 rows |
| A5 — Document data freshness | Record snapshot dates per table | A4 | `v_data_freshness` shows < 24 hours stale |

**Output:** Clean, verified PostgreSQL instance with 3 months of collections data.

---

### Phase B — Power BI Data Model (2 days)

**Goal:** Import star schema and build the DAX layer.

| Task | Description | Dependencies | Notes |
|---|---|---|---|
| B1 — Import tables | Power Query: import all 11 tables (6 dim + 5 fact) | Phase A | Disable table load on unused columns |
| B2 — Define relationships | Map all FK relationships between dim → fact | B1 | Ensure cross-filter direction is correct (single: dim → fact) |
| B3 — Create measure tables | 3 empty tables: `_Contact & Volume`, `_Promise & Recovery`, `_Portfolio & Trends` | B2 | Use `Enter Data` with a single dummy row, then hide |
| B4 — Implement Contact DAX | 19 measures: Calls, Connections, RPC%, AHT, ACW, Utilization, Occupancy | B3 | Reference `dax_measures_dictionary.md` |
| B5 — Implement Promise DAX | 26 measures: PTPs, KP%, BB Conversion, Capped KP$, Cures | B3 | Same source |
| B6 — Implement Portfolio DAX | 25 measures: Arrears, Mora Rate, DPD buckets, MoM/YTD/Rolling | B3 | Same source |
| B7 — Add RLS | Row-level security by `supervisor_id` (teams see only their agents) | B6 | Role: `TeamLead`, filter: `Dim_Agents[supervisor_id] = USERPRINCIPALNAME()` |
| B8 — Validate DAX | Spot-check against SQL KPI views | B6 | `v_monthly_summary` values should match DAX values at month grain |

**Measure table reference:**

| Table | Measures | Key DAX Patterns |
|---|---|---|
| `_Contact & Volume` | `Calls Attempted`, `RPC %`, `RPC per Op Hr`, `Avg AHT RPC`, `Avg Utilization %` | `SUM`, `DIVIDE`, `CALCULATE` with boolean filter |
| `_Promise & Recovery` | `Total PTPs`, `KP %`, `BB Conversion Rate`, `Capped KP $`, `Total Cures`, `Self-Cure Rate %` | `DIVIDE` with `CALCULATE`, `COUNTROWS` with filter |
| `_Portfolio & Trends` | `Portfolio Total Arrears`, `Mora Rate %`, `KP % Prior Month`, `Rolling 3M KP %` | `MAX(snapshot_date)` for EOM, `DATEADD`, `DATESINPERIOD` |

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

### Phase C — Dashboard Pages (3 days)

**Goal:** Build 5 dashboard pages with slicers, navigation, and formatting.

#### Page 1 — Executive Overview
| Element | Visual Type | Position | Data Source |
|---|---|---|---|
| Total Arrears | Card (new) | Top-left | `[Portfolio Total Arrears]` |
| Mora Rate | Card (new) | Top | `[Mora Rate %]` |
| KP % | Card (new) | Top | `[KP %]` |
| Cured Amount | Card (new) | Top-right | `[Total Amount Paid]` |
| MoM KP% + RPC% | Line chart (dual axis) | Middle-left | `[KP %]`, `[RPC %]` × Dim_Calendar[month_name] |
| Arrears Waterfall | Waterfall chart | Middle-right | Fact_EOM_Snapshot[arrears] by month |
| PTP → Cure Funnel | Funnel chart | Bottom-left | Counts: Total RPCs → Total PTPs → PTP Kept → Total Cures |
| DPD Bucket Treemap | Treemap | Bottom-right | Fact_EOM_Snapshot[dpd_bucket], size = SUM(arrears) |
| Slicers | Slicer (dropdown) | Top bar | Month, Product, Team |

#### Page 2 — Agent Scorecard
| Element | Visual Type | Position | Data Source |
|---|---|---|---|
| Slicers | Slicers (dropdown) | Top bar | Team, Agent, Month, Metric |
| Agent Ranking | Table (conditional) | Left | Agent Name, Composite Score, Team Rank, Status |
| Composite Gauge | Gauge | Right-top | `[Composite Score]` |
| Component Bars | Clustered bar | Right-bottom | RPC%, KP%, Util%, AHT Score (4 bars per selected agent) |
| Coaching Alerts | Multi-row card | Bottom | Top 3 agents with WoW drops |

#### Page 3 — Team Leaderboard
| Element | Visual Type | Position | Data Source |
|---|---|---|---|
| Top Teams | Bar chart (horizontal) | Left | Team Name vs `[KP %]` or `[Composite Score]` |
| RPC% vs KP% | Scatter chart | Right | X=RPC%, Y=KP%, size=[Total Cures], legend=Team |
| Handle Time | Box plot (Deneb) | Bottom-left | Team × AHT Distribution (whisker = σ, box = IQR) |
| Workload Z-scores | Table with icons | Bottom-right | Agent Name, accounts_z_score, calls_z_score, icon if >2 |

#### Page 4 — Portfolio Health
| Element | Visual Type | Position | Data Source |
|---|---|---|---|
| Arrears Line | Line chart | Top-left | Fact_EOM_Snapshot[arrears] by month, color=product |
| DPD Migration | Sankey (Deneb) | Top-right | prev_dpd_bucket → dpd_bucket (needs calc column) |
| Product Concentration | Treemap | Bottom-left | product_name, size=SUM(arrears) |
| Risk Score Matrix | Matrix (colored) | Bottom-right | Rows=segment, Columns=product, Values=AVG(balance) |

#### Page 5 — Promise Intelligence
| Element | Visual Type | Position | Data Source |
|---|---|---|---|
| KP% by DPD | Bar chart | Left-top | X=dpd_bucket, Y=`[KP %]` |
| PTP%/KP% Matrix | Matrix | Right-top | Rows=product, Values=PTP%, KP%, BB Conversion |
| Promise Heatmap | Matrix (conditional) | Bottom | Rows=Agent, Columns=iso_week, Values=`[KP %]`, color scale |
| Capped KP/RPC Trend | Line chart | Bottom-right | `[Capped KP per Op Hr]` by month |

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
| DR1 | 3 months (Oct-Dec 2025) interaction data | data_generator_v7.py | fact_interactions | 🟡 1 month loaded |
| DR2 | Agent dimension with supervisor mapping | data_generator_v7.py | dim_agents | ✅ |
| DR3 | EOM account snapshots with DPD buckets | data_generator_v7.py | fact_eom_snapshot | 🟡 1 month loaded |
| DR4 | PTP log with status (Kept/Broken/Pending) | data_generator_v7.py | fact_ptp_log | 🟡 1 month loaded |
| DR5 | Payment / cure transactions | data_generator_v7.py | fact_payments | 🟡 1 month loaded |
| DR6 | Agent time log (login/logout/utilization) | data_generator_v7.py | fact_agent_time_log | 🟡 1 month loaded |
| DR7 | Calendar dimension with flags | data_generator_v7.py | dim_calendar | ✅ |
| DR8 | Weekend interactions removed (bug fix) | Generator patch | fact_interactions | ❌ Not fixed |

### KPI Requirements

| # | KPI | Category | Must-have? | Page |
|---|---|---|---|---|
| KR1 | Total Calls Attempted | Contact | Yes | 1, 2, 3 |
| KR2 | Total RPCs | Contact | Yes | 1, 2, 3 |
| KR3 | RPC% | Contact | Yes | 1, 2, 3 |
| KR4 | RPC per Operating Hour | Contact | Yes | 3 |
| KR5 | Avg AHT RPC (sec) | Contact | Yes | 2, 3 |
| KR6 | Avg ACW RPC (sec) | Contact | Yes | 2, 3 |
| KR7 | Total PTPs | Promise | Yes | 1, 2, 5 |
| KR8 | PTP% | Promise | Yes | 1, 2, 5 |
| KR9 | PTP Kept | Promise | Yes | 1, 2, 5 |
| KR10 | KP% | Promise | Yes | 1, 2, 5 |
| KR11 | BB Conversion Rate | Promise | Yes | 1, 5 |
| KR12 | Capped KP$ | Promise | Yes | 5 |
| KR13 | Capped KP / RPC Arrears | Promise | Yes | 5 |
| KR14 | Total Cures | Recovery | Yes | 1, 4 |
| KR15 | Agent Cures | Recovery | Yes | 2, 4 |
| KR16 | Self-Cures | Recovery | Yes | 4 |
| KR17 | Self-Cure Rate % | Recovery | Yes | 4 |
| KR18 | Total Amount Paid | Recovery | Yes | 1 |
| KR19 | Cures per THT | Recovery | Yes | 3 |
| KR20 | Utilization % | Productivity | Yes | 1, 2, 3 |
| KR21 | Portfolio Total Arrears | Portfolio | Yes | 1, 4 |
| KR22 | Mora Rate % | Portfolio | Yes | 1, 4 |
| KR23 | DPD Bucket Distribution | Portfolio | Yes | 1, 4 |
| KR24 | Arrears / Balance % | Portfolio | Yes | 4 |
| KR25 | KP% MoM Change | Portfolio | Yes | 1, 5 |
| KR26 | Mora Rate MoM Change | Portfolio | Yes | 1, 4 |
| KR27 | Rolling 3M KP% | Portfolio | Nice-to-have | 5 |
| KR28 | Portfolio Balance (current) | Portfolio | Yes | 4 |
| KR29 | Accounts in Mora | Portfolio | Yes | 4 |

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
| BR1 | VP/Directors see portfolio health at a glance | Critical | Page 1 + Page 4 |
| BR2 | Supervisors identify bottom performers daily | Critical | Page 2 + Excel Sheet 1 |
| BR3 | Managers compare teams and allocate headcount | High | Page 3 |
| BR4 | Analysts investigate promise-to-pay quality | High | Page 5 |
| BR5 | Daily MIS distributed to all managers by 9 AM | Critical | Excel report |
| BR6 | RLS prevents cross-team visibility | High | Supervisors should not see other teams |
| BR7 | Red/Amber/Green status for every KPI | Critical | Drives action without data expertise |
| BR8 | MoM trend on every KPI | High | "Are we improving?" |
| BR9 | Coaching alerts surfaced automatically | Medium | Page 2 bottom section |
| BR10 | Fixed Excel template (branded, locked formulas) | Medium | Audit trail |

---

## 4. Timeline

| Phase | Days | Start | End | Dependencies |
|---|---|---|---|---|
| A — Data Foundation | 2 | Day 1 | Day 2 | None |
| B — Power BI Model | 2 | Day 3 | Day 4 | Phase A |
| C — Dashboard Pages | 3 | Day 5 | Day 7 | Phase B |
| D — Excel MIS Report | 2 | Day 8 | Day 9 | Phase A (needs data) |
| E — Publishing | 1 | Day 10 | Day 10 | Phase C, D |
| **Total** | **10 business days** | | | |

### Parallel Paths
- Phase A (data) and Phase B (DAX) can overlap if using existing Oct data for DAX development
- Phase C (dashboards) and Phase D (Excel) can be built simultaneously
- Weekend bug fix (A1) is the only true blocking task — everything depends on clean data

---

## 5. Key Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Weekend bug not fixed in time | Medium | High | Document as known limitation; add footnote to reports |
| Only October data available | High | Medium | Build dashboards with Oct data; add MoM measures but expect NULL |
| PBIX file crashes (8.9 MB legacy) | Low | High | Build fresh .pbix from scratch; import model only |
| RLS not supported (no Power BI Pro) | Medium | High | Fallback: publish separate team-level PBIX files (one per team) |
| Excel template formatting breaks with large data | Low | Low | Test with full 3-month dataset; add data validation |
| Stakeholders request endless changes | High | Medium | Lock scope after Phase C; document change request process |

---

## 6. Deliverables Checklist

- [ ] `dashboards/collections_project/collections_dashboard.pbix` — Power BI dashboard (5 pages)
- [ ] `reports/generate_daily_mis.py` — Python script for Excel generation
- [ ] `reports/output/*_MSI_Daily_MIS.xlsx` — Daily MIS Excel reports
- [ ] `dashboards/assets/user_guide.md` — End-user documentation
- [ ] README update with build plan reference

---

## 7. Decision Log

| Date | Decision | Option Chosen | Rationale |
|---|---|---|---|
| TBD | Connection mode | Import (not DirectQuery) | ~550K rows fits in memory; faster DAX |
| TBD | Weekend bug fix | (PENDING) Needs decision | |
| TBD | PBIX starting point | Build fresh (not modify existing) | Avoid inheriting unknown model issues |
| TBD | Excel template style | (PENDING) Needs brand direction | |
