# PLAN DE IMPLEMENTACIÓN: 9 DASHBOARDS DE COLLECTIONS

**Fecha:** 2026-07-21 (última actualización)
**Objetivo:** Preparar generator, schema y DAX para 9 dashboards de collections
**Consolidación:** Executive Collections + Executive Scorecard fusionados en uno solo
**Status:** Generator ✅ | Schema ✅ | DAX ✅ (256 measures) | Dashboard Build → PENDING

---

## RESUMEN DE DASHBOARDS

| # | Dashboard | DAX Coverage | Status | KPIs Needed | KPIs Available | Gap |
|---|-----------|-------------|--------|-------------|----------------|-----|
| 1 | Executive Collections | **95%** | ✅ Ready | 12 | 11 | 1 visual only |
| 2 | Agent Performance | **95%** | ✅ Ready | 10 | 10 | None |
| 3 | Dialer Performance | **80%** | ⚠️ Limited | 8 | 7 | 1 measure (campaign — schema gap) |
| 4 | Portfolio Management | **95%** | ✅ Ready | 9 | 9 | None |
| 5 | Operations Command Center | **55%** | ⚠️ Limited | 8 | 5 | 3 measures (schema gaps) |
| 6 | Credit Risk | **80%** | ✅ Ready | 8 | 8 | None |
| 7 | Financial Recovery | **95%** | ✅ Ready | 8 | 8 | None |
| 8 | Vintage Analysis | **85%** | ✅ Ready | 6 | 6 | None |
| 9 | Roll Rate Analysis | **90%** | ✅ Ready | 8 | 8 | None |

**Excluidos (6):** Executive Scorecard, WFM, QA, Compliance, Customer Experience, Recovery Forecast

---

## DAX STATUS: 256 MEASURES COMPLETE

### What EXISTS in CSV (256 measures)

| Table | Measures | Status |
|-------|----------|--------|
| `_Goals & Targets` | 31 (2 calc tables + 29 measures) | ✅ Complete |
| `_Outreach & Activity` | 20 | ✅ Complete |
| `_Promise & Conversion` | 13 | ✅ Complete |
| `_Recovery & Collection` | 16 | ✅ Complete |
| `_Portfolio Health` | 23 | ✅ Complete |
| `_Time Intelligence` | 120 (MoM 36 + WoW 21 + DoD 21 + YoY 21 + OTC 21) | ✅ Complete |
| `_Executive` | 3 | ✅ Complete |
| `_Agent Performance` | 6 | ✅ Complete |
| `_Dialer Performance` | 4 | ✅ Complete |
| `_Portfolio Management` | 3 | ✅ Complete |
| `_Financial Recovery` | 9 | ✅ Complete |
| `_Vintage Analysis` | 3 | ✅ Complete |
| `_Roll Rate Analysis` | 5 | ✅ Complete |
| **TOTAL** | **256** | **✅ All in CSV** |

### Documentation Files
- `dashboards/dax/collections_dax_v2.csv` — 256 measures (source of truth)
- `docs/dashboards/dax_measures_all.md` — Complete DAX reference (all 256 as code blocks)
- `docs/dashboards/dax_measures_dictionary_v2.md` — v2.2 (tables, formats, dependencies)
- `dashboards/dax/dax_targets_and_comparisons.md` — Goals & Targets patterns

---

## DASHBOARD-BY-DASHBOARD DAX COVERAGE

### Dashboard 1: Executive Collections — 95% ✅

**Audience:** VP Collections, Directors
**Purpose:** Portfolio health at a glance, KPI cards, trend sparklines

