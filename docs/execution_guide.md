# Execution Guide — MIS Collections Portfolio

> Companion to `ROADMAP.md`. This file answers: **what**, **why**, **how**, and **how to verify** for every task.
> Always read the corresponding roadmap phase first, then drill into this guide for the task you're working on.

---

## How to Use This Guide

Each task entry follows this structure:

```
### Task N: [Short Name]
PURPOSE      -> What this change actually does
WHY          -> Why it matters to the project
WHAT DONE    -> How to know the task is complete
PROMPT       -> Exact text to paste into OpenCode
VERIFY       -> Command or check to run after the edit
COMMIT       -> Suggested commit message
```

**Workflow:** Read PURPOSE + WHY -> paste PROMPT into OpenCode -> review the generated code -> run VERIFY -> COMMIT.

---

# PHASE 1 — Data Generation

> **Goal:** Make the generator reproducible, configurable, and self-validating.
> **Current:** 70% -> **Target:** 95%

---

### Task 1: Add `--output-dir` and `--months` CLI Parameters

**PURPOSE** -> Replace hardcoded paths and fixed month range with command-line arguments. Currently the generator always outputs to `data_sources/generators/raw` and always generates Oct-Dec 2025.

**WHY** -> A reviewer or future you may want to generate data in a temporary folder, or generate only one month for testing. CLI flags make the tool flexible without modifying source code.

**WHAT DONE** -> Running `python data_generator_v7.py` works exactly as before (backwards compatible). Running with `--output-dir /tmp/test --months 10,11` generates only October and November CSVs in `/tmp/test`.

**PROMPT:**
```
In data_sources/generators/data_generator_v7.py, add argparse with three flags:
  --output-dir (string, default: current OUTPUT_DIR value)
  --months (comma-separated integers, default: "10,11,12")
  --seed (integer, default: None)

Override the CFG dict values based on CLI args before generation starts.
Keep all existing behavior as the default so nothing breaks.
Add the argparse code near the top, right after the CFG definition.
```

**VERIFY:** `python data_generator_v7.py --help` shows the new flags. `python data_generator_v7.py --seed 42 --months 10 --output-dir ./test-out` generates data in `./test-out` with only October dates.

**COMMIT:** `feat: add CLI arguments --output-dir, --months, --seed`

---

### Task 2: Generate CSVs with Headers and Explicit DTypes

**PURPOSE** -> Ensure every CSV export uses consistent formatting: ISO 8601 dates (`2025-10-01`), 2 decimal places for currency, consistent boolean representation (`True`/`False`).

**WHY** -> The ETL pipeline (`data_to_pg.py`) reads these CSVs with `pandas.read_csv()`. If date formatting varies between files, PostgreSQL ingest fails or corrupts data. Consistent types at generation = reliable downstream processing.

**WHAT DONE** -> Every CSV has a header row. All dates are `YYYY-MM-DD`. All currency columns have exactly 2 decimal places. No scientific notation (no `1.5e+04`).

**PROMPT:**
```
In data_sources/generators/data_generator_v7.py, find all DataFrame.to_csv() calls.
Ensure each one produces:
  - ISO 8601 dates: use date_format='%Y-%m-%d'
  - Currency columns (balance, arrears, amounts): format to 2 decimal places before export
  - No scientific notation for numeric columns
  - Header row present (header=True, which should already be the case)

Apply these formatting rules consistently across all CSV exports.
```

**VERIFY:** Open any generated CSV (e.g., `Dim_Accounts.csv`). Check that dates look like `2025-10-15`, balances look like `12345.67`, and there's a header row on line 1.

**COMMIT:** `feat: enforce consistent CSV formatting with ISO dates and fixed decimals`

---

### Task 3: Add Generator Logging

**PURPOSE** -> Replace ad-hoc `print()` statements with Python's `logging` module. Emit structured output: start/end timestamps, row counts per table, total generation time, anomaly count.

**WHY** -> When the generator runs for 30+ seconds, you need visibility into what happened. Logging also enables the pipeline script (Phase 7) to capture output to a file for audit trails.

**WHAT DONE** -> Running the generator produces timestamped `[INFO]` lines on console. Logs are also written to `data_sources/generators/logs/generator.log` with DEBUG-level detail (daily simulation progress). A `--log-level` flag controls console verbosity (INFO/DEBUG/WARNING/ERROR). At the end, a summary shows total time and rows generated per table plus anomaly count.

**PROMPT:**
```
In data_sources/generators/data_generator_v7.py, replace all print() statements with Python's logging module.
Configure logging with two handlers:
  1. Console handler (StreamHandler, level=INFO): short timestamps "%H:%M:%S"
  2. File handler (FileHandler, level=DEBUG): full timestamps, writes to data_sources/generators/logs/generator.log

Add a --log-level CLI arg to control console verbosity.

Add logging for:
  - Generation start (output dir, date range, seed)
  - Each dimension/fact table generated (table name + row count)
  - Total anomalies injected
  - Generation complete + total elapsed time (use time.time())

Keep the output clean and readable. Use logging.info() for normal flow.
```

**VERIFY:** `python data_generator_v7.py` produces formatted `[INFO]` lines with timestamps and a timing summary at the end. `data_sources/generators/logs/generator.log` exists with full DEBUG-level output including daily progress. `--log-level DEBUG` shows per-day stats on console.

**COMMIT:** `feat: replace print statements with structured logging module`

---

### Task 4: Add Output Validation Post-Generation

**PURPOSE** -> After generating all CSVs, run a self-check pass that reads the files back and validates: row counts within +/-5% of expected, no nulls in PK columns, FK values exist in referenced dimension tables.

**WHY** -> Catches data corruption at the source. If the generator creates accounts referencing a `client_id` that doesn't exist in `Dim_Clients`, you want to know immediately -- not when the ETL fails or the dashboard shows wrong numbers.

**WHAT DONE** -> After generation completes, a validation block prints `[PASS]`/`[FAIL]` for 21 checks (row counts, PK nulls, dimension FK integrity, fact table completeness, fact FK integrity). The script exits with `sys.exit(1)` if any check fails.

**PROMPT:**
```
In data_sources/generators/data_generator_v7.py, add a validate_output(output_dir) function that runs after all CSVs are written.
It should:
  1. Read each CSV back with pandas
  2. Check row counts: Dim_Supervisors=8, Dim_Agents=80, Dim_Clients=10000, Dim_Accounts~=20000 (+/-5% tolerance for fact tables)
  3. Check no null values in PK columns (e.g., agent_id in Dim_Agents, account_id in Dim_Accounts)
  4. Check FK integrity: every supervisor_id in Dim_Agents exists in Dim_Supervisors, every client_id in Dim_Accounts exists in Dim_Clients, etc.
  5. Check fact tables have rows and their FK columns reference valid dimension entries
  6. Print [PASS] or [FAIL] for each check with a brief description
  7. Return True if all pass, False otherwise

Call this function at the end of main() and exit with sys.exit(1) if validation fails.
Use logging.info for validation messages.
```

**VERIFY:** `python data_generator_v7.py` shows a validation section at the end with all `[PASS]` lines (21 checks). Test a failure by temporarily breaking a FK in the generator code and confirming it prints `[FAIL]` and exits with code 1.

**COMMIT:** `feat: add post-generation validation with row count, PK, and FK integrity checks`

---

### Task 5: Create `__init__.py` Package Files

**PURPOSE** -> Create empty `__init__.py` files in `data_sources/` and `data_sources/generators/` to make them proper Python packages.

**WHY** -> Allows `from data_sources.generators.config import CFG` style imports. Standard Python convention that signals "this directory is an importable module." Required for Task 8 (config extraction) to work cleanly.

**WHAT DONE** -> Two empty files exist: `data_sources/__init__.py` and `data_sources/generators/__init__.py`.

**PROMPT:**
```
Create two empty files:
  data_sources/__init__.py
  data_sources/generators/__init__.py
```

**VERIFY:** `python -c "from data_sources.generators import data_generator_v7"` runs without error.

**COMMIT:** `chore: add __init__.py files to make data_sources a Python package`

---

### Task 6: Centralize Configuration into `config.py`

**PURPOSE** -> Extract the `CFG` dictionary and `PRODUCT_CFG` dictionary from `data_generator_v7.py` into a separate file `data_sources/generators/config.py`.

**WHY** -> Separation of concerns. Configuration should be separate from generation logic. If someone wants to tweak parameters (e.g., change mora rate from 0.25 to 0.30), they shouldn't need to navigate 810 lines of code. Also makes the config importable by tests and validation scripts.

