# DASHBOARD BLUEPRINT — 9 Pages, Power BI

**Purpose:** Page-by-page wireframe, visual specs, field wells, formatting, and DAX references for building all 9 dashboards from scratch.
**DAX source of truth:** `docs/powerbi/dax_measures_all.md` (148 active measures, 5 measure tables + _Time Intelligence CG)
**CSV import source:** `dashboards/dax/collections_dax_v2.csv`

---

# 1. GLOBAL SETTINGS

## 1.1 Theme File

Import `dashboards/theme/Tema 1.json` via **View > Themes > Browse for themes**.

Key settings from the theme:
| Setting | Value |
|---|---|
| Primary data color | `#262A76` (Scotia Blue) |
| Secondary colors | `#234990`, `#2F8AC3`, `#26B0D2` |
| Accent / red | `#EB5559` |
| Background | White `#FFFFFF` |
| Outspace (page) | `#ABABAB` at 25% transparency |
| Table accent | `#262A76` |
| Label font | Calibri 11pt |
| Callout font | Calibri 18pt |
| Title font | Calibri 12pt |
| Header font | Calibri |

## 1.2 Additional Formatting (manual overrides after theme import)

| Element | Setting |
|---|---|
| Page background | `#F5F6FA` (light gray-blue) |
| Canvas size | 16:9 — **1920 × 1080 px** (Full HD widescreen) |
| Visual backgrounds | Transparent (no fill) |
| Visual borders | Off |
| Visual shadows | Off |
| RAG colors | Green `#00B050`, Amber `#FFC000`, Red `#FF0000` |
| KPI card font (value) | Calibri **Bold 36pt** |
| KPI card font (label) | Calibri Regular 12pt, color `#666666` |
| KPI card font (delta) | Calibri Regular 11pt |
| Section titles | Calibri **Semibold 16pt**, color `#262A76` |
| Subtitles | Calibri Regular 11pt, color `#999999` |

## 1.3 Global Slicers (top bar, same across all 9 pages)

Place in a **horizontal slicer panel** at the top of every page:
- **Month** — slicer (dropdown), field: `Dim_Calendar[month_name]`
- **Product** — slicer (dropdown), field: `Dim_Products[product_name]`
- **Team** — slicer (dropdown), field: `Dim_Supervisors[team_name]`

Slicer styling:
- Background: `#FFFFFF`
- Border: `1px solid #E0E0E0`
- Font: Calibri 10pt
- Selected item: `#262A76` background, white text

## 1.4 Navigation Sidebar (left, 75px wide)

A **vertical bookmark navigation bar** on the left side of every page:
- Height: full page (1080px)
- Width: 75px
- Background: `#262A76`
- Icons: 9 icons (one per dashboard page), white, 32×32px
- Hover state: lighten to `#3A3F99`
- Active page: highlighted with a left border accent `#FFC000` (3px)
- Use **Bookmarks** + **Buttons** for page navigation

## 1.5 Page Title Bar (top, below slicers)

Every page has a consistent title bar:
- Position: y=0, full width, height=60px
- Background: `#262A76`
- Title text: Calibri **Semibold 16pt**, white, left-aligned (x=90, to account for nav bar)
- Subtitle: Calibri Regular 11pt, `#CCCCCC`, right-aligned

---

# 2. DASHBOARD 1 — EXECUTIVE COLLECTIONS

**Page name:** `Executive Collections`
**Audience:** VP Collections, Directors
**Storytelling flow:** What happened (KPIs) → Why (trends) → Where (risk heat map) → Who (no drill-through, this is executive)

## 2.1 Layout (1920 × 1080)

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│ [NAV]  │ Month ▼  Product ▼  Team ▼                         Executive Collections │  y=0..60
│  BAR   │                                                                          │
├────────┼──────────────────────────────────────────────────────────────────────────┤  y=60
│        │                                                                          │
│  NAV   │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐    │  y=75..195
│        │  │ Total  │ │ Mora   │ │  PTP%  │ │  KP%   │ │Cures/  │ │ Util%  │    │  KPI Row
│        │  │Arrears │ │ Rate   │ │        │ │        │ │THT Hr  │ │        │    │
│        │  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘    │
│        │                                                                          │
│        │  ┌───────────────────────────┐ ┌───────────────────────────┐            │  y=210..570
│        │  │ MoM Trend (Line)          │ │ Risk Heat Map              │            │  Middle Row
│        │  │ PTP% + KP% MoM            │ │ (Matrix: DPD x Prod)       │            │
│        │  └───────────────────────────┘ └───────────────────────────┘            │
│        │                                                                          │
│        │  ┌───────────────────────────┐ ┌───────────────────────────┐            │  y=585..930
│        │  │ Arrears Waterfall          │ │ DPD Bucket Treemap         │            │  Bottom Row
│        │  │ (Stacked bar/bridge)       │ │ (Size = arrears)           │            │
│        │  └───────────────────────────┘ └───────────────────────────┘            │
│        │                                                                          │
│        │  ── Goals & Targets gauge bar (7 mini gauges) ──                        │  y=945..1050
│        │  [PTP%] [KP%] [ACW RPC] [ACW Non-RPC] [Capped] [Cures] [Util]          │
└────────┴──────────────────────────────────────────────────────────────────────────┘
```

## 2.2 KPI Cards Row (y=75..195, height=120, each card width ~270, gap=20)

| # | Card Title | DAX Measure | Format | RAG? |
|---|-----------|-------------|--------|------|
| 1 | Total Arrears | `[Portfolio Total Arrears]` | `$#,##0` | No (context card) |
| 2 | Mora Rate | `[Mora Rate]` | `0.0%` | Yes (green >=0.85xgoal, red <0.85xgoal) |
| 3 | Promise Rate (PTP%) | `[Promise Rate]` | `0.0%` | Yes |
| 4 | KP Rate | `[KP Rate]` | `0.0%` | Yes |
| 5 | Cures / THT Hr | `[Cures per THT Hr]` | `#,##0.00` | Yes |
| 6 | Utilization % | `[Avg Utilization %]` | `0.0%` | Yes |

**Card layout:** Each card has:
- Title: Calibri 12pt, `#666666`, top-left
- Value: Calibri **Bold 36pt**, center
- Delta: MoM change, green if positive (for HigherIsBetter metrics), red if negative
- Background: `#FFFFFF`
- Border: `1px solid #E8E8E8`
- Border radius: 6px

**RAG indicator:** Small circle (12x12px) at top-right of card:
- Green `#00B050` if actual >= green threshold
- Amber `#FFC000` if actual >= amber threshold
- Red `#FF0000` otherwise

Use conditional formatting on a **Shape** visual behind the card, or use the built-in Power BI card conditional formatting.

## 2.3 MoM Trend Chart (y=210, x=75, width=885, height=360)

