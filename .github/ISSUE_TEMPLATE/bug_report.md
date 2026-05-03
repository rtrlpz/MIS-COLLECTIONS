---
name: Bug report
about: Create a report to help us improve the data pipeline or dashboards
title: "[BUG] "
labels: bug
assignees: ''

---

**Describe the bug**
A clear and concise description of what the bug is. (e.g., "The Capped KP calculation in the SQL view is returning NULL for self-cures.")

**To Reproduce**
Steps to reproduce the behavior:
1. Run the data generator `python 01_data_sources/data_generator_v7.py`
2. Execute the ETL script `load_data.py`
3. Check the `Fact_Payments` table for row ID XYZ
4. See error

**Expected behavior**
A clear and concise description of what you expected to happen. (e.g., "The Capped KP should equal the promised amount if the payment was made within the 3-day window.")

**Screenshots / Code Snippets**
If applicable, add screenshots or SQL snippets to help explain your problem.

**Environment (please complete the following information):**
 - Database: [e.g., PostgreSQL 15, SQL Server 2019]
 - Python Version: [e.g., 3.10]
 - Power BI Desktop Version: [e.g., October 2023]

**Additional context**
Add any other context about the problem here.