**WHAT DONE** -> `config.py` contains `CFG` and `PRODUCT_CFG`. The generator imports them with `from .config import CFG, PRODUCT_CFG`. Running the generator produces identical output as before.

**PROMPT:**
```
In data_sources/generators/:
  1. Create a new file config.py containing the CFG dict and PRODUCT_CFG dict from data_generator_v7.py
  2. In data_generator_v7.py, remove those two dicts and replace with:
     from .config import CFG, PRODUCT_CFG
  3. Ensure the generator still works identically after this change.
```

**VERIFY:** `python data_generator_v7.py --seed 42` generates data. Compare output to a previous run with the same seed -- should be identical.

**COMMIT:** `refactor: extract CFG and PRODUCT_CFG into config.py`

---

### Task 7: Add Anomaly Injection Report

**PURPOSE** -> The generator already injects anomalies (`anomaly_prob: 0.018` in config). This task tracks each anomaly and exports a report CSV: `anomaly_report.csv`.

**WHY** -> In a real bank, you'd audit outliers. For your portfolio, it demonstrates data quality awareness and gives reviewers insight into what edge cases exist in the synthetic data.

**WHAT DONE** -> After generation, `anomaly_report.csv` exists in the output directory with columns: `anomaly_id`, `table`, `record_id`, `anomaly_type`, `value`, `expected_range`.

**PROMPT:**
```
In data_sources/generators/data_generator_v7.py, find where anomalies are currently injected (search for anomaly_prob or anomaly_mul).
Add an anomalies_tracking list that records each anomaly as a dict with keys:
  anomaly_id, table, record_id, anomaly_type, value, expected_range

At the end of generation, after all CSVs are written, export this list to anomaly_report.csv in the output directory.
Include it in the logging output: "Anomaly report written: X anomalies tracked"
```

**VERIFY:** `python data_generator_v7.py` generates `anomaly_report.csv` in the output folder. Open it and confirm it has rows with meaningful data.

**COMMIT:** `feat: add anomaly tracking and anomaly_report.csv export`

---

### Task 8: Add `requirements.txt` with Pinned Versions

**PURPOSE** -> List all Python dependencies with exact versions so anyone can recreate the environment.

**WHY** -> If your generator works with `pandas==2.1.4` but someone installs `pandas==2.2.0` and it breaks, that's a dependency issue. Pinning versions guarantees the project works for anyone who clones it.

**WHAT DONE** -> `requirements.txt` exists with pinned versions for: faker, pandas, numpy, python-dotenv, psycopg2-binary, openpyxl.

**PROMPT:**
```
Read the current requirements.txt (if it exists) and the imports in data_generator_v7.py, database/etl/data_to_pg.py.
Update requirements.txt with pinned versions for all dependencies used in the project:
  faker, pandas, numpy, python-dotenv, psycopg2-binary, openpyxl
Use the format: package==X.Y.Z
```

**VERIFY:** `pip install -r requirements.txt` installs all packages without errors in a fresh virtual environment.

**COMMIT:** `chore: pin dependency versions in requirements.txt`

---

### Task 9: Add `data_sources/generators/README.md`

**PURPOSE** -> Document how to use the generator: prerequisites, CLI flags, output description, configuration reference.

**WHY** -> Anyone cloning your repo needs to generate data without reading 810 lines of Python. This is the first file they'll read after the root README.

**WHAT DONE** -> A clean markdown file with: quick start, CLI reference, output structure, configuration parameters, anomaly explanation.

**PROMPT:** (Write this yourself -- you now know every detail about the generator.)

**VERIFY:** A teammate with no context can run the generator using only this README.

**COMMIT:** `docs: add generator README with usage and configuration reference`

---

# PHASE 2 — ETL Pipeline

> **Goal:** Make data ingestion reliable, observable, and idempotent.
> **Current:** 35% -> **Target:** 90%

---

### Task 1: Add Logging to ETL Script

**PURPOSE** -> Replace `print()` statements in `database/etl/data_to_pg.py` with Python's `logging` module. Use INFO for progress, ERROR for failures, with timestamps.

**WHY** -> The current script mixes Spanish and English print statements with emojis. Logging provides structured, searchable output that can be captured to a file by the pipeline script.

**WHAT DONE** -> All output uses `logging.info()` or `logging.error()`. Format: `[INFO] 2025-05-04 10:30:00 - Ingesting dim_agents...`

**PROMPT:**
```
In database/etl/data_to_pg.py, replace all print() statements with Python's logging module.
Configure logging at the top:
  logging.basicConfig(level=logging.INFO, format='[%(levelname)s] %(asctime)s - %(message)s', datefmt='%Y-%m-%d %H:%M:%S')

Use logging.info() for progress messages (connection, table loads, completion).
Use logging.error() for errors (file not found, connection failure, ingestion errors).
Remove emojis from messages. Keep the logic identical.
```

**VERIFY:** `python database/etl/data_to_pg.py` produces clean timestamped log lines. No emojis, no raw prints.

**COMMIT:** `refactor: replace print statements with logging in ETL script`

---

### Task 2: Add Data Validation on Ingest

**PURPOSE** -> Before loading each CSV into PostgreSQL, validate: file exists, has headers, row count > 0, PK column has no nulls.

**WHY** -> Currently if a CSV is missing or malformed, the ETL either crashes with an opaque error or silently loads bad data. Pre-load validation catches problems early with clear messages.

**WHAT DONE** -> Each table load prints `[VALIDATING] <table>...` then `[OK]` or `[FAIL] <reason>`. Failed tables are skipped with a clear error.

**PROMPT:**
```
In database/etl/data_to_pg.py, add a validate_csv(file_path, table_name) function that checks:
  1. File exists
  2. Has headers (first line is not empty)
  3. Row count > 0
  4. Primary key column (match column name to table: agent_id for dim_agents, etc.) has no null values

Call this function before ingest_data_to_pg() for each CSV.
If validation fails, log an error and skip that file (don't crash).
If validation passes, proceed with ingest.
Define PK column mapping:
  dim_supervisors: supervisor_id
  dim_agents: agent_id
  dim_clients: client_id
  dim_products: product_id
  dim_accounts: account_id
  fact_interactions: interaction_id
  fact_ptp_log: ptp_id
  fact_payments: payment_id
  fact_agent_time_log: log_id
For fact_eom_snapshot, validate both snapshot_date and account_id are not null.
```

**VERIFY:** Create an empty CSV file for one table, run ETL, confirm it prints a validation error and skips that table without crashing.

**COMMIT:** `feat: add pre-load CSV validation to ETL pipeline`

---

### Task 3: Add Transaction Wrapping

**PURPOSE** -> Wrap the entire ETL load in a single PostgreSQL transaction. If ANY table fails, ROLLBACK everything. Currently, partial loads can leave the database in an inconsistent state.

**WHY** -> If 5 of 11 tables load successfully but the 6th fails, your database has incomplete data. Transaction wrapping guarantees atomicity: all or nothing.

**WHAT DONE** -> If table 6 fails, tables 1-5 are rolled back. The database is exactly as it was before the ETL started.

**PROMPT:**
```
In database/etl/data_to_pg.py, wrap the entire table loading loop (inside main()) in a single transaction.
Remove the conn.commit() and conn.rollback() calls from inside ingest_data_to_pg().
Instead:
  - After ALL tables load successfully, call conn.commit() once
  - If ANY table fails, call conn.rollback() in the except block
This ensures atomicity: either all tables load, or none do.

Also, pass the cursor from main() instead of creating a new one per table to stay within the same transaction.
```

**VERIFY:** Run ETL, then temporarily break one table's CSV (e.g., add a bad value). Run ETL again. Confirm that NO tables were loaded (the rollback worked).

**COMMIT:** `feat: wrap entire ETL in single transaction for atomicity`

---

### Task 4: Add Idempotency

**PURPOSE** -> Before loading each table, TRUNCATE it so re-runs produce clean state. Running the ETL twice should not duplicate rows.

**WHY** -> Currently running ETL twice would insert duplicate data. Idempotency means "running it N times = same result as running it once." Essential for reliable pipelines.

**WHAT DONE** -> `python data_to_pg.py` run twice produces the same row counts. No duplicates.

**PROMPT:**
```
In database/etl/data_to_pg.py, add a TRUNCATE TABLE <name> CASCADE command before loading each table.
Use cursor.execute(f"TRUNCATE TABLE {pg_table_name} CASCADE") right before cursor.copy_from().
This ensures re-runs start from a clean slate.
Handle the case where the table doesn't exist yet (use TRUNCATE only if table exists, or catch the error).
```