| Setting | Value |
|---|---|
| Visual type | **Line chart** |
| X axis | `Dim_Calendar[month_name]` (sorted by month_num) |
| Y axis (primary) | `[Promise Rate]` — blue `#262A76` |
| Y axis (secondary) | `[KP Rate]` — teal `#2F8AC3` |
| Gridlines | Horizontal only, `#E8E8E8`, 1px dashed |
| Data labels | Off (use tooltips) |
| Legend | Bottom, Calibri 11pt |
| Title | "Monthly Promise & KP Rate Trend" — Calibri 14pt Semibold, `#262A76` |

## 2.4 Risk Heat Map (y=210, x=985, width=885, height=360)

| Setting | Value |
|---|---|
| Visual type | **Matrix** |
| Rows | `Fact_EOM_Snapshot[dpd_bucket]` (Current, 30, 60, 90, 120, 150+) |
| Columns | `Dim_Products[product_name]` |
| Values | `SUM(Fact_EOM_Snapshot[arrears])` formatted as `$#,##0` |
| Conditional formatting | Background color scale: white → `#FF0000` (red) based on value |
| Column headers | Calibri 11pt Semibold, `#262A76` |
| Row headers | Calibri 11pt, `#333333` |
| Title | "Risk Heat Map — Arrears by DPD x Product" |

## 2.5 Arrears Waterfall (y=585, x=75, width=885, height=345)

| Setting | Value |
|---|---|
| Visual type | **Waterfall chart** (or stacked bar if waterfall unavailable) |
| Category | `Dim_Calendar[month_name]` |
| Values | `[Portfolio Total Arrears]` |
| Increase color | `#FF0000` (deterioration) |
| Decrease color | `#00B050` (improvement) |
| Total bar | `#262A76` |
| Title | "Arrears Waterfall — Monthly Movement" |

**Note:** If the waterfall chart doesn't work well with the data, use a **stacked bar chart** with positive (red) and negative (green) values.

## 2.6 DPD Bucket Treemap (y=585, x=985, width=885, height=345)

| Setting | Value |
|---|---|
| Visual type | **Treemap** |
| Group | `Fact_EOM_Snapshot[dpd_bucket]` |
| Details | `Dim_Products[product_name]` |
| Values | `SUM(Fact_EOM_Snapshot[arrears])` |
| Color | Automatic (use theme palette) |
| Title | "Arrears Distribution by DPD Bucket" |

## 2.7 Goals & Targets Gauge Bar (y=945, x=75, width=1795, height=105)

Create **7 mini gauge visuals** in a horizontal row, each one showing a goal vs actual:

| # | Gauge Label | Actual Measure | Goal Measure | Format | Direction |
|---|-----------|---------------|-------------|--------|-----------|
| 1 | PTP% | `[Promise Rate]` | `[Goal PTP%]` | `0.0%` | HigherIsBetter |
| 2 | KP% | `[KP Rate]` | `[Goal KP%]` | `0.0%` | HigherIsBetter |
| 3 | ACW RPC | `[Avg AHT RPC (sec)]` | `[Goal ACW RPC (sec)]` | `#,##0` | LowerIsBetter |
| 4 | ACW Non-RPC | `[Avg AHT Non-RPC (sec)]` | `[Goal ACW Non-RPC (sec)]` | `#,##0` | LowerIsBetter |
| 5 | Capped KP/RPC | `[Capped KP per RPC Arrears]` | `[Goal Capped KP per RPC Arrears]` | `0.0%` | HigherIsBetter |
| 6 | Cures/THT | `[Cures per THT Hr]` | `[Goal Cures per THT Hr]` | `#,##0.00` | HigherIsBetter |
| 7 | Utilization | `[Avg Utilization %]` | `[Goal Utilization]` | `0.0%` | HigherIsBetter |

**Gauge settings:**
- Type: Radial gauge
- Min: 0, Max: 1.2 x Goal (for HigherIsBetter) or 1.5 x Goal (for LowerIsBetter)
- Target line: Goal value
- Fill color: Use `[Goal * Status]` conditional → Green/Amber/Red
- Title: metric label, Calibri 10pt
- Width per gauge: ~250px, height: 90px

## 2.8 DAX Measures Used (Dashboard 1)

> **Live model mapping (v3):** Table names below reflect the actual `collections_dashboard_v3.pbix` model. Legacy v2 tables `_Executive`, `_Promise & Conversion`, `_Recovery & Collection` were renamed/merged in v3.

| Table | Measures |
|---|---|
| `_Composites & Strategy` | `[Portfolio Health Score]`, `[Portfolio At-Risk Balance]`, `[Net Recovery]` |
| `_Portfolio Health` | `[Portfolio Total Arrears]`, `[Mora Rate]`, `[Arrears to Balance]`, `[Accounts DPD *]`, `[Roll Rate *]` |
| `_Promise & Recovery` | `[Promise Rate]`, `[KP Rate]`, `[Cures per THT Hr]`, `[Total Cures]`, `[Cured Amount]`, `[Collection Efficiency]` |
| `_Outreach & Activity` | `[Avg Utilization %]` |
| `_Goals & Targets` | `[Goal PTP%]`, `[Goal KP%]`, `[Goal ACW RPC (sec)]`, `[Goal ACW Non-RPC (sec)]`, `[Goal Capped KP per RPC Arrears]`, `[Goal Cures per THT Hr]`, `[Goal Utilization]`, `[PTP% Gap]`, `[KP% Gap]`, `[ACW RPC Gap]`, `[ACW Non-RPC Gap]`, `[Capped KP Gap]`, `[Cures/THT Gap]`, `[Util Gap]`, `[PTP% Status]`, `[KP% Status]`, `[ACW RPC Status]`, `[ACW Non-RPC Status]`, `[Capped KP Status]`, `[Cures/THT Status]`, `[Util Status]` |
| `Dim_Targets` (calc) | Goal config — 7 metrics, thresholds, direction, sort order |
| `Color Reference` (calc) | RAG hex — Green `#00B050`, Amber `#FFC000`, Red `#FF0000` |
| `_Time Intelligence` (CG) | 18 items — apply as slicer to event-date base measures only |

**Notes:**
- `Monthly Recovery Rate` (legacy `_Executive`) does **not** exist in v3. Use `[Net Recovery]` or `[Collection Efficiency]` for the headline recovery card.
- `_Time Intelligence` CG is safe for **event-date** measures (Recovery, PTP%, KP% via `fact_payments`/`fact_ptp_log`/`fact_interactions`). Do **not** apply it to EOM-snapshot measures (`Portfolio Total Arrears`, Mora Rate) — those pin `snapshot_date = MAX(...)` internally.

---

# 3. DASHBOARD 2 — AGENT PERFORMANCE

**Page name:** `Agent Performance`
**Audience:** Supervisors, Team Leads
**Storytelling flow:** Who are my best/worst agents (leaderboard) → Why (component breakdown) → What to do (coaching alerts)

