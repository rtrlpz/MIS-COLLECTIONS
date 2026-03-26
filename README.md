# 📊 MIS Collections – Local Analytics Environment (Enhanced)

A self-built analytics environment that simulates the data infrastructure of a bank's collections department. This project replicates the full MIS Data Analyst workflow end-to-end—from raw data generation to business insights and decision-making dashboards.

---

## 📌 Project Overview

This project simulates a full month of collections activity (October 2025) for a fictional financial institution managing:

- ~80 agents
- ~10,000 clients
- ~20,000 accounts

Across three product types:
- Credit Cards
- Personal Loans
- Mortgages

The dataset covers the full collections lifecycle:

- Dialer calls and Right Party Contact (RPC)
- Promise-to-Pay (PTP) tracking
- Payment/cure events
- Agent time & utilization
- Expected vs actual payments

---

## 💼 Business Use Case

This environment is designed to answer real operational questions faced by collections teams:

- Which agents are underperforming and need coaching?
- Which segments have low RPC or conversion rates?
- Are outbound strategies effective for high-risk accounts?
- How efficiently are agents converting time into recoveries?

The goal is to simulate how a real MIS Analyst supports decision-making in a bank’s collections department.

---

## 📈 Key Insights (Sample Analysis)

### 🔍 Insight 1: High Arrears ≠ High Recovery
Accounts with >90 days in arrears showed higher RPC rates but lower KP%.

👉 Interpretation: While agents are reaching customers, conversion into payments becomes harder as delinquency increases.

---

### 🔍 Insight 2: Outbound Drives Volume, Not Efficiency
Outbound calls generated the majority of PTPs but had lower KP% compared to inbound interactions.

👉 Interpretation: Outbound strategy is effective for engagement but less efficient in driving actual payments.

---

### 🔍 Insight 3: Utilization Trade-off
Agents with utilization above 85% showed a drop in KP%.

👉 Interpretation: Overloading agents may reduce effectiveness in closing payments.

---

## 🛠️ Tech Stack

- **PostgreSQL** — Relational database (Dockerized)
- **Python** — Data generation & ETL (`pandas`, `psycopg2`)
- **SQL** — Schema design, KPI views, analysis
- **Power BI** — Dashboard & reporting
- **Excel** — Daily MIS reporting template

---

## 🧱 Architecture

1. **Data Generation (Python)** → Synthetic operational data
2. **Database Layer (PostgreSQL)** → Structured relational schema
3. **Semantic Layer (SQL Views)** → KPI calculations
4. **Visualization Layer (Power BI / Excel)** → Reporting & dashboards

---

## 📊 KPI Framework

### Contact Metrics
- RPC % = Total RPCs / Total Connections
- Total Handle Time (THT)
- Utilization %

### Conversion Metrics
- PTP % = Total PTP / Total RPC
- KP % = Kept Promises / Total Promises
- BB Conversion = PTP % × KP %

### Financial Metrics
- Cures (accounts recovered)
- Cured Amounts
- Cures / THT (efficiency metric)

---

## 📂 Project Structure

```text
MIS-CollectionsDB/
├── 01_data_sources/
├── 02_database/
├── 03_sql_analysis/
├── 04_dashboards/
├── 05_excel_reports/
├── 06_docs/
├── 07_interview_prep/
```

---

## 🚀 How to Run Locally

```bash
# 1. Start database
docker-compose up -d

# 2. Create schema
psql -h localhost -U your_user -d MSI_CollectionsDB -f 02_database/01_create_tables.sql

# 3. Load data
cd 02_database
python data_to_pg.py

# 4. Create KPI views
psql -h localhost -U your_user -d MSI_CollectionsDB -f 02_database/kpi_views.sql
```

---

## 📊 Dashboard Features (Power BI)

- KPI Cards (RPC%, KP%, Cures)
- Agent leaderboard (Top/Bottom performers)
- Supervisor-level aggregation
- Filters by product, arrears bucket, and channel
- Time-series trends

---

## 🧠 Advanced Extension (Next Steps)

Potential improvements to extend the project:

- Predictive model: Probability of PTP being kept
- Customer segmentation (behavioral clustering)
- Cohort analysis by delinquency stage

---

## 🎯 60-Second Interview Pitch

“I built a full collections analytics environment simulating a bank’s operations. I generated synthetic data using Python, modeled it in PostgreSQL, and created KPI views to track agent performance metrics like RPC, PTP, and KP. I then built a Power BI dashboard to analyze performance, identify inefficiencies, and simulate real MIS reporting workflows used in financial institutions.”

---

## 💡 Key Takeaway

This project demonstrates the ability to:

- Work across the full data lifecycle
- Translate business processes into data models
- Build decision-driven dashboards
- Think like both a data analyst and a data engineer

---

## 📬 Final Note

This is not just a dashboard project — it is a simulation of real-world MIS analytics in a banking collections environment.