**VERIFY:** Run ETL twice. After each run, check row counts in PostgreSQL: `SELECT count(*) FROM dim_agents;` -- should be identical both times.

**COMMIT:** `feat: add TRUNCATE before load for ETL idempotency`

---

### Task 5: Add Environment Variable Support

**PURPOSE** -> Ensure all DB credentials come from `.env` via `python-dotenv`. Currently the script already does this partially -- this task makes it explicit and adds a `--env-file` flag.

**WHY** -> Credentials should never be hardcoded. The `.env` approach is standard for Python projects and works with Docker Compose.

**WHAT DONE** -> `python data_to_pg.py` reads `.env` automatically. `python data_to_pg.py --env-file .env.production` reads from a different file.

**PROMPT:**
```
In database/etl/data_to_pg.py, add argparse with --env-file flag (default: .env in the script's directory).
Load the specified env file with load_dotenv(env_file_path).
Keep all existing credential loading via os.getenv().
Add a check: if any required env var is missing, print a clear error listing which ones are missing.
```

**VERIFY:** Rename your `.env` to `.env.backup`, run ETL, confirm it errors with "missing credentials." Restore `.env`, run again, confirm it works.

**COMMIT:** `feat: add --env-file flag for flexible credential loading`

---

### Task 6: Add `--dry-run` Flag

**PURPOSE** -> Validate all CSV files without actually loading them into PostgreSQL. Useful for CI/CD or pre-flight checks.

**WHY** -> Lets you verify data quality before touching the database. Especially valuable before a production load.

**WHAT DONE** -> `python data_to_pg.py --dry-run` runs all validations, prints what WOULD be loaded, then exits without connecting to the database.

**PROMPT:**
```
In database/etl/data_to_pg.py, add a --dry-run flag via argparse.
When --dry-run is True:
  - Skip database connection entirely
  - Run all CSV validations (file exists, headers, row count > 0, PK not null)
  - Print what would be loaded: table name, file path, row count
  - Exit with 0 if all validations pass, 1 if any fail
```

**VERIFY:** `python data_to_pg.py --dry-run` prints a summary of all CSVs that would be loaded without touching the database.

**COMMIT:** `feat: add --dry-run flag for pre-flight CSV validation`

---

### Task 7: Add `--incremental` Flag

**PURPOSE** -> Load only CSVs from months that aren't already in the database. Skip months that have been loaded before.

**WHY** -> If you generate data for October, load it, then generate November+December, you don't want to reload October. Incremental loading saves time.

**WHAT DONE** -> `python data_to_pg.py --incremental` checks which months exist in the database, loads only new ones.

**PROMPT:**
```
In database/etl/data_to_pg.py, add an --incremental flag via argparse.
When --incremental is True:
  - Connect to the database
  - Query which months already exist in fact_interactions (SELECT DISTINCT EXTRACT(MONTH FROM interaction_date) ...)
  - For transactional tables, skip CSVs from months that are already loaded
  - For shared/dimension tables, always load them (they're static)
  - Log which months are being skipped and which are being loaded
```

**VERIFY:** Load October data normally. Run with `--incremental` -- should only load November and December. Run again with `--incremental` -- should report "all months already loaded."

**COMMIT:** `feat: add --incremental flag to skip already-loaded months`

---

### Task 8: Add ETL Load Log Metadata Table

**PURPOSE** -> Create an `etl_load_log` table in the database. After each ETL run, insert a row per table with: table name, rows loaded, timestamp, status (success/fail), CSV checksum.

**WHY** -> Provides an audit trail of all data loads. Answers: "When was the last time this table was loaded? How many rows? Was it successful?"

**WHAT DONE** -> After ETL runs, `SELECT * FROM etl_load_log ORDER BY loaded_at DESC;` shows a history of all loads.

**PROMPT:**
```
In database/etl/data_to_pg.py:
  1. At the start of main(), create the etl_load_log table if it doesn't exist:
     CREATE TABLE IF NOT EXISTS etl_load_log (
       id SERIAL PRIMARY KEY,
       table_name VARCHAR(100),
       rows_loaded INT,
       loaded_at TIMESTAMP DEFAULT NOW(),
       status VARCHAR(20),
       csv_checksum VARCHAR(64)
     );
  2. After each table loads (or fails), INSERT a row into etl_load_log.
  3. Compute the CSV checksum using hashlib.sha256 on the file content.
  4. Log the checksum in the etl_load_log row.
```

**VERIFY:** Run ETL, then `SELECT * FROM etl_load_log;` in psql. Should show one row per loaded table with timestamps and checksums.

**COMMIT:** `feat: add etl_load_log metadata table for load audit trail`

---

### Task 9: Add Retry Logic with Backoff

**PURPOSE** -> If a database connection fails or a table load errors, retry up to 3 times with 5-second intervals between attempts.

**WHY** -> Transient network issues or brief database unavailability shouldn't kill the entire pipeline. Retry logic adds resilience.

**WHAT DONE** -> If the first connection attempt fails, the script retries 2 more times before giving up with a clear error.

**PROMPT:**
```
In database/etl/data_to_pg.py, add retry logic to the database connection in main():
  - Try to connect up to 3 times
  - Wait 5 seconds between attempts (use time.sleep(5))
  - If all 3 attempts fail, log a fatal error and exit
Use a simple for loop with range(3) and break on success.
```

**VERIFY:** Stop Docker (`docker compose down`), run ETL, confirm it retries 3 times then fails with a clear message. Start Docker, run again, confirm it connects on the first try.

**COMMIT:** `feat: add retry logic with backoff for database connection`

---

### Task 10: Add Error Recovery

**PURPOSE** -> When a table load fails, write the problematic rows to `errors/<table>_errors.csv` instead of losing them.

**WHY** -> If 9,999 of 10,000 client rows are valid but 1 has a malformed date, you want to save the bad row for investigation, not discard the entire file.

**WHAT DONE** -> After a failed load, an `errors/` directory contains CSVs with the rows that caused failures.

**PROMPT:**
```
In database/etl/data_to_pg.py, add error recovery:
  1. Create an errors/ directory if it doesn't exist (relative to the ETL script)
  2. When ingest_data_to_pg() fails for a table, write the problematic DataFrame to errors/<table_name>_errors.csv
  3. Log where the error file was saved
  4. Continue with the next table (don't stop the entire pipeline for one bad table)

Note: Since we wrapped everything in a transaction (Task 3), error recovery should work at the per-table level before the final commit.
Consider using savepoints (cursor.execute("SAVEPOINT sp")) per table so one bad table doesn't rollback the others.
```

**VERIFY:** Create a CSV with one bad row, run ETL, confirm the bad rows are saved to `errors/<table>_errors.csv` and the rest of the pipeline continues.

**COMMIT:** `feat: add error recovery with per-table savepoints and error CSV export`

---

### Task 11: Add Pipeline Orchestration to `run_pipeline.bat`

**PURPOSE** -> Update the empty `run_pipeline.bat` to call: generator -> ETL -> validation in sequence.

**WHY** -> Currently the pipeline script is empty. This is the single entry point for running the full data pipeline on Windows.

**WHAT DONE** -> Double-clicking `run_pipeline.bat` generates data, loads it into PostgreSQL, and reports success or failure.

**PROMPT:**
```
Write a run_pipeline.bat script that:
  1. Checks if Docker is running (docker info >nul 2>&1)
  2. Generates data: python data_sources/generators/data_generator_v7.py
  3. Checks generator exit code, exits if failed
  4. Runs ETL: python database/etl/data_to_pg.py
  5. Checks ETL exit code, exits if failed
  6. Prints a summary: "Pipeline complete. Data generated and loaded."
  7. Pauses at the end so the user can see the output

Use color codes if possible (green for success, red for errors).
```

**VERIFY:** Run `run_pipeline.bat`. Confirm it executes each step in order and reports success or failure.

**COMMIT:** `feat: add pipeline orchestration to run_pipeline.bat`

---

# PHASE 3 — Database & Schema (Merged with Phase 5: KPI Views)

> **Goal:** Index the schema for performance, define KPI views, add constraints, and document the database.
> **Current:** 60% -> **Target:** 90%

---

### Task 1: Add Indexes on FK Columns

**PURPOSE** -> Create B-tree indexes on all foreign key columns. Currently queries that join fact tables to dimensions do full table scans.

