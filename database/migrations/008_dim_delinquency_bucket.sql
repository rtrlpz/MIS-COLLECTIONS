-- ============================================================================
-- 008_dim_delinquency_bucket.sql — apply I2 to an ALREADY-LOADED database
-- ============================================================================
-- Fresh builds get the bucket dimension + snapshot.bucket_key from
-- 001_create_tables.sql and seeds/003. This migration brings existing
-- databases to the same state WITHOUT dropping/reloading:
--   1. create dim_delinquency_bucket if missing
--   2. seed its 5 rows (idempotent)
--   3. add fact_eom_snapshot.bucket_key if missing
--   4. backfill bucket_key from dpd_bucket labels
--   5. attach the FK once everything validates
-- Idempotent: every step is a no-op on re-run.
-- ============================================================================

-- 1. dimension table
CREATE TABLE IF NOT EXISTS dim_delinquency_bucket (
    bucket_key SMALLINT PRIMARY KEY,
    bucket_label VARCHAR(20) NOT NULL UNIQUE,
    sort_order SMALLINT NOT NULL,
    days_from INT,
    days_to INT
);

-- 2. seed rows
INSERT INTO dim_delinquency_bucket (bucket_key, bucket_label, sort_order, days_from, days_to) VALUES
    (0, 'Current', 0, NULL,   0),
    (1, '1-30',    1,    1,  30),
    (2, '31-60',   2,   31,  60),
    (3, '61-90',   3,   61,  90),
    (4, '90+',     4,   91, NULL)
ON CONFLICT (bucket_key) DO NOTHING;

-- 3. fact column (append-only; CREATE OR REPLACE VIEW-safe pattern)
ALTER TABLE fact_eom_snapshot ADD COLUMN IF NOT EXISTS bucket_key SMALLINT;

-- 4. backfill from labels
UPDATE fact_eom_snapshot e
SET    bucket_key = b.bucket_key
FROM   dim_delinquency_bucket b
WHERE  e.dpd_bucket = b.bucket_label
  AND  e.bucket_key IS DISTINCT FROM b.bucket_key;

-- 5. FK (validated — safe because step 4 removed any orphans)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_eom_bucket') THEN
        ALTER TABLE fact_eom_snapshot
            ADD CONSTRAINT fk_eom_bucket
            FOREIGN KEY (bucket_key) REFERENCES dim_delinquency_bucket(bucket_key);
    END IF;
END $$;
