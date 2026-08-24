"""
MIS Collections — Data Generator v7 (Star Schema Edition)
==========================================================
Strict Star Schema engine for Power BI:
  - Dim_ / Fact_ naming throughout; Date and Time as separate columns
  - DPD anchored to monthly billing cycle, not random daily increment
  - Payday seasonality: spike payments around the 15th and month-end
  - Event-driven PTP state machine with grace period resolution
  - Agent-Cure vs Self-Cure distinction on every payment
  - Fact_EOM_Snapshot: month-end balance/arrears/DPD-bucket per account
  - Fact_Writeoffs: write-off events at 91+ DPD
  - Payments allowed on any date (payment_date = date made, not processed); interactions during 08:00–21:00 weekdays only

Phase 6 Enhancements (G1-G9):
  - G1: Vintage open_date spread (23 months, weighted distribution)
  - G2: Agent hire dates + experience tiers (senior/mid/junior)
  - G3: Credit limit lognormal distribution per product
  - G4: Client income brackets (5 segments)
  - G5: Interaction channel mix (Dialer/FICO/SMS/Manual)
  - G6: Fact_Writeoffs table (5% write-off rate at 91+ DPD)
  - G7: 12-month data expansion (Jan-Dec 2025, seasonal patterns)
  - G8: Supervisor hire dates (5-year span)
  - G9: Agent cost model (hourly rates by tier + overhead)
"""

import os
import sys
import time
import random
import logging
import calendar
import argparse
from datetime import date, datetime, timedelta
from collections import defaultdict
from pathlib import Path

import numpy as np
import pandas as pd
from faker import Faker

BASE_PATH  = Path(__file__).resolve().parent

# ═══════════════════════════════════════════════════════════════════════════
# LOGGING SETUP
# ═══════════════════════════════════════════════════════════════════════════

logger = logging.getLogger("mis_collections_generator")
logger.setLevel(logging.DEBUG)

# Console handler
console_handler = logging.StreamHandler()
console_handler.setLevel(logging.INFO)
console_formatter = logging.Formatter("%(asctime)s | %(levelname)-8s | %(message)s", datefmt="%H:%M:%S")
console_handler.setFormatter(console_formatter)
logger.addHandler(console_handler)

# File handler → data_sources/logs/
LOG_DIR = BASE_PATH / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)
LOG_FILE = LOG_DIR / "generator.log"

file_handler = logging.FileHandler(LOG_FILE, mode="w", encoding="utf-8")
file_handler.setLevel(logging.DEBUG)
file_formatter = logging.Formatter("%(asctime)s | %(levelname)-8s | %(message)s", datefmt="%Y-%m-%d %H:%M:%S")
file_handler.setFormatter(file_formatter)
logger.addHandler(file_handler)

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURATION (imported from config.py)
# ═══════════════════════════════════════════════════════════════════════════

try:
    from .config import (
        CFG, PRODUCT_CFG, CONTACT_NON_RPC, NON_CONTACT, PAY_METHODS, PAY_WEIGHTS,
        VINTAGE_CFG, AGENT_HIRE_CFG, CREDIT_LIMIT_CFG, INCOME_BRACKET_CFG,
        CHANNEL_CFG, WRITEOFF_CFG, DATA_EXPANSION_CFG, SUPERVISOR_HIRE_CFG,
        AGENT_COST_CFG,
    )
except ImportError:
    from config import (
        CFG, PRODUCT_CFG, CONTACT_NON_RPC, NON_CONTACT, PAY_METHODS, PAY_WEIGHTS,
        VINTAGE_CFG, AGENT_HIRE_CFG, CREDIT_LIMIT_CFG, INCOME_BRACKET_CFG,
        CHANNEL_CFG, WRITEOFF_CFG, DATA_EXPANSION_CFG, SUPERVISOR_HIRE_CFG,
        AGENT_COST_CFG,
    )

BASE_PATH  = Path(__file__).resolve().parent
OUTPUT_DIR = BASE_PATH / "raw"
CFG["output_dir"] = str(OUTPUT_DIR)
CFG["start_date"] = date(DATA_EXPANSION_CFG["start_year"], DATA_EXPANSION_CFG["start_month"], 1)
CFG["end_date"]   = date(2025, 12, 31)

# ═══════════════════════════════════════════════════════════════════════════
# CLI ARGUMENTS
# ═══════════════════════════════════════════════════════════════════════════

parser = argparse.ArgumentParser(
    description="MIS Collections Data Generator v7 — Synthetic bank collections data"
)
parser.add_argument(
    "--output-dir", type=str, default=None,
    help="Output directory for generated CSVs (default: data_sources/raw)"
)
parser.add_argument(
    "--months", type=str, default="1,2,3,4,5,6,7,8,9,10,11,12",
    help="Comma-separated month numbers to generate (default: all 12 months)"
)
parser.add_argument(
    "--seed", type=int, default=42,
    help="Random seed for reproducibility (default: 42)"
)
parser.add_argument(
    "--log-level", type=str, default="INFO", choices=["DEBUG", "INFO", "WARNING", "ERROR"],
    help="Logging verbosity (default: INFO)"
)
args = parser.parse_args()

# Configure logging based on CLI argument
logger.setLevel(getattr(logging, args.log_level))
console_handler.setLevel(getattr(logging, args.log_level))

# Override CFG based on CLI arguments
if args.output_dir:
    CFG["output_dir"] = args.output_dir

if args.months:
    months = [int(m) for m in args.months.split(",")]
    year = 2025
    CFG["start_date"] = date(year, min(months), 1)
    max_month = max(months)
    CFG["end_date"] = date(year, max_month, calendar.monthrange(year, max_month)[1])

# ═══════════════════════════════════════════════════════════════════════════
# SEED (applied after CLI overrides for reproducibility)
# ═══════════════════════════════════════════════════════════════════════════

t_start = time.time()
logger.info("MIS Collections Data Generator v7")
logger.info("Output: %s", CFG["output_dir"])
logger.info("Date range: %s → %s", CFG["start_date"], CFG["end_date"])
logger.info("Seed: %d", args.seed)
logger.info("---")

fake = Faker("es_ES")
Faker.seed(args.seed)
random.seed(args.seed)
np.random.seed(args.seed)

# ═══════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════

START      = CFG["start_date"]
END        = CFG["end_date"]
DATE_RANGE = [START + timedelta(days=i) for i in range((END - START).days + 1)]

# Extended calendar for Power BI time intelligence (PREVIOUSMONTH etc.)
# Includes one month before START so DATEADD(..., -1, MONTH) resolves correctly.
_month   = START.month - 1 if START.month > 1 else 12
_year    = START.year if START.month > 1 else START.year - 1
CAL_START = date(_year, _month, 1)
CAL_RANGE = [CAL_START + timedelta(days=i) for i in range((END - CAL_START).days + 1)]


def fmt_id(prefix, n, w):
    return f"{prefix}-{str(n).zfill(w)}"


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def gauss_secs(mu, sigma, adj=0.0):
    return max(5, int(random.gauss(mu + adj, sigma)))


def is_weekday(d: date) -> bool:
    return d.weekday() < 5