**WHY** -> FK columns are used in JOINs constantly (e.g., `fact_interactions JOIN dim_agents ON agent_id`). Without indexes, every JOIN scans the entire table. Indexes speed up queries by 10-100x.

**WHAT DONE** -> Running a query that joins `fact_interactions` to `dim_agents` uses an Index Scan instead of a Seq Scan (verify with `EXPLAIN`).

**PROMPT:**
```
Create database/migrations/004_indexes.sql with CREATE INDEX statements for all FK columns:
  - dim_agents(supervisor_id)
  - dim_accounts(client_id)
  - dim_accounts(product_id)
  - fact_interactions(agent_id)
  - fact_interactions(account_id)
  - fact_interactions(interaction_date)
  - fact_ptp_log(agent_id)
  - fact_ptp_log(account_id)
  - fact_ptp_log(ptp_date)
  - fact_payments(account_id)
  - fact_payments(payment_date)
  - fact_payments(agent_id)
  - fact_agent_time_log(agent_id)
  - fact_agent_time_log(log_date)
  - fact_eom_snapshot(account_id)
  - fact_eom_snapshot(snapshot_date)

Use CREATE INDEX IF NOT EXISTS idx_<table>_<column> ON <table>(<column>);
Add a comment at the top explaining the purpose of the file.
```

**VERIFY:** `psql -f database/migrations/004_indexes.sql` runs without errors. Run `EXPLAIN SELECT * FROM fact_interactions JOIN dim_agents USING (agent_id);` -- should show "Index Scan" not "Seq Scan."

**COMMIT:** `feat: add indexes on all FK columns for query performance`

---

### Task 2: Add Indexes on Common Query Columns

**PURPOSE** -> Create indexes on date columns and other frequently queried columns used in WHERE clauses and GROUP BY.

**WHY** -> Every analysis query filters by date (`WHERE interaction_date BETWEEN ...`). Date indexes make time-range queries fast.

**WHAT DONE** -> Queries filtering by date use Index Scan.

**PROMPT:**
```
Append to database/migrations/004_indexes.sql additional indexes for common query patterns:
  - fact_interactions(rpc_flag) -- for filtering connected vs not connected
  - fact_ptp_log(status) -- for filtering kept/broken PTPs
  - fact_payments(is_cured) -- for filtering cured accounts
  - fact_agent_time_log(utilization) -- for utilization range queries
  - fact_eom_snapshot(dpd_bucket) -- for DPD bucket grouping

Use CREATE INDEX IF NOT EXISTS with descriptive names.
```

**VERIFY:** `EXPLAIN SELECT * FROM fact_ptp_log WHERE status = 'Kept';` -- should show Index Scan.

**COMMIT:** `feat: add indexes on common filter columns (status, flags, buckets)`

---

### Task 3: Add Composite Indexes

**PURPOSE** -> Create multi-column indexes for queries that filter on two columns together, e.g., `(agent_id, interaction_date)`.

**WHY** -> A composite index on `(agent_id, interaction_date)` is faster than two separate indexes for queries like "get all interactions for agent X in date range Y."

**WHAT DONE** -> Queries filtering by agent + date together use the composite index.

**PROMPT:**
```
Append to database/migrations/004_indexes.sql:
  - fact_interactions(agent_id, interaction_date) -- for per-agent daily queries
  - fact_ptp_log(agent_id, ptp_date) -- for per-agent PTP tracking
  - fact_agent_time_log(agent_id, log_date) -- for per-agent daily utilization
  - fact_eom_snapshot(account_id, snapshot_date) -- for account history
  - dim_agents(supervisor_id, agent_id) -- for team lookups
  - dim_accounts(product_id, client_id) -- for product-based client queries

Use CREATE INDEX IF NOT EXISTS with descriptive names.
```

**VERIFY:** `EXPLAIN SELECT * FROM fact_interactions WHERE agent_id = 'AGT_001' AND interaction_date BETWEEN '2025-10-01' AND '2025-10-31';` -- should use the composite index.

**COMMIT:** `feat: add composite indexes for common query patterns`

---

### Task 4: Add CHECK Constraints

**PURPOSE** -> Enforce data integrity at the database level: `DPD >= 0`, `utilization BETWEEN 0 AND 100`, `call_duration > 0`.

**WHY** -> Prevents invalid data from being inserted. If someone tries to insert a negative DPD or 150% utilization, PostgreSQL rejects it with a clear error. This is the last line of defense against bad data.

**WHAT DONE** -> Attempting to insert `DPD = -5` fails with a constraint violation error.

**PROMPT:**
```
Create database/migrations/003_constraints.sql with ALTER TABLE ADD CONSTRAINT statements:
  - fact_interactions: CHECK (calls_attempted >= 0), CHECK (calls_connected >= 0), CHECK (aht_seconds > 0), CHECK (acw_seconds >= 0)
  - fact_ptp_log: CHECK (promised_amount > 0)
  - fact_payments: CHECK (amount_paid > 0), CHECK (dpd_at_payment >= 0)
  - fact_agent_time_log: CHECK (utilization BETWEEN 0 AND 100), CHECK (operational_hours >= 0), CHECK (break_minutes >= 0)
  - fact_eom_snapshot: CHECK (dpd >= 0), CHECK (balance >= 0), CHECK (arrears >= 0)
  - dim_accounts: CHECK (initial_balance >= 0), CHECK (min_payment >= 0), CHECK (due_day BETWEEN 1 AND 31)

Use ALTER TABLE <table> ADD CONSTRAINT chk_<table>_<column> CHECK (...);
```

**VERIFY:** `psql -f database/migrations/003_constraints.sql` runs without errors. Then try: `INSERT INTO fact_agent_time_log (...) VALUES (..., 150, ...);` -- should fail with constraint violation.

**COMMIT:** `feat: add CHECK constraints for data integrity`

---

### Task 5: Add COMMENT ON TABLE/COLUMN

**PURPOSE** -> Add descriptive comments to every table and column in the database using PostgreSQL's COMMENT ON syntax.

**WHY** -> Comments appear in pgAdmin, psql `\d` commands, and are queryable via `pg_description`. They serve as in-database documentation so anyone exploring the schema understands what each column means.

**WHAT DONE** -> Running `\d dim_agents` in psql shows descriptions for every column.

**PROMPT:**
```
Create database/migrations/005_comments.sql with COMMENT ON statements for all 11 tables and their columns.
Example format:
  COMMENT ON TABLE dim_agents IS 'Collection agents with supervisor assignment, skill score, and hire date';
  COMMENT ON COLUMN dim_agents.agent_id IS 'Unique agent identifier (format: AGT_XXX)';
  COMMENT ON COLUMN dim_agents.skill_score IS 'Agent performance score (0.000-1.000)';

Generate comments for every table and every column based on the schema in 001_create_tables.sql.
Keep comments concise but descriptive -- explain what the column stores, not just its name.
```

**VERIFY:** `psql -f database/migrations/005_comments.sql` runs. Then `\d+ dim_agents` in psql shows column descriptions.

**COMMIT:** `feat: add COMMENT ON for all tables and columns`

---

### Task 6: Create Seed SQL Scripts

**PURPOSE** -> Generate `seeds/001_dim_products.sql` (INSERT 3 products) and `seeds/002_dim_calendar.sql` (INSERT full 2025 calendar with flags).

**WHY** -> Currently these tables are populated by the Python generator and ETL. Seed scripts allow loading static reference data directly into PostgreSQL without running the full pipeline. Useful for testing and fresh database setup.

**WHAT DONE** -> `psql -f seeds/001_dim_products.sql` inserts 3 products. `psql -f seeds/002_dim_calendar.sql` inserts 365 date rows with weekday, quarter, payday flags.

**PROMPT:**
```
Create two seed scripts in database/seeds/:

1. 001_dim_products.sql -- INSERT 3 rows matching PRODUCT_CFG in config.py:
   - Credit Card Standard (Tarjeta, 25.99%, 25 grace days, 2% of Balance)
   - Personal Loan 5yr (Prestamo, 12.50%, 0 grace days, Fixed Monthly Installment)
   - Mortgage 30yr (Hipoteca, 6.75%, 15 grace days, Fixed Monthly Installment)

2. 002_dim_calendar.sql -- INSERT 365 rows for all of 2025:
   - date, year, quarter, month_num, month_name, iso_week, day_of_week, day_name
   - is_weekday (TRUE Mon-Fri, FALSE Sat-Sun)
   - is_month_end (TRUE on last day of each month)
   - is_payday_week (TRUE for weeks containing the 15th and last day of month)
   - payday_factor (1.0 normal, 1.3 on payday weeks)

Use INSERT INTO ... VALUES (...), (...), ...; format for efficiency.
```

