-- ============================================================================
-- 006_comments.sql — Table and Column Comments for Documentation
-- ============================================================================
-- Purpose: Add descriptive comments to all tables and columns in the database
-- schema. These comments appear in pgAdmin, system catalogs, and help
-- developers understand the data model without referring to external docs.
--
-- Phase: Phase 3 (Database Layer — Indexes, Constraints, Comments)
-- ============================================================================

-- ============================================================================
-- DIMENSION TABLES
-- ============================================================================

-- Dim_Supervisors
COMMENT ON TABLE dim_supervisors IS 'Collection supervisors managing teams of agents across regions';
COMMENT ON COLUMN dim_supervisors.supervisor_id IS 'Unique supervisor identifier (format: SUP_XXX)';
COMMENT ON COLUMN dim_supervisors.supervisor_name IS 'Full name of the supervisor';
COMMENT ON COLUMN dim_supervisors.team_name IS 'Team name assigned to the supervisor';
COMMENT ON COLUMN dim_supervisors.region IS 'Geographic region (e.g., North, South, Central)';

-- Dim_Agents
COMMENT ON TABLE dim_agents IS 'Collection agents with supervisor details, tenure cohort, skill dimensions, and hire date';
COMMENT ON COLUMN dim_agents.agent_id IS 'Unique agent identifier (format: AGT_XXX)';
COMMENT ON COLUMN dim_agents.agent_name IS 'Full name of the agent';
COMMENT ON COLUMN dim_agents.supervisor_id IS 'Supervisor ID managing this agent';
COMMENT ON COLUMN dim_agents.supervisor_name IS 'Full name of the agent supervisor (denormalized)';
COMMENT ON COLUMN dim_agents.team_name IS 'Team name (denormalized from supervisor)';
COMMENT ON COLUMN dim_agents.region IS 'Geographic region (denormalized from supervisor)';
COMMENT ON COLUMN dim_agents.tenure_cohort IS 'Performance cohort: Low/Mid/High (adjusts base rate ranges)';
COMMENT ON COLUMN dim_agents.contact_skill IS 'Contact skill multiplier (0.700-1.300) — scales connection_rate and rpc_rate';
COMMENT ON COLUMN dim_agents.negotiation_skill IS 'Negotiation skill multiplier (0.700-1.300) — scales ptp_rate and kp_tendency';
COMMENT ON COLUMN dim_agents.efficiency_skill IS 'Efficiency skill multiplier (0.800-1.200) — scales AHT/ACW (lower = faster)';

-- Dim_Clients
COMMENT ON TABLE dim_clients IS 'Bank clients with risk profile and segmentation data';
COMMENT ON COLUMN dim_clients.client_id IS 'Unique client identifier (format: CLN_XXXX)';
COMMENT ON COLUMN dim_clients.full_name IS 'Client full legal name';
COMMENT ON COLUMN dim_clients.dob IS 'Date of birth for age calculation';
COMMENT ON COLUMN dim_clients.segment IS 'Client segment (e.g., Premium, Standard, Basic)';
COMMENT ON COLUMN dim_clients.risk_score IS 'Credit risk score (0.00-100.00)';

-- Dim_Products
COMMENT ON TABLE dim_products IS 'Bank product catalog: Credit Cards, Personal Loans, Mortgages';
COMMENT ON COLUMN dim_products.product_id IS 'Unique product identifier (format: PRD_XXX)';
COMMENT ON COLUMN dim_products.product_name IS 'Product display name (e.g., Credit Card Platinum)';
COMMENT ON COLUMN dim_products.product_type IS 'Product category: Credit Card, Personal Loan, Mortgage';
COMMENT ON COLUMN dim_products.annual_rate_pct IS 'Annual interest rate percentage';
COMMENT ON COLUMN dim_products.grace_days IS 'Number of grace days before late fees apply';
COMMENT ON COLUMN dim_products.min_payment_rule IS 'Rule for calculating minimum payment (e.g., 5% of balance)';

