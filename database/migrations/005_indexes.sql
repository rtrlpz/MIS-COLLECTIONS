-- ============================================================================
-- 005_indexes.sql — Database Indexes for Performance Optimization
-- ============================================================================
-- Purpose: Create indexes on all foreign key columns and frequently queried
-- date columns across dimension and fact tables. These indexes improve query
-- performance for KPI views, analytical queries, and ETL operations.
--
-- Phase: Phase 3 (Database Layer — Indexes, Constraints, Comments)
-- ============================================================================

-- Dimension table indexes
CREATE INDEX IF NOT EXISTS idx_dim_agents_supervisor_id ON dim_agents(supervisor_id);
CREATE INDEX IF NOT EXISTS idx_dim_accounts_client_id ON dim_accounts(client_id);
CREATE INDEX IF NOT EXISTS idx_dim_accounts_product_id ON dim_accounts(product_id);

-- Fact_Interactions indexes
CREATE INDEX IF NOT EXISTS idx_fact_interactions_agent_id ON fact_interactions(agent_id);
CREATE INDEX IF NOT EXISTS idx_fact_interactions_account_id ON fact_interactions(account_id);
CREATE INDEX IF NOT EXISTS idx_fact_interactions_interaction_date ON fact_interactions(interaction_date);

-- Fact_PTP_Log indexes
CREATE INDEX IF NOT EXISTS idx_fact_ptp_log_agent_id ON fact_ptp_log(agent_id);
CREATE INDEX IF NOT EXISTS idx_fact_ptp_log_account_id ON fact_ptp_log(account_id);
CREATE INDEX IF NOT EXISTS idx_fact_ptp_log_ptp_date ON fact_ptp_log(ptp_date);

-- Fact_Payments indexes
CREATE INDEX IF NOT EXISTS idx_fact_payments_account_id ON fact_payments(account_id);
CREATE INDEX IF NOT EXISTS idx_fact_payments_payment_date ON fact_payments(payment_date);
CREATE INDEX IF NOT EXISTS idx_fact_payments_agent_id ON fact_payments(agent_id);

-- Fact_Agent_Time_Log indexes
CREATE INDEX IF NOT EXISTS idx_fact_agent_time_log_agent_id ON fact_agent_time_log(agent_id);
CREATE INDEX IF NOT EXISTS idx_fact_agent_time_log_log_date ON fact_agent_time_log(log_date);

-- Fact_EOM_Snapshot indexes
CREATE INDEX IF NOT EXISTS idx_fact_eom_snapshot_account_id ON fact_eom_snapshot(account_id);
CREATE INDEX IF NOT EXISTS idx_fact_eom_snapshot_snapshot_date ON fact_eom_snapshot(snapshot_date);

-- Additional indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_fact_interactions_rpc_flag ON fact_interactions(rpc_flag);
CREATE INDEX IF NOT EXISTS idx_fact_ptp_log_status ON fact_ptp_log(status);
CREATE INDEX IF NOT EXISTS idx_fact_payments_is_cured ON fact_payments(is_cured);
CREATE INDEX IF NOT EXISTS idx_fact_agent_time_log_utilization ON fact_agent_time_log(utilization);
CREATE INDEX IF NOT EXISTS idx_fact_eom_snapshot_dpd_bucket ON fact_eom_snapshot(dpd_bucket);

-- Composite indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_fact_interactions_agent_date ON fact_interactions(agent_id, interaction_date);
CREATE INDEX IF NOT EXISTS idx_fact_ptp_log_agent_date ON fact_ptp_log(agent_id, ptp_date);
CREATE INDEX IF NOT EXISTS idx_fact_agent_time_log_agent_date ON fact_agent_time_log(agent_id, log_date);
CREATE INDEX IF NOT EXISTS idx_fact_eom_snapshot_account_date ON fact_eom_snapshot(account_id, snapshot_date);
CREATE INDEX IF NOT EXISTS idx_fact_eom_snapshot_date_account ON fact_eom_snapshot(snapshot_date, account_id);
CREATE INDEX IF NOT EXISTS idx_dim_agents_supervisor_agent ON dim_agents(supervisor_id, agent_id);
CREATE INDEX IF NOT EXISTS idx_dim_accounts_product_client ON dim_accounts(product_id, client_id);