**VERIFY:** `psql -f database/seeds/001_dim_products.sql` then `SELECT count(*) FROM dim_products;` = 3. Same for calendar: `SELECT count(*) FROM dim_calendar;` = 365.

**COMMIT:** `feat: add seed scripts for dim_products and dim_calendar`

---

### Task 7: Populate KPI Views in `002_kpi_views.sql`

**PURPOSE** -> Write 7 SQL views that compute collections KPIs. These views are the single source of truth for all analysis queries, the Power BI dashboard, and Excel reports.

**WHY** -> Every downstream consumer (analysis SQL files, dashboard, reports) queries these views instead of raw tables. This centralizes business logic -- if the RPC% formula changes, you update one view, not 17 analysis files.

**WHAT DONE** -> Each view exists in the database and returns correct results. `SELECT * FROM v_contact_metrics LIMIT 10;` works.

**PROMPT:** (Do this one view at a time. Start with the first, verify, then move to the next.)

```
Write the v_contact_metrics view in database/migrations/002_kpi_views.sql:
  - Joins: fact_interactions + dim_agents + dim_supervisors + dim_calendar
  - Metrics per agent per day:
    - total_calls: SUM(calls_attempted)
    - connected_calls: SUM(calls_connected)
    - rpc_count: SUM(CASE WHEN rpc_flag THEN 1 ELSE 0 END)
    - rpc_pct: rpc_count * 100.0 / NULLIF(connected_calls, 0)
    - rpc_arrears_total: SUM(rpc_arrears)
  - Group by: agent_id, agent_name, supervisor_id, team_name, interaction_date, month_num
  - Also aggregate at team level (supervisor_id, interaction_date) and month level
Include all 3 granularities in the view using GROUPING SETS or separate CTEs.
```

**VERIFY:** `psql -f database/migrations/002_kpi_views.sql` runs. `SELECT * FROM v_contact_metrics WHERE granularity = 'agent' LIMIT 5;` returns sensible data.

**COMMIT:** `feat: populate v_contact_metrics KPI view`

---

### v_promise_metrics

```
Write v_promise_metrics:
  - Joins: fact_ptp_log + dim_agents + dim_supervisors + dim_calendar
  - Metrics: ptp_count, ptp_pct (ptp_count / NULLIF(rpc_count, 0)), kept_count, broken_count, kept_pct, bucket_conversion
  - Group by agent/day, team/day, and month
  - Status values: 'Kept', 'Broken', 'Scheduled'
```

### v_recovery_metrics

```
Write v_recovery_metrics:
  - Joins: fact_payments + fact_ptp_log + dim_accounts + dim_products + dim_calendar
  - Metrics: cure_count, cured_amount, cure_rate, agent_cure_count, self_cure_count
  - Distinguish agent-driven cures (agent_id IS NOT NULL) from self-cures (agent_id IS NULL)
  - Group by product/day, agent/day, and month
```

### v_productivity_metrics

```
Write v_productivity_metrics:
  - Joins: fact_agent_time_log + fact_interactions + dim_agents + dim_supervisors + dim_calendar
  - Metrics: utilization_pct, contacts_per_agent_hour, no_touch_letter_rate
  - no_touch_letter_rate = 1 - (letters_sent / accounts_assigned) -- approximate from available data
  - Group by agent/day, team/day, and month
```

### v_handle_time_metrics

```
Write v_handle_time_metrics:
  - Joins: fact_interactions + fact_agent_time_log + dim_agents + dim_calendar
  - Metrics: avg_aht_rpc, avg_aht_nonrpc, avg_acw_rpc, avg_acw_nonrpc
  - Separate RPC and non-RPC handle times
  - Group by agent/day, team/day, and month
```

### v_daily_mis

```
Write v_daily_mis:
  - Consolidated daily view combining all KPI categories
  - One row per agent per day with all metrics: contact, promise, recovery, productivity, handle time
  - This view feeds the Excel MIS report template
```

### v_monthly_summary

```
Write v_monthly_summary:
  - Month-level rollup of all KPIs
  - One row per agent per month (or team per month, or portfolio per month)
  - Used for dashboard trend lines and MoM comparisons
```

---

### Task 8: Populate Agent Scorecard View in `003_agents_scorecards.sql`

**PURPOSE** -> Create a composite score for each agent combining multiple KPIs with weights. Rank agents within their team.

**WHY** -> Provides a single number to compare agent performance. The scorecard view feeds the `agent_scorecard.sql` analysis file and the Power BI leaderboard.

**WHAT DONE** -> `SELECT * FROM v_agent_scorecards ORDER BY composite_score DESC;` returns ranked agents with individual component scores.

**PROMPT:**
```
Write database/migrations/003_agents_scorecards.sql creating a view v_agent_scorecards:
  - Composite score = weighted combination of:
    - rpc_pct * 0.25 (25% weight)
    - kept_pct * 0.25 (25% weight)
    - cure_rate * 0.20 (20% weight)
    - utilization * 0.15 (15% weight)
    - inverse_aht * 0.15 (15% weight -- lower AHT is better, so invert)
  - Normalize each component to 0-100 scale before weighting
  - Rank agents within their team using RANK() OVER (PARTITION BY supervisor_id ORDER BY composite_score DESC)
  - Include individual component scores for transparency
  - Group by agent and month for monthly scorecards
```

**VERIFY:** `psql -f database/migrations/003_agents_scorecards.sql` runs. `SELECT agent_name, composite_score, team_rank FROM v_agent_scorecards WHERE month_num = 10 ORDER BY composite_score DESC LIMIT 10;` returns ranked agents.

**COMMIT:** `feat: populate v_agent_scorecards composite score view`

---

### Task 9: Create `v_etl_load_summary` View

**PURPOSE** -> A view that reads `etl_load_log` and presents a clean summary: last load time per table, rows loaded, status, data freshness.

**WHY** -> Quick way to check when data was last loaded and whether all tables are in sync. Useful for ops monitoring.

**WHAT DONE** -> `SELECT * FROM v_etl_load_summary;` shows one row per table with last load info.

**PROMPT:**
```
Append to database/migrations/002_kpi_views.sql:
Create v_etl_load_summary that queries etl_load_log:
  - One row per table_name
  - Columns: table_name, last_loaded_at, rows_loaded, status, csv_checksum
  - Use ROW_NUMBER() OVER (PARTITION BY table_name ORDER BY loaded_at DESC) to get the latest load per table
  - Also include a data_freshness column: NOW() - last_loaded_at as an interval
```

**VERIFY:** `SELECT * FROM v_etl_load_summary;` shows one row per table with the most recent load timestamp.

**COMMIT:** `feat: add v_etl_load_summary view for ETL monitoring`

---

### Task 10: Add Data Freshness Query

**PURPOSE** -> A simple query that checks how recent the data is: "What's the latest date in each fact table?"

**WHY** -> Before running analysis or presenting the dashboard, you need to confirm the data is current. This query answers: "Is my data stale?"

**WHAT DONE** -> A single query returns the max date from each fact table, showing whether data covers the expected Oct-Dec 2025 range.

**PROMPT:**
```
Append to database/migrations/002_kpi_views.sql:
Create v_data_freshness that returns:
  - table_name, max_date, days_ago (current date - max_date)
  - For: fact_interactions, fact_ptp_log, fact_payments, fact_agent_time_log, fact_eom_snapshot
  - Use a UNION ALL of SELECT statements, one per fact table
```

**VERIFY:** `SELECT * FROM v_data_freshness;` shows the latest date in each fact table.

**COMMIT:** `feat: add v_data_freshness view for data recency checks`

---

# PHASE 4 — Analysis SQL

> **Goal:** Write 17 analytical queries that demonstrate end-to-end collections analytics capability.
> **Current:** 8% -> **Target:** 100%
> **Approach:** Write one file at a time, easiest to hardest. Each file queries the KPI views from Phase 3.

---

### Execution Pattern for All 17 Files

Every analysis SQL file follows this template:

```sql
-- ========================================================================
-- <filename>.sql
-- Audience: <Supervisor | Manager | Director>
-- Purpose: <one-line description>
-- Dependencies: <views or tables used>
-- ========================================================================

-- CTE 1: Base data extraction
WITH base AS (
    SELECT ... FROM v_<relevant_view> ...
),

-- CTE 2: Transformations/calculations
metrics AS (
    SELECT ... FROM base ...
)

-- Final output
SELECT ... FROM metrics
ORDER BY ...;
```

