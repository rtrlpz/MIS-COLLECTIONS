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
    "self_cure_base_rate":      0.020,    # daily: spontaneous full-arrears payment
    "self_cure_payday_boost":   2.5,      # 60% of self-cures cluster on payday weeks
    "monthly_drift_std":        0.08,     # ±8% monthly rate drift per agent

    # Dialer targeting
    "accts_per_agent_day": (50, 80),
    "mora_contact_pct":    0.90,
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

# ============================================================================
# PHASE 6: GENERATOR ENHANCEMENTS (G1-G9)
# ============================================================================
# These parameters drive data diversity for the 9 Power BI dashboards.
# Each section corresponds to a generator enhancement identified in PLAN_DASHBOARDS.md.

# --- G1: Vintage/Cohort Account open_date Spread ---
# Accounts need diverse open_date values spread across 12-24 months,
# not all clustered within the last 3 months. This enables vintage/months-on-book analysis.
VINTAGE_CFG = {
    "open_date_start_month": -23,     # Months before data start (e.g., -23 = ~2 years ago)
    "open_date_end_month": -2,        # Months before data start (e.g., -2 = last month)
    "open_date_distribution": "weighted",  # "uniform" | "weighted" (more recent = more accounts)
    "open_date_weights": {            # Weights for weighted distribution (normalized internally)
        -23: 2, -22: 2, -21: 2, -20: 3, -19: 3, -18: 4,
        -17: 4, -16: 5, -15: 5, -14: 6, -13: 6, -12: 7,
        -11: 7, -10: 8, -9: 8, -8: 9, -7: 9, -6: 10,
        -5: 10, -4: 11, -3: 11, -2: 12, -1: 12, 0: 0,
    },
}

# --- G2: Agent Experience Distribution (Hire Dates) ---
# Agents need varied hire dates: some 3+ years, some <6 months,
# to analyze experience impact on performance metrics.
AGENT_HIRE_CFG = {
    "hire_date_start_month": -48,     # Months before data start (e.g., -48 = 4 years ago)
    "hire_date_end_month": -1,        # Months before data start
    "hire_date_distribution": "weighted",  # More recent hires = more agents
    "experience_tiers": {
        "senior": {"min_months": 36, "max_months": 48, "pct": 0.25},   # 25% senior agents
        "mid":    {"min_months": 12, "max_months": 35, "pct": 0.40},   # 40% mid-level
        "junior": {"min_months": 0,  "max_months": 11, "pct": 0.35},   # 35% junior
    },
    "agent_cost_per_hour": {         # By experience tier (for Financial Recovery page)
        "senior": 38.00,             # Senior agent rate
        "mid": 32.00,                # Mid-level rate
        "junior": 26.00,             # Junior rate
    },
}

# --- G3: Credit Limit Spread ---
# Credit limits need realistic distribution across account types,
# not uniform $50K. Enables Credit Risk page analysis.
CREDIT_LIMIT_CFG = {
    "tarjeta_credit_limit": {        # Credit card limits
        "min": 1000, "max": 25000,
        "distribution": "lognormal", # More accounts at lower limits
        "mean_log": 8.5,            # ln(4915) ≈ 8.5 → median ~$5K
        "sigma_log": 0.8,
    },
    "prestamo_credit_limit": {       # Personal loan amounts
        "min": 5000, "max": 50000,
        "distribution": "lognormal",
        "mean_log": 9.5,            # ln(13360) ≈ 9.5 → median ~$13K
        "sigma_log": 0.7,
    },
    "hipoteca_credit_limit": {       # Mortgage amounts
        "min": 100000, "max": 800000,
        "distribution": "lognormal",
        "mean_log": 12.5,           # ln(268337) ≈ 12.5 → median ~$268K
        "sigma_log": 0.6,
    },
}