| KPI Needed | DAX Measure | Table | Status |
|------------|-------------|-------|--------|
| Portfolio Health Score | `[Portfolio Health Score]` | _Executive | ✅ |
| Monthly Recovery Rate | `[Monthly Recovery Rate]` | _Executive | ✅ |
| Portfolio At-Risk Balance | `[Portfolio At-Risk Balance]` | _Executive | ✅ |
| Promise Rate (PTP%) | `[Promise Rate]` | _Promise & Conversion | ✅ |
| KP Rate | `[KP Rate]` | _Promise & Conversion | ✅ |
| Cures per THT Hr | `[Cures per THT Hr]` | _Recovery & Collection | ✅ |
| Utilization % | `[Avg Utilization %]` | _Outreach & Activity | ✅ |
| All 7 Goal measures | `[Goal *]` | _Goals & Targets | ✅ |
| All 7 Gap measures | `[* Gap]` | _Goals & Targets | ✅ |
| All 7 RAG Status | `[* Status]` | _Goals & Targets | ✅ |
| MoM/WoW/DoD/YoY/OTC | 120 Time Intelligence | _Time Intelligence | ✅ |
| Risk Heat Map | Visual only (DPD buckets) | _Portfolio Health | ⚠️ Visual |

**Gap:** Risk Heat Map is a visual layout, not a DAX measure. All KPIs covered.

---

### Dashboard 2: Agent Performance — 95% ✅

**Audience:** Supervisors, Team Leads
**Purpose:** Agent leaderboard, coaching flags, performance tiers

| KPI Needed | DAX Measure | Table | Status |
|------------|-------------|-------|--------|
| Agent RPC per Hour | `[Agent RPC per Hour]` | _Agent Performance | ✅ |
| Agent KP Rate | `[Agent KP Rate]` | _Agent Performance | ✅ |
| Agent Quality Score | `[Agent Quality Score]` | _Agent Performance | ✅ |
| Agent Performance Tier | `[Agent Performance Tier]` | _Agent Performance | ✅ |
| Agent Tenure Months | `[Agent Tenure Months]` | _Agent Performance | ✅ |
| Coaching Alert | `[Coaching Alert]` | _Agent Performance | ✅ |
| RPC Rate | `[RPC Rate]` | _Outreach & Activity | ✅ |
| Promise Rate | `[Promise Rate]` | _Promise & Conversion | ✅ |
| Avg Utilization % | `[Avg Utilization %]` | _Outreach & Activity | ✅ |
| Avg AHT RPC (sec) | `[Avg AHT RPC (sec)]` | _Outreach & Activity | ✅ |

**Coverage:** All KPIs covered.

---

### Dashboard 3: Dialer Performance — 80% ⚠️

**Audience:** Operations Managers
**Purpose:** Dialer efficiency, channel comparison, campaign analytics

| KPI Needed | DAX Measure | Table | Status |
|------------|-------------|-------|--------|
| Dialer Connection Rate | `[Dialer Connection Rate]` | _Dialer Performance | ✅ |
| Dialer Abandon Rate | `[Dialer Abandon Rate]` | _Dialer Performance | ✅ |
| Dialer Efficiency Score | `[Dialer Efficiency Score]` | _Dialer Performance | ✅ |
| Dialer Productive Rate | `[Dialer Productive Rate]` | _Dialer Performance | ✅ |
| Total Calls Attempted | `[Total Calls Attempted]` | _Outreach & Activity | ✅ |
| Total Connected | `[Total Connected]` | _Outreach & Activity | ✅ |
| RPC Rate | `[RPC Rate]` | _Outreach & Activity | ✅ |
| Campaign Breakdown | Missing (needs campaign field) | — | ❌ Schema gap |

**Gaps:**
1. Campaign breakdown requires a `campaign_id` column in Fact_Interactions — **schema gap**, not just DAX

---

### Dashboard 4: Portfolio Management — 95% ✅

**Audience:** Portfolio Managers, Directors
**Purpose:** Arrears waterfall, delinquency bands, DPD migration

| KPI Needed | DAX Measure | Table | Status |
|------------|-------------|-------|--------|
| Portfolio Total Balance | `[Portfolio Total Balance]` | _Portfolio Health | ✅ |
| Portfolio Total Arrears | `[Portfolio Total Arrears]` | _Portfolio Health | ✅ |
| Mora Rate | `[Mora Rate]` | _Portfolio Health | ✅ |
| Arrears to Balance | `[Arrears to Balance]` | _Portfolio Health | ✅ |
| Portfolio Concentration Index | `[Portfolio Concentration Index]` | _Portfolio Management | ✅ |
| Mora Balance Rate | `[Mora Balance Rate]` | _Portfolio Management | ✅ |
| DPD Migration Rate | `[DPD Migration Rate]` | _Portfolio Management | ✅ |
| All DPD counts | `[Accounts DPD *]` | _Portfolio Health | ✅ |
| All Mora Rate by DPD | `[Mora Rate by DPD *]` | _Portfolio Health | ✅ |
| Arrears Waterfall | Visual only | — | ⚠️ Visual |