**OpenCode prompt template (adapt per file):**
```
Write analysis/sql/<level>/<filename>.sql.
It should produce <description from roadmap>.
Use PostgreSQL dialect. Use CTEs for readability.
Reference KPI views where possible, fall back to raw tables when needed.
Include window functions, rankings, or statistical calculations as appropriate.
The output should be a clean result set ready for reporting.
Add comments explaining the logic.
```

---

### Recommended Order (Easiest to Hardest)

| # | File | Level | Key Techniques |
|---|------|-------|---------------|
| 1 | `daily_agent_activity.sql` | Supervisor | Basic aggregations, daily totals |
| 2 | `agent_scorecard.sql` | Supervisor | Reuse v_agent_scorecards, rankings |
| 3 | `portfolio_health.sql` | Director | DPD buckets, cure rates, trend lines |
| 4 | `agent_exception_report.sql` | Supervisor | Percentiles, top/bottom N |
| 5 | `team_comparison.sql` | Manager | GROUP BY team, side-by-side metrics |
| 6 | `agent_leaderboard.sql` | Manager | Rankings, WoW changes |
| 7 | `handle_time_benchmark.sql` | Manager | SLA comparisons, benchmarking |
| 8 | `workload_distribution.sql` | Manager | Deviation from mean, std dev |
| 9 | `coaching_opportunities.sql` | Supervisor | WoW metric drops, trend detection |
| 10 | `schedule_adherence.sql` | Supervisor | Hourly gaps, expected vs actual |
| 11 | `campaign_effectiveness.sql` | Manager | Time-of-day analysis, correlation |
| 12 | `recovery_trend_mom.sql` | Director | MoM trends, seasonal patterns |
| 13 | `target_vs_actual.sql` | Director | Gap analysis, trend to target |
| 14 | `portfolio_concentration.sql` | Director | Top 10% by balance, risk metrics |
| 15 | `eda_agents.sql` | Supervisor | Distribution analysis, correlation |
| 16 | `eda_supervisors.sql` | Manager | Tenure correlation, validation |
| 17 | `roll_rate_analysis.sql` | Director | **Hardest** -- DPD migration matrix |

---

### File-by-File Prompts

**1. `daily_agent_activity.sql`**
```
Write analysis/sql/agent_level_operational_supervisors/daily_agent_activity.sql.
Per-agent daily totals: calls attempted, connected, RPC count, PTPs set, payments received.
Include running window totals using SUM() OVER (PARTITION BY agent_id ORDER BY interaction_date ROWS UNBOUNDED PRECEDING).
Also compute 7-day moving averages for RPC count and PTP count.
Order by agent_id, interaction_date.
```

**2. `agent_scorecard.sql`**
```
Write analysis/sql/agent_level_operational_supervisors/agent_scorecard.sql.
Query v_agent_scorecards. Show each agent's composite score, individual component scores, and rank within team.
Add a color-coded status column: 'Top Performer' (top 25%), 'On Track' (middle 50%), 'Needs Coaching' (bottom 25%).
Order by team, then rank.
```

**3. `portfolio_health.sql`**
```
Write analysis/sql/portfolio_level_strategic_directors/portfolio_health.sql.
Show: % of accounts per DPD bucket (1-30, 31-60, 61-90, 90+), cure rate by product, arrears trend MoM.
Use fact_eom_snapshot for DPD buckets and fact_payments for cure rates.
Include a portfolio-level summary row at the bottom.
```

**4. `agent_exception_report.sql`**
```
Write analysis/sql/agent_level_operational_supervisors/agent_exception_report.sql.
Flag agents in the top 5 and bottom 5 for: RPC%, AHT, PTP kept%.
Use PERCENT_RANK() or NTILE(20) to identify extremes.
Show the metric value, team average, and deviation from average.
Order by metric category, then deviation.
```

**5. `team_comparison.sql`**
```
Write analysis/sql/team_level_tactical_managers/team_comparison.sql.
Side-by-side team metrics: total calls, RPC%, PTP%, kept%, cure rate, avg utilization.
Include a simple t-test approximation: show mean and standard deviation for each metric per team.
Highlight teams that are >1 std dev above/below portfolio average.
```

**6. `agent_leaderboard.sql`**
```
Write analysis/sql/team_level_tactical_managers/agent_leaderboard.sql.
Top 10 and bottom 10 agents by composite score.
Include trend columns: score change from previous week, rank change from previous week.
Use LAG() OVER (PARTITION BY agent_id ORDER BY week) for WoW comparisons.
```

**7. `handle_time_benchmark.sql`**
```
Write analysis/sql/team_level_tactical_managers/handle_time_benchmark.sql.
AHT by product, agent, and region.
Compare against SLA targets (define targets as constants: RPC AHT < 300s, NonRPC AHT < 60s).
Show % of calls within SLA per agent.
Flag agents below SLA threshold.
```

**8. `workload_distribution.sql`**
```
Write analysis/sql/team_level_tactical_managers/workload_distribution.sql.
Accounts per agent, calls per agent.
Calculate deviation from team average using AVG() OVER (PARTITION BY supervisor_id).
Show std deviation and identify agents >2 std devs from team mean (overloaded or underloaded).
```

**9. `coaching_opportunities.sql`**
```
Write analysis/sql/agent_level_operational_supervisors/coaching_opportunities.sql.
Flag agents with week-over-week drops in key metrics: RPC% down >5pp, PTP kept% down >10pp, utilization down >10%.
Use LAG() to compare current week vs previous week.
Show the metric, previous value, current value, and change.
Order by magnitude of drop.
```

**10. `schedule_adherence.sql`**
```
Write analysis/sql/agent_level_operational_supervisors/schedule_adherence.sql.
Hourly activity vs expected schedule.
Use fact_interactions to count interactions per hour per agent.
Compare against expected 8-hour schedule with break.
Flag hours with zero activity during expected working hours.
```

**11. `campaign_effectiveness.sql`**
```
Write analysis/sql/team_level_tactical_managers/campaign_effectiveness.sql.
Contact frequency vs RPC%: do more calls = better connections, or diminishing returns?
PTP set rate by time of day: which hours have highest PTP conversion?
Use EXTRACT(HOUR FROM interaction_time) for time-of-day analysis.
Include a scatter-plot-ready output (agent_id, calls_per_day, rpc_pct).
```

**12. `recovery_trend_mom.sql`**
```
Write analysis/sql/portfolio_level_strategic_directors/recovery_trend_mom.sql.
Month-over-month cures, cure rate, cost-to-collect proxy (AHT * wage_rate).
Include seasonal pattern detection: compare Oct vs Nov vs Dec.
Use LAG() for MoM comparison and show % change.
```

**13. `target_vs_actual.sql`**
```
Write analysis/sql/portfolio_level_strategic_directors/target_vs_actual.sql.
Define KPI targets as constants (RPC% >= 65%, PTP% >= 70%, Kept% >= 60%, Cure rate >= 25%).
Compare actuals vs targets by team and by month.
Show gap (actual - target) and trend to target (is the gap closing or widening?).
```

**14. `portfolio_concentration.sql`**
```
Write analysis/sql/portfolio_level_strategic_directors/portfolio_concentration.sql.
Top 10% of accounts by balance -- what % of total arrears do they represent?
Geographic/product mix risk: % of portfolio by product type and region.
Identify concentration risk: if a single product or region represents >40% of arrears, flag it.
```

**15. `eda_agents.sql`**
```
Write analysis/sql/agent_level_operational_supervisors/eda_agents.sql.
Distribution analysis: histogram of RPC% across all agents.
Tenure vs RPC% correlation: do newer agents perform differently?
Include summary statistics: mean, median, std dev, min, max for key metrics.
Use PERCENTILE_CONT() for distribution analysis.
```

**16. `eda_supervisors.sql`**
```
Write analysis/sql/team_level_tactical_managers/eda_supervisors.sql.
Supervisor tenure correlation: does supervisor experience correlate with team performance?
Validate existing analysis: compute team-level metrics and compare against expected patterns.
Include agent turnover proxy (if available) vs team performance.
```

**17. `roll_rate_analysis.sql`**
```
Write analysis/sql/portfolio_level_strategic_directors/roll_rate_analysis.sql.
DPD migration matrix: track accounts moving between buckets month-over-month.
Buckets: Current (0 DPD), 1-30, 31-60, 61-90, 90+.
Show: for accounts in bucket X in October, what % moved to each bucket in November?
Use fact_eom_snapshot with LAG() OVER (PARTITION BY account_id ORDER BY snapshot_date) to track bucket changes.
Output a matrix format: from_bucket, to_bucket, count, pct.
```

