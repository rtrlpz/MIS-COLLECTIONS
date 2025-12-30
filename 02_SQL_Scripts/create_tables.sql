-- Clients
CREATE TABLE clients(
    client_id   INT PRIMARY KEY AUTO_INCREMENT,
    name        VARCHAR(100) NOT NULL,
    dob         DATE,
    segment     VARCHAR(50), -- retail, tarjeta, prestamo
    risk_score  DECIMAL(5, 2)
);

-- Products
CREATE TABLE products (
    product_id INT PRIMARY KEY AUTO_INCREMENT,
    product_name    VARCHAR(100) NOT NULL,
    product_type VARCHAR(50) NOT NULL,
    interest_rate   DECIMAL(5,2),
    grace_period_days INT,
    default_min_payment_rule VARCHAR(100)
);

-- Accounts
CREATE TABLE accounts (
    account_id      INT PRIMARY KEY AUTO_INCREMENT,
    client_id       INT NOT NULL,
    product_id      INT NOT NULL,
    open_date       DATE NOT NULL,  -- Fecha apertura
    due_date        DATE, -- fecha pago mensual
    min_payment     DECIMAL(12, 2) NOT NULL,
    balance DECIMAL(12, 2) NOT NULL,
    status VARCHAR(20) CHECK (status IN ('Activo', 'Mora', 'Cerrado')),
    CONSTRAINT fk_accounts_clients FOREIGN KEY (client_id) REFERENCES clients(client_id),
    CONSTRAINT fk_accounts_products FOREIGN KEY (product_id) REFERENCES products(product_id)
);


-- Supervisors
CREATE TABLE supervisors (
    supervisor_id   INT PRIMARY KEY AUTO_INCREMENT,
    name            VARCHAR(100) NOT NULL,
    team_name       VARCHAR(50),
    region          VARCHAR(50)
);


-- Agents
CREATE TABLE agents (
    agent_id    INT PRIMARY KEY AUTO_INCREMENT,
    agent_name  VARCHAR(100) NOT NULL,
    supervisor_id  INT,
    CONSTRAINT fk_agents_supervisor FOREIGN KEY (supervisor_id) REFERENCES supervisors(supervisor_id)
);


-- Dialer Interactions (POM)
CREATE TABLE dialer_interactions (
    interaction_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    date    DATE NOT NULL,
    agent_id    INT NOT NULL,
    account_id  INT NOT NULL,
    calls_attempted   INT NOT NULL,
    calls_connected   INT NOT NULL,
    rpc_flag BOOLEAN NOT NULL, -- 1 si fue RPC 0 si fue No RPC
    aht_seconds INT, -- Average handle time
    acw_seconds INT, -- After call work
    CONSTRAINT fk_dialer_agents FOREIGN KEY (agent_id) REFERENCES agents(agent_id),
    CONSTRAINT fk_dialer_accounts FOREIGN KEY (account_id) REFERENCES accounts(account_id)
);

-- PTP Log (CACS)
CREATE TABLE ptp_log (
    ptp_id  BIGINT PRIMARY KEY AUTO_INCREMENT,
    date_of_interaction     DATE NOT NULL,
    agent_id    INT NOT NULL,
    account_id  INT NOT NULL,
    amount_promised DECIMAL(12, 2) NOT NULL,
    status  VARCHAR(20) CHECK (status IN ('Pending', 'Kept', 'Broken')),
    CONSTRAINT fk_ptp_agents FOREIGN KEY (agent_id) REFERENCES agents(agent_id),
    CONSTRAINT fk_ptp_accounts FOREIGN KEY (account_id) REFERENCES accounts(account_id)
);

-- Cures log
CREATE TABLE cures_log (
    cure_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    payment_date DATE NOT NULL,
    agent_id    INT NOT NULL,
    account_id  INT NOT NULL,
    amount_paid DECIMAL(12, 2) NOT NULL,
    payment_method VARCHAR(50) CHECK (payment_method IN ('Online', 'Branch/ATM', 'OFI')),
    CONSTRAINT fk_cure_agents FOREIGN KEY (agent_id) REFERENCES agents(agent_id),
    CONSTRAINT fk_cure_accounts FOREIGN KEY (account_id) REFERENCES accounts(account_id)
);

-- Payment schedule
CREATE TABLE payment_schedule ( -- quizás linkear con ptp, no se si necesario
    schedule_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    account_id INT NOT NULL,
    due_date DATE NOT NULL,
    expected_amount     DECIMAL(12,2) NOT NULL,
    status VARCHAR(20) CHECK (status IN ('Pending', 'Paid', 'Overdue')),
    CONSTRAINT fk_schedule_accounts FOREIGN KEY (account_id) REFERENCES accounts(account_id)
);

-- Agent schedule
CREATE TABLE agent_time_log (
    time_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    date DATE NOT NULL,
    agent_id    INT NOT NULL,
    login_time  TIME NOT NULL,
    logout_time TIME NOT NULL,
    break_minutes   INT,
    operational_hours   DECIMAL(5, 2), --horas operativas
    tht_hours   DECIMAL(5, 2),
    schedule_time   DATETIME,
    utilization DECIMAL(5, 2), -- %
    CONSTRAINT fk_time_agents FOREIGN KEY (agent_id) REFERENCES agents(agent_id)
);