**Gap:** Arrears Waterfall is a visual layout (stacked bar/bridge chart), not a DAX measure. All KPIs covered.

---

### Dashboard 5: Operations Command Center — 55% ⚠️

**Audience:** Operations Managers, WFM
**Purpose:** Real-time operations monitoring, agent utilization

| KPI Needed | DAX Measure | Table | Status |
|------------|-------------|-------|--------|
| Avg Utilization % | `[Avg Utilization %]` | _Outreach & Activity | ✅ |
| Agents Below Util Target | `[Agents Below Util Target]` | _Outreach & Activity | ✅ |
| Total Op Hours | `[Total Op Hours]` | _Outreach & Activity | ✅ |
| Total THT Hours | `[Total THT Hours]` | _Outreach & Activity | ✅ |
| THT Alignment % | `[THT Alignment %]` | _Outreach & Activity | ✅ |
| Avg AHT RPC (sec) | `[Avg AHT RPC (sec)]` | _Outreach & Activity | ✅ |
| Calls Offered vs Answered | Missing (needs answered field) | — | ❌ Schema gap |
| Occupancy Rate | Missing (needs talk + hold + wrap) | — | ❌ Schema gap |
| Agent Login/Logout | Missing (needs session tracking) | — | ❌ Schema gap |

**Gaps:** These 3 measures require schema changes (answered calls, occupancy breakdown, session logs). **This dashboard is the most limited** — recommend building as a simplified version with available metrics.

---

### Dashboard 6: Credit Risk — 80% ✅

**Audience:** Credit Risk Managers
**Purpose:** Delinquency by segment, credit utilization, risk scoring

| KPI Needed | DAX Measure | Table | Status |
|------------|-------------|-------|--------|
| Mora Rate | `[Mora Rate]` | _Portfolio Health | ✅ |
| DPD Distribution | `[Accounts DPD *]` | _Portfolio Health | ✅ |
| Roll Rates | `[Roll Rate *]` | _Portfolio Health | ✅ |
| Arrears to Balance | `[Arrears to Balance]` | _Portfolio Health | ✅ |
| Avg Credit Limit | `[Avg Credit Limit]` | _Credit Risk | ✅ |
| Credit Utilization % | `[Credit Utilization %]` | _Credit Risk | ✅ |
| Income Segment | `[Income Segment]` | _Credit Risk | ✅ |
| Write-off Analysis | `[Write-off Amount]` | _Financial Recovery | ✅ |

**Coverage:** All KPIs covered.

---

### Dashboard 7: Financial Recovery — 95% ✅

**Audience:** Recovery Managers, Finance
**Purpose:** Recovery vs cost, write-offs, cost-to-collect

| KPI Needed | DAX Measure | Table | Status |
|------------|-------------|-------|--------|
| Total Recovery | `[Total Recovery]` | _Recovery & Collection | ✅ |
| Cured Amount | `[Cured Amount]` | _Recovery & Collection | ✅ |
| Total Cures | `[Total Cures]` | _Recovery & Collection | ✅ |
| Cost per Cure | `[Cost per Cure]` | _Financial Recovery | ✅ |
| Collection Efficiency Ratio | `[Collection Efficiency Ratio]` | _Financial Recovery | ✅ |
| Agent-Assisted Cure Rate | `[Agent-Assisted Cure Rate]` | _Financial Recovery | ✅ |
| Recovery per RPC | `[Recovery per RPC]` | _Financial Recovery | ✅ |
| Net Recovery | `[Net Recovery]` | _Financial Recovery | ✅ |
| Cost to Collect | `[Cost to Collect]` | _Financial Recovery | ✅ |
| Write-off Amount | `[Write-off Amount]` | _Financial Recovery | ✅ |
| Cost per Account | `[Cost per Account]` | _Financial Recovery | ✅ |
| Cost per Dollar Collected | `[Cost per Dollar Collected]` | _Financial Recovery | ✅ |