## 3.1 Layout (1920 × 1080)

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│ [NAV]  │ Month ▼  Product ▼  Team ▼  Agent ▼               Agent Performance      │
├────────┼──────────────────────────────────────────────────────────────────────────┤
│        │                                                                          │
│  NAV   │  ┌───────────────────────────────┐ ┌─────────────────────────┐          │  y=75..600
│        │  │ Agent Leaderboard Table        │ │ Agent Detail Panel       │          │  Main Area
│        │  │ (sortable, conditional)        │ │ (card + gauge + bars)   │          │
│        │  │ Left 60%                       │ │ Right 40%               │          │
│        │  └───────────────────────────────┘ └─────────────────────────┘          │
│        │                                                                          │
│        │  ┌─────────────────────────────────────────────────────────┐            │  y=615..1020
│        │  │ Coaching Alerts (Multi-row card / Table)                 │            │  Bottom
│        │  │ "Agents with WoW quality score drop > 10%"              │            │
│        │  └─────────────────────────────────────────────────────────┘            │
└────────┴──────────────────────────────────────────────────────────────────────────┘
```

## 3.2 Agent Leaderboard Table (y=75, x=75, width=1080, height=525)

| Setting | Value |
|---|---|
| Visual type | **Table** (or Matrix) |
| Columns | Agent Name, Team, Composite Score, Team Rank, Performance Tier, RPC%, KP%, Util%, Coaching Alert |
| Sort | `[Agent Rank]` ascending |
| Conditional formatting | Performance Tier: background color (Emerging=blue, Proficient=green, Advanced=teal, Expert=gold) |
| Row height | 40px |
| Header | Calibri 11pt Semibold, `#262A76` background, white text |
| Font | Calibri 11pt |
| Alternating rows | `#F5F6FA` and `#FFFFFF` |

**Fields to include:**
| Column | Field/Measure | Width |
|---|---|---|
| Agent | `Dim_Agents[agent_name]` | 220px |
| Team | `Dim_Supervisors[team_name]` | 150px |
| Composite Score | `[Agent Quality Score]` | 120px |
| Rank | `[Agent Rank]` | 75px |
| Tier | `[Agent Performance Tier]` | 120px |
| RPC/hr | `[Agent RPC per Hour]` | 90px |
| KP% | `[Agent KP Rate]` | 90px |
| Util% | `[Avg Utilization %]` | 90px |
| Alert | `[Coaching Alert]` | 90px |

## 3.3 Agent Detail Panel (y=75, x=1175, width=705, height=525)

This panel updates when a row is selected in the leaderboard.

### 3.3.1 Agent Scorecard Cards (y=75, x=1175, width=705, height=120)

Four small KPI cards in a row (width ~165 each):
| Card | Measure | Format |
|---|---|---|
| Composite Score | `[Agent Quality Score]` | `0.00` |
| Team Rank | `[Agent Rank]` | `#,##0` of `#` |
| Tenure | `[Agent Tenure Months]` | `#,##0` months |
| Tier | `[Agent Performance Tier]` | Text |

### 3.3.2 Component Bar Chart (y=210, x=1175, width=705, height=240)

| Setting | Value |
|---|---|
| Visual type | **Clustered bar chart** (horizontal) |
| Category | Static labels: "RPC Rate", "KP Rate", "Utilization", "AHT Score" |
| Values | `[RPC Rate]`, `[KP Rate]`, `[Avg Utilization %]`, `[AHT Score]` (normalize to 0-100%) |
| Color | `#262A76` for all bars |
| Target line | 0.80 (80%) as vertical reference line, `#FFC000` dashed |
| Title | "Performance Components vs Target" |

### 3.3.3 Trend Sparkline (y=465, x=1175, width=705, height=135)

| Setting | Value |
|---|---|
| Visual type | **Line chart** (sparkline, no axes) |
| X | `Dim_Calendar[week_date]` |
| Y | `[Agent Quality Score]` filtered to selected agent |
| Line color | `#262A76` |
| Width | 3px |
| Title | "Quality Score Trend (Weekly)" — Calibri 11pt |

## 3.4 Coaching Alerts (y=615, x=75, width=1800, height=405)

| Setting | Value |
|---|---|
| Visual type | **Table** |
| Filter | `[Coaching Alert] = "Alert"` (agents with WoW quality score drop > 10%) |
| Columns | Agent Name, Team, Current Score, Prior Week Score, WoW Change %, Alert Reason |
| Header | `#FF0000` background (to draw attention), white text |
| Row font | Calibri 11pt |
| Empty state | "No coaching alerts this period" — centered text, `#999999` |

**If no alerts exist:** Show a **Bookmark** with a green checkmark and "All agents performing within thresholds" text.

## 3.5 DAX Measures Used (Dashboard 2)

| Table | Measures |
|---|---|
| `_Agent Performance` | `[Agent Quality Score]`, `[Agent Performance Tier]`, `[Agent RPC per Hour]`, `[Agent KP Rate]`, `[Agent Tenure Months]`, `[Coaching Alert]` |
| `_Outreach & Activity` | `[RPC Rate]`, `[Avg Utilization %]` |
| `_Promise & Conversion` | `[Promise Rate]` |

---

# 4. DASHBOARD 3 — DIALER PERFORMANCE

**Page name:** `Dialer Performance`
**Audience:** Operations Managers
**Storytelling flow:** How is the dialer performing (KPIs) → Channel comparison → Volume trends

## 4.1 Layout (1920 × 1080)

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│ [NAV]  │ Month ▼  Product ▼  Team ▼                            Dialer Performance │
├────────┼──────────────────────────────────────────────────────────────────────────┤
│        │                                                                          │
│  NAV   │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐               │  y=75..195
│        │  │ Total  │ │ Total  │ │  RPC   │ │ Dialer │ │ Dialer │               │  KPI Row
│        │  │ Calls  │ │Connctd │ │ Rate   │ │ Abndn% │ │ Effic% │               │
│        │  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘               │
│        │                                                                          │
│        │  ┌───────────────────────────┐ ┌───────────────────────────┐            │  y=210..570
│        │  │ Calls by Channel           │ │ AHT by Channel             │            │  Middle Row
│        │  │ (Clustered bar)            │ │ (Clustered bar)            │            │
│        │  └───────────────────────────┘ └───────────────────────────┘            │
│        │                                                                          │
│        │  ┌─────────────────────────────────────────────────────────┐            │  y=585..930
│        │  │ Call Volume Trend (Line chart, color=channel)            │            │  Bottom
│        │  └─────────────────────────────────────────────────────────┘            │
└────────┴──────────────────────────────────────────────────────────────────────────┘
```

## 4.2 KPI Cards Row (y=75..195, height=120)

| # | Card Title | DAX Measure | Format |
|---|-----------|-------------|--------|
| 1 | Total Calls | `[Total Calls Attempted]` | `#,##0` |
| 2 | Total Connected | `[Total Connected]` | `#,##0` |
| 3 | RPC Rate | `[RPC Rate]` | `0.0%` |
| 4 | Abandon Rate | `[Dialer Abandon Rate]` | `0.0%` |
| 5 | Efficiency Score | `[Dialer Efficiency Score]` | `0.0%` |