def rand_time_str(open_h: int, close_h: int) -> str:
    """Return HH:MM:SS string within [open_h, close_h)."""
    h = random.randint(open_h, close_h - 1)
    return f"{h:02d}:{random.randint(0,59):02d}:{random.randint(0,59):02d}"


def payday_factor(d: date) -> float:
    """
    Payment probability multiplier based on payday seasonality.
    Spike near the 15th (mid-month pay) and last 3 / first 2 days (month-end pay).
    """
    day     = d.day
    max_day = calendar.monthrange(d.year, d.month)[1]
    if 13 <= day <= 17:
        return 1.55
    if day >= max_day - 2 or day <= 2:
        return 1.75
    return 1.0


def last_day(d: date) -> date:
    return date(d.year, d.month, calendar.monthrange(d.year, d.month)[1])


def safe_due_day(year: int, month: int, due_day: int) -> int:
    """Clamp due_day to the actual number of days in that month."""
    return min(due_day, calendar.monthrange(year, month)[1])


def calc_min_payment(p_type: str, balance: float) -> float:
    if p_type == "Tarjeta":
        return round(max(balance * 0.005, balance * 0.02), 2)
    if p_type == "Prestamo":
        return round(balance / random.uniform(36, 72), 2)
    return round(balance / random.uniform(180, 360), 2)       # Hipoteca


def lognormal_clamp(mean_log, sigma_log, lo, hi):
    """Generate a lognormal-distributed value clamped to [lo, hi]."""
    val = random.lognormvariate(mean_log, sigma_log)
    return clamp(round(val, 2), lo, hi)


def weighted_choice(weights):
    """Return index chosen from weights list."""
    return random.choices(range(len(weights)), weights=weights)[0]


# ═══════════════════════════════════════════════════════════════════════════
# SECTION 1 — DIMENSION TABLES
# ═══════════════════════════════════════════════════════════════════════════

t_stage = time.time()
logger.info("Building dimension tables...")

# ── Dim_Employees (merged supervisors + agents) ─────────────────────────────
# Supervisors get agent_id = SUP-01..SUP-08, agents get EID-001..EID-080
# Self-referencing hierarchy: agents.supervisor_id → supervisors.agent_id
# Agent-only columns (tenure_cohort, skills) are NULL for supervisors

employee_rows = []
agent_profile = {}   # simulation-internal; not exported directly

TENURE_COHORTS = ["Low", "Mid", "High"]
TENURE_WEIGHTS = [0.30, 0.40, 0.30]

# G2: Experience tier definitions from AGENT_HIRE_CFG
EXP_TIERS = AGENT_HIRE_CFG["experience_tiers"]
EXP_TIER_NAMES = list(EXP_TIERS.keys())
EXP_TIER_WEIGHTS = [EXP_TIERS[t]["pct"] for t in EXP_TIER_NAMES]


def tenure_adjusted_range(cohort, lo, hi):
    span = hi - lo
    if cohort == "Low":
        return (lo, lo + span * 0.33)
    elif cohort == "Mid":
        return (lo + span * 0.33, lo + span * 0.67)
    else:
        return (lo + span * 0.67, hi)


def random_hire_date(tier_name):
    """Generate a random hire date within the tier's experience range."""
    tier = EXP_TIERS[tier_name]
    months_ago = random.randint(tier["min_months"], tier["max_months"])
    hire = START - timedelta(days=months_ago * 30)
    return str(hire)


# ── Generate supervisors first (so agents can reference them) ──
sup_agent_ids = []   # will hold SUP-01..SUP-08 for agent assignment

for i in range(1, CFG["num_supervisors"] + 1):
    sup_eid = fmt_id("SUP", i, 2)
    sup_agent_ids.append(sup_eid)
    employee_rows.append({
        "agent_id":          sup_eid,
        "agent_name":        fake.name(),
        "employee_type":     "Supervisor",
        "supervisor_id":     None,          # supervisors have no manager in this model
        "team_name":         f"Team {i}",
        "region":            random.choice(["North", "South", "East", "West"]),
        "hire_date":         str(START + timedelta(
            days=random.randint(SUPERVISOR_HIRE_CFG["hire_date_start_month"] * 30,
                                SUPERVISOR_HIRE_CFG["hire_date_end_month"] * 30)
        )),
        "experience_tier":   "senior",      # supervisors are always senior
        "cost_per_hour":     AGENT_HIRE_CFG["agent_cost_per_hour"]["senior"],
        "tenure_cohort":     None,
        "contact_skill":     None,
        "negotiation_skill": None,
        "efficiency_skill":  None,
    })

# ── Generate agents ─────────────────────────────────────────────────────────
for i in range(1, CFG["num_agents"] + 1):
    eid = fmt_id("EID", i, 3)
    contact_skill = clamp(random.gauss(1.0, 0.15), 0.70, 1.30)
    negotiation_skill = clamp(random.gauss(1.0, 0.15), 0.70, 1.30)
    efficiency_skill = clamp(random.gauss(1.0, 0.10), 0.80, 1.20)
    tenure_cohort = random.choices(TENURE_COHORTS, weights=TENURE_WEIGHTS)[0]
    exp_tier = random.choices(EXP_TIER_NAMES, weights=EXP_TIER_WEIGHTS)[0]
    sid = random.choice(sup_agent_ids)

    employee_rows.append({
        "agent_id":          eid,
        "agent_name":        fake.name(),
        "employee_type":     "Agent",
        "supervisor_id":     sid,
        "team_name":         None,          # filled from supervisor lookup below
        "region":            None,
        "hire_date":         random_hire_date(exp_tier),
        "experience_tier":   exp_tier,
        "cost_per_hour":     AGENT_HIRE_CFG["agent_cost_per_hour"][exp_tier],
        "tenure_cohort":     tenure_cohort,
        "contact_skill":     round(contact_skill, 3),
        "negotiation_skill": round(negotiation_skill, 3),
        "efficiency_skill":  round(efficiency_skill, 3),
    })

    c_lo, c_hi = tenure_adjusted_range(tenure_cohort, *CFG["connection_rate"])
    r_lo, r_hi = tenure_adjusted_range(tenure_cohort, *CFG["rpc_rate_base"])
    p_lo, p_hi = tenure_adjusted_range(tenure_cohort, *CFG["ptp_rate_base"])
    k_lo, k_hi = tenure_adjusted_range(tenure_cohort, *CFG["kp_tendency"])

    agent_profile[eid] = {
        "supervisor_id":     sid,
        "contact_skill":     contact_skill,
        "negotiation_skill": negotiation_skill,
        "efficiency_skill":  efficiency_skill,
        "tenure_cohort":     tenure_cohort,
        "connection_rate":   clamp(random.uniform(c_lo, c_hi) * contact_skill, 0.20, 0.90),
        "rpc_rate":          clamp(random.uniform(r_lo, r_hi) * contact_skill, 0.15, 0.85),
        "ptp_rate":          clamp(random.uniform(p_lo, p_hi) * negotiation_skill, 0.20, 0.90),
        "kp_tendency":       clamp(random.uniform(k_lo, k_hi) * negotiation_skill, 0.30, 0.95),
        "utilization":       random.uniform(*CFG["utilization"]),
        "aht_rpc_adj":       random.gauss(0, CFG["aht_rpc_adj_std"]),
        "aht_nrpc_adj":      random.gauss(0, CFG["aht_nrpc_adj_std"]),
        "acw_rpc_adj":       random.gauss(0, CFG["acw_rpc_adj_std"]),
        "acw_nrpc_adj":      random.gauss(0, CFG["acw_nrpc_adj_std"]),
        "cost_per_hour":     AGENT_HIRE_CFG["agent_cost_per_hour"][exp_tier],  # G9
    }

