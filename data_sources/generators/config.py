"""
MIS Collections — Configuration
================================
Centralized constants for the data generator.
Import with: from .config import CFG, PRODUCT_CFG
"""

# Generator parameters
CFG = {
    "num_supervisors": 8,
    "num_agents":      80,
    "num_clients":     10_000,
    "start_date":      None,   # set by generator after CLI parsing
    "end_date":        None,   # set by generator after CLI parsing

    # Portfolio dynamics
    "mora_rate":                0.25,
    "mora_replenishment_rate":  0.0018,   # daily: Activo -> Mora
    "self_cure_base_rate":      0.0010,   # daily: spontaneous full-arrears payment
    "self_cure_payday_boost":   2.5,      # 60% of self-cures cluster on payday weeks
    "monthly_drift_std":        0.08,     # ±8% monthly rate drift per agent

    # Dialer targeting
    "accts_per_agent_day": (50, 80),
    "mora_contact_pct":    0.72,
    "attempts_per_acct":   (1, 2),

    # Agent profile ranges (skill multiplier applied on top)
    "connection_rate": (0.45, 0.80),
    "rpc_rate_base":   (0.35, 0.65),
    "ptp_rate_base":   (0.65, 0.88),
    "kp_tendency":     (0.70, 0.92),
    "utilization":     (0.85, 0.97),

    # Handle-time normal distributions (seconds)
    "aht_rpc":  {"mu": 245, "sigma": 52},
    "aht_nrpc": {"mu":  58, "sigma": 18},
    "acw_rpc":  {"mu": 125, "sigma": 30},
    "acw_nrpc": {"mu":  22, "sigma":  8},

    # Per-agent personal AHT/ACW offsets (Gauss std dev)
    "aht_rpc_adj_std":  30,
    "aht_nrpc_adj_std": 10,
    "acw_rpc_adj_std":  15,
    "acw_nrpc_adj_std":  5,

    # PTP mechanics
    "promise_window_days": (3, 14),   # days client requests to pay
    "grace_period_days":   (3,  7),   # bank buffer after promise window
    "payment_delay_days":  (0, 16),   # actual payment arrival lag

    "kp_noise_std":   0.05,
    "schedule_hours": 8.0,
    "break_minutes":  (20, 45),

    # Anomaly injection (escalation AHT spikes)
    "anomaly_prob": 0.018,
    "anomaly_mul":  (2.0, 3.5),
}

# Product catalogue
PRODUCT_CFG = {
    "Tarjeta": {
        "id": 1, "name": "Credit Card Standard",
        "rate": 25.99, "grace_days": 25,
        "rule": "2% of Balance",
        "bal_range": (500, 25_000),
        "rpc_boost": 1.00,   # no collateral — hardest to reach when evading
    },
    "Prestamo": {
        "id": 2, "name": "Personal Loan 5yr",
        "rate": 12.50, "grace_days": 0,
        "rule": "Fixed Monthly Installment",
        "bal_range": (3_000, 80_000),
        "rpc_boost": 1.15,   # some collateral
    },
    "Hipoteca": {
        "id": 3, "name": "Mortgage 30yr",
        "rate": 5.85, "grace_days": 0,
        "rule": "Fixed Monthly Installment",
        "bal_range": (50_000, 500_000),
        "rpc_boost": 1.22,   # highest collateral — most motivated to answer
    },
}

# Call-outcome pools
CONTACT_NON_RPC = (["Third_Party", "Wrong_Number", "Message_w_Relative"], [0.45, 0.35, 0.20])
NON_CONTACT = (["Voicemail", "No_Answer", "Busy"], [0.60, 0.30, 0.10])

PAY_METHODS = ["Online", "Branch/ATM", "OFI"]
PAY_WEIGHTS  = [0.45, 0.25, 0.30]
