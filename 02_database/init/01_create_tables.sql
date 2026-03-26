-- Supervisors
CREATE TABLE supervisors (
    supervisor_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    team_name VARCHAR(50),
    region VARCHAR(50)
);

-- Agents
CREATE TABLE agents (
    agent_id VARCHAR(10) PRIMARY KEY,
    agent_name VARCHAR(100) NOT NULL,
    supervisor_id INT,
    CONSTRAINT fk_agents_supervisor FOREIGN KEY (supervisor_id) REFERENCES supervisors(supervisor_id)
);

-- Clients
CREATE TABLE clients (
    client_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    dob DATE,
    segment VARCHAR(50),
    risk_score DECIMAL(5, 2)
);

-- Products
CREATE TABLE products (
    product_id SERIAL PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    product_type VARCHAR(50) NOT NULL,
    interest_rate DECIMAL(5,2),
    grace_period_days INT,
    default_min_payment_rule VARCHAR(100)
);

-- Accounts
CREATE TABLE accounts (
    account_id SERIAL PRIMARY KEY,
    client_id INT NOT NULL,
    product_id INT NOT NULL,
    open_date DATE NOT NULL,
    due_date DATE,
    min_payment DECIMAL(12, 2) NOT NULL,
    balance DECIMAL(12, 2) NOT NULL,
    status VARCHAR(20),
    CONSTRAINT fk_accounts_clients FOREIGN KEY (client_id) REFERENCES clients(client_id),
    CONSTRAINT fk_accounts_products FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- Dialer Interactions (POM)
CREATE TABLE dialer_interactions (
    interaction_id BIGSERIAL PRIMARY KEY,
    date TIMESTAMP NOT NULL,
    agent_id VARCHAR(10) NOT NULL,
    account_id INT NOT NULL,
    calls_attempted INT,
    calls_connected INT,
    rpc_flag VARCHAR(10),
    aht_seconds INT,
    acw_seconds INT,
    CONSTRAINT fk_dialer_agents FOREIGN KEY (agent_id) REFERENCES agents(agent_id),
    CONSTRAINT fk_dialer_accounts FOREIGN KEY (account_id) REFERENCES accounts(account_id)
);

-- PTP Log (CACS)
CREATE TABLE ptp_log (
    ptp_id BIGSERIAL PRIMARY KEY,
    date_of_interaction TIMESTAMP NOT NULL,
    agent_id VARCHAR(10) NOT NULL,
    account_id INT NOT NULL,
    amount_promised DECIMAL(12, 2) NOT NULL,
    status VARCHAR(20),
    CONSTRAINT fk_ptp_agents FOREIGN KEY (agent_id) REFERENCES agents(agent_id),
    CONSTRAINT fk_ptp_accounts FOREIGN KEY (account_id) REFERENCES accounts(account_id)
);

-- Cures log
CREATE TABLE cures_log (
    cure_id BIGSERIAL PRIMARY KEY,
    payment_date TIMESTAMP NOT NULL,
    agent_id VARCHAR(10) NOT NULL,
    account_id INT NOT NULL,
    amount_paid DECIMAL(12, 2) NOT NULL,
    payment_method VARCHAR(50),
    CONSTRAINT fk_cure_agents FOREIGN KEY (agent_id) REFERENCES agents(agent_id),
    CONSTRAINT fk_cure_accounts FOREIGN KEY (account_id) REFERENCES accounts(account_id)
);

-- Payment schedule
CREATE TABLE payment_schedule (
    schedule_id BIGSERIAL PRIMARY KEY,
    account_id INT NOT NULL,
    due_date DATE NOT NULL,
    expected_amount DECIMAL(12,2) NOT NULL,
    status VARCHAR(20),
    CONSTRAINT fk_schedule_accounts FOREIGN KEY (account_id) REFERENCES accounts(account_id)
);

-- Agent Time Log
CREATE TABLE agent_time_log (
    time_id BIGSERIAL PRIMARY KEY,
    date DATE NOT NULL,
    agent_id VARCHAR(10) NOT NULL,
    login_time TIME,
    logout_time TIME,
    break_minutes INT,
    operational_hours DECIMAL(5, 2),
    tht_hours DECIMAL(5, 2),
    schedule_time TIMESTAMP,
    utilization DECIMAL(5, 2),
    CONSTRAINT fk_time_agents FOREIGN KEY (agent_id) REFERENCES agents(agent_id)
);