## 4.3 Calls by Channel (y=210, x=75, width=885, height=360)

| Setting | Value |
|---|---|
| Visual type | **Clustered bar chart** (horizontal) |
| Category | `Fact_Interactions[channel]` (Dialer, FICO, SMS) |
| Values | `[Total Calls Attempted]` |
| Color | `#262A76` (Dialer), `#2F8AC3` (FICO), `#26B0D2` (SMS) |
| Data labels | On, Calibri 10pt |
| Title | "Calls Attempted by Channel" |

## 4.4 AHT by Channel (y=210, x=985, width=885, height=360)

| Setting | Value |
|---|---|
| Visual type | **Clustered bar chart** (horizontal) |
| Category | `Fact_Interactions[channel]` |
| Values | `[Avg AHT RPC (sec)]` |
| Color | `#262A76` |
| Reference line | Target: 120 sec, `#FFC000` dashed |
| Data labels | On, format `#,##0 sec` |
| Title | "Average Handle Time by Channel" |

## 4.5 Call Volume Trend (y=585, x=75, width=1795, height=345)

| Setting | Value |
|---|---|
| Visual type | **Line chart** |
| X | `Dim_Calendar[date]` (daily) |
| Y | `[Total Calls Attempted]` |
| Color (series) | `Fact_Interactions[channel]` |
| Line width | 3px |
| Gridlines | Horizontal only, `#E8E8E8` |
| Title | "Daily Call Volume by Channel" |

## 4.6 DAX Measures Used (Dashboard 3)

| Table | Measures |
|---|---|
| `_Dialer Performance` | `[Dialer Connection Rate]`, `[Dialer Abandon Rate]`, `[Dialer Efficiency Score]`, `[Dialer Productive Rate]` |
| `_Outreach & Activity` | `[Total Calls Attempted]`, `[Total Connected]`, `[RPC Rate]` |

---

# 5. DASHBOARD 4 — PORTFOLIO MANAGEMENT

**Page name:** `Portfolio Management`
**Audience:** Portfolio Managers, Directors
**Storytelling flow:** Overall portfolio health (KPIs) → DPD migration patterns → Product concentration → Trend

## 5.1 Layout (1920 × 1080)

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│ [NAV]  │ Month ▼  Product ▼  Team ▼                        Portfolio Management    │
├────────┼──────────────────────────────────────────────────────────────────────────┤
│        │                                                                          │
│  NAV   │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐               │  y=75..195
│        │  │ Total  │ │ Total  │ │ Mora   │ │Arrears │ │  DPD   │               │  KPI Row
│        │  │Balnc   │ │Arrrs   │ │ Rate   │ │to Blnc │ │ Migr%  │               │
│        │  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘               │
│        │                                                                          │
│        │  ┌───────────────────────────┐ ┌───────────────────────────┐            │  y=210..570
│        │  │ Arrears Trend (Line)       │ │ DPD Distribution           │            │  Middle Row
│        │  │ color=product              │ │ (Stacked bar)              │            │
│        │  └───────────────────────────┘ └───────────────────────────┘            │
│        │                                                                          │
│        │  ┌───────────────────────────┐ ┌───────────────────────────┐            │  y=585..930
│        │  │ Product Treemap            │ │ Mora Rate by DPD           │            │  Bottom Row
│        │  │ (Size = arrears)           │ │ (Grouped bar)              │            │
│        │  └───────────────────────────┘ └───────────────────────────┘            │
└────────┴──────────────────────────────────────────────────────────────────────────┘
```

## 5.2 KPI Cards Row (y=75..195, height=120)

| # | Card Title | DAX Measure | Format |
|---|-----------|-------------|--------|
| 1 | Total Balance | `[Portfolio Total Balance]` | `$#,##0` |
| 2 | Total Arrears | `[Portfolio Total Arrears]` | `$#,##0` |
| 3 | Mora Rate | `[Mora Rate]` | `0.0%` |
| 4 | Arrears to Balance | `[Arrears to Balance]` | `0.0%` |
| 5 | DPD Migration Rate | `[DPD Migration Rate]` | `0.0%` |

## 5.3 Arrears Trend Line (y=210, x=75, width=885, height=360)

| Setting | Value |
|---|---|
| Visual type | **Line chart** |
| X | `Dim_Calendar[month_name]` |
| Y | `[Portfolio Total Arrears]` |
| Color (series) | `Dim_Products[product_name]` |
| Line width | 3px |
| Data labels | Off |
| Legend | Bottom |
| Title | "Monthly Arrears by Product" |

## 5.4 DPD Distribution (y=210, x=985, width=885, height=360)

| Setting | Value |
|---|---|
| Visual type | **Stacked bar chart** (horizontal) |
| Category | `Dim_Calendar[month_name]` |
| Values | `[Accounts DPD Current]`, `[Accounts DPD 30]`, `[Accounts DPD 60]`, `[Accounts DPD 90]`, `[Accounts DPD 120]`, `[Accounts DPD 150+]` |
| Colors | Green → Yellow → Orange → Red gradient (by DPD severity) |
| Legend | Bottom, sorted by DPD severity |
| Title | "DPD Distribution Over Time" |

## 5.5 Product Concentration Treemap (y=585, x=75, width=885, height=345)

| Setting | Value |
|---|---|
| Visual type | **Treemap** |
| Group | `Dim_Products[product_name]` |
| Values | `[Portfolio Total Arrears]` |
| Color | `#262A76` gradient |
| Data labels | Product name + `$ value` |
| Title | "Product Concentration" |

## 5.6 Mora Rate by DPD (y=585, x=985, width=885, height=345)

| Setting | Value |
|---|---|
| Visual type | **Clustered bar chart** (horizontal) |
| Category | DPD buckets (Current, 30, 60, 90, 120, 150+) |
| Values | `[Mora Rate by DPD Current]`, `[Mora Rate by DPD 30]`, `[Mora Rate by DPD 60]`, `[Mora Rate by DPD 90]`, `[Mora Rate by DPD 120]`, `[Mora Rate by DPD 150+]` |
| Color | `#262A76` |
| Data labels | `0.0%` |
| Title | "Mora Rate by DPD Bucket" |

## 5.7 DAX Measures Used (Dashboard 4)

| Table | Measures |
|---|---|
| `_Portfolio Health` | `[Portfolio Total Balance]`, `[Portfolio Total Arrears]`, `[Mora Rate]`, `[Arrears to Balance]`, `[Accounts DPD Current]`, `[Accounts DPD 30]`, `[Accounts DPD 60]`, `[Accounts DPD 90]`, `[Accounts DPD 120]`, `[Accounts DPD 150+]`, `[Mora Rate by DPD Current]`, `[Mora Rate by DPD 30]`, `[Mora Rate by DPD 60]`, `[Mora Rate by DPD 90]`, `[Mora Rate by DPD 120]`, `[Mora Rate by DPD 150+]` |
| `_Portfolio Management` | `[Portfolio Concentration Index]`, `[Mora Balance Rate]`, `[DPD Migration Rate]` |

