# Data Analysis & Business Intelligence

What it does: Turns raw collections data into actionable insights across three organizational levels.

- Operational (Supervisor): Agent-level daily activity, coaching opportunities, schedule adherence, exception reports

- Tactical (Manager): Team comparisons, agent leaderboards, campaign effectiveness, handle time benchmarks, workload distribution

- Strategic (Director): Portfolio health, roll rates, vintage analysis, recovery trends, target vs actual, concentration risk

Output: SQL queries → KPI views → Power BI dashboard + Excel MIS reports
---

# Data Quality & Testing

What it does: Validates the synthetic data and analysis outputs.

- Data Integrity: Foreign key validation, null checks, date range verification, row count expectations

- Generator Tests: Verify synthetic data matches business rules (weekday-only, PTP state machine, DPD logic)

- KPI Validation: Ensure calculated metrics match expected formulas (RPC%, PTP%, cure rates)
---

# Data Documentation & Governance
What it does: Makes the data understandable and auditable.

- Schema Dictionary: Column-level definitions for all 16 tables

- KPI Definitions: Business formulas for every metric (Contact, Promise, Recovery, Productivity)

- Data Dictionary: Full documentation with relationships, constraints, load order

- Context File: Single-source overview for AI-assisted development and team onboarding
---

# Data Infrastructure
What it does: Provides the technical foundation for data operations.

- PostgreSQL 15 (Dockerized) — Production-like database with pgAdmin

- Migrations — Versioned schema changes (001_create_tables, 002_kpi_views, 003_scorecards)

- Seeds — Static lookup data (products, calendar dimensions)

- Pipeline Orchestration — run_pipeline.bat for end-to-end execution on Windows
---

In one sentence: End-to-end data engineering + analytics platform simulating a bank's collections department, from synthetic data generation through PostgreSQL storage to BI dashboards and SQL analysis across three organizational levels.