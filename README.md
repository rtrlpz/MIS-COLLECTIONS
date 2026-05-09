# MIS Collections — Local Analytics Environment

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
python data_sources/generators/data_generator_v7.py

# 3. Run the full ETL pipeline
./run_pipeline.bat
```

---

## Future Work

- Predictive model for PTP keep probability
- Behavioral clustering for customer segmentation
- Cohort analysis by delinquency stage

---

> A complete simulation of a banking collections ecosystem — owning the entire data lifecycle, from business process modeling to relational design to strategic reporting.
