# PLAN DE IMPLEMENTACIÓN: 9 DASHBOARDS DE COLLECTIONS

**Fecha:** 2026-07-21 (última actualización)
**Objetivo:** Preparar generator, schema y DAX para 9 dashboards de collections
**Consolidación:** Executive Collections + Executive Scorecard fusionados en uno solo
**Status:** Generator ✅ | Schema ✅ | DAX ✅ (now 148 active measures + TI calc group; see `dax_measures_all.md`) | Dashboard Build → PENDING

> *Counts below reflect the original v2.2 build plan (256 incl. per-metric time intelligence). Time intelligence has since moved to a calculation group and 118 legacy TI measures were retired — see `dashboards/dax/legacy/`.*

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

## DAX STATUS: 148 ACTIVE MEASURES + CALCULATION GROUP

> **Note:** v3.2 retired 118 legacy per-metric time intelligence measures to a single `_Time Intelligence` Calculation Group (18 items). The counts below reflect the v2.2 legacy structure (256 measures) for reference; current v3.2 has **148 base measures across 5 measure tables** + the Calculation Group.

### What EXISTS in CSV (v3.2: 148 active measures)

| Measure Table | Measures | Status |
|---------------|----------|--------|
| `_Outreach & Activity` | 22 | ✅ Complete |
| `_Promise & Recovery` | 30 | ✅ Complete |
| `_Portfolio Health` | 34 | ✅ Complete |
| `_Goals & Targets` | 31 | ✅ Complete |
| `_Composites & Strategy` | 31 | ✅ Complete |
| **TOTAL (base)** | **148** | **✅ All in CSV** |
| `_Time Intelligence` CG | 18 items | ✅ Single TI mechanism |

### Documentation Files
- `dashboards/dax/collections_dax_v2.csv` — 148 measures (source of truth, v3.2)
- `dashboards/dax/legacy/time_intelligence_legacy.csv` — 118 retired TI measures (reference only)
- `dashboards/dax/calculation_group_ti.json` — `_Time Intelligence` CG definition (18 items)
- `docs/powerbi/dax_measures_all.md` — Complete DAX reference (148 + 18 CG items as code blocks)
- `docs/powerbi/legacy/dax_measures_dictionary_v2.md` — v2.2 legacy documentation (tables, formats, dependencies; archived)
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
| Promise Rate (PTP%) | `[Promise Rate]` | _Promise & Recovery | ✅ |
| KP Rate | `[KP Rate]` | _Promise & Recovery | ✅ |
| Cures per THT Hr | `[Cures per THT Hr]` | _Portfolio Health | ✅ |
| Utilization % | `[Avg Utilization %]` | _Outreach & Activity | ✅ |
| All 7 Goal measures | `[Goal *]` | _Goals & Targets | ✅ |
| All 7 Gap measures | `[* Gap]` | _Goals & Targets | ✅ |
| All 7 RAG Status | `[* Status]` | _Goals & Targets | ✅ |
| MoM/WoW/DoD/YoY/OTC | `_Time Intelligence` Calculation Group (18 items) | — | ✅ |
| Risk Heat Map | Visual only (DPD buckets) | _Portfolio Health | ⚠️ Visual |

**Gap:** Risk Heat Map is a visual layout, not a DAX measure. All KPIs covered. (Note: v3.2 consolidated dashboard-specific tables into 5 core measure tables)

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
| Promise Rate | `[Promise Rate]` | _Promise & Recovery | ✅ |
| Avg Utilization % | `[Avg Utilization %]` | _Outreach & Activity | ✅ |
| Avg AHT RPC (sec) | `[Avg AHT RPC (sec)]` | _Outreach & Activity | ✅ |

**Coverage:** All KPIs covered. (Note: v3.2 consolidated dashboard-specific tables into 5 core measure tables)

---

### Dashboard 3: Dialer Performance — 80% ⚠️

**Audience:** Operations Managers
**Purpose:** Dialer efficiency, channel comparison, campaign analytics

