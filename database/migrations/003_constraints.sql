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
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_dim_agents_supervisor') THEN
        ALTER TABLE dim_agents ADD CONSTRAINT fk_dim_agents_supervisor
            FOREIGN KEY (supervisor_id) REFERENCES dim_supervisors(supervisor_id);
    END IF;
END $$;

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
