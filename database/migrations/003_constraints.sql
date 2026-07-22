-- ============================================================================
-- 003_constraints.sql — Table Constraints for Data Integrity
-- ============================================================================
-- Purpose: Add CHECK constraints to fact and dimension tables to enforce
-- data integrity rules at the database level. These constraints prevent
-- invalid data from being inserted or updated.
--
-- Phase: Phase 3 (Database Layer — Indexes, Constraints, Comments)
-- ============================================================================

-- Fact_Interactions constraints
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_interactions_calls_attempted') THEN
        ALTER TABLE fact_interactions ADD CONSTRAINT chk_fact_interactions_calls_attempted CHECK (calls_attempted >= 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_interactions_calls_connected') THEN
        ALTER TABLE fact_interactions ADD CONSTRAINT chk_fact_interactions_calls_connected CHECK (calls_connected >= 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_interactions_aht_seconds') THEN
        ALTER TABLE fact_interactions ADD CONSTRAINT chk_fact_interactions_aht_seconds CHECK (aht_seconds > 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_interactions_acw_seconds') THEN
        ALTER TABLE fact_interactions ADD CONSTRAINT chk_fact_interactions_acw_seconds CHECK (acw_seconds >= 0);
    END IF;
END $$;

-- Fact_PTP_Log constraints
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_ptp_log_promised_amount') THEN
        ALTER TABLE fact_ptp_log ADD CONSTRAINT chk_fact_ptp_log_promised_amount CHECK (promised_amount > 0);
    END IF;
END $$;

-- Fact_Payments constraints
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_payments_amount_paid') THEN
        ALTER TABLE fact_payments ADD CONSTRAINT chk_fact_payments_amount_paid CHECK (amount_paid > 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_payments_dpd_at_payment') THEN
        ALTER TABLE fact_payments ADD CONSTRAINT chk_fact_payments_dpd_at_payment CHECK (dpd_at_payment >= 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_payments_balance_after') THEN
        ALTER TABLE fact_payments ADD CONSTRAINT chk_fact_payments_balance_after CHECK (balance_after >= 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_payments_arrears_after') THEN
        ALTER TABLE fact_payments ADD CONSTRAINT chk_fact_payments_arrears_after CHECK (arrears_after >= 0);
    END IF;
END $$;

-- Fact_Agent_Time_Log constraints
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_agent_time_log_utilization') THEN
        ALTER TABLE fact_agent_time_log ADD CONSTRAINT chk_fact_agent_time_log_utilization CHECK (utilization BETWEEN 0 AND 100);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_agent_time_log_operational_hours') THEN
        ALTER TABLE fact_agent_time_log ADD CONSTRAINT chk_fact_agent_time_log_operational_hours CHECK (operational_hours >= 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_agent_time_log_break_minutes') THEN
        ALTER TABLE fact_agent_time_log ADD CONSTRAINT chk_fact_agent_time_log_break_minutes CHECK (break_minutes >= 0);
    END IF;
END $$;

-- Fact_EOM_Snapshot constraints
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_eom_snapshot_dpd') THEN
        ALTER TABLE fact_eom_snapshot ADD CONSTRAINT chk_fact_eom_snapshot_dpd CHECK (dpd >= 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_eom_snapshot_balance') THEN
        ALTER TABLE fact_eom_snapshot ADD CONSTRAINT chk_fact_eom_snapshot_balance CHECK (balance >= 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_eom_snapshot_arrears') THEN
        ALTER TABLE fact_eom_snapshot ADD CONSTRAINT chk_fact_eom_snapshot_arrears CHECK (arrears >= 0);
    END IF;
END $$;

-- Dim_Accounts constraints
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_dim_accounts_initial_balance') THEN
        ALTER TABLE dim_accounts ADD CONSTRAINT chk_dim_accounts_initial_balance CHECK (initial_balance >= 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_dim_accounts_min_payment') THEN
        ALTER TABLE dim_accounts ADD CONSTRAINT chk_dim_accounts_min_payment CHECK (min_payment >= 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_dim_accounts_due_day') THEN
        ALTER TABLE dim_accounts ADD CONSTRAINT chk_dim_accounts_due_day CHECK (due_day BETWEEN 1 AND 31);
    END IF;
END $$;

-- Foreign key: dim_agents.supervisor_id -> dim_supervisors.supervisor_id
-- REMOVED: dim_supervisors merged into dim_employees; self-ref FK is in DDL

-- Fact_PTP_Log: status must be one of the state machine values (includes pre-resolve "Pending")
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_ptp_log_status') THEN
        ALTER TABLE fact_ptp_log ADD CONSTRAINT chk_fact_ptp_log_status
            CHECK (status IN ('Scheduled', 'Pending', 'Kept', 'Broken'));
    END IF;
END $$;

-- Fact_Payments: if cure_flag is set it must be a valid value (nullable convenience field)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_payments_cure_flag') THEN
        ALTER TABLE fact_payments ADD CONSTRAINT chk_fact_payments_cure_flag
            CHECK (cure_flag IS NULL OR cure_flag IN ('Agent-Cure', 'Self-Cure', 'Agent_Cure', 'Self_Cure'));
    END IF;
END $$;

-- Fact_Interactions: cannot have more connections than attempts
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_interactions_attempts_vs_connected') THEN
        ALTER TABLE fact_interactions ADD CONSTRAINT chk_fact_interactions_attempts_vs_connected
            CHECK (calls_attempted >= calls_connected);
    END IF;
END $$;

-- Fact_Agent_Time_Log: login must be before logout
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_agent_time_log_login_logout') THEN
        ALTER TABLE fact_agent_time_log ADD CONSTRAINT chk_fact_agent_time_log_login_logout
            CHECK (login_time < logout_time);
    END IF;
END $$;

-- ============================================================================
-- PHASE 6: NEW CONSTRAINTS (G1-G9)
-- ============================================================================

-- Fact_Interactions: channel must be a valid value
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_interactions_channel') THEN
        ALTER TABLE fact_interactions ADD CONSTRAINT chk_fact_interactions_channel
            CHECK (channel IN ('Dialer', 'Manual', 'FICO', 'SMS'));
    END IF;
END $$;

-- Dim_Employees: experience_tier must be a valid value (NULL allowed for supervisors)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_dim_employees_experience_tier') THEN
        ALTER TABLE dim_employees ADD CONSTRAINT chk_dim_employees_experience_tier
            CHECK (experience_tier IN ('senior', 'mid', 'junior') OR experience_tier IS NULL);
    END IF;
END $$;

-- Dim_Employees: cost_per_hour must be positive
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_dim_employees_cost_per_hour') THEN
        ALTER TABLE dim_employees ADD CONSTRAINT chk_dim_employees_cost_per_hour
            CHECK (cost_per_hour > 0);
    END IF;
END $$;

-- Fact_Agent_Time_Log: cost_per_hour must be positive
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_agent_time_log_cost_per_hour') THEN
        ALTER TABLE fact_agent_time_log ADD CONSTRAINT chk_fact_agent_time_log_cost_per_hour
            CHECK (cost_per_hour > 0);
    END IF;
END $$;

-- Fact_Agent_Time_Log: total_cost must be non-negative
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_agent_time_log_total_cost') THEN
        ALTER TABLE fact_agent_time_log ADD CONSTRAINT chk_fact_agent_time_log_total_cost
            CHECK (total_cost >= 0);
    END IF;
END $$;

-- Fact_Writeoffs: writeoff_amount must be positive
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_writeoffs_amount') THEN
        ALTER TABLE fact_writeoffs ADD CONSTRAINT chk_fact_writeoffs_amount
            CHECK (writeoff_amount > 0);
    END IF;
END $$;

-- Fact_Writeoffs: dpd_at_writeoff must be positive
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_writeoffs_dpd') THEN
        ALTER TABLE fact_writeoffs ADD CONSTRAINT chk_fact_writeoffs_dpd
            CHECK (dpd_at_writeoff >= 0);
    END IF;
END $$;

-- Fact_Writeoffs: balance_before must be non-negative
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_writeoffs_balance') THEN
        ALTER TABLE fact_writeoffs ADD CONSTRAINT chk_fact_writeoffs_balance
            CHECK (balance_before >= 0);
    END IF;
END $$;

-- ============================================================================
-- BATCH 2: SCHEMA IMPROVEMENTS (H5, H6, H7, H8, M3)
-- ============================================================================

-- H5: Narrow cure_flag CHECK to only the 2 values the generator produces
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_payments_cure_flag') THEN
        ALTER TABLE fact_payments DROP CONSTRAINT chk_fact_payments_cure_flag;
    END IF;
    ALTER TABLE fact_payments ADD CONSTRAINT chk_fact_payments_cure_flag
        CHECK (cure_flag IS NULL OR cure_flag IN ('Agent_Cure', 'Self_Cure'));
END $$;

-- H6: CHECK dpd_after_payment >= 0 (consistent with dpd_at_payment)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_payments_dpd_after') THEN
        ALTER TABLE fact_payments ADD CONSTRAINT chk_fact_payments_dpd_after
            CHECK (dpd_after_payment >= 0);
    END IF;
END $$;

-- H7: CHECK initial_status valid values
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_dim_accounts_initial_status') THEN
        ALTER TABLE dim_accounts ADD CONSTRAINT chk_dim_accounts_initial_status
            CHECK (initial_status IN ('Activo', 'Mora'));
    END IF;
END $$;

-- M4: CHECK product_type on dim_accounts (denormalized from dim_products)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_dim_accounts_product_type') THEN
        ALTER TABLE dim_accounts ADD CONSTRAINT chk_dim_accounts_product_type
            CHECK (product_type IN ('Tarjeta', 'Prestamo', 'Hipoteca'));
    END IF;
END $$;

-- H8: NOT NULL on login_time/logout_time (generator always produces both)
DO $$
BEGIN
    ALTER TABLE fact_agent_time_log ALTER COLUMN login_time SET NOT NULL;
    ALTER TABLE fact_agent_time_log ALTER COLUMN logout_time SET NOT NULL;
EXCEPTION WHEN others THEN NULL;
END $$;

-- M3: CHECK constraints on dimension columns
DO $$
BEGIN
    -- dim_clients.segment
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_dim_clients_segment') THEN
        ALTER TABLE dim_clients ADD CONSTRAINT chk_dim_clients_segment
            CHECK (segment IN ('Retail', 'Premium', 'Tarjeta', 'Prestamo', 'Hipoteca'));
    END IF;
    -- dim_products.product_type
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_dim_products_product_type') THEN
        ALTER TABLE dim_products ADD CONSTRAINT chk_dim_products_product_type
            CHECK (product_type IN ('Tarjeta', 'Prestamo', 'Hipoteca'));
    END IF;
    -- fact_eom_snapshot.status
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_eom_snapshot_status') THEN
        ALTER TABLE fact_eom_snapshot ADD CONSTRAINT chk_fact_eom_snapshot_status
            CHECK (status IN ('Activo', 'Mora'));
    END IF;
    -- fact_eom_snapshot.dpd_bucket
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_fact_eom_snapshot_dpd_bucket') THEN
        ALTER TABLE fact_eom_snapshot ADD CONSTRAINT chk_fact_eom_snapshot_dpd_bucket
            CHECK (dpd_bucket IN ('Current', '1-30', '31-60', '61-90', '90+'));
    END IF;
    -- dim_employees.region
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_dim_employees_region') THEN
        ALTER TABLE dim_employees ADD CONSTRAINT chk_dim_employees_region
            CHECK (region IN ('North', 'South', 'East', 'West') OR region IS NULL);
    END IF;
END $$;
