# MIS Collections — Local Analytics Environment

![Python](https://img.shields.io/badge/python-3.12-blue)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-336791)
![Tests](https://img.shields.io/badge/tests-84%20passing-brightgreen)
![DAX](https://img.shields.io/badge/DAX-148%20measures%20%2B%20TI%20CG-orange)
![Status](https://img.shields.io/badge/status-90%25%20complete-yellow)
![Phase](https://img.shields.io/badge/phase-8%20(docs)-blueviolet)

End-to-end collections analytics platform simulating a bank's full data infrastructure, from synthetic raw data generation to interactive business dashboards.

---

## Overview

Simulated collections operations for a financial institution across **~80 agents**, **~10,000 clients**, and **~20,000 accounts** spanning three product lines — Credit Cards, Personal Loans, and Mortgages.

The dataset covers the complete collections lifecycle:

- Dialer operations & Right Party Contact (RPC) rates
- Promise-to-Pay (PTP) tracking & fulfillment
- Payment posting and cure events
- Agent time tracking & utilization
- Expected vs. actual payment reconciliation

---

## Business Use Case

Designed to answer real operational questions collections teams face daily:

| Question | Impact |
|---|---|
| Which agents are underperforming and need coaching? | Workforce optimization |
| Which portfolio segments show low RPC or conversion rates? | Targeted strategy adjustment |
| Are outbound strategies effective for high-risk accounts? | Dialer campaign ROI |
| How efficiently does agent time convert into recoveries? | Operational efficiency |

---

## Key Findings

### High Arrears ≠ High Recovery
Accounts >90 days past due show **higher RPC rates but lower Kept Promise (KP%)**. As delinquency ages, converting conversations into payments becomes significantly harder — signaling a need for specialized recovery or settlement tactics.

### Outbound Drives Volume, Not Efficiency
Outbound calls generate the majority of PTPs but yield **lower KP% vs. inbound interactions**. Inbound callers demonstrate higher intent to pay; routing top agents to handle inbound flow maximizes recovery.

### The Utilization Trade-off
Agents pushed past **85% utilization** experience a measurable drop in KP%. Overloading leads to rushed calls and reduced effectiveness in negotiating closed payments.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Data Generation | Python (pandas, psycopg2) |
| Database | PostgreSQL 15 (Docker) |
| ETL | Python pipeline |
| Analytics | SQL (star schema, KPI views) |
| Visualization | Power BI, Excel (Power Query) |

---

## Architecture

```
Data Generation (Python)  →  Database Layer (PostgreSQL)
                                    ↓
                            Semantic Layer (SQL Views)
                                    ↓
                     Visualization (Power BI / Excel)
```

A standard 4-tier data architecture: synthetic data with real-world friction → structured star schema → centralized KPI calculations → automated reporting.

## Data Lineage

```mermaid
flowchart LR
    subgraph Generation
        G[data_generator_v7.py<br/>config.py]
        CSV[raw/ CSVs<br/>15 tables, ~1.9M rows]
    end
    subgraph Database
        PG[(PostgreSQL 15<br/>MIS_CollectionsDB)]
        MIG[migrations/<br/>6 SQL files]
        SEED[seeds/<br/>products + calendar]
    end
    subgraph Views
        V[12 KPI Views<br/>v_contact_metrics<br/>v_promise_metrics<br/>v_recovery_metrics<br/>v_daily_mis<br/>v_monthly_summary<br/>...]
        A[17 Analysis Queries<br/>agent / team / portfolio]
    end
    subgraph BI
        DAX[dashboards/dax/<br/>148 DAX measures + TI calc group]
        PBI[dashboards/<br/>9 PBIX pages]
        EXCEL[reports/<br/>MIS Excel generator]
    end
    G --> CSV
    CSV -->|ETL: data_to_pg.py| PG
    MIG --> PG
    SEED --> PG
    PG --> V
    PG --> A
    PG --> DAX
    DAX --> PBI
    V --> EXCEL
```

**Upstream → Downstream:** Generator → CSVs → PostgreSQL (star schema) → SQL Views → DAX measures → Power BI dashboards + Excel reports.

---

## KPI Framework

| Category | Metrics |
|---|---|
| **Contact** | RPC% (RPCs / Total Connections), Total Handle Time (THT), Utilization% |
| **Conversion** | PTP% (PTP / RPC), KP% (Kept Promises / Total Promises), BB Conversion (PTP% × KP%) |
| **Financial** | Cures (accounts recovered to $0 past due), Cured Amounts ($ recovered), Cures / THT |

---

## Project Structure

```
MIS-CollectionsDB/
├── data_sources/          # Python data generators
├── database/              # Docker config & SQL schema
├── etl/                   # ETL pipeline
├── sql_analysis/          # Ad-hoc analysis & KPI views
├── dashboards/            # Power BI (.pbix) files
├── excel_reports/         # MIS reporting templates
├── docs/                  # Data dictionaries & documentation
├── test/                  # pytest test suite
```

---

## Quick Start

```bash
# 1. Start the database
docker-compose -f database/docker-compose.yml up -d

# 2. Generate synthetic data
python data_sources/data_generator_v7.py

# 3. Run the full ETL pipeline
./run_pipeline.bat
```

Detailed setup: [`docs/QUICKSTART.md`](docs/QUICKSTART.md)

---

## Documentation

| Doc | Description |
|-----|-------------|
| [`docs/QUICKSTART.md`](docs/QUICKSTART.md) | 5-minute setup guide |
| [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) | Error resolution reference |
| [`docs/KPI_VIEWS.md`](docs/KPI_VIEWS.md) | View documentation (13 of 16 views; rest documented inline in SQL) |
| [`docs/kpi_definitions.md`](docs/kpi_definitions.md) | KPI formulas and definitions |
| [`docs/data_dictionary.md`](docs/data_dictionary.md) | Column-level dictionary |
| [`docs/dashboards/execution_guide.md`](docs/dashboards/execution_guide.md) | Enterprise build guide |
| [`docs/CONTEXT.md`](docs/CONTEXT.md) | Full project context |
| [`docs/README.md`](docs/README.md) | Documentation index |
| [`CHANGELOG.md`](docs/CHANGELOG.md) | Version history |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Phase completion tracking |
| [`CONTEXT.md`](CONTEXT.md) | Full project context |

## Future Work

- Predictive model for PTP keep probability
- Behavioral clustering for customer segmentation
- Cohort analysis by delinquency stage

---

> A complete simulation of a banking collections ecosystem — owning the entire data lifecycle, from business process modeling to relational design to strategic reporting.
