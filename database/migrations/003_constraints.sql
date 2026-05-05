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
ALTER TABLE fact_interactions ADD CONSTRAINT chk_fact_interactions_calls_attempted CHECK (calls_attempted >= 0);
ALTER TABLE fact_interactions ADD CONSTRAINT chk_fact_interactions_calls_connected CHECK (calls_connected >= 0);
ALTER TABLE fact_interactions ADD CONSTRAINT chk_fact_interactions_aht_seconds CHECK (aht_seconds > 0);
ALTER TABLE fact_interactions ADD CONSTRAINT chk_fact_interactions_acw_seconds CHECK (acw_seconds >= 0);

-- Fact_PTP_Log constraints
ALTER TABLE fact_ptp_log ADD CONSTRAINT chk_fact_ptp_log_promised_amount CHECK (promised_amount > 0);

-- Fact_Payments constraints
ALTER TABLE fact_payments ADD CONSTRAINT chk_fact_payments_amount_paid CHECK (amount_paid > 0);
ALTER TABLE fact_payments ADD CONSTRAINT chk_fact_payments_dpd_at_payment CHECK (dpd_at_payment >= 0);

-- Fact_Agent_Time_Log constraints
ALTER TABLE fact_agent_time_log ADD CONSTRAINT chk_fact_agent_time_log_utilization CHECK (utilization BETWEEN 0 AND 100);
ALTER TABLE fact_agent_time_log ADD CONSTRAINT chk_fact_agent_time_log_operational_hours CHECK (operational_hours >= 0);
ALTER TABLE fact_agent_time_log ADD CONSTRAINT chk_fact_agent_time_log_break_minutes CHECK (break_minutes >= 0);

-- Fact_EOM_Snapshot constraints
ALTER TABLE fact_eom_snapshot ADD CONSTRAINT chk_fact_eom_snapshot_dpd CHECK (dpd >= 0);
ALTER TABLE fact_eom_snapshot ADD CONSTRAINT chk_fact_eom_snapshot_balance CHECK (balance >= 0);
ALTER TABLE fact_eom_snapshot ADD CONSTRAINT chk_fact_eom_snapshot_arrears CHECK (arrears >= 0);

-- Dim_Accounts constraints
ALTER TABLE dim_accounts ADD CONSTRAINT chk_dim_accounts_initial_balance CHECK (initial_balance >= 0);
ALTER TABLE dim_accounts ADD CONSTRAINT chk_dim_accounts_min_payment CHECK (min_payment >= 0);
ALTER TABLE dim_accounts ADD CONSTRAINT chk_dim_accounts_due_day CHECK (due_day BETWEEN 1 AND 31);