---

# 6. DASHBOARD 5 — OPERATIONS COMMAND CENTER

**Page name:** `Operations Command Center`
**Audience:** Operations Managers, WFM
**Storytelling flow:** Current state (utilization) → Productivity → Capacity (limited by schema gaps)

**⚠️ LIMITATION:** 3 of 8 KPIs require schema changes (calls offered/answered, occupancy, login/logout). Build simplified version with available metrics.

## 6.1 Layout (1920 × 1080)

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│ [NAV]  │ Month ▼  Product ▼  Team ▼                     Operations Command Center  │
├────────┼──────────────────────────────────────────────────────────────────────────┤
│        │                                                                          │
│  NAV   │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐   │  y=75..195
│        │  │ Util%  │ │ Agents │ │ Total  │ │ Total  │ │  THT   │ │  Avg   │   │  KPI Row
│        │  │        │ │ Below  │ │ Op Hrs │ │ THT Hr │ │Align%  │ │  AHT   │   │
│        │  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘   │
│        │                                                                          │
│        │  ┌───────────────────────────┐ ┌───────────────────────────┐            │  y=210..570
│        │  │ Utilization Trend          │ │ Agent Cost Summary         │            │  Middle Row
│        │  │ (Line + target)            │ │ (Bar chart)                │            │
│        │  └───────────────────────────┘ └───────────────────────────┘            │
│        │                                                                          │
│        │  ┌─────────────────────────────────────────────────────────┐            │  y=585..930
│        │  │ Agent Time Breakdown (Stacked bar)                       │            │  Bottom
│        │  │ Login | Talk | Hold | Wrap | Idle                         │            │
│        │  └─────────────────────────────────────────────────────────┘            │
└────────┴──────────────────────────────────────────────────────────────────────────┘
```

## 6.2 KPI Cards Row (y=75..195, height=120)

| # | Card Title | DAX Measure | Format | Note |
|---|-----------|-------------|--------|------|
| 1 | Utilization % | `[Avg Utilization %]` | `0.0%` | |
| 2 | Below Util Target | `[Agents Below Util Target]` | `#,##0` | Red if >0 |
| 3 | Total Op Hours | `[Total Op Hours]` | `#,##0.0` | |
| 4 | Total THT Hours | `[Total THT Hours]` | `#,##0.0` | |
| 5 | THT Alignment % | `[THT Alignment %]` | `0.0%` | |
| 6 | Avg AHT (RPC) | `[Avg AHT RPC (sec)]` | `#,##0` | |

## 6.3 Utilization Trend (y=210, x=75, width=885, height=360)

| Setting | Value |
|---|---|
| Visual type | **Line chart** |
| X | `Dim_Calendar[date]` (daily) |
| Y | `[Avg Utilization %]` |
| Target line | 90% (`[Goal Utilization]`), `#00B050` solid |
| Area fill | `#262A76` at 10% opacity |
| Gridlines | Horizontal, `#E8E8E8` |
| Title | "Daily Utilization Trend" |

## 6.4 Agent Cost Summary (y=210, x=985, width=885, height=360)

| Setting | Value |
|---|---|
| Visual type | **Clustered bar chart** (horizontal) |
| Category | `Dim_Supervisors[team_name]` |
| Values | `SUM(Fact_Agent_Time_Log[total_cost])` |
| Color | `#262A76` |
| Data labels | `$#,##0` |
| Title | "Agent Cost by Team" |

## 6.5 Agent Time Breakdown (y=585, x=75, width=1795, height=345)

| Setting | Value |
|---|---|
| Visual type | **Stacked bar chart** (horizontal) |
| Category | `Dim_Agents[agent_name]` (top 15 by cost) |
| Values | `SUM(Fact_Agent_Time_Log[login_time])` (login), talk, hold, wrap, idle components |
| Colors | `#262A76` (login), `#2F8AC3` (talk), `#FFC1CB` (hold), `#FFC000` (wrap), `#E8E8E8` (idle) |
| Legend | Bottom |
| Title | "Agent Time Distribution (Top 15)" |

## 6.6 DAX Measures Used (Dashboard 5)

| Table | Measures |
|---|---|
| `_Outreach & Activity` | `[Avg Utilization %]`, `[Agents Below Util Target]`, `[Total Op Hours]`, `[Total THT Hours]`, `[THT Alignment %]`, `[Avg AHT RPC (sec)]` |

---

# 7. DASHBOARD 6 — CREDIT RISK

**Page name:** `Credit Risk`
**Audience:** Credit Risk Managers
**Storytelling flow:** Portfolio risk profile (KPIs) → Credit utilization → Income segment analysis → Write-off patterns

## 7.1 Layout (1920 × 1080)

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│ [NAV]  │ Month ▼  Product ▼  Team ▼                                    Credit Risk │
├────────┼──────────────────────────────────────────────────────────────────────────┤
│        │                                                                          │
│  NAV   │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐               │  y=75..195
│        │  │ Mora   │ │  Avg   │ │ Credit │ │Arrears │ │Write-  │               │  KPI Row
│        │  │ Rate   │ │CrdLim  │ │ Util%  │ │to Blnc │ │off $   │               │
│        │  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘               │
│        │                                                                          │
│        │  ┌───────────────────────────┐ ┌───────────────────────────┐            │  y=210..570
│        │  │ Credit Utilization         │ │ DPD by Income              │            │  Middle Row
│        │  │ (Histogram)                │ │ Segment (Stacked bar)      │            │
│        │  └───────────────────────────┘ └───────────────────────────┘            │
│        │                                                                          │
│        │  ┌───────────────────────────┐ ┌───────────────────────────┐            │  y=585..930
│        │  │ Write-off Trend            │ │ Roll Rate Overview         │            │  Bottom Row
│        │  │ (Area chart)               │ │ (Table with RAG)           │            │
│        │  └───────────────────────────┘ └───────────────────────────┘            │
└────────┴──────────────────────────────────────────────────────────────────────────┘
```

## 7.2 KPI Cards Row (y=75..195, height=120)

| # | Card Title | DAX Measure | Format |
|---|-----------|-------------|--------|
| 1 | Mora Rate | `[Mora Rate]` | `0.0%` |
| 2 | Avg Credit Limit | `[Avg Credit Limit]` | `$#,##0` |
| 3 | Credit Utilization % | `[Credit Utilization %]` | `0.0%` |
| 4 | Arrears to Balance | `[Arrears to Balance]` | `0.0%` |
| 5 | Write-off Amount | `[Write-off Amount]` | `$#,##0` |

## 7.3 Credit Utilization Distribution (y=210, x=75, width=885, height=360)