dim_employees = pd.DataFrame(employee_rows)
agent_ids     = list(agent_profile.keys())

# ── Backfill team_name / region from supervisor rows ──
sup_lookup = dim_employees.set_index("agent_id")[["team_name", "region"]].to_dict(orient="index")
for idx in dim_employees.index:
    if dim_employees.at[idx, "employee_type"] == "Agent":
        sid = dim_employees.at[idx, "supervisor_id"]
        dim_employees.at[idx, "team_name"] = sup_lookup[sid]["team_name"]
        dim_employees.at[idx, "region"]    = sup_lookup[sid]["region"]

# ── Dim_Products ─────────────────────────────────────────────────────────────
dim_products = pd.DataFrame([{
    "product_id":          fmt_id("PRD", cfg["id"], 2),
    "product_name":        cfg["name"],
    "product_type":        p_type,
    "annual_rate_pct":     cfg["rate"],
    "grace_days":          cfg["grace_days"],
    "min_payment_rule":    cfg["rule"],
} for p_type, cfg in PRODUCT_CFG.items()])

product_id_map = {p: fmt_id("PRD", cfg["id"], 2) for p, cfg in PRODUCT_CFG.items()}

# ── Dim_Clients ──────────────────────────────────────────────────────────────
dim_clients = pd.DataFrame([{
    "client_id":       fmt_id("CLI", i, 4),
    "full_name":       fake.name(),
    "dob":             str(fake.date_of_birth(minimum_age=22, maximum_age=68)),
    "segment":         random.choice(["Retail", "Premium", "Tarjeta", "Prestamo", "Hipoteca"]),
    "income_bracket":  INCOME_BRACKET_CFG["brackets"][weighted_choice(INCOME_BRACKET_CFG["weights"])],
    "risk_score":      clamp(round(random.gauss(650, 80), 2), 400, 850),
} for i in range(1, CFG["num_clients"] + 1)])

client_ids = dim_clients["client_id"].tolist()

# ── Dim_Accounts + live account_state dict ───────────────────────────────────
account_rows  = []
account_state = {}    # mutable throughout the simulation
acct_ctr      = 1

# G1: Build open_date pool from VINTAGE_CFG
_vintage_months = list(VINTAGE_CFG["open_date_weights"].keys())
_vintage_weights = [VINTAGE_CFG["open_date_weights"][m] for m in _vintage_months]

# G3: Credit limit configs per product
_credit_cfg_map = {
    "Tarjeta":   CREDIT_LIMIT_CFG["tarjeta_credit_limit"],
    "Prestamo":  CREDIT_LIMIT_CFG["prestamo_credit_limit"],
    "Hipoteca":  CREDIT_LIMIT_CFG["hipoteca_credit_limit"],
}


def random_open_date():
    """G1: Pick open_date from weighted distribution across 23 months."""
    months_offset = random.choices(_vintage_months, weights=_vintage_weights)[0]
    open_dt = START + timedelta(days=months_offset * 30)
    return str(open_dt)


def random_credit_limit(p_type):
    """G3: Lognormal credit limit per product type."""
    cfg = _credit_cfg_map[p_type]
    return lognormal_clamp(cfg["mean_log"], cfg["sigma_log"], cfg["min"], cfg["max"])