---

# PHASE 6 — Testing

> **Goal:** Prove data integrity and code correctness with automated tests.
> **Current:** 5% -> **Target:** 100%

---

### Task 1: Python QA Validation Tests

**PURPOSE** -> Implement `test/qa_validation.py` with pytest tests that validate data integrity in PostgreSQL.

**WHY** -> Tests catch regressions. If a code change accidentally doubles the row count or breaks FK integrity, tests fail before you commit bad data.

**WHAT DONE** -> `pytest test/qa_validation.py -v` runs 12 tests, all pass.

**PROMPT:**
```
Implement test/qa_validation.py with pytest. Use psycopg2 to connect to PostgreSQL.
Read DB credentials from environment variables (same as ETL script).

Tests to implement:
1. test_row_counts: Dim_Agents=80, Dim_Clients=10000, Dim_Accounts~=20000 (+/-5%)
2. test_no_null_pks: Zero nulls in all PK columns across all tables
3. test_fk_integrity: Every FK value exists in the referenced dimension table
4. test_date_ranges: All fact dates within Oct-Dec 2025, calendar covers full 2025
5. test_weekday_only: No interactions on weekends (day_of_week NOT IN (6,7) or is_weekday=TRUE)
6. test_dpd_logic: DPD >= 0 in all tables
7. test_utilization_bounds: Utilization BETWEEN 0 AND 100
8. test_call_duration: All AHT > 0s, max < 3600s
9. test_kpi_view_output: Each KPI view returns rows, no nulls in required columns, percentages 0-100
10. test_etl_idempotency: Run ETL twice, verify same row counts (requires ETL to already have idempotency)
11. test_generator_seed: Run generator with --seed 42 twice, compare CSVs are identical

Use pytest fixtures for DB connection. Use assert for pass/fail.
Add a conftest.py if needed for shared fixtures.
```

**VERIFY:** `pytest test/qa_validation.py -v` shows all tests passing.

**COMMIT:** `test: implement QA validation tests for data integrity`

---

### Task 2: KPI View SQL Tests

**PURPOSE** -> Implement `test/test_kpi_views.sql` that queries each KPI view and validates output using RAISE NOTICE.

**WHY** -> SQL-level tests run directly in psql without Python. They validate that views return expected data shapes and value ranges.

**WHAT DONE** -> `psql -f test/test_kpi_views.sql` outputs PASS/FAIL for each view.

**PROMPT:**
```
Write test/test_kpi_views.sql that tests each KPI view:
  v_contact_metrics, v_promise_metrics, v_recovery_metrics,
  v_productivity_metrics, v_handle_time_metrics, v_daily_mis, v_monthly_summary

For each view:
  1. Check it returns at least 1 row
  2. Check required columns are not null (e.g., rpc_pct should not be null)
  3. Check percentage columns are between 0 and 100
  4. Print RAISE NOTICE 'PASS: v_contact_metrics returns rows' or 'FAIL: ...'

Use DO $$ ... $$ blocks with EXCEPTION handling for each view test.
```

**VERIFY:** `psql -f test/test_kpi_views.sql` outputs PASS/FAIL notices for each view.

**COMMIT:** `test: add SQL validation tests for KPI views`

---

### Task 3: Generator Tests

**PURPOSE** -> Implement `test/test_generator.py` that runs the generator with a fixed seed and validates output.

**WHY** -> Ensures the generator produces correct output. If someone modifies the generator and accidentally changes row counts or breaks CSV formatting, tests catch it.

**WHAT DONE** -> `pytest test/test_generator.py -v` runs tests that generate data to a temp folder and validate it.

**PROMPT:**
```
Implement test/test_generator.py with pytest.
Tests:
1. test_generator_seed: Run generator with --seed 42 twice to a temp directory.
   Compare output CSVs -- they should be byte-identical.
2. test_output_structure: After generation, verify all expected CSV files exist.
   Expected: Dim_Supervisors.csv, Dim_Agents.csv, Dim_Clients.csv, Dim_Products.csv,
   Dim_Accounts.csv, Dim_Calendar.csv, Fact_Interactions.csv, Fact_PTP_Log.csv,
   Fact_Payments.csv, Fact_Agent_Time_Log.csv, Fact_EOM_Snapshot.csv
3. test_row_counts: Verify row counts match expected values (+/-5% for fact tables).
4. test_csv_headers: Verify each CSV has a header row with expected column names.

Use subprocess.run() to call the generator. Use tempfile.TemporaryDirectory for output.
Use pandas to read CSVs for validation.
```

**VERIFY:** `pytest test/test_generator.py -v` shows all generator tests passing.

**COMMIT:** `test: implement generator tests for reproducibility and output validation`

---

# PHASE 9 -- BI & Reporting

> **Goal:** Refine Power BI dashboard, validate DAX measures, and automate Excel report generation.
> **Current:** 40% -> **Target:** 90%

---

### Task 1: Validate DAX Formulas

**PURPOSE** -> Compare DAX formulas in `dax_measures_dictionary.md` against the SQL KPI definitions in `docs/kpi_definitions.md`.

**WHY** -> If DAX calculates RPC% differently than the SQL view, the dashboard shows different numbers than the analysis files. Consistency is critical.

**WHAT DONE** -> Each DAX formula produces the same result as its SQL equivalent when run against the same data.

**PROMPT:** (Manual work -- requires Power BI. OpenCode can help compare the formulas textually.)
```
Read dashboards/dax_measures_dictionary.md and docs/kpi_definitions.md.
For each KPI, compare the DAX formula against the SQL definition.
Flag any discrepancies in logic, filters, or denominators.
```

**VERIFY:** Manually create a Power BI measure, run it against the database, compare the result to `SELECT * FROM v_contact_metrics;`.

**COMMIT:** `docs: validate DAX formulas against SQL KPI definitions`

---

### Task 2: Document Power BI Data Model

**PURPOSE** -> Document the relationships between tables in Power BI: cardinality, cross-filter direction, active/inactive relationships.

**WHY** -> Anyone opening the .pbix file needs to understand the data model. This is especially important for reviewers who may not be Power BI experts.

**WHAT DONE** -> A markdown file or diagram showing all relationships.

**PROMPT:**
```
Read the schema from database/migrations/001_create_tables.sql and dashboards/dax_measures_dictionary.md.
Generate a text-based data model documentation showing:
  - Each table and its columns
  - Relationships between tables (which column connects to which)
  - Cardinality (1:*, 1:1, *:*)
  - Cross-filter direction (single, both)
  - Active vs inactive relationships

Format as a markdown table or mermaid diagram.
```

**VERIFY:** The documentation accurately describes the Power BI model (cross-check with the actual .pbix file).

**COMMIT:** `docs: document Power BI data model relationships`

---

### Task 3: Add Dashboard Screenshot

**PURPOSE** -> Take a screenshot of the Power BI dashboard and save to `dashboards/assets/screenshots/dashboard_preview.png`.

**WHY** -> The README needs a visual of the dashboard. Screenshots are the only way to show a .pbix file in a git repo (since .pbix is binary and git-ignored).

**WHAT DONE** -> A clear, readable screenshot of the dashboard exists in the screenshots folder.

**PROMPT:** (Manual -- open Power BI, take screenshot, save to the path.)

---

### Task 4: Add Excel Report Generation Script

**PURPOSE** -> Write a Python script that reads from `v_daily_mis` and populates `daily_mis.xlsx` using openpyxl.

**WHY** -> Automates the daily MIS report that supervisors currently build manually. Demonstrates end-to-end automation from database to executive report.

**WHAT DONE** -> Running the script produces a formatted Excel file matching the template in `reports/templates/daily_mis.xlsx`.

**PROMPT:**
```
Create reports/generate_daily_mis.py:
  1. Connect to PostgreSQL (use same env vars as ETL)
  2. Query SELECT * FROM v_daily_mis WHERE date = <target_date>
  3. Use openpyxl to load reports/templates/daily_mis.xlsx
  4. Populate the template with query results
  5. Save to reports/output/daily_mis_<YYYYMMDD>.xlsx
  6. Apply formatting: bold headers, number formats, conditional formatting for KPI thresholds

Add argparse for --date flag (default: today) and --output-dir flag.
```

**VERIFY:** `python reports/generate_daily_mis.py --date 2025-10-15` produces a formatted Excel file. Open it and verify data matches the database.

**COMMIT:** `feat: add automated Excel MIS report generation script`