| Setting | Value |
|---|---|
| Visual type | **Histogram** (or Power BI binning on bar chart) |
| Field | `Dim_Accounts[credit_limit]` (binned into $5K intervals) |
| Values | `COUNTROWS(Dim_Accounts)` or `[Credit Utilization %]` average |
| Color | `#262A76` |
| Title | "Credit Limit Distribution" |

**Note:** Power BI doesn't have a native histogram. Use a **column chart** with credit_limit on X axis and bins set to $5,000, values = count of accounts.

## 7.4 DPD by Income Segment (y=210, x=985, width=885, height=360)

| Setting | Value |
|---|---|
| Visual type | **Stacked bar chart** (horizontal) |
| Category | `[Income Segment]` (Low, Medium, High, Premium) |
| Values | `[Accounts DPD Current]`, `[Accounts DPD 30]`, `[Accounts DPD 60]`, `[Accounts DPD 90+]` |
| Colors | Green → Red gradient |
| Title | "Delinquency by Income Segment" |

## 7.5 Write-off Trend (y=585, x=75, width=885, height=345)

| Setting | Value |
|---|---|
| Visual type | **Area chart** |
| X | `Dim_Calendar[month_name]` |
| Y | `[Write-off Amount]` |
| Fill color | `#EB5559` at 30% opacity |
| Line color | `#EB5559` |
| Title | "Monthly Write-off Amount" |

## 7.6 Roll Rate Overview (y=585, x=985, width=885, height=345)

| Setting | Value |
|---|---|
| Visual type | **Table** |
| Columns | Transition, Rate, Trend, Status |
| Rows | Current→30, 30→60, 60→90, 90→120, 120→150+ |
| Values | `[Roll Rate Current to Delinquent]`, `[Roll Rate 30 to 60]`, `[Roll Rate 60 to 90]`, `[Roll Rate 90 to 120]`, `[Roll Rate 120 to 150+]` |
| Conditional formatting | Status column: Green/Amber/Red background |
| Title | "Roll Rate Summary" |

## 7.7 DAX Measures Used (Dashboard 6)

| Table | Measures |
|---|---|
| `_Portfolio Health` | `[Mora Rate]`, `[Arrears to Balance]`, `[Accounts DPD *]`, `[Roll Rate *]` |
| `_Credit Risk` | `[Avg Credit Limit]`, `[Credit Utilization %]`, `[Income Segment]` |
| `_Financial Recovery` | `[Write-off Amount]` |
| `_Roll Rate Analysis` | `[Net Roll Rate]`, `[Roll Rate Trend]` |

---

# 8. DASHBOARD 7 — FINANCIAL RECOVERY

**Page name:** `Financial Recovery`
**Audience:** Recovery Managers, Finance
**Storytelling flow:** Recovery vs cost (KPIs) → Cost efficiency → Write-off analysis → Net recovery trend

## 8.1 Layout (1920 × 1080)

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│ [NAV]  │ Month ▼  Product ▼  Team ▼                          Financial Recovery   │
├────────┼──────────────────────────────────────────────────────────────────────────┤
│        │                                                                          │
│  NAV   │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐   │  y=75..195
│        │  │ Total  │ │ Cured  │ │ Cost/  │ │  Net   │ │ Cost/  │ │Write-  │   │  KPI Row
│        │  │ Recov  │ │ Amount │ │ Cure   │ │ Recov  │ │ $Coll  │ │off $   │   │
│        │  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘   │
│        │                                                                          │
│        │  ┌───────────────────────────┐ ┌───────────────────────────┐            │  y=210..570
│        │  │ Recovery vs Cost           │ │ Cost Efficiency            │            │  Middle Row
│        │  │ (Dual-axis line)           │ │ (Scatter plot)             │            │
│        │  └───────────────────────────┘ └───────────────────────────┘            │
│        │                                                                          │
│        │  ┌───────────────────────────┐ ┌───────────────────────────┐            │  y=585..930
│        │  │ Net Recovery Trend         │ │ Collection Efficiency      │            │  Bottom Row
│        │  │ (Bar chart)                │ │ by Team (Bar)              │            │
│        │  └───────────────────────────┘ └───────────────────────────┘            │
└────────┴──────────────────────────────────────────────────────────────────────────┘
```

## 8.2 KPI Cards Row (y=75..195, height=120)

| # | Card Title | DAX Measure | Format |
|---|-----------|-------------|--------|
| 1 | Total Recovery | `[Total Recovery]` | `$#,##0` |
| 2 | Cured Amount | `[Cured Amount]` | `$#,##0` |
| 3 | Cost per Cure | `[Cost per Cure]` | `$#,##0` |
| 4 | Net Recovery | `[Net Recovery]` | `$#,##0` |
| 5 | Cost per $ Collected | `[Cost per Dollar Collected]` | `$0.00` |
| 6 | Write-off Amount | `[Write-off Amount]` | `$#,##0` |

## 8.3 Recovery vs Cost (y=210, x=75, width=885, height=360)

| Setting | Value |
|---|---|
| Visual type | **Line chart** (dual Y axis) |
| X | `Dim_Calendar[month_name]` |
| Y (primary) | `[Total Recovery]` — `#262A76` |
| Y (secondary) | `[Cost to Collect]` — `#EB5559` |
| Line width | 3px |
| Legend | Bottom |
| Title | "Monthly Recovery vs Cost" |

## 8.4 Cost Efficiency Scatter (y=210, x=985, width=885, height=360)

| Setting | Value |
|---|---|
| Visual type | **Scatter chart** |
| X | `[Cost per Cure]` |
| Y | `[Collection Efficiency Ratio]` |
| Size | `[Total Cures]` |
| Color | `Dim_Supervisors[team_name]` |
| Detail | `Dim_Agents[agent_name]` |
| Title | "Cost Efficiency by Team (bubble = volume)" |

## 8.5 Net Recovery Trend (y=585, x=75, width=885, height=345)

| Setting | Value |
|---|---|
| Visual type | **Clustered bar chart** |
| Category | `Dim_Calendar[month_name]` |
| Values | `[Net Recovery]` |
| Conditional coloring | Green if positive, red if negative |
| Data labels | `$#,##0` |
| Title | "Monthly Net Recovery" |

## 8.6 Collection Efficiency by Team (y=585, x=985, width=885, height=345)

| Setting | Value |
|---|---|
| Visual type | **Clustered bar chart** (horizontal) |
| Category | `Dim_Supervisors[team_name]` |
| Values | `[Collection Efficiency Ratio]` |
| Color | `#262A76` |
| Reference line | 100% target, `#00B050` |
| Data labels | `0.0%` |
| Title | "Collection Efficiency by Team" |

## 8.7 DAX Measures Used (Dashboard 7)

| Table | Measures |
|---|---|
| `_Recovery & Collection` | `[Total Recovery]`, `[Cured Amount]`, `[Total Cures]` |
| `_Financial Recovery` | `[Cost per Cure]`, `[Collection Efficiency Ratio]`, `[Agent-Assisted Cure Rate]`, `[Recovery per RPC]`, `[Net Recovery]`, `[Cost to Collect]`, `[Write-off Amount]`, `[Cost per Account]`, `[Cost per Dollar Collected]` |