for client_id in client_ids:
    n_prod  = random.choices([1, 2, 3], weights=[0.55, 0.35, 0.10])[0]
    p_types = random.sample(list(PRODUCT_CFG.keys()), k=n_prod)

    for p_type in p_types:
        cfg_p   = PRODUCT_CFG[p_type]
        acct_id = fmt_id("ACC", acct_ctr, 5)
        balance = random_credit_limit(p_type)   # G3: lognormal spread
        min_pay = calc_min_payment(p_type, balance)
        due_day = random.randint(1, 28)   # max 28 avoids month-end edge cases
        in_mora = random.random() < CFG["mora_rate"]

        if in_mora:
            dpd      = random.randint(1, 120)
            n_missed = max(1, dpd // 30)
            arrears  = min(
                round(min_pay * n_missed * random.uniform(1.0, 1.35), 2), balance
            )
            if p_type == "Tarjeta":
                arrears = max(round(balance * 0.005, 2), arrears)
            status = "Mora"
        else:
            dpd, arrears, status = 0, 0.0, "Activo"

        account_rows.append({
            "account_id":      acct_id,
            "client_id":       client_id,
            "product_id":      product_id_map[p_type],
            "product_type":    p_type,
            "open_date":       random_open_date(),   # G1: vintage spread
            "credit_limit":    round(balance, 2),     # G3: lognormal
            "due_day":         due_day,
            "min_payment":     min_pay,
            "initial_balance": balance,
            "initial_status":  status,
        })

        account_state[acct_id] = {
            "balance":            balance,
            "arrears":            arrears,
            "dpd":                dpd,
            "status":             status,
            "min_payment":        min_pay,
            "product_type":       p_type,
            "due_day":            due_day,
            "billing_periods":    set(),    # (year, month) already billed — prevents double increment
            "cure_count":         0,
        }

        acct_ctr += 1

ever_mora = {a for a, s in account_state.items() if s["status"] == "Mora"}

dim_accounts = pd.DataFrame(account_rows)
all_acct_ids = list(account_state.keys())

logger.info("  Accounts:  %s", f"{len(dim_accounts):,}")
logger.info("  In Mora:   %s", f"{sum(1 for s in account_state.values() if s['status']=='Mora'):,}")
logger.info("  Dimension tables built in %.1f seconds", time.time() - t_stage)

# ── Dim_Calendar ─────────────────────────────────────────────────────────────
cal_rows = []
for d in CAL_RANGE:
    max_d = calendar.monthrange(d.year, d.month)[1]
    cal_rows.append({
        "date":           str(d),
        "year":           d.year,
        "quarter":        (d.month - 1) // 3 + 1,
        "month_num":      d.month,
        "month_name":     d.strftime("%B"),
        "iso_week":       d.isocalendar()[1],
        "day_of_week":    d.weekday() + 1,   # 1=Monday … 7=Sunday
        "day_name":       d.strftime("%A"),
        "is_weekday":     d.weekday() < 5,
        "is_month_end":   d.day == max_d,
        "is_payday_week": payday_factor(d) > 1.0,
        "payday_factor":  round(payday_factor(d), 2),
    })

dim_calendar = pd.DataFrame(cal_rows)

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 2 — SIMULATION LOOP (Day-by-day event-driven state machine)
# ═══════════════════════════════════════════════════════════════════════════

logger.info("Running simulation engine...")
t_stage = time.time()

# Fact-table row lists
fact_interactions  = []
fact_ptp_log       = []
fact_payments      = []
fact_time_log      = []
fact_eom_snapshots = []
fact_writeoffs     = []   # G6

ptp_registry  = {}               # ptp_id → dict (status mutated in-place)
payment_queue = defaultdict(list) # date → [payment events]
int_ctr = ptp_ctr = pay_ctr = 0

agent_drift   = {}               # agent_id → monthly multiplier (regenerated each month)
current_month = None

for sim_date in DATE_RANGE:

    is_wkday  = is_weekday(sim_date)
    p_factor  = payday_factor(sim_date)
    eom_today = (sim_date == last_day(sim_date))

    # ── MONTHLY DRIFT UPDATE ──────────────────────────────────────────────
    # At the start of each calendar month, apply ±8% persistent drift
    # to each agent's connection_rate, rpc_rate, ptp_rate, kp_tendency.
    # Single draw per agent per month — drift is constant all month.
    if sim_date.month != current_month:
        current_month = sim_date.month
        for agent_id in agent_ids:
            agent_drift[agent_id] = clamp(
                1.0 + random.gauss(0, CFG["monthly_drift_std"]), 0.75, 1.30
            )
        logger.debug(
            f"Monthly drift applied for month {current_month}: "
            f"min={min(agent_drift.values()):.3f} "
            f"max={max(agent_drift.values()):.3f} "
            f"mean={sum(agent_drift.values())/len(agent_drift):.3f}"
        )

    # ── 3A. PROCESS SCHEDULED PAYMENTS ────────────────────────────────────
    for pay in payment_queue.pop(sim_date, []):
        acct_id = pay["account_id"]
        ptp_id  = pay.get("ptp_id")
        state   = account_state[acct_id]
        ptp_rec = ptp_registry.get(ptp_id) if ptp_id else None

        if state["arrears"] <= 0:
            continue    # already cured by an earlier payment this day

        arrears_before       = state["arrears"]
        balance_before       = state["balance"]
        dpd_before           = state["dpd"]
        applied_to_arrears   = min(pay["amount"], arrears_before)
        excess_to_principal  = round(max(0.0, pay["amount"] - applied_to_arrears), 2)
        state["arrears"]     = round(arrears_before - applied_to_arrears, 2)
        state["balance"]     = round(max(0.0, balance_before - pay["amount"]), 2)
        is_cured             = state["arrears"] <= 0

        if is_cured:
            state["status"]    = "Activo"
            state["dpd"]       = 0
            state["cure_count"] += 1

        # Cure classification — all PTP-linked payments are agent-assisted
        if is_cured and ptp_rec is not None:
            cure_flag = "Agent_Cure"
        elif is_cured and ptp_rec is None:
            cure_flag = "Self_Cure"
        else:
            cure_flag = "None"

        # Resolve PTP: Kept if on-time AND payment covers ≥95% of promised
        if ptp_rec and ptp_rec["status"] == "Pending":
            on_time  = sim_date <= ptp_rec["grace_until"]
            full_pay = pay["amount"] >= ptp_rec["promised_amount"] * 0.95
            ptp_rec["status"] = "Kept" if (on_time and full_pay) else "Broken"

        pay_ctr += 1
        fact_payments.append({
            "payment_id":         fmt_id("PAY", pay_ctr, 6),
            "payment_date":       str(sim_date),
            "payment_time":       rand_time_str(8, 17),    # bank processing hours
            "account_id":         acct_id,
            "ptp_id":             ptp_id,
            "agent_id":           pay.get("agent_id"),
            "amount_paid":        round(pay["amount"], 2),
            "payment_method":     pay["method"],
            "is_cured":           is_cured,
            "cure_flag":          cure_flag,
            "dpd_at_payment":     dpd_before,
            "balance_before":     round(balance_before, 2),
            "balance_after":      round(state["balance"], 2),
            "arrears_before":     round(arrears_before, 2),
            "arrears_after":      round(state["arrears"], 2),
            "amount_to_arrears":  round(applied_to_arrears, 2),
            "amount_to_principal":round(excess_to_principal, 2),
            "dpd_after_payment":  state["dpd"],
        })

    # ── 3B. EXPIRE PTPs & BUILD SUPPRESSION SET ────────────────────────────
    # Must happen before self-cure and dialer pool construction.
    suppressed = set()
    for pid, prec in ptp_registry.items():
        if prec["status"] == "Pending":
            if sim_date > prec["grace_until"]:
                prec["status"] = "Broken"   # grace expired — release account
            else:
                suppressed.add(prec["account_id"])

    # ── 3C. ORGANIC SELF-CURES (payday-boosted) ──────────────────────────
    # Accounts that are in Mora, not suppressed by an active PTP,
    # spontaneously make a payment clearing full arrears.
    # On payday periods (p_factor > 1.0), multiply rate by 2.5x
    # to cluster ~60% of self-cures on payday weeks.
    sc_prob = CFG["self_cure_base_rate"] * p_factor
    if p_factor > 1.0:
        sc_prob *= CFG["self_cure_payday_boost"]
    for acct_id, state in account_state.items():
        if (state["status"] == "Mora"
                and state["arrears"] > 0
                and acct_id not in suppressed
                and random.random() < sc_prob * max(0.1, 0.5 ** state["cure_count"])):

            sc_balance_before = state["balance"]
            sc_arrears_before = state["arrears"]
            sc_dpd_before     = state["dpd"]   # I6: record DPD at cure, not 0
            applied           = state["arrears"]
            state["arrears"]  = 0.0
            state["balance"]  = round(max(0.0, state["balance"] - applied), 2)
            state["status"]   = "Activo"
            state["dpd"]      = 0
            state["cure_count"] += 1

            pay_ctr += 1
            fact_payments.append({
                "payment_id":         fmt_id("PAY", pay_ctr, 6),
                "payment_date":       str(sim_date),
                "payment_time":       rand_time_str(8, 17),
                "account_id":         acct_id,
                "ptp_id":             None,
                "agent_id":           None,
                "amount_paid":        round(applied, 2),
                "payment_method":     random.choices(PAY_METHODS, weights=PAY_WEIGHTS)[0],
                "is_cured":           True,
                "cure_flag":          "Self_Cure",
                "dpd_at_payment":     sc_dpd_before,
                "balance_before":     round(sc_balance_before, 2),
                "balance_after":      round(state["balance"], 2),
                "arrears_before":     round(sc_arrears_before, 2),
                "arrears_after":      0.0,
                "amount_to_arrears":  round(applied, 2),
                "amount_to_principal":0.0,
                "dpd_after_payment":  0,
            })

    # ── 3D. BILLING CYCLE CHECK ────────────────────────────────────────────
    # On an account's due_day each month:
    #   - If arrears still > 0 → DPD += 30, add another missed payment to arrears
    #   - billing_periods set prevents double-processing within the same month
    for acct_id, state in account_state.items():
        actual_due = safe_due_day(sim_date.year, sim_date.month, state["due_day"])
        period_key = (sim_date.year, sim_date.month)

        if sim_date.day == actual_due and period_key not in state["billing_periods"]:
            state["billing_periods"].add(period_key)

            if state["status"] == "Mora" and state["arrears"] > 0:
                state["dpd"] = min(state["dpd"] + 30, 360)
                # Accrue another missed minimum payment to arrears (capped at balance)
                headroom = max(0.0, state["balance"] - state["arrears"])
                accrual  = min(state["min_payment"], headroom)
                if accrual > 0:
                    state["arrears"] = round(state["arrears"] + accrual, 2)

    # ── 3E. BUILD DIALER POOLS ─────────────────────────────────────────────
    mora_pool  = [a for a, s in account_state.items()
                  if s["status"] == "Mora"   and a not in suppressed]
    other_pool = [a for a, s in account_state.items()
                  if s["status"] == "Activo" and a not in suppressed and a in ever_mora]

    # ── 3F. AGENT LOOP (Horarios de Operación y Turnos) ──────────────────────
    # Call center operates weekdays only (Monday–Friday)
    if is_wkday:
        shift_start_max = 13  # Login by 1pm + 8h shift → logout by 9pm

        accts_ptp_today = set()

        for agent_id in agent_ids:
            prof = agent_profile[agent_id]
            dr = agent_drift[agent_id]

            # --- DEFINIMOS EL TURNO DEL AGENTE PRIMERO ---
            # El agente hace login entre las 8am y el límite máximo del día
            lh = random.randint(8, shift_start_max)
            lm = random.randint(0, 59)
            oh = lh + int(CFG["schedule_hours"])  # Hora de salida (Logout)

            n_total = random.randint(*CFG["accts_per_agent_day"])
            n_mora = int(n_total * CFG["mora_contact_pct"])
            n_other = n_total - n_mora

            contacts = (
                    random.sample(mora_pool, k=min(n_mora, len(mora_pool)))
                    + random.sample(other_pool, k=min(n_other, len(other_pool)))
            )

            agent_tht_s = 0

            for acct_id in contacts:
                state = account_state[acct_id]
                p_type = state["product_type"]
                n_att = random.randint(*CFG["attempts_per_acct"])
                rpc_boost = PRODUCT_CFG[p_type]["rpc_boost"]
                evasion = 0.70 if state["dpd"] > 90 else 1.0
                reentry_penalty = max(0.4, 1.0 - 0.2 * state["cure_count"])

                connected = False
                rpc_flag = False
                call_outcome = None

                for _ in range(n_att):
                    if random.random() < prof["connection_rate"] * dr * reentry_penalty:
                        connected = True
                        adj_rpc = clamp(prof["rpc_rate"] * dr * rpc_boost * evasion, 0.05, 0.92)

                        if random.random() < adj_rpc:
                            rpc_flag = True
                            call_outcome = "RPC"
                            break
                        else:
                            if call_outcome != "RPC":
                                call_outcome = random.choices(*CONTACT_NON_RPC)[0]
                            break
                    else:
                        if call_outcome not in (("RPC",) + tuple(CONTACT_NON_RPC[0])):
                            call_outcome = random.choices(*NON_CONTACT)[0]

                if call_outcome is None:
                    call_outcome = "No_Answer"

                if rpc_flag:
                    aht = gauss_secs(CFG["aht_rpc"]["mu"], CFG["aht_rpc"]["sigma"], prof["aht_rpc_adj"])
                    acw = gauss_secs(CFG["acw_rpc"]["mu"], CFG["acw_rpc"]["sigma"], prof["acw_rpc_adj"])
                else:
                    aht = gauss_secs(CFG["aht_nrpc"]["mu"], CFG["aht_nrpc"]["sigma"], prof["aht_nrpc_adj"])
                    acw = gauss_secs(CFG["acw_nrpc"]["mu"], CFG["acw_nrpc"]["sigma"], prof["acw_nrpc_adj"])

                reentry_aht_boost = 1.0 + 0.15 * state["cure_count"]
                eff = prof["efficiency_skill"]
                aht = max(5, int(aht * eff * reentry_aht_boost))
                acw = max(5, int(acw * eff * reentry_aht_boost))

                agent_tht_s += aht + acw

                int_ctr += 1

                # G5: Assign interaction channel
                channel = random.choices(
                    CHANNEL_CFG["channels"],
                    weights=CHANNEL_CFG["weights"]
                )[0]

                # La hora de la interacción ahora siempre ocurre dentro del turno real de este agente
                interaction_time_str = rand_time_str(lh, oh)

                fact_interactions.append({
                    "interaction_id": fmt_id("INT", int_ctr, 6),
                    "interaction_date": str(sim_date),
                    "interaction_time": interaction_time_str,
                    "agent_id": agent_id,
                    "account_id": acct_id,
                    "calls_attempted": n_att,
                    "calls_connected": int(connected),
                    "rpc_flag": str(rpc_flag).lower(),
                    "call_outcome": call_outcome,
                    "channel": channel,                    # G5
                    "aht_seconds": aht,
                    "acw_seconds": acw,
                    "rpc_arrears": round(state["arrears"], 2) if rpc_flag else 0.0,
                    "dpd_at_contact": state["dpd"],
                })

                # ── PTP GENERATION ──────────────────────────────────────────────
                if (rpc_flag
                        and state["status"] == "Mora"
                        and state["arrears"] > 0
                        and acct_id not in suppressed
                        and acct_id not in accts_ptp_today
                        and random.random() < prof["ptp_rate"] * dr):

                    ptp_ctr += 1
                    ptp_id = fmt_id("PTP", ptp_ctr, 6)

                    p_win = random.randint(*CFG["promise_window_days"])
                    g_days = random.randint(*CFG["grace_period_days"])
                    prom_date = sim_date + timedelta(days=p_win)
                    grace_until = prom_date + timedelta(days=g_days)

                    lo = max(5.0, min(state["min_payment"] * 0.5, state["arrears"]))
                    hi = state["arrears"]
                    amt = round(random.uniform(lo, hi) if lo < hi else hi, 2)

                    kp_p = clamp(prof["kp_tendency"] * dr + random.gauss(0, CFG["kp_noise_std"]), 0.05, 0.98)
                    kp_p = clamp(kp_p * p_factor, 0.05, 0.98)
                    will_pay = random.random() < kp_p

                    if will_pay:
                        delay = random.randint(*CFG["payment_delay_days"])
                        pay_date = min(sim_date + timedelta(days=delay), END)
                        payment_queue[pay_date].append({
                            "account_id": acct_id,
                            "agent_id": agent_id,
                            "amount": amt,
                            "ptp_id": ptp_id,
                            "method": random.choices(PAY_METHODS, weights=PAY_WEIGHTS)[0],
                        })

                    ptp_registry[ptp_id] = {
                        "account_id": acct_id,
                        "agent_id": agent_id,
                        "promised_amount": amt,
                        "promised_date": prom_date,
                        "grace_until": grace_until,
                        "status": "Pending",
                        "will_pay": will_pay,
                        "rpc_arrears_at": round(state["arrears"], 2),
                    }

                    fact_ptp_log.append({
                        "ptp_id": ptp_id,
                        "ptp_date": str(sim_date),
                        "ptp_time": interaction_time_str,  # Usamos la misma hora del contacto
                        "agent_id": agent_id,
                        "account_id": acct_id,
                        "promised_amount": amt,
                        "promised_date": str(prom_date),
                        "grace_until_date": str(grace_until),
                        "status": "Pending",
                        "rpc_arrears_at_contact": round(state["arrears"], 2),
                    })

                    suppressed.add(acct_id)
                    accts_ptp_today.add(acct_id)

            # ── AGENT TIME LOG (WFM BUSINESS LOGIC) ─────────────────────────────
            break_mins = random.randint(*CFG["break_minutes"])
            break_hrs = break_mins / 60.0

            op_hrs = round(CFG["schedule_hours"] - break_hrs, 2)
            op_secs = op_hrs * 3600
            actual_tht_hrs = round(agent_tht_s / 3600.0, 4)
            utilization = round(min(agent_tht_s / op_secs, 0.95), 4)

            # G9: Agent cost model
            agent_cost = prof.get("cost_per_hour", 32.00)
            total_cost = round(agent_cost * op_hrs * AGENT_COST_CFG["overhead_multiplier"], 2)

            fact_time_log.append({
                "log_id": fmt_id("TML", len(fact_time_log) + 1, 6),
                "log_date": str(sim_date),
                "agent_id": agent_id,
                "login_time": f"{lh:02d}:{lm:02d}:00",
                "logout_time": f"{oh:02d}:{random.randint(0, 59):02d}:00",
                "break_minutes": break_mins,
                "operational_hours": op_hrs,
                "tht_hours": actual_tht_hrs,
                "utilization": utilization,
                "schedule_hours": CFG["schedule_hours"],
                "cost_per_hour": agent_cost,          # G9
                "total_cost": total_cost,              # G9
            })

    # ── 3G. MORA AGING & REPLENISHMENT ────────────────────────────────────
    replenish_p = CFG["mora_replenishment_rate"] * p_factor
    for acct_id, state in account_state.items():
        if state["status"] == "Activo" and state["balance"] > 0:
            if random.random() < replenish_p:
                p_type      = state["product_type"]
                new_min     = calc_min_payment(p_type, state["balance"])
                missed      = random.randint(1, 2)
                new_arrears = min(
                    round(new_min * missed * random.uniform(1.0, 1.2), 2),
                    state["balance"]
                )
                if p_type == "Tarjeta":
                    new_arrears = max(round(state["balance"] * 0.005, 2), new_arrears)
                ever_mora.add(acct_id)
                state.update({
                    "status":          "Mora",
                    "arrears":         new_arrears,
                    "dpd":             missed * 30,
                    "min_payment":     new_min,
                })

    # ── 3H. END-OF-MONTH SNAPSHOT ─────────────────────────────────────────
    if eom_today:
        for acct_id, state in account_state.items():
            # C2: charged-off accounts exit the book — no further snapshots.
            # Their final row is the month-end of the write-off itself (emitted
            # below BEFORE the write-off event mutates state); after that they
            # must stop polluting 90+ stock and roll-rate denominators.
            if state["status"] == "WrittenOff":
                continue
            dpd = state["dpd"]
            if dpd == 0:
                bucket = "Current"
            elif dpd <= 30:
                bucket = "1-30"
            elif dpd <= 60:
                bucket = "31-60"
            elif dpd <= 90:
                bucket = "61-90"
            else:
                bucket = "90+"

            fact_eom_snapshots.append({
                "snapshot_date":  str(sim_date),
                "snapshot_month": sim_date.strftime("%B_%Y"),
                "account_id":     acct_id,
                "status":         state["status"],
                "balance":        round(state["balance"], 2),
                "arrears":        round(state["arrears"], 2),
                "dpd":            state["dpd"],
                "dpd_bucket":     bucket,
                "min_payment":    state["min_payment"],
            })

        # G6: WRITE-OFF EVENTS at month end
        if WRITEOFF_CFG["enabled"]:
            for acct_id, state in account_state.items():
                if (state["dpd"] >= 91
                        and state["arrears"] > 0
                        and random.random() < WRITEOFF_CFG["write_off_rate"]):
                    writeoff_amt = round(state["arrears"] * WRITEOFF_CFG["write_off_amount_pct"]["91+"], 2)
                    fact_writeoffs.append({
                        "writeoff_id":   fmt_id("WOF", len(fact_writeoffs) + 1, 6),
                        "writeoff_date": str(sim_date),
                        "account_id":    acct_id,
                        "product_type":  state["product_type"],
                        "writeoff_amount": writeoff_amt,
                        "balance_before": round(state["balance"], 2),
                        "dpd_at_writeoff": state["dpd"],
                    })
                    state["balance"] = round(max(0.0, state["balance"] - writeoff_amt), 2)
                    state["arrears"] = 0.0
                    state["status"]  = "WrittenOff"

    logger.debug(
        f"{sim_date} | INT: {int_ctr:>7,} | PTP: {ptp_ctr:>5,} | "
        f"PAY: {pay_ctr:>5,} | MORA: {sum(1 for s in account_state.values() if s['status']=='Mora'):>5,}"
    )

logger.info("Simulation complete. (%.1f seconds)", time.time() - t_stage)

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 3 — BUILD & FINALIZE DATAFRAMES
# ═══════════════════════════════════════════════════════════════════════════

t_stage = time.time()
logger.info("Finalizing fact tables...")

df_interactions = pd.DataFrame(fact_interactions)
df_payments     = pd.DataFrame(fact_payments)
df_time_log     = pd.DataFrame(fact_time_log)
df_eom          = pd.DataFrame(fact_eom_snapshots)
df_writeoffs    = pd.DataFrame(fact_writeoffs)   # G6

df_ptp = pd.DataFrame(fact_ptp_log)

# Resolve all PTP statuses from the live registry
if len(df_ptp) > 0:
    status_map  = {pid: rec["status"] for pid, rec in ptp_registry.items()}
    # Force Broken for non-payers whose grace expired before END
    for pid, rec in ptp_registry.items():
        if rec["status"] == "Pending" and not rec["will_pay"] and rec["grace_until"] <= END:
            status_map[pid] = "Broken"
    df_ptp["status"] = df_ptp["ptp_id"].map(status_map)

# Anomaly injection: escalation AHT spikes in interactions
anomalies_tracking = []
if len(df_interactions) > 0:
    n_anom   = int(len(df_interactions) * CFG["anomaly_prob"])
    anom_idx = df_interactions.sample(n=n_anom, random_state=99).index
    for i, idx in enumerate(anom_idx):
        original_val = df_interactions.loc[idx, "aht_seconds"]
        mul = random.uniform(*CFG["anomaly_mul"])
        new_val = max(5, int(original_val * mul))
        df_interactions.loc[idx, "aht_seconds"] = new_val

        anomalies_tracking.append({
            "anomaly_id":    fmt_id("ANM", i + 1, 4),
            "table":         "Fact_Interactions",
            "record_id":     df_interactions.loc[idx, "interaction_id"],
            "anomaly_type":  "AHT_escalation",
            "value":         new_val,
            "expected_range": f"{CFG['aht_rpc']['mu']-3*CFG['aht_rpc']['sigma']}:{CFG['aht_rpc']['mu']+3*CFG['aht_rpc']['sigma']}",
        })

    df_interactions.loc[anom_idx, "aht_seconds"] = df_interactions.loc[anom_idx, "aht_seconds"].astype("Int64")
    logger.info("  Anomalies injected:  %s", f"{n_anom:,}")

# Round financial columns
for col in ["rpc_arrears", "dpd_at_contact"]:
    if col in df_interactions.columns:
        df_interactions[col] = df_interactions[col].round(2)

if len(df_payments) > 0:
    df_payments["amount_paid"] = df_payments["amount_paid"].round(2)

logger.info("  Fact_Interactions:    %s", f"{len(df_interactions):>8,}")
logger.info("  Fact_PTP_Log:         %s", f"{len(df_ptp):>8,}")
logger.info("  Fact_Payments:        %s", f"{len(df_payments):>8,}")
logger.info("  Fact_Agent_Time_Log:  %s", f"{len(df_time_log):>8,}")
logger.info("  Fact_EOM_Snapshot:    %s", f"{len(df_eom):>8,}")
logger.info("  Fact_Writeoffs:       %s", f"{len(df_writeoffs):>8,}")
logger.info("  Fact tables finalized in %.1f seconds", time.time() - t_stage)

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 3B — ENSURE EXPLICIT DTYpes FOR CSV EXPORT
# ═══════════════════════════════════════════════════════════════════════════

# Currency columns (2 decimal places)
currency_cols = [
    "min_payment", "initial_balance", "balance", "arrears",
    "promised_amount", "amount_paid", "rpc_arrears", "rpc_arrears_at_contact",
    "annual_rate_pct", "contact_skill", "negotiation_skill", "efficiency_skill", "risk_score", "payday_factor",
    "cost_per_hour", "total_cost", "credit_limit", "writeoff_amount",
]

# Date columns (ISO 8601: YYYY-MM-DD)
date_cols = [
    "dob", "open_date", "interaction_date", "payment_date",
    "ptp_date", "promised_date", "grace_until_date", "snapshot_date",
    "log_date", "date", "hire_date", "writeoff_date",
]

def format_for_export(df):
    """Apply explicit dtypes to a DataFrame before CSV export."""
    df = df.copy()
    # Round currency columns to 2 decimals (only if numeric)
    for col in currency_cols:
        if col in df.columns and pd.api.types.is_numeric_dtype(df[col]):
            df[col] = df[col].round(2)
    # Ensure date columns are string-formatted as ISO 8601
    for col in date_cols:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], errors="coerce").dt.strftime("%Y-%m-%d")
    return df

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 4 — EXPORT (Star Schema, monthly split)
# ═══════════════════════════════════════════════════════════════════════════

