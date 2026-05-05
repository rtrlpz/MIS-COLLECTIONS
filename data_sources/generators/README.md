Here is a revised version of the documentation. I have simplified the technical jargon, shortened the paragraphs, and focused on *what it actually does* in plain English. This format is much easier to read, especially for recruiters or non-technical managers.

***

# ⚙️ MIS Collections: Data Generator

## 📖 What is this?
This script (`data_generator_v7.py`) is the engine behind the MIS Collections project. 

Instead of just spitting out random numbers, it acts as an **event-driven simulation** of a real bank's collections department. It tracks individual agents making calls, customers breaking promises, and accounts aging into worse delinquency—all outputted into a clean, Power BI-ready dataset.

---

## ✨ Why this generator is special

*   **It’s Predictable (Reproducible):** By using a "seed," you can run the script 100 times and get the exact same data every time. This is crucial for testing.
*   **It’s Realistic:** It mimics real human behavior. Payments spike on the 15th and at the end of the month (paydays). Agents only make calls during their actual scheduled shifts.
*   **It Tests Your Dashboard:** It deliberately injects fake "errors" (like a call lasting 5 hours) and logs them in an `anomaly_report.csv`. This proves your downstream data cleaning actually works.
*   **It Checks Its Own Work:** Before saving any files, the script runs an automated Quality Assurance (QA) check. If primary keys are missing or numbers don't add up, it stops and warns you.

---

## 🚀 How to use it

You can run the generator directly from your terminal. 

**Quick Start (Default Run):**
Generates data for Oct, Nov, and Dec 2025 using default settings.
```bash
python data_generator_v7.py
```

**Advanced Run (Custom Settings):**
Allows you to change the months, lock the seed, and see detailed logs.
```bash
python data_generator_v7.py --seed 42 --months 10,11 --log-level DEBUG --output-dir ./custom_raw
```

### Command Line Options:
| Command | What it does | Default |
| :--- | :--- | :--- |
| `--seed` | Locks the random numbers so outputs are identical every time. | `42` |
| `--months` | Chooses which months to generate (comma-separated). | `10,11,12` |
| `--output-dir` | Changes where the CSV files are saved. | `./raw` |
| `--log-level` | Changes how much info prints to the screen (`INFO` or `DEBUG`). | `INFO` |

---

## 📂 What it creates (Output Structure)

To mimic a real enterprise database, the generator organizes the output neatly. **Dimensions** (data that rarely changes, like agent names) are saved once. **Facts** (daily events, like calls and payments) are split into monthly folders.

```text
raw/
├── shared/                             # Customer and Agent details
│   ├── Dim_Supervisors.csv
│   ├── Dim_Agents.csv
│   └── ... (Other dimensions)
├── october_2025/                       # Daily events for October
│   ├── Fact_Interactions.csv           # Every call made
│   ├── Fact_Payments.csv               # Every payment received
│   └── ... (Other facts)
├── november_2025/
├── december_2025/
└── anomaly_report.csv                  # List of injected errors for testing
```

---

## 🧠 The Business Rules Simulated

This engine operates on four strict banking rules:

1.  **Promises to Pay (PTP):** When an agent gets a promise, it comes with a grace period. If the customer pays at least 95% of what they promised before the grace period ends, it is marked **Kept**. If not, it is **Broken**.
2.  **Who gets the credit?** If an account pays off its debt because of a recent agent call, it is flagged as an `Agent_Cure`. If the customer pays on their own without being called, it is a `Self_Cure`.
3.  **Strict Billing Cycles:** An account's "Days Past Due" (DPD) doesn't just go up randomly. It only increases if the account remains unpaid on its specific monthly `due_day`.
4.  **Operational Hours:** The Call Center has rules. Agents only interact with customers between 08:00 - 21:00 on weekdays, and 08:00 - 18:00 on Saturdays.