-- ============================================================================
-- 010_fact_recoveries.sql — apply N4 to an ALREADY-LOADED database
-- ============================================================================
-- Fresh builds get the table from 001. This creates it on existing databases.
-- It stays EMPTY until the next regeneration: recovery events are generated
-- post-write-off by data_generator_v7.py §3H2 and land via ETL.
-- Idempotent: no-op on re-run.
-- ============================================================================

CREATE TABLE IF NOT EXISTS fact_recoveries (
    recovery_id VARCHAR(15) PRIMARY KEY,
    recovery_date DATE NOT NULL,
    account_id VARCHAR(15) NOT NULL,
    product_type VARCHAR(50),
    amount_recovered DECIMAL(12,2),
    channel VARCHAR(50),
    remaining_recoverable DECIMAL(12,2),
    CONSTRAINT fk_rec_accounts FOREIGN KEY (account_id) REFERENCES dim_accounts(account_id),
    CONSTRAINT fk_rec_date FOREIGN KEY (recovery_date) REFERENCES dim_calendar(date)
);
