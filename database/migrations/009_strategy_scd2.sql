-- ============================================================================
-- 009_strategy_scd2.sql — apply I4/I5 to an ALREADY-LOADED database
-- ============================================================================
-- Fresh builds get these objects from 001 + seeds. This migration upgrades
-- existing databases in place, WITHOUT dropping or regenerating:
--   I5: dim_strategy seeded with the 3 arms; fact_interactions.strategy_id
--       backfilled via a deterministic hash of account_id using the same
--       60/25/15 split as STRATEGY_CFG — so the CURRENT data is already
--       sliceable by treatment arm before the next regeneration.
--   I4: dim_employees gains SCD Type-2 validity columns (current-state rows);
--       dim_employee_history created and baseline-populated with one current
--       segment per employee. Post-regeneration CSVs add mid-year transfer
--       segments.
-- Idempotent: every step is a no-op on re-run.
-- ============================================================================

BEGIN;

-- ── I5 ──────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS dim_strategy (
    strategy_id VARCHAR(15) PRIMARY KEY,
    strategy_name VARCHAR(50) NOT NULL,
    description TEXT,
    pct_accounts DECIMAL(5,3),
    channel_mix TEXT,
    connection_mult DECIMAL(5,3),
    rpc_mult DECIMAL(5,3)
);

INSERT INTO dim_strategy (strategy_id, strategy_name, description, pct_accounts, channel_mix, connection_mult, rpc_mult) VALUES
    ('STG-01', 'Champion_Dialer',        'Incumbent outbound dialer practice (champion arm)',            0.600, 'Dialer 75%, Manual 25%', 1.00, 1.00),
    ('STG-02', 'Challenger_SMS_First',   'SMS-led pre-contact nudge before dialing (cheaper, weaker)',  0.250, 'SMS 55%, Dialer 35%, Manual 10%', 0.88, 0.97),
    ('STG-03', 'Challenger_FICO_Priority','Score-based prioritized dialing on high-propensity accounts', 0.150, 'FICO 45%, Dialer 45%, Manual 10%', 1.06, 1.12)
ON CONFLICT (strategy_id) DO NOTHING;

ALTER TABLE fact_interactions ADD COLUMN IF NOT EXISTS strategy_id VARCHAR(15);

-- Deterministic assignment mirrors generator weights (60/25/15)
UPDATE fact_interactions fi
SET    strategy_id = CASE
           WHEN abs(hashtext(fi.account_id))::int % 100 < 60 THEN 'STG-01'
           WHEN abs(hashtext(fi.account_id))::int % 100 < 85 THEN 'STG-02'
           ELSE 'STG-03'
       END
WHERE  fi.strategy_id IS NULL;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_int_strategy') THEN
        ALTER TABLE fact_interactions
            ADD CONSTRAINT fk_int_strategy
            FOREIGN KEY (strategy_id) REFERENCES dim_strategy(strategy_id);
    END IF;
END $$;

-- ── I4 ──────────────────────────────────────────────────────────────────────
ALTER TABLE dim_employees ADD COLUMN IF NOT EXISTS valid_from DATE;
ALTER TABLE dim_employees ADD COLUMN IF NOT EXISTS valid_to   DATE;
ALTER TABLE dim_employees ADD COLUMN IF NOT EXISTS is_current BOOLEAN;

UPDATE dim_employees
SET    valid_from = hire_date,
       valid_to   = DATE '9999-12-31',
       is_current = TRUE
WHERE  valid_from IS NULL;

CREATE TABLE IF NOT EXISTS dim_employee_history (
    hist_id VARCHAR(15) PRIMARY KEY,
    agent_id VARCHAR(15) NOT NULL,
    employee_type VARCHAR(20),
    supervisor_id VARCHAR(15),
    team_name VARCHAR(50),
    region VARCHAR(50),
    experience_tier VARCHAR(10),
    cost_per_hour DECIMAL(6,2),
    valid_from DATE NOT NULL,
    valid_to   DATE NOT NULL,
    is_current BOOLEAN,
    CONSTRAINT fk_emp_hist_employee FOREIGN KEY (agent_id) REFERENCES dim_employees(agent_id)
);

-- Baseline: one current segment per employee (transfers arrive with regen)
INSERT INTO dim_employee_history (hist_id, agent_id, employee_type, supervisor_id, team_name, region, experience_tier, cost_per_hour, valid_from, valid_to, is_current)
SELECT 'EMH-B' || row_number() OVER (ORDER BY agent_id)::text,
       agent_id, employee_type, supervisor_id, team_name, region,
       experience_tier, cost_per_hour,
       COALESCE(hire_date, DATE '2021-01-01'), DATE '9999-12-31', TRUE
FROM dim_employees e
WHERE NOT EXISTS (SELECT 1 FROM dim_employee_history h WHERE h.agent_id = e.agent_id);

COMMIT;