logger.info("Exporting CSVs...")
t_stage = time.time()

BASE_DIR   = CFG["output_dir"]
shared_dir = os.path.join(BASE_DIR, "shared")
os.makedirs(shared_dir, exist_ok=True)

# Dimension tables → shared/ (reference data, one copy)
dims = {
    "Dim_Employees":   dim_employees,
    "Dim_Clients":     dim_clients,
    "Dim_Products":    dim_products,
    "Dim_Accounts":    dim_accounts,
    "Dim_Calendar":    dim_calendar,
}

for name, df in dims.items():
    path = os.path.join(shared_dir, f"{name}.csv")
    df_exp = format_for_export(df)
    df_exp.to_csv(path, index=False, date_format="%Y-%m-%d", float_format="%.2f")
    logger.info("  [shared] %s.csv  (%s rows)", name, f"{len(df):,}")

# Fact tables → monthly folders (split by date column)
facts = {
    "Fact_Interactions":   (df_interactions, "interaction_date"),
    "Fact_PTP_Log":        (df_ptp,          "ptp_date"),
    "Fact_Payments":       (df_payments,      "payment_date"),
    "Fact_Agent_Time_Log": (df_time_log,      "log_date"),
    "Fact_EOM_Snapshot":   (df_eom,           "snapshot_date"),
    "Fact_Writeoffs":      (df_writeoffs,     "writeoff_date"),   # G6
}