# --- G4: Income Bracket ---
# Client income brackets for Credit Risk page analysis.
# Enables understanding of recovery patterns by income segment.
INCOME_BRACKET_CFG = {
    "brackets": ["<30K", "30K-50K", "50K-75K", "75K-100K", "100K+"],
    "weights": [0.15, 0.25, 0.30, 0.20, 0.10],  # More in middle brackets
}

# --- G5: Dialer Channel Mix ---
# Calls need channel classification (Dialer/FICO/SMS/Manual),
# with Dialer being the primary channel. Enables Dialer Performance page.
CHANNEL_CFG = {
    "channels": ["Dialer", "Manual", "FICO", "SMS"],
    "weights": [0.65, 0.15, 0.10, 0.10],  # 65% dialer, 15% manual, 10% each other
    "rpc_rate_by_channel": {        # RPC% varies by channel
        "Dialer": 0.42,
        "Manual": 0.58,
        "FICO": 0.08,
        "SMS": 0.12,
    },
    "outbound_only": True,          # All interactions are outbound (no inbound queue data)
}

# --- G6: Write-off Events ---
# Write-offs occur when accounts move through 90+ DPD aging,
# enabling Financial Recovery page (Net Recovery, Cost to Collect, Write-off Amount).
WRITEOFF_CFG = {
    "enabled": True,
    "trigger_bucket": "91+",        # Write-off triggers at 91+ DPD
    "write_off_rate": 0.05,         # 5% of 91+ DPD accounts get written off per month
    "write_off_amount_pct": {       # % of outstanding balance written off
        "91+": 1.0,                 # Full write-off at 91+
    },
}

# --- G7: 12-Month Data Expansion ---
# Expand from 3 months to 12 months (Jan-Dec 2025).
# Requires seasonal patterns for realistic full-year data.
DATA_EXPANSION_CFG = {
    "num_months": 12,               # Generate 12 months of data
    "start_year": 2025,
    "start_month": 1,               # January 2025
    "seasonal_volume": {            # Monthly volume multipliers
        1: 0.85,  # January (post-holiday dip)
        2: 0.90,  # February
        3: 1.00,  # March (baseline)
        4: 1.02,  # April
        5: 1.05,  # May
        6: 1.08,  # June (mid-year push)
        7: 1.03,  # July (summer)
        8: 0.98,  # August
        9: 1.00,  # September (back to school)
        10: 1.05, # October (Q4 push)
        11: 1.10, # November (year-end urgency)
        12: 0.80, # December (holidays)
    },
    "seasonal_mora": {              # Monthly delinquency multipliers
        1: 1.10,  # January (post-holiday delinquency spike)
        2: 1.05,  # February
        3: 0.95,  # March (tax refunds)
        4: 0.90,  # April
        5: 0.88,  # May
        6: 0.92,  # June
        7: 0.95,  # July
        8: 0.98,  # August
        9: 1.00,  # September
        10: 1.05, # October
        11: 1.10, # November (holiday debt)
        12: 1.15, # December (holiday delinquency)
    },
}

# --- G8: Supervisor Hire Dates ---
# Supervisors need hire dates for tenure calculations and organizational hierarchy.
SUPERVISOR_HIRE_CFG = {
    "hire_date_start_month": -60,    # Months before data start (e.g., -60 = 5 years)
    "hire_date_end_month": -6,       # Months before data start
}

# --- G9: Agent Cost Model ---
# Cost per hour varies by experience tier for Financial Recovery page.
# Enables "Cost to Collect" and "Cost per Dollar Collected" KPIs.
AGENT_COST_CFG = {
    "cost_per_hour": {
        "senior": 38.00,            # 3+ years experience
        "mid": 32.00,               # 1-3 years experience
        "junior": 26.00,            # <1 year experience
    },
    "overhead_multiplier": 1.25,    # Add 25% overhead (benefits, tools, etc.)
    "productivity_hours_per_day": 6.5,  # Productive hours per day (out of 8)
}