---

# 9. DASHBOARD 8 — VINTAGE ANALYSIS

**Page name:** `Vintage Analysis`
**Audience:** Portfolio Analysts
**Storytelling flow:** Account aging (KPIs) → Balance by vintage → Cure rates → Migration patterns

## 9.1 Layout (1920 × 1080)

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│ [NAV]  │ Month ▼  Product ▼  Team ▼                                Vintage Analysis│
├────────┼──────────────────────────────────────────────────────────────────────────┤
│        │                                                                          │
│  NAV   │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐               │  y=75..195
│        │  │  Avg   │ │  Avg   │ │ Cure   │ │DPD by  │ │ Roll   │               │  KPI Row
│        │  │Vintage │ │Vintage │ │ Rate   │ │Vintge  │ │ Rates  │               │
│        │  │ Age Mo │ │Balance │ │ by V.  │ │ Dist   │ │ by V.  │               │
│        │  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘               │
│        │                                                                          │
│        │  ┌───────────────────────────┐ ┌───────────────────────────┐            │  y=210..570
│        │  │ Balance by Vintage         │ │ Cure Rate by Vintage       │            │  Middle Row
│        │  │ (Stacked bar)              │ │ (Line chart)               │            │
│        │  └───────────────────────────┘ └───────────────────────────┘            │
│        │                                                                          │
│        │  ┌─────────────────────────────────────────────────────────┐            │  y=585..930
│        │  │ DPD Distribution by Vintage (Grouped bar)                │            │  Bottom
│        │  └─────────────────────────────────────────────────────────┘            │
└────────┴──────────────────────────────────────────────────────────────────────────┘
```

## 9.2 KPI Cards Row (y=75..195, height=120)

| # | Card Title | DAX Measure | Format |
|---|-----------|-------------|--------|
| 1 | Avg Vintage Age | `[Vintage Age Months]` | `#,##0 months` |
| 2 | Avg Vintage Balance | `[Average Vintage Balance]` | `$#,##0` |
| 3 | Cure Rate by Vintage | `[Cure Rate by Vintage]` | `0.0%` |
| 4 | DPD Distribution | `[Accounts DPD *]` | Visual (mini bar) |
| 5 | Roll Rates | `[Roll Rate *]` | Visual (mini bar) |

## 9.3 Balance by Vintage (y=210, x=75, width=885, height=360)

| Setting | Value |
|---|---|
| Visual type | **Stacked bar chart** (horizontal) |
| Category | `Dim_Accounts[open_date]` (binned by vintage month: 0-3, 4-6, 7-12, 13-18, 19-24, 25+) |
| Values | `[Portfolio Total Arrears]` |
| Color | `#262A76` gradient by vintage age |
| Data labels | `$#,##0` |
| Title | "Arrears by Account Vintage" |

## 9.4 Cure Rate by Vintage (y=210, x=985, width=885, height=360)

| Setting | Value |
|---|---|
| Visual type | **Line chart** |
| X | `Dim_Accounts[open_date]` (binned by vintage month) |
| Y | `[Cure Rate by Vintage]` |
| Line color | `#00B050` |
| Target line | 80%, `#FFC000` dashed |
| Data labels | `0.0%` |
| Title | "Cure Rate by Account Vintage" |

## 9.5 DPD Distribution by Vintage (y=585, x=75, width=1795, height=345)

| Setting | Value |
|---|---|
| Visual type | **Clustered bar chart** |
| Category | Vintage buckets (0-3, 4-6, 7-12, 13-18, 19-24, 25+) |
| Values | `[Accounts DPD Current]`, `[Accounts DPD 30]`, `[Accounts DPD 60]`, `[Accounts DPD 90+]` |
| Colors | Green → Red gradient |
| Legend | Bottom |
| Title | "DPD Distribution by Account Vintage" |

## 9.6 DAX Measures Used (Dashboard 8)

| Table | Measures |
|---|---|
| `_Vintage Analysis` | `[Vintage Age Months]`, `[Average Vintage Balance]`, `[Cure Rate by Vintage]` |
| `_Portfolio Health` | `[Accounts DPD *]`, `[Portfolio Total Arrears]`, `[Roll Rate *]` |

---

# 10. DASHBOARD 9 — ROLL RATE ANALYSIS

**Page name:** `Roll Rate Analysis`
**Audience:** Portfolio Analysts, Risk Managers
**Storytelling flow:** Migration matrix (KPIs) → Skip/deterioration paths → Stuck accounts → Trend

## 10.1 Layout (1920 × 1080)

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│ [NAV]  │ Month ▼  Product ▼  Team ▼                          Roll Rate Analysis   │
├────────┼──────────────────────────────────────────────────────────────────────────┤
│        │                                                                          │
│  NAV   │  ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐   │  y=75..195
│        │  │Curr→   │ │ 30→60  │ │ 60→90  │ │  Net   │ │  Skip  │ │ Stuck  │   │  KPI Row
│        │  │Delinq  │ │ Roll   │ │ Roll   │ │ Roll   │ │ Paths  │ │  90+   │   │
│        │  └────────┘ └────────┘ └────────┘ └────────┘ └────────┘ └────────┘   │
│        │                                                                          │
│        │  ┌───────────────────────────┐ ┌───────────────────────────┐            │  y=210..570
│        │  │ Migration Matrix           │ │ Skip & Deterioration       │            │  Middle Row
│        │  │ (Heat map matrix)          │ │ (Bar chart)                │            │
│        │  └───────────────────────────┘ └───────────────────────────┘            │
│        │                                                                          │
│        │  ┌───────────────────────────┐ ┌───────────────────────────┐            │  y=585..930
│        │  │ Roll Rate Trend            │ │ Stuck 90+ Accounts         │            │  Bottom Row
│        │  │ (Line chart)               │ │ (Table by team)            │            │
│        │  └───────────────────────────┘ └───────────────────────────┘            │
└────────┴──────────────────────────────────────────────────────────────────────────┘
```

## 10.2 KPI Cards Row (y=75..195, height=120)

| # | Card Title | DAX Measure | Format |
|---|-----------|-------------|--------|
| 1 | Current→Delinquent | `[Roll Rate Current to Delinquent]` | `0.0%` |
| 2 | 30→60 Roll Rate | `[Roll Rate 30 to 60]` | `0.0%` |
| 3 | 60→90 Roll Rate | `[Roll Rate 60 to 90]` | `0.0%` |
| 4 | Net Roll Rate | `[Net Roll Rate]` | `0.0%` |
| 5 | Skip Paths | `[Skip Path Accounts]` | `#,##0` |
| 6 | Stuck 90+ | `[Stuck 90+ Accounts]` | `#,##0` |

## 10.3 Migration Matrix Heat Map (y=210, x=75, width=885, height=360)