for period in pd.date_range(START, END, freq="MS"):
    folder    = period.strftime("%B_%Y").lower()
    month_dir = os.path.join(BASE_DIR, folder)
    os.makedirs(month_dir, exist_ok=True)
    total     = 0

    for name, (df, date_col) in facts.items():
        if len(df) == 0:
            df_exp = format_for_export(df)
            df_exp.to_csv(os.path.join(month_dir, f"{name}.csv"), index=False, date_format="%Y-%m-%d", float_format="%.2f")
            continue
        mask     = pd.to_datetime(df[date_col]).dt.to_period("M") == period.to_period("M")
        df_month = df[mask].copy()
        df_exp = format_for_export(df_month)
        df_exp.to_csv(os.path.join(month_dir, f"{name}.csv"), index=False, date_format="%Y-%m-%d", float_format="%.2f")
        total   += len(df_month)

    logger.info("  [%s]  %s total fact rows", folder, f"{total:,}")

logger.info("Export complete. (%.1f seconds)", time.time() - t_stage)

# Export anomaly report
if anomalies_tracking:
    df_anomalies = pd.DataFrame(anomalies_tracking)
    df_anomalies.to_csv(os.path.join(BASE_DIR, "anomaly_report.csv"), index=False)
    logger.info("  Anomaly report written: %s anomalies tracked", f"{len(df_anomalies):,}")