-- Dim_Calendar
COMMENT ON TABLE dim_calendar IS 'Date dimension with business calendar flags for filtering and grouping';
COMMENT ON COLUMN dim_calendar.date IS 'Calendar date (primary key)';
COMMENT ON COLUMN dim_calendar.year IS 'Year number (e.g., 2025)';
COMMENT ON COLUMN dim_calendar.quarter IS 'Quarter number (1-4)';
COMMENT ON COLUMN dim_calendar.month_num IS 'Month number (1-12)';
COMMENT ON COLUMN dim_calendar.month_name IS 'Month name (e.g., October)';
COMMENT ON COLUMN dim_calendar.iso_week IS 'ISO week number (1-53)';
COMMENT ON COLUMN dim_calendar.day_of_week IS 'Day of week number (1=Monday, 7=Sunday)';
COMMENT ON COLUMN dim_calendar.day_name IS 'Day name (e.g., Monday)';
COMMENT ON COLUMN dim_calendar.is_weekday IS 'True if date is Monday-Friday (collections operate on weekdays only)';
COMMENT ON COLUMN dim_calendar.is_month_end IS 'True if date is the last day of the month';
COMMENT ON COLUMN dim_calendar.is_payday_week IS 'True if this is a payday week (payment probability spikes)';
COMMENT ON COLUMN dim_calendar.payday_factor IS 'Multiplier for payment probability on this date (1.00 = baseline)';

-- Dim_Accounts
COMMENT ON TABLE dim_accounts IS 'Delinquent accounts with product, client, and balance information';
COMMENT ON COLUMN dim_accounts.account_id IS 'Unique account identifier (format: ACC_XXXXX)';
COMMENT ON COLUMN dim_accounts.client_id IS 'FK to dim_clients — account holder';
COMMENT ON COLUMN dim_accounts.product_id IS 'FK to dim_products — product type for this account';
COMMENT ON COLUMN dim_accounts.open_date IS 'Account opening date';
COMMENT ON COLUMN dim_accounts.due_day IS 'Day of month when payment is due (1-31)';
COMMENT ON COLUMN dim_accounts.min_payment IS 'Minimum required payment amount';
COMMENT ON COLUMN dim_accounts.initial_balance IS 'Current outstanding balance';
COMMENT ON COLUMN dim_accounts.initial_status IS 'Account status at creation (e.g., Current, 30DPD)';

-- ============================================================================
-- FACT TABLES (Transactional)
-- ============================================================================

-- Fact_Interactions
COMMENT ON TABLE fact_interactions IS 'Dialer call records: attempts, connections, RPC flags, and handle times';
COMMENT ON COLUMN fact_interactions.interaction_id IS 'Unique interaction identifier (format: INT_XXXXX)';
COMMENT ON COLUMN fact_interactions.interaction_date IS 'Date of the call (FK to dim_calendar, weekdays only)';
COMMENT ON COLUMN fact_interactions.interaction_time IS 'Time of day when call occurred';
COMMENT ON COLUMN fact_interactions.agent_id IS 'FK to dim_agents — agent who made the call';
COMMENT ON COLUMN fact_interactions.account_id IS 'FK to dim_accounts — account being contacted';
COMMENT ON COLUMN fact_interactions.calls_attempted IS 'Number of dial attempts for this interaction';
COMMENT ON COLUMN fact_interactions.calls_connected IS 'Number of successful connections (0 or 1)';
COMMENT ON COLUMN fact_interactions.rpc_flag IS 'True if Right Party Contact (spoke to account holder)';
COMMENT ON COLUMN fact_interactions.call_outcome IS 'Result of call (e.g., PTP, NoAnswer, Busy, Refusal)';
COMMENT ON COLUMN fact_interactions.aht_seconds IS 'Average Handle Time in seconds (talk + wrap)';
COMMENT ON COLUMN fact_interactions.acw_seconds IS 'After-Call Work time in seconds';
COMMENT ON COLUMN fact_interactions.rpc_arrears IS 'Outstanding arrears amount at time of RPC';
COMMENT ON COLUMN fact_interactions.dpd_at_contact IS 'Days Past Due when contact was made';

-- Fact_PTP_Log
COMMENT ON TABLE fact_ptp_log IS 'Promise-to-Pay events with state machine: scheduled → kept/broken';
COMMENT ON COLUMN fact_ptp_log.ptp_id IS 'Unique promise identifier (format: PTP_XXXXX)';
COMMENT ON COLUMN fact_ptp_log.ptp_date IS 'Date when promise was made (FK to dim_calendar)';
COMMENT ON COLUMN fact_ptp_log.ptp_time IS 'Time of day when promise was made';
COMMENT ON COLUMN fact_ptp_log.agent_id IS 'FK to dim_agents — agent who secured the promise';
COMMENT ON COLUMN fact_ptp_log.account_id IS 'FK to dim_accounts — account promising payment';
COMMENT ON COLUMN fact_ptp_log.promised_amount IS 'Dollar amount promised by the client';
COMMENT ON COLUMN fact_ptp_log.promised_date IS 'Date by which payment was promised';
COMMENT ON COLUMN fact_ptp_log.grace_until_date IS 'Grace period end date before promise is marked broken';
COMMENT ON COLUMN fact_ptp_log.status IS 'Promise state: Scheduled, Kept, Broken';
COMMENT ON COLUMN fact_ptp_log.rpc_arrears_at_contact IS 'Arrears amount when RPC was made';