| KPI Needed | DAX Measure | Table (v3.2) | Status |
|------------|-------------|--------------|--------|
| Dialer Connection Rate | `[Dialer Connection Rate]` | _Outreach & Activity | ✅ |
| Dialer Non-RPC Share % | `[Dialer Non-RPC Share %]` | _Outreach & Activity | ✅ |
| Dialer Efficiency Score | `[Dialer Efficiency Score]` | _Composites & Strategy | ✅ |
| Dialer Productive Rate | `[Dialer Productive Rate]` | _Outreach & Activity | ✅ |
| Total Calls Attempted | `[Total Calls Attempted]` | _Outreach & Activity | ✅ |
| Total Connected | `[Total Connected]` | _Outreach & Activity | ✅ |
| RPC Rate | `[RPC Rate]` | _Outreach & Activity | ✅ |
| Campaign Breakdown | Missing (needs campaign field) | — | ❌ Schema gap |

**Gaps:**
1. Campaign breakdown requires a `campaign_id` column in Fact_Interactions — **schema gap**, not just DAX
2. v3.2 renamed "Dialer Abandon Rate" → "Dialer Non-RPC Share %" (measured connected-non-RPC, not abandonment)
3. v3.2 consolidated dashboard-specific tables into 5 core measure tables

---

### Dashboard 4: Portfolio Management — 95% ✅

**Audience:** Portfolio Managers, Directors
**Purpose:** Arrears waterfall, delinquency bands, DPD migration

| KPI Needed | DAX Measure | Table (v3.2) | Status |
|------------|-------------|--------------|--------|
| Portfolio Total Balance | `[Portfolio Total Balance]` | _Portfolio Health | ✅ |
| Portfolio Total Arrears | `[Portfolio Total Arrears]` | _Portfolio Health | ✅ |
| Mora Rate | `[Mora Rate]` | _Portfolio Health | ✅ |
| Arrears to Balance | `[Arrears to Balance]` | _Portfolio Health | ✅ |
| Portfolio Concentration Index | `[Portfolio Concentration Index]` | _Composites & Strategy | ✅ |
| Mora Balance Rate | `[Mora Balance Rate]` | _Composites & Strategy | ✅ |
| DPD Migration Rate | `[DPD Migration Rate]` | _Composites & Strategy | ✅ |
| All DPD counts | `[Accounts DPD *]` | _Portfolio Health | ✅ |
| All Mora Rate by DPD | `[Mora Rate by DPD *]` | _Portfolio Health | ✅ |
| Arrears Waterfall | Visual only | — | ⚠️ Visual |

**Gap:** Arrears Waterfall is a visual layout (stacked bar/bridge chart), not a DAX measure. All KPIs covered. (Note: v3.2 consolidated dashboard-specific tables into 5 core measure tables)

---

### Dashboard 5: Operations Command Center — 55% ⚠️

**Audience:** Operations Managers, WFM
**Purpose:** Real-time operations monitoring, agent utilization

| KPI Needed | DAX Measure | Table (v3.2) | Status |
|------------|-------------|--------------|--------|
| Avg Utilization % | `[Avg Utilization %]` | _Outreach & Activity | ✅ |
| Agents Below Util Target | `[Agents Below Util Target]` | _Outreach & Activity | ✅ |
| Total Op Hours | `[Total Op Hours]` | _Outreach & Activity | ✅ |
| Total THT Hours | `[Total THT Hours]` | _Outreach & Activity | ✅ |
| THT Alignment % | `[THT Alignment %]` | _Outreach & Activity | ✅ |
| Avg AHT RPC (sec) | `[Avg AHT RPC (sec)]` | _Outreach & Activity | ✅ |
| Calls Offered vs Answered | Missing (needs answered field) | — | ❌ Schema gap |
| Occupancy Rate | Missing (needs talk + hold + wrap) | — | ❌ Schema gap |
| Agent Login/Logout | Missing (needs session tracking) | — | ❌ Schema gap |

**Gaps:** These 3 measures require schema changes (answered calls, occupancy breakdown, session logs). **This dashboard is the most limited** — recommend building as a simplified version with available metrics. (Note: v3.2 consolidated dashboard-specific tables into 5 core measure tables)

---

### Dashboard 6: Credit Risk — 80% ✅

**Audience:** Credit Risk Managers
**Purpose:** Delinquency by segment, credit utilization, risk scoring

| KPI Needed | DAX Measure | Table (v3.2) | Status |
|------------|-------------|--------------|--------|
| Mora Rate | `[Mora Rate]` | _Portfolio Health | ✅ |
| DPD Distribution | `[Accounts DPD *]` | _Portfolio Health | ✅ |
| Roll Rates | `[Roll Rate *]` | _Portfolio Health | ✅ |
| Arrears to Balance | `[Arrears to Balance]` | _Portfolio Health | ✅ |
| Avg Credit Limit | `[Avg Credit Limit]` | _Composites & Strategy | ✅ |
| Credit Utilization % | `[Credit Utilization %]` | _Composites & Strategy | ✅ |
| Income Segment | `[Income Segment]` | _Composites & Strategy | ✅ |
| Write-off Analysis | `[Write-off Amount]` | _Portfolio Health | ✅ |

