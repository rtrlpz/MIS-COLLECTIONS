📊 MIS Collections – Local Analytics Environment
Welcome to my MIS Collections project. I built this local analytics environment to replicate the data infrastructure of a bank's collections department. This project showcases my ability to execute the full workflow of an MIS Data Analyst end-to-end—from generating synthetic raw data to delivering business insights through interactive dashboards.

📌 Project Overview
In this project, I simulated a full month of collections activity (October 2025) for a fictional financial institution. The dataset I developed manages:

~80 agents

~10,000 clients

~20,000 accounts

Across three distinct product types:

Credit Cards

Personal Loans

Mortgages

I engineered the dataset to cover the entire collections lifecycle, including:

Dialer calls and Right Party Contact (RPC) rates

Promise-to-Pay (PTP) tracking

Payment and cure events

Agent time tracking and utilization

Expected vs. actual payment reconciliations

💼 Business Use Case
I designed this environment specifically to answer the real operational questions that collections teams face daily:

Which agents are underperforming and need targeted coaching?

Which portfolio segments are experiencing low RPC or conversion rates?

Are our outbound strategies actually effective for high-risk accounts?

How efficiently are agents converting their operational time into real recoveries?

My goal was to demonstrate how I can leverage data to support strategic decision-making and operational efficiency in a banking environment.

📈 Key Findings
Through my analysis of the simulated data, I uncovered several actionable insights:

🔍 Insight 1: High Arrears ≠ High Recovery
I found that accounts >90 days in arrears showed higher RPC rates but lower Kept Promise (KP) percentages.
👉 Interpretation: While agents successfully reach these customers, converting those conversations into actual payments becomes significantly harder as delinquency ages. Strategy should shift from standard negotiation to specialized recovery or settlement tactics for this bucket.

🔍 Insight 2: Outbound Drives Volume, Not Efficiency
My data showed that outbound calls generated the vast majority of PTPs but yielded a lower KP% compared to inbound interactions.
👉 Interpretation: Outbound dialing is great for engagement, but inbound callers show much higher intent to pay. We should optimize routing to ensure top agents are handling inbound flow.

🔍 Insight 3: The Utilization Trade-off
I noticed that agents pushed past an 85% utilization rate experienced a drop in their KP%.
👉 Interpretation: Overloading agents leads to burnout or rushed calls, reducing their effectiveness in negotiating closed payments.

🛠️ Tech Stack
To build this, I utilized the following tools:

PostgreSQL: Relational database management (Dockerized)

Python: Data generation & ETL pipelines (pandas, psycopg2)

SQL: Schema design, complex KPI view creation, and deep-dive analysis

Power BI: Interactive executive and operational dashboards

Excel: Daily MIS reporting templates utilizing Power Query

🧱 Architecture
I structured the project using a standard 4-tier data architecture:

Data Generation (Python) → Creating synthetic operational data with built-in real-world friction.

Database Layer (PostgreSQL) → Storing data in a structured, relational Star Schema.

Semantic Layer (SQL Views) → Centralizing complex KPI calculations.

Visualization Layer (Power BI / Excel) → Delivering automated reporting and dashboards.

📊 KPI Framework
I built the reporting layer around these core metrics:

Contact Metrics

RPC % (Total RPCs / Total Connections)

Total Handle Time (THT)

Utilization %

Conversion Metrics

PTP % (Total PTP / Total RPC)

KP % (Kept Promises / Total Promises)

BB Conversion (PTP % × KP %)

Financial Metrics

Cures (Total accounts recovered to $0 past due)

Cured Amounts (Total dollars recovered)

Cures / THT (Ultimate efficiency metric)

📂 Project Structure
Plaintext
MIS-CollectionsDB/
├── 01_data_sources/     # Python data generators
├── 02_database/         # Docker config and SQL schema setup
├── 03_sql_analysis/     # SQL queries for ad-hoc analysis and views
├── 04_dashboards/       # Power BI (.pbix) files
├── 05_excel_reports/    # MIS reporting templates
├── 06_docs/             # Data dictionaries and documentation
🚀 How to Run Locally
If you want to replicate my environment, follow these steps:

Bash
# 1. Start the database
docker-compose up -d

# 2. Create the schema
psql -h localhost -U your_user -d MSI_CollectionsDB -f 02_database/01_create_tables.sql

# 3. Generate and load the data
python etl/data_to_pg.py

# 4. Create the KPI views
psql -h localhost -U your_user -d MSI_CollectionsDB -f 02_database/kpi_views.sql
🧠 Future Enhancements
I am continuously looking to improve this environment. My next steps include:

Building a predictive Python model to score the probability of a PTP being kept.

Implementing behavioral clustering for customer segmentation.

Creating a cohort analysis by delinquency stage to track degradation over time.

💡 Final Note
This project is more than just a dashboard—it is a complete simulation of a banking collections ecosystem. It showcases my ability to own the entire data lifecycle, translate complex business processes into relational data models, and build reporting tools that drive strategic action.