**Coverage:** All KPIs covered.

---

### Dashboard 8: Vintage Analysis — 85% ✅

**Audience:** Portfolio Analysts
**Purpose:** Account aging, balance by vintage, cure by vintage

| KPI Needed | DAX Measure | Table | Status |
|------------|-------------|-------|--------|
| Vintage Age Months | `[Vintage Age Months]` | _Vintage Analysis | ✅ |
| Average Vintage Balance | `[Average Vintage Balance]` | _Vintage Analysis | ✅ |
| Cure Rate by Vintage | `[Cure Rate by Vintage]` | _Vintage Analysis | ✅ |
| DPD Distribution by Vintage | Available via DPD counts + open_date | — | ✅ |
| Roll Rates by Vintage | Available via Roll Rates + open_date | — | ✅ |
| Vintage Balance Distribution | Visual only (histogram) | — | ⚠️ Visual |

**Gap:** Vintage Balance Distribution is a visual layout (histogram of balance by vintage month), not a DAX measure. All KPIs covered.

---

### Dashboard 9: Roll Rate Analysis — 90% ✅

**Audience:** Portfolio Analysts, Risk Managers
**Purpose:** DPD migration matrix, skip/deteriorate paths, stuck accounts

| KPI Needed | DAX Measure | Table | Status |
|------------|-------------|-------|--------|
| Roll Rate Current→Delinquent | `[Roll Rate Current to Delinquent]` | _Portfolio Health | ✅ |
| Roll Rate 30→60 | `[Roll Rate 30 to 60]` | _Portfolio Health | ✅ |
| Roll Rate 60→90 | `[Roll Rate 60 to 90]` | _Portfolio Health | ✅ |
| Net Roll Rate | `[Net Roll Rate]` | _Roll Rate Analysis | ✅ |
| Roll Rate Trend | `[Roll Rate Trend]` | _Roll Rate Analysis | ✅ |
| Skip Paths (30→90+) | `[Skip Path Accounts]` | _Roll Rate Analysis | ✅ |
| Deterioration Rate | `[Deterioration Rate]` | _Roll Rate Analysis | ✅ |
| Stuck 90+ | `[Stuck 90+ Accounts]` | _Roll Rate Analysis | ✅ |

**Coverage:** All KPIs covered.

---

## SUMMARY: REMAINING GAPS

| Category | Measures | Difficulty | Priority |
|----------|----------|------------|----------|
| Campaign Breakdown (Dashboard 3) | 0 | **Schema gap** (needs campaign_id) | Low |
| Calls Offered/Answered (Dashboard 5) | 0 | **Schema gap** (needs answered field) | Low |
| Occupancy Rate (Dashboard 5) | 0 | **Schema gap** (needs talk/hold/wrap) | Low |
| Agent Login/Logout (Dashboard 5) | 0 | **Schema gap** (needs session tracking) | Low |

**Schema gaps (4):** Campaign breakdown, calls offered/answered, occupancy rate, agent login/logout — these require generator + schema changes that are NOT in the current Phase 8.5 scope. Recommend building simplified versions with available metrics.

**All DAX measures are complete.** No additional measures needed — the 12 measures identified as "missing" in prior sprints have all been added to the CSV.

---

## RECOMMENDED BUILD ORDER (by DAX coverage)

1. **Build Dashboard 1: Executive Collections** (95% coverage)
2. **Build Dashboard 4: Portfolio Management** (95%)
3. **Build Dashboard 2: Agent Performance** (95%)
4. **Build Dashboard 7: Financial Recovery** (95%)
5. **Build Dashboard 9: Roll Rate Analysis** (90%)
6. **Build Dashboard 8: Vintage Analysis** (85%)
7. **Build Dashboard 6: Credit Risk** (80%)
8. **Build Dashboard 3: Dialer Performance** (80%)
9. **Build Dashboard 5: Operations Command Center** (55%, most limited)