-- Fact_Payments
COMMENT ON TABLE fact_payments IS 'Payment transactions including cure events and self-cures';
COMMENT ON COLUMN fact_payments.payment_id IS 'Unique payment identifier (format: PAY_XXXXX)';
COMMENT ON COLUMN fact_payments.payment_date IS 'Date payment was made (can include weekends — not a processing date; FK to dim_calendar)';
COMMENT ON COLUMN fact_payments.payment_time IS 'Time of day when payment was processed';
COMMENT ON COLUMN fact_payments.account_id IS 'FK to dim_accounts — account making the payment';
COMMENT ON COLUMN fact_payments.ptp_id IS 'FK to fact_ptp_log — linked promise (NULL for self-cures)';
COMMENT ON COLUMN fact_payments.agent_id IS 'FK to dim_agents — agent who collected (NULL for self-cures)';
COMMENT ON COLUMN fact_payments.amount_paid IS 'Dollar amount of the payment';
COMMENT ON COLUMN fact_payments.payment_method IS 'How payment was made (e.g., Online, Phone, Branch)';
COMMENT ON COLUMN fact_payments.is_cured IS 'True if payment brought account current (DPD = 0)';
COMMENT ON COLUMN fact_payments.cure_flag IS 'Cure type: Agent-Cure, Self-Cure, or NULL';
COMMENT ON COLUMN fact_payments.dpd_at_payment IS 'Days Past Due when payment was made';

-- Fact_Agent_Time_Log
COMMENT ON TABLE fact_agent_time_log IS 'Daily agent utilization: login hours, breaks, THT, and productivity';
COMMENT ON COLUMN fact_agent_time_log.log_id IS 'Unique log entry identifier (format: TML_XXXXX)';
COMMENT ON COLUMN fact_agent_time_log.log_date IS 'Date of the time log entry (FK to dim_calendar)';
COMMENT ON COLUMN fact_agent_time_log.agent_id IS 'FK to dim_agents — agent being tracked';
COMMENT ON COLUMN fact_agent_time_log.login_time IS 'Time agent logged into the dialer';
COMMENT ON COLUMN fact_agent_time_log.logout_time IS 'Time agent logged out of the dialer';
COMMENT ON COLUMN fact_agent_time_log.break_minutes IS 'Total break time in minutes for the day';
COMMENT ON COLUMN fact_agent_time_log.operational_hours IS 'Total productive hours (login - break)';
COMMENT ON COLUMN fact_agent_time_log.tht_hours IS 'Total Handle Time: talk + ACW across all calls';
COMMENT ON COLUMN fact_agent_time_log.utilization IS 'Utilization ratio: THT / Operational Hours (decimal 0-1)';
COMMENT ON COLUMN fact_agent_time_log.schedule_hours IS 'Scheduled shift hours for the day';

-- Fact_EOM_Snapshot
COMMENT ON TABLE fact_eom_snapshot IS 'End-of-month account snapshots: balance, DPD, status, and arrears';
COMMENT ON COLUMN fact_eom_snapshot.snapshot_date IS 'Month-end date (FK to dim_calendar, part of composite PK)';
COMMENT ON COLUMN fact_eom_snapshot.snapshot_month IS 'Month label (e.g., 2025-10) for reporting';
COMMENT ON COLUMN fact_eom_snapshot.account_id IS 'FK to dim_accounts — account being snapshotted (part of composite PK)';
COMMENT ON COLUMN fact_eom_snapshot.status IS 'Account status at month-end (e.g., Current, 30DPD, 60DPD)';
COMMENT ON COLUMN fact_eom_snapshot.balance IS 'Outstanding balance at month-end';
COMMENT ON COLUMN fact_eom_snapshot.arrears IS 'Past-due amount at month-end';
COMMENT ON COLUMN fact_eom_snapshot.dpd IS 'Days Past Due at month-end';
COMMENT ON COLUMN fact_eom_snapshot.dpd_bucket IS 'DPD bucket for grouping: Current, 0-30, 31-60, 61-90, 90+';
COMMENT ON COLUMN fact_eom_snapshot.min_payment IS 'Minimum payment due for next billing cycle';
