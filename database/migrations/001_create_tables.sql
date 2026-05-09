-- =========================================================================
-- 1. CLEANUP (Reverse order to handle Foreign Keys)
-- =========================================================================
DROP TABLE IF EXISTS fact_eom_snapshot CASCADE;
DROP TABLE IF EXISTS fact_agent_time_log CASCADE;
DROP TABLE IF EXISTS fact_payments CASCADE;
DROP TABLE IF EXISTS fact_ptp_log CASCADE;
DROP TABLE IF EXISTS fact_interactions CASCADE;
DROP TABLE IF EXISTS dim_accounts CASCADE;
DROP TABLE IF EXISTS dim_products CASCADE;
DROP TABLE IF EXISTS dim_clients CASCADE;
DROP TABLE IF EXISTS dim_agents CASCADE;
DROP TABLE IF EXISTS dim_supervisors CASCADE;
DROP TABLE IF EXISTS dim_calendar CASCADE;

-- =========================================================================
-- 2. DIMENSION TABLES (Shared)
-- =========================================================================

CREATE TABLE dim_supervisors (
    supervisor_id VARCHAR(15) PRIMARY KEY,
    supervisor_name VARCHAR(100) NOT NULL,
    team_name VARCHAR(50),
    region VARCHAR(50)
);

CREATE TABLE dim_agents (
    agent_id VARCHAR(15) PRIMARY KEY,
    agent_name VARCHAR(100) NOT NULL,
    supervisor_id VARCHAR(15),
    supervisor_name VARCHAR(100),
    team_name VARCHAR(50),
    region VARCHAR(50),
    skill_score DECIMAL(5,3)
);

CREATE TABLE dim_clients (
    client_id VARCHAR(15) PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    dob DATE,
    segment VARCHAR(50),
    risk_score DECIMAL(5,2)
);

CREATE TABLE dim_products (
    product_id VARCHAR(15) PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    product_type VARCHAR(50) NOT NULL,
    annual_rate_pct DECIMAL(5,2),
    grace_days INT,
    min_payment_rule VARCHAR(100)
);

CREATE TABLE dim_calendar (
    date DATE PRIMARY KEY,
    year INT,
    quarter INT,
    month_num INT,
    month_name VARCHAR(20),
    iso_week INT,
    day_of_week INT,
    day_name VARCHAR(20),
    is_weekday BOOLEAN,
    is_month_end BOOLEAN,
    is_payday_week BOOLEAN,
    payday_factor DECIMAL(5,2)
);

CREATE TABLE dim_accounts (
    account_id VARCHAR(15) PRIMARY KEY,
    client_id VARCHAR(15) NOT NULL,
    product_id VARCHAR(15) NOT NULL,
    open_date DATE NOT NULL,
    due_day INT,
    min_payment DECIMAL(12, 2) NOT NULL,
    initial_balance DECIMAL(12, 2) NOT NULL,
    initial_status VARCHAR(20),
    CONSTRAINT fk_accounts_clients FOREIGN KEY (client_id) REFERENCES dim_clients(client_id),
    CONSTRAINT fk_accounts_products FOREIGN KEY (product_id) REFERENCES dim_products(product_id)
);

-- =========================================================================
-- 3. FACT TABLES (Transactional)
-- =========================================================================

CREATE TABLE fact_interactions (
    interaction_id VARCHAR(15) PRIMARY KEY,
    interaction_date DATE NOT NULL,
    interaction_time TIME NOT NULL,
    agent_id VARCHAR(15) NOT NULL,
    account_id VARCHAR(15) NOT NULL,
    calls_attempted INT,
    calls_connected INT,
    rpc_flag BOOLEAN,
    call_outcome VARCHAR(50),
    aht_seconds INT,
    acw_seconds INT,
    rpc_arrears DECIMAL(12,2),
    dpd_at_contact INT,
    CONSTRAINT fk_int_agents FOREIGN KEY (agent_id) REFERENCES dim_agents(agent_id),
    CONSTRAINT fk_int_accounts FOREIGN KEY (account_id) REFERENCES dim_accounts(account_id),
    CONSTRAINT fk_int_date FOREIGN KEY (interaction_date) REFERENCES dim_calendar(date)
);

CREATE TABLE fact_ptp_log (
    ptp_id VARCHAR(15) PRIMARY KEY,
    ptp_date DATE NOT NULL,
    ptp_time TIME NOT NULL,
    agent_id VARCHAR(15) NOT NULL,
    account_id VARCHAR(15) NOT NULL,
    promised_amount DECIMAL(12, 2) NOT NULL,
    promised_date DATE,
    grace_until_date DATE,
    status VARCHAR(20),
    rpc_arrears_at_contact DECIMAL(12,2),
    CONSTRAINT fk_ptp_agents FOREIGN KEY (agent_id) REFERENCES dim_agents(agent_id),
    CONSTRAINT fk_ptp_accounts FOREIGN KEY (account_id) REFERENCES dim_accounts(account_id),
    CONSTRAINT fk_ptp_date FOREIGN KEY (ptp_date) REFERENCES dim_calendar(date)
);

CREATE TABLE fact_payments (
    payment_id VARCHAR(15) PRIMARY KEY,
    payment_date DATE NOT NULL,
    payment_time TIME NOT NULL,
    account_id VARCHAR(15) NOT NULL,
    ptp_id VARCHAR(15), -- Nullable due to self-cures
    agent_id VARCHAR(15), -- Nullable due to self-cures
    amount_paid DECIMAL(12, 2) NOT NULL,
    payment_method VARCHAR(50),
    is_cured BOOLEAN,
    cure_flag VARCHAR(20),
    dpd_at_payment INT,
    CONSTRAINT fk_pay_accounts FOREIGN KEY (account_id) REFERENCES dim_accounts(account_id),
    CONSTRAINT fk_pay_date FOREIGN KEY (payment_date) REFERENCES dim_calendar(date)
    -- Intentionally left off the explicit ptp_id FK constraint here to prevent insertion order headaches,
    -- but it connects perfectly in Power BI.
);

CREATE TABLE fact_agent_time_log (
    log_id VARCHAR(15) PRIMARY KEY,
    log_date DATE NOT NULL,
    agent_id VARCHAR(15) NOT NULL,
    login_time TIME,
    logout_time TIME,
    break_minutes INT,
    operational_hours DECIMAL(5, 2),
    tht_hours DECIMAL(5, 2),
    utilization DECIMAL(5, 2),
    schedule_hours DECIMAL(5,2),
    CONSTRAINT fk_time_agents FOREIGN KEY (agent_id) REFERENCES dim_agents(agent_id),
    CONSTRAINT fk_time_date FOREIGN KEY (log_date) REFERENCES dim_calendar(date)
);

CREATE TABLE fact_eom_snapshot (
    snapshot_date DATE NOT NULL,
    snapshot_month VARCHAR(20),
    account_id VARCHAR(15) NOT NULL,
    status VARCHAR(20),
    balance DECIMAL(12, 2),
    arrears DECIMAL(12, 2),
    dpd INT,
    dpd_bucket VARCHAR(20),
    min_payment DECIMAL(12,2),
    -- Composite primary key to ensure one record per account per month
    PRIMARY KEY (snapshot_date, account_id),
    CONSTRAINT fk_eom_accounts FOREIGN KEY (account_id) REFERENCES dim_accounts(account_id),
    CONSTRAINT fk_eom_date FOREIGN KEY (snapshot_date) REFERENCES dim_calendar(date)
);