| Setting | Value |
|---|---|
| Visual type | **Matrix** |
| Rows | `v_dpd_migration_matrix[from_bucket]` |
| Columns | `v_dpd_migration_matrix[to_bucket]` |
| Values | `v_dpd_migration_matrix[migration_count]` or rate |
| Conditional formatting | Background color scale: white → `#FF0000` (red) by value |
| Column headers | Calibri 11pt Semibold, `#262A76` |
| Title | "DPD Migration Matrix (Month-over-Month)" |

## 10.4 Skip & Deterioration Paths (y=210, x=985, width=885, height=360)

| Setting | Value |
|---|---|
| Visual type | **Clustered bar chart** (horizontal) |
| Category | Path labels: "30→90+ (Skip)", "60→120+ (Skip)", "Current→60 (Deteriorate)", "30→90 (Deteriorate)" |
| Values | `[Skip Path Accounts]`, `[Deterioration Rate]` |
| Color | `#EB5559` (skip = red), `#FFC000` (deteriorate = amber) |
| Data labels | On |
| Title | "Skip & Deterioration Path Analysis" |

## 10.5 Roll Rate Trend (y=585, x=75, width=885, height=345)

| Setting | Value |
|---|---|
| Visual type | **Line chart** |
| X | `Dim_Calendar[month_name]` |
| Y | `[Roll Rate Current to Delinquent]`, `[Roll Rate 30 to 60]`, `[Roll Rate 60 to 90]` |
| Colors | `#262A76`, `#2F8AC3`, `#EB5559` |
| Line width | 3px |
| Legend | Bottom |
| Title | "Roll Rate Trends (Monthly)" |

## 10.6 Stuck 90+ Accounts (y=585, x=985, width=885, height=345)

| Setting | Value |
|---|---|
| Visual type | **Table** |
| Columns | Team, Stuck 90+ Count, % of Portfolio, Trend (MoM) |
| Values | `[Stuck 90+ Accounts]`, `[Stuck 90+ %]`, `[Stuck 90+ MoM]` |
| Sort | Stuck 90+ Count descending |
| Conditional formatting | Trend column: green if improving, red if worsening |
| Title | "Stuck 90+ Accounts by Team" |

## 10.7 DAX Measures Used (Dashboard 9)

| Table | Measures |
|---|---|
| `_Portfolio Health` | `[Roll Rate Current to Delinquent]`, `[Roll Rate 30 to 60]`, `[Roll Rate 60 to 90]` |
| `_Roll Rate Analysis` | `[Net Roll Rate]`, `[Roll Rate Trend]`, `[Skip Path Accounts]`, `[Deterioration Rate]`, `[Stuck 90+ Accounts]` |

---

# 11. BUILD CHECKLIST (per page)

For each dashboard page, follow this sequence:

1. **Create page** — Rename to dashboard name, set page size to 16:9
2. **Apply theme** — Import `Tema 1.json`
3. **Add navigation sidebar** — Bookmark-based, 50px wide, left
4. **Add slicer bar** — Month, Product, Team (sync across pages)
5. **Add title bar** — Page name + subtitle
6. **Build KPI cards row** — Top of page, 6-7 cards
7. **Build middle row visuals** — 2 visuals, left and right
8. **Build bottom row visuals** — 2 visuals, left and right
9. **Add conditional formatting** — RAG colors, data bars, color scales
10. **Add tooltips** — Custom report page tooltips (280×150px) for each KPI card
11. **Add bookmarks** — Drill-through pages if needed
12. **Test** — Verify against `dax_measures_all.md` formulas
13. **Format** — Remove gridlines, borders, ensure consistent spacing

---

# 12. RELATIONSHIP MAP (Power BI Model View)

Ensure these relationships exist before building any visuals:

```
Dim_Calendar[date]          1 → *  Fact_Interactions[interaction_date]
Dim_Calendar[date]          1 → *  Fact_PTP_Log[ptp_date]
Dim_Calendar[date]          1 → *  Fact_Payments[payment_date]
Dim_Calendar[date]          1 → *  Fact_Agent_Time_Log[work_date]
Dim_Calendar[date]          1 → *  Fact_EOM_Snapshot[snapshot_date]
Dim_Calendar[date]          1 → *  Fact_Writeoffs[writeoff_date]

Dim_Supervisors[supervisor_id]  1 → *  Dim_Agents[supervisor_id]

Dim_Agents[agent_id]        1 → *  Fact_Interactions[agent_id]
Dim_Agents[agent_id]        1 → *  Fact_Agent_Time_Log[agent_id]

Dim_Clients[client_id]      1 → *  Dim_Accounts[client_id]

Dim_Accounts[account_id]    1 → *  Fact_Interactions[account_id]
Dim_Accounts[account_id]    1 → *  Fact_PTP_Log[account_id]
Dim_Accounts[account_id]    1 → *  Fact_Payments[account_id]
Dim_Accounts[account_id]    1 → *  Fact_EOM_Snapshot[account_id]
Dim_Accounts[account_id]    1 → *  Fact_Writeoffs[account_id]

Dim_Products[product_id]    1 → *  Dim_Accounts[product_id]
```

**Critical:** All relationships must be **single direction** (dimension → fact). No bidirectional cross-filtering.

**Mark as Date Table:** `Dim_Calendar[date]` must be marked as the date table in Power BI (Modeling > Mark as Date Table).

---

# 13. DAX IMPORT WORKFLOW

1. Open `dax_measures_all.md` — it contains all 148 active DAX measures (+ 18 CG items) as copy-paste code blocks
2. For each measure:
   - In Power BI: right-click the measure table → **New measure**
   - Paste the DAX formula from the `.md` file
   - Verify the measure appears in the correct table
3. Import order:
   1. `_Goals & Targets` (31 measures + 2 calculated tables)
   2. `_Outreach & Activity` (20 measures)
   3. `_Promise & Conversion` (13 measures)
   4. `_Recovery & Collection` (16 measures)
   5. `_Portfolio Health` (23 measures)
   6. `_Time Intelligence` (120 measures)
   7. `_Executive` (3 measures)
   8. `_Agent Performance` (6 measures)
   9. `_Dialer Performance` (4 measures)
   10. `_Portfolio Management` (3 measures)
   11. `_Financial Recovery` (9 measures)
   12. `_Vintage Analysis` (3 measures)
   13. `_Roll Rate Analysis` (5 measures)
4. After import: **Validate** — spot-check 5-10 measures against SQL views in PostgreSQL

---

# 14. RLS CONFIGURATION

| Setting | Value |
|---|---|
| Role name | `TeamLead` |
| Table | `Dim_Agents` |
| Filter | `Dim_Agents[supervisor_id] = USERPRINCIPALNAME()` |
| Apply to | All fact tables (Interactions, PTP, Payments, Agent Time, EOM Snapshot, Writeoffs) |
| Test | View as > TeamLead role > Verify only team data visible |

---

> **End of Blueprint.**
> For DAX formulas, refer to `docs/powerbi/dax_measures_all.md` (148 active measures + TI CG).