---

### Task 5: Add Automated Report Scheduling Simulation

**PURPOSE** -> Write a script that generates daily MIS reports for all weekdays Oct-Dec 2025 (simulating a scheduled daily run).

**WHY** -> Demonstrates that the reporting pipeline can run autonomously. For your portfolio, it shows you understand operational automation.

**WHAT DONE** -> Running the script produces ~65 Excel files (weekdays only, Oct-Dec 2025).

**PROMPT:**
```
Create reports/generate_all_reports.py:
  1. Generate all weekdays between 2025-10-01 and 2025-12-31
  2. For each weekday, call the generate_daily_mis.py logic (or import and reuse the function)
  3. Skip dates with no data in the database
  4. Print progress: "Generating 2025-10-01... done (X rows)"
  5. At the end, print summary: "Generated X reports out of Y weekdays"
```

**VERIFY:** `python reports/generate_all_reports.py` produces ~65 Excel files in reports/output/.

**COMMIT:** `feat: add batch report generation for Oct-Dec 2025`

---

# PHASE 7 -- Automation & Operations

> **Goal:** Wire everything together into a single-command pipeline with proper error handling and logging.
> **Current:** 15% -> **Target:** 90%

---

### Task 1: Rewrite `run_pipeline.bat`

**PURPOSE** -> Full pipeline orchestration: check Docker -> generate data -> validate CSVs -> run ETL -> apply migrations -> run tests -> report summary.

**WHY** -> One command to go from nothing to a fully loaded, tested database. Essential for CI/CD and for anyone setting up the project.

**WHAT DONE** -> `run_pipeline.bat` runs all steps, reports success/failure at each step, exits with appropriate code.

**PROMPT:**
```
Rewrite run_pipeline.bat with the following flow:
  1. Check Docker is running (docker info >nul 2>&1), exit if not
  2. Start containers (docker compose -f database/docker-compose.yml up -d)
  3. Wait for PostgreSQL to be ready (poll with docker exec ... pg_isready)
  4. Generate data (python data_sources/generators/data_generator_v7.py --seed 42)
  5. Validate CSVs exist and have content
  6. Run ETL (python database/etl/data_to_pg.py)
  7. Apply migrations (psql -f database/migrations/004_indexes.sql, etc.)
  8. Run tests (pytest test/ -v)
  9. Print summary: "Pipeline complete. X tables loaded, Y tests passed."

Use exit codes: 0 for success, 1 for failure at any step.
Add timestamps to each step.
Log output to logs/pipeline_<timestamp>.log.
```

**VERIFY:** Run `run_pipeline.bat`. Confirm it executes all steps and produces a log file.

**COMMIT:** `feat: rewrite run_pipeline.bat with full pipeline orchestration`

---

### Task 2: Add Pipeline Log File

**PURPOSE** -> All pipeline output (generator, ETL, migrations, tests) is captured to `logs/pipeline_YYYYMMDD_HHMMSS.log`.

**WHY** -> Audit trail. If the pipeline fails, you can review the log to find exactly which step failed and why.

**WHAT DONE** -> After running the pipeline, a log file exists in `logs/` with timestamped output.

**PROMPT:**
```
In run_pipeline.bat, redirect all output to a log file:
  1. Create logs/ directory if it doesn't exist
  2. Set log filename: logs\pipeline_%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%.log
  3. Append all command output to this file using >>
  4. Also echo output to console (tee-like behavior)
```

**VERIFY:** Run pipeline, confirm a log file exists in `logs/` with full output.

**COMMIT:** `feat: add pipeline log file capture`

---

### Task 3: Add Makefile

**PURPOSE** -> Unix-friendly alternative to `run_pipeline.bat`. Targets: `make generate`, `make db-up`, `make etl`, `make test`, `make full-pipeline`.

**WHY** -> Many developers prefer Makefiles. It also demonstrates cross-platform compatibility awareness.

**WHAT DONE** -> `make generate` runs the generator. `make full-pipeline` runs everything.

**PROMPT:**
```
Create a Makefile with targets:
  generate: python data_sources/generators/data_generator_v7.py
  db-up: docker compose -f database/docker-compose.yml up -d
  db-down: docker compose -f database/docker-compose.yml down
  etl: python database/etl/data_to_pg.py
  test: pytest test/ -v
  migrations: psql -h localhost -p 5433 -U $$POSTGRES_USER -d $$POSTGRES_DB -f database/migrations/001_create_tables.sql
  full-pipeline: generate etl test
  clean: rm -rf data_sources/generators/raw/ reports/output/ logs/

Use .PHONY for all targets.
```

**VERIFY:** `make generate` runs the generator. `make db-up` starts containers.

**COMMIT:** `feat: add Makefile for Unix-friendly pipeline commands`

---

### Task 4: Add Docker Health Check

**PURPOSE** -> Add a `healthcheck` to the PostgreSQL service in `docker-compose.yml`.

**WHY** -> Docker can automatically detect if PostgreSQL is healthy and restart it if it's not. The pipeline script can also wait for the health check before proceeding.

**WHAT DONE** -> `docker compose ps` shows `(healthy)` status for the PostgreSQL container.

**PROMPT:**
```
Add a healthcheck to the postgres service in database/docker-compose.yml:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB"]
    interval: 10s
    timeout: 5s
    retries: 5
    start_period: 30s
```

**VERIFY:** `docker compose up -d` then `docker compose ps` shows the postgres container as `(healthy)` after ~30 seconds.

**COMMIT:** `chore: add PostgreSQL healthcheck to docker-compose.yml`

---

### Task 5: Add `.dockerignore`

**PURPOSE** -> Exclude unnecessary files from Docker build context: `.git/`, `__pycache__/`, `*.pyc`, generated CSVs, reports output.

**WHY** -> Reduces Docker build context size and prevents accidentally including generated data in the container.

**WHAT DONE** -> A `.dockerignore` file exists at the project root with appropriate exclusions.

**PROMPT:**
```
Create .dockerignore with:
  .git/
  __pycache__/
  *.pyc
  data_sources/generators/raw/
  reports/output/
  logs/
  *.log
  .env
  *.md
  docs/
  analysis/
  test/
```

**VERIFY:** `docker compose build` runs faster (smaller context).

**COMMIT:** `chore: add .dockerignore`

---

# PHASE 8 -- Documentation

> **Goal:** Final polish -- write docs that make the project accessible to anyone.
> **Current:** 65% -> **Target:** 95%
> **Approach:** Write these yourself. You've built everything -- you're the best person to explain it.

---

### Task 1: `QUICKSTART.md`

**PURPOSE** -> 5-minute setup guide: prerequisites, 3 commands, done.

**WHAT DONE** -> A new developer clones the repo and has data loaded in under 5 minutes.

**Content outline:**
1. Prerequisites (Python 3.x, Docker, PostgreSQL client)
2. `git clone` + `cd`
3. `docker compose -f database/docker-compose.yml up -d`
4. `python data_sources/generators/data_generator_v7.py`
5. `python database/etl/data_to_pg.py`
6. Verify: `SELECT count(*) FROM dim_agents;` -> 80

---

### Task 2: `TROUBLESHOOTING.md`

**PURPOSE** -> Common errors and how to fix them.

**Content outline:**
- Docker: "Port 5433 already in use" -> change port in docker-compose.yml
- ETL: "Connection refused" -> check Docker is running, check .env credentials
- Generator: "ModuleNotFoundError" -> pip install -r requirements.txt
- PostgreSQL: "database does not exist" -> run 001_create_tables.sql first

---

### Task 3: `CHANGELOG.md`

**PURPOSE** -> Track what changed in each version/release.

**Format:** Keep a Changelog standard format.

---

### Task 4-8: Remaining Documentation

Write incrementally after each phase. Don't batch at the end.

---

## General Tips for Using OpenCode

1. **One task at a time.** Don't ask for an entire phase. Ask for one task, verify, commit, then move on.
2. **Always review the diff.** OpenCode writes code -- you're responsible for what gets committed.
3. **Run before committing.** Never commit code you haven't executed.
4. **If OpenCode gets it wrong**, say "Try again, but this time [specific correction]." Be precise about what's wrong.
5. **If a task is ambiguous**, ask OpenCode: "Read file X and explain what it currently does. Then suggest how to add feature Y."
6. **Use `/edit` to modify files.** Use `/run` to execute commands. Use plain conversation to ask questions.
7. **Keep sessions focused.** If a session gets too long or context gets muddled, start fresh. OpenCode re-reads files on each new session.