**Coverage:** All KPIs covered. (Note: v3.2 consolidated dashboard-specific tables into 5 core measure tables)

---

### Dashboard 7: Financial Recovery — 95% ✅

**Audience:** Recovery Managers, Finance
**Purpose:** Recovery vs cost, write-offs, cost-to-collect

| KPI Needed | DAX Measure | Table (v3.2) | Status |
|------------|-------------|--------------|--------|
| Total Recovery | `[Total Recovery]` | _Portfolio Health | ✅ |
| Cured Amount | `[Cured Amount]` | _Portfolio Health | ✅ |
| Total Cures | `[Total Cures]` | _Portfolio Health | ✅ |
| Cost per Cure | `[Cost per Cure]` | _Composites & Strategy | ✅ |
| Collection Efficiency Ratio | `[Collection Efficiency Ratio]` | _Composites & Strategy | ✅ |
| Agent-Assisted Cure Rate | `[Agent-Assisted Cure Rate]` | _Composites & Strategy | ✅ |
| Recovery per RPC | `[Recovery per RPC]` | _Composites & Strategy | ✅ |
| Net Recovery | `[Net Recovery]` | _Composites & Strategy | ✅ |
| Cost to Collect | `[Cost to Collect]` | _Composites & Strategy | ✅ |
| Write-off Amount | `[Write-off Amount]` | _Portfolio Health | ✅ |
| Cost per Account | `[Cost per Account]` | _Composites & Strategy | ✅ |
| Cost per Dollar Collected | `[Cost per Dollar Collected]` | _Composites & Strategy | ✅ |

**Coverage:** All KPIs covered. (Note: v3.2 consolidated dashboard-specific tables into 5 core measure tables)

---

### Dashboard 8: Vintage Analysis — 85% ✅

**Audience:** Portfolio Analysts
**Purpose:** Account aging, balance by vintage, cure by vintage

| KPI Needed | DAX Measure | Table (v3.2) | Status |
|------------|-------------|--------------|--------|
| Vintage Age Months | `[Vintage Age Months]` | _Composites & Strategy | ✅ |
| Average Vintage Balance | `[Average Vintage Balance]` | _Composites & Strategy | ✅ |
| Cure Rate by Vintage | `[Cure Rate by Vintage]` | _Composites & Strategy | ✅ |
| DPD Distribution by Vintage | Available via DPD counts + open_date | — | ✅ |
| Roll Rates by Vintage | Available via Roll Rates + open_date | — | ✅ |
| Vintage Balance Distribution | Visual only (histogram) | — | ⚠️ Visual |

**Gap:** Vintage Balance Distribution is a visual layout (histogram of balance by vintage month), not a DAX measure. All KPIs covered. (Note: v3.2 consolidated dashboard-specific tables into 5 core measure tables)

---

### Dashboard 9: Roll Rate Analysis — 90% ✅

**Audience:** Portfolio Analysts, Risk Managers
**Purpose:** DPD migration matrix, skip/deteriorate paths, stuck accounts

| KPI Needed | DAX Measure | Table (v3.2) | Status |
|------------|-------------|--------------|--------|
| Roll Rate Current→Delinquent | `[Roll Rate Current to Delinquent]` | _Portfolio Health | ✅ |
| Roll Rate 30→60 | `[Roll Rate 30 to 60]` | _Portfolio Health | ✅ |
| Roll Rate 60→90 | `[Roll Rate 60 to 90]` | _Portfolio Health | ✅ |
| Net Roll Rate | `[Net Roll Rate]` | _Composites & Strategy | ✅ |
| Roll Rate Trend | `[Roll Rate Trend]` | _Composites & Strategy | ✅ |
| Skip Paths (30→90+) | `[Skip Path Accounts]` | _Composites & Strategy | ✅ |
| Deterioration Rate | `[Deterioration Rate]` | _Composites & Strategy | ✅ |
| Stuck 90+ | `[Stuck 90+ Accounts]` | _Composites & Strategy | ✅ |

**Coverage:** All KPIs covered. (Note: v3.2 consolidated dashboard-specific tables into 5 core measure tables)

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
