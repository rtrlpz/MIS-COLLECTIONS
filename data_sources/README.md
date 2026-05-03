### 🎲 Data Sources & Generation (Tier 0 Architecture)
This directory contains the Python-based data generation engine. Instead of relying on static, perfect dummy data, this script creates a synthetic but highly realistic Collections ecosystem.

The generator is designed to simulate the specific operational friction found in banking (e.g., late agent logins, varying contact rates, and delayed payments), providing a robust dataset for advanced ETL and attribution testing.

### ⚙️ How It Works
The script (data_generator_v7.py) utilizes the Faker library and custom probability logic to generate five core datasets over a 31-day period (October 2025).

Key Business Logic Simulated:

Agent Noise: 15% of agents log in late, affecting morning "Utilization Alignment."

Contact Reality: A realistic 15-25% connection rate, with RPC (Right Party Contact) success influenced by an assigned "Agent Skill Factor."

Payment Lag (Attribution): Payments resulting from a promise (PTP) occur 1 to 3 days after the call.

Orphan Payments: 25% of all payments are generated with no associated agent_id, simulating organic digital or branch payments.

### 🚀 How to Run the Generator
Ensure you have your Python environment activated and the required dependencies installed (see the root requirements.txt).

Open your terminal and navigate to the project root.

Run the generator script:

Bash
python 01_data_sources/data_generator_v7.py


### ⏱️ Performance & Output
*   **Execution Time:** The script typically completes in **~15 to 30 seconds**, depending on your machine's CPU.
*   **Output Location:** Once complete, a new directory named `scotiabank_refined/` (or your configured output path) will be created inside this folder.
*   **File Volumes:** 
    *   `accounts.csv`: ~10,000 to 15,000 rows.
    *   `dialer_interactions.csv`: ~150,000+ rows (simulating heavy daily dialing).
    *   `ptp_log.csv`, `cures_log.csv`, `agent_time_log.csv`: Variable rows based on interaction outcomes.