elapsed = time.time() - t_start
logger.info("Generation complete. Total elapsed time: %.1f seconds", elapsed)


# ═══════════════════════════════════════════════════════════════════════════
# SECTION 5 — POST-GENERATION VALIDATION
# ═══════════════════════════════════════════════════════════════════════════

t_stage = time.time()

def validate_output(output_dir):
    """Validate generated CSVs for row counts, PK nulls, and FK integrity."""
    shared = os.path.join(output_dir, "shared")
    passed = True

    def _check(description, condition):
        nonlocal passed
        tag = "[PASS]" if condition else "[FAIL]"
        if not condition:
            passed = False
        logger.info("  %s  %s", tag, description)
        return condition

    # ── 1. Read dimension CSVs ────────────────────────────────────────
    logger.info("Running post-generation validation...")

    dim_tables = {}
    for name in ["Dim_Employees", "Dim_Clients",
                 "Dim_Products", "Dim_Accounts", "Dim_Calendar"]:
        path = os.path.join(shared, f"{name}.csv")
        dim_tables[name] = pd.read_csv(path)

    # ── 2. Row count checks ───────────────────────────────────────────
    logger.info("  --- Row Counts ---")
    _check("Dim_Employees == 88 (8 supervisors + 80 agents)",
           len(dim_tables["Dim_Employees"]) == 88)
    _check("Dim_Clients == 10000", len(dim_tables["Dim_Clients"]) == 10_000)
    _check("Dim_Products == 3", len(dim_tables["Dim_Products"]) == 3)

    acct_count = len(dim_tables["Dim_Accounts"])
    acct_ok = 15_000 <= acct_count <= 25_000
    _check(f"Dim_Accounts ~20,000 (actual: {acct_count:,})", acct_ok)

    # ── 3. PK null checks ─────────────────────────────────────────────
    logger.info("  --- Primary Key Null Checks ---")
    pk_checks = {
        "Dim_Employees": "agent_id",
        "Dim_Clients": "client_id",
        "Dim_Products": "product_id",
        "Dim_Accounts": "account_id",
    }
    for table, pk_col in pk_checks.items():
        nulls = dim_tables[table][pk_col].isna().sum()
        _check(f"{table}.{pk_col} has no nulls", nulls == 0)

    # ── 3B. NEW COLUMN PRESENCE CHECKS ─────────────────────────────────
    logger.info("  --- New Column Presence ---")
    _check("Dim_Employees has hire_date", "hire_date" in dim_tables["Dim_Employees"].columns)
    _check("Dim_Employees has experience_tier", "experience_tier" in dim_tables["Dim_Employees"].columns)
    _check("Dim_Employees has cost_per_hour", "cost_per_hour" in dim_tables["Dim_Employees"].columns)
    _check("Dim_Employees has employee_type", "employee_type" in dim_tables["Dim_Employees"].columns)
    _check("Dim_Employees has supervisor_id (self-ref)", "supervisor_id" in dim_tables["Dim_Employees"].columns)
    _check("Dim_Clients has income_bracket", "income_bracket" in dim_tables["Dim_Clients"].columns)
    _check("Dim_Accounts has credit_limit", "credit_limit" in dim_tables["Dim_Accounts"].columns)
    _check("Dim_Accounts has product_type", "product_type" in dim_tables["Dim_Accounts"].columns)

    # ── 4. FK integrity checks ────────────────────────────────────────
    logger.info("  --- Foreign Key Integrity ---")

    # Dim_Employees.supervisor_id (self-ref) → Dim_Employees.agent_id
    all_emp_ids = set(dim_tables["Dim_Employees"]["agent_id"])
    agent_sup_ids = set(dim_tables["Dim_Employees"]["supervisor_id"].dropna())
    _check("All Dim_Employees.supervisor_id (self-ref) exist in Dim_Employees.agent_id",
           agent_sup_ids.issubset(all_emp_ids))

    # Dim_Accounts.client_id → Dim_Clients.client_id
    client_ids = set(dim_tables["Dim_Clients"]["client_id"])
    acct_client_ids = set(dim_tables["Dim_Accounts"]["client_id"])
    _check("All Dim_Accounts.client_id exist in Dim_Clients",
           acct_client_ids.issubset(client_ids))

    # Dim_Accounts.product_id → Dim_Products.product_id
    prod_ids = set(dim_tables["Dim_Products"]["product_id"])
    acct_prod_ids = set(dim_tables["Dim_Accounts"]["product_id"])
    _check("All Dim_Accounts.product_id exist in Dim_Products",
           acct_prod_ids.issubset(prod_ids))

    # ── 5. Fact table non-empty check ─────────────────────────────────
    logger.info("  --- Fact Table Completeness ---")
    fact_tables = {
        "Fact_Interactions": "interaction_date",
        "Fact_PTP_Log": "ptp_date",
        "Fact_Payments": "payment_date",
        "Fact_Agent_Time_Log": "log_date",
        "Fact_EOM_Snapshot": "snapshot_date",
        "Fact_Writeoffs": "writeoff_date",
    }

    # Read from first month folder
    first_month = min(d for d in os.listdir(output_dir)
                      if os.path.isdir(os.path.join(output_dir, d)))
    month_dir = os.path.join(output_dir, first_month)

    for name, date_col in fact_tables.items():
        path = os.path.join(month_dir, f"{name}.csv")
        fact_df = pd.read_csv(path)
        _check(f"{name} has rows in {first_month} ({len(fact_df):,})",
               len(fact_df) > 0)

    # ── 6. Fact table FK checks (sample from first month) ─────────────
    agent_ids_dim = set(dim_tables["Dim_Employees"]["agent_id"])
    acct_ids_dim = set(dim_tables["Dim_Accounts"]["account_id"])

    interactions = pd.read_csv(os.path.join(month_dir, "Fact_Interactions.csv"))
    if "agent_id" in interactions.columns:
        bad_agents = set(interactions["agent_id"].dropna()) - agent_ids_dim
        _check("All Fact_Interactions.agent_id exist in Dim_Employees",
               len(bad_agents) == 0)
    if "account_id" in interactions.columns:
        bad_accts = set(interactions["account_id"].dropna()) - acct_ids_dim
        _check("All Fact_Interactions.account_id exist in Dim_Accounts",
               len(bad_accts) == 0)

    ptp = pd.read_csv(os.path.join(month_dir, "Fact_PTP_Log.csv"))
    if "agent_id" in ptp.columns:
        bad_agents = set(ptp["agent_id"].dropna()) - agent_ids_dim
        _check("All Fact_PTP_Log.agent_id exist in Dim_Employees",
               len(bad_agents) == 0)
    if "account_id" in ptp.columns:
        bad_accts = set(ptp["account_id"].dropna()) - acct_ids_dim
        _check("All Fact_PTP_Log.account_id exist in Dim_Accounts",
               len(bad_accts) == 0)

    payments = pd.read_csv(os.path.join(month_dir, "Fact_Payments.csv"))
    if "account_id" in payments.columns:
        bad_accts = set(payments["account_id"].dropna()) - acct_ids_dim
        _check("All Fact_Payments.account_id exist in Dim_Accounts",
               len(bad_accts) == 0)

    time_log = pd.read_csv(os.path.join(month_dir, "Fact_Agent_Time_Log.csv"))
    if "agent_id" in time_log.columns:
        bad_agents = set(time_log["agent_id"].dropna()) - agent_ids_dim
        _check("All Fact_Agent_Time_Log.agent_id exist in Dim_Employees",
               len(bad_agents) == 0)

    eom = pd.read_csv(os.path.join(month_dir, "Fact_EOM_Snapshot.csv"))
    if "account_id" in eom.columns:
        bad_accts = set(eom["account_id"].dropna()) - acct_ids_dim
        _check("All Fact_EOM_Snapshot.account_id exist in Dim_Accounts",
               len(bad_accts) == 0)

    writeoffs = pd.read_csv(os.path.join(month_dir, "Fact_Writeoffs.csv"))
    if "account_id" in writeoffs.columns:
        bad_accts = set(writeoffs["account_id"].dropna()) - acct_ids_dim
        _check("All Fact_Writeoffs.account_id exist in Dim_Accounts",
               len(bad_accts) == 0)

    logger.info("Validation result: %s", "ALL CHECKS PASSED" if passed else "SOME CHECKS FAILED")
    return passed


validation_ok = validate_output(CFG["output_dir"])
logger.info("Validation complete. (%.1f seconds)", time.time() - t_stage)
if not validation_ok:
    logger.error("Validation failed. Check logs for details.")
    sys.exit(1)
