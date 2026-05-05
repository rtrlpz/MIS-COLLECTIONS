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
  - Weekday-only payment clearing; interactions during 08:00–21:00 only
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

# File handler → data_sources/generators/logs/
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
    from .config import CFG, PRODUCT_CFG, CONTACT_NON_RPC, NON_CONTACT, PAY_METHODS, PAY_WEIGHTS
except ImportError:
    from config import CFG, PRODUCT_CFG, CONTACT_NON_RPC, NON_CONTACT, PAY_METHODS, PAY_WEIGHTS

BASE_PATH  = Path(__file__).resolve().parent
OUTPUT_DIR = BASE_PATH / "raw"
CFG["output_dir"] = str(OUTPUT_DIR)
CFG["start_date"] = date(2025, 10, 1)
CFG["end_date"]   = date(2025, 12, 31)

# ═══════════════════════════════════════════════════════════════════════════
# CLI ARGUMENTS
# ═══════════════════════════════════════════════════════════════════════════

parser = argparse.ArgumentParser(
    description="MIS Collections Data Generator v7 — Synthetic bank collections data"
)
parser.add_argument(
    "--output-dir", type=str, default=None,
    help="Output directory for generated CSVs (default: data_sources/generators/raw)"
)
parser.add_argument(
    "--months", type=str, default="10,11,12",
    help="Comma-separated month numbers to generate (default: 10,11,12)"
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


def fmt_id(prefix, n, w):
    return f"{prefix}-{str(n).zfill(w)}"


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def gauss_secs(mu, sigma, adj=0.0):
    return max(5, int(random.gauss(mu + adj, sigma)))


def is_weekday(d: date) -> bool:
    return d.weekday() < 5


def next_weekday(d: date) -> date:
    """Advance to Monday if d falls on a weekend."""
    while d.weekday() >= 5:
        d += timedelta(days=1)
    return d


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


# ═══════════════════════════════════════════════════════════════════════════
# SECTION 1 — DIMENSION TABLES
# ═══════════════════════════════════════════════════════════════════════════

logger.info("Building dimension tables...")

# ── Dim_Supervisors ──────────────────────────────────────────────────────────
dim_supervisors = pd.DataFrame([{
    "supervisor_id":   fmt_id("SUP", i, 2),
    "supervisor_name": fake.name(),
    "team_name":       f"Team {i}",
    "region":          random.choice(["North", "South", "East", "West"]),
} for i in range(1, CFG["num_supervisors"] + 1)])

sup_ids = dim_supervisors["supervisor_id"].tolist()

# ── Dim_Agents ───────────────────────────────────────────────────────────────
agent_rows    = []
agent_profile = {}   # simulation-internal; not exported directly

for i in range(1, CFG["num_agents"] + 1):
    eid   = fmt_id("EID", i, 3)
    skill = clamp(random.gauss(1.0, 0.15), 0.70, 1.30)

    agent_rows.append({
        "agent_id":      eid,
        "agent_name":    fake.name(),
        "supervisor_id": random.choice(sup_ids),
        "skill_score":   round(skill, 3),    # exported — useful as BI slicer
    })

    agent_profile[eid] = {
        "skill":           skill,
        "connection_rate": clamp(random.uniform(*CFG["connection_rate"]) * skill, 0.20, 0.90),
        "rpc_rate":        clamp(random.uniform(*CFG["rpc_rate_base"])   * skill, 0.15, 0.85),
        "ptp_rate":        clamp(random.uniform(*CFG["ptp_rate_base"])   * skill, 0.20, 0.90),
        "kp_tendency":     clamp(random.uniform(*CFG["kp_tendency"])     * skill, 0.30, 0.95),
        "utilization":     random.uniform(*CFG["utilization"]),
        "aht_rpc_adj":  random.gauss(0, CFG["aht_rpc_adj_std"]),
        "aht_nrpc_adj": random.gauss(0, CFG["aht_nrpc_adj_std"]),
        "acw_rpc_adj":  random.gauss(0, CFG["acw_rpc_adj_std"]),
        "acw_nrpc_adj": random.gauss(0, CFG["acw_nrpc_adj_std"]),
    }

dim_agents = pd.DataFrame(agent_rows)
agent_ids  = list(agent_profile.keys())

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
    "client_id":  fmt_id("CLI", i, 4),
    "full_name":  fake.name(),
    "dob":        str(fake.date_of_birth(minimum_age=22, maximum_age=68)),
    "segment":    random.choice(["Retail", "Premium", "Tarjeta", "Prestamo", "Hipoteca"]),
    "risk_score": clamp(round(random.gauss(650, 80), 2), 400, 850),
} for i in range(1, CFG["num_clients"] + 1)])

client_ids = dim_clients["client_id"].tolist()

# ── Dim_Accounts + live account_state dict ───────────────────────────────────
account_rows  = []
account_state = {}    # mutable throughout the simulation
acct_ctr      = 1

for client_id in client_ids:
    n_prod  = random.choices([1, 2, 3], weights=[0.55, 0.35, 0.10])[0]
    p_types = random.sample(list(PRODUCT_CFG.keys()), k=n_prod)

    for p_type in p_types:
        cfg_p   = PRODUCT_CFG[p_type]
        acct_id = fmt_id("ACC", acct_ctr, 5)
        balance = round(random.uniform(*cfg_p["bal_range"]), 2)
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
            "open_date":       str(fake.date_between(start_date="-5y", end_date="-3m")),
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
        }

        acct_ctr += 1

dim_accounts = pd.DataFrame(account_rows)
all_acct_ids = list(account_state.keys())

logger.info("  Accounts:  %s", f"{len(dim_accounts):,}")
logger.info("  In Mora:   %s", f"{sum(1 for s in account_state.values() if s['status']=='Mora'):,}")

# ── Dim_Calendar ─────────────────────────────────────────────────────────────
cal_rows = []
for d in DATE_RANGE:
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

# Fact-table row lists
fact_interactions  = []
fact_ptp_log       = []
fact_payments      = []
fact_time_log      = []
fact_eom_snapshots = []

ptp_registry  = {}               # ptp_id → dict (status mutated in-place)
payment_queue = defaultdict(list) # date → [payment events]
int_ctr = ptp_ctr = pay_ctr = 0

for sim_date in DATE_RANGE:

    is_wkday  = is_weekday(sim_date)
    p_factor  = payday_factor(sim_date)
    eom_today = (sim_date == last_day(sim_date))

    # ── 3A. PROCESS SCHEDULED PAYMENTS (weekdays only) ────────────────────
    # Payment queue already adjusted to weekdays at PTP creation (next_weekday).
    if is_wkday:
        for pay in payment_queue.pop(sim_date, []):
            acct_id = pay["account_id"]
            ptp_id  = pay.get("ptp_id")
            state   = account_state[acct_id]
            ptp_rec = ptp_registry.get(ptp_id) if ptp_id else None

            if state["arrears"] <= 0:
                continue    # already cured by an earlier payment this day

            applied          = min(pay["amount"], state["arrears"])
            state["arrears"] = round(state["arrears"] - applied, 2)
            state["balance"] = round(max(0.0, state["balance"] - applied), 2)
            is_cured         = state["arrears"] <= 0

            if is_cured:
                state["status"] = "Activo"
                state["dpd"]    = 0

            # Cure classification
            if is_cured and ptp_rec and ptp_rec["status"] == "Pending":
                cure_flag = "Agent_Cure"
            elif is_cured and ptp_rec is None:
                cure_flag = "Self_Cure"
            else:
                cure_flag = "None"

            # Resolve PTP: Kept if on-time AND payment covers ≥95% of promised
            if ptp_rec and ptp_rec["status"] == "Pending":
                on_time  = sim_date <= ptp_rec["grace_until"]
                full_pay = applied >= ptp_rec["promised_amount"] * 0.95
                ptp_rec["status"] = "Kept" if (on_time and full_pay) else "Broken"

            pay_ctr += 1
            fact_payments.append({
                "payment_id":     fmt_id("PAY", pay_ctr, 6),
                "payment_date":   str(sim_date),
                "payment_time":   rand_time_str(8, 17),    # bank processing hours
                "account_id":     acct_id,
                "ptp_id":         ptp_id,
                "agent_id":       pay.get("agent_id"),
                "amount_paid":    round(applied, 2),
                "payment_method": pay["method"],
                "is_cured":       is_cured,
                "cure_flag":      cure_flag,
                "dpd_at_payment": state["dpd"],
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

    # ── 3C. ORGANIC SELF-CURES (weekdays, payday-boosted) ─────────────────
    # Accounts that are in Mora, not suppressed by an active PTP,
    # spontaneously make a payment clearing full arrears.
    if is_wkday:
        sc_prob = CFG["self_cure_base_rate"] * p_factor
        for acct_id, state in account_state.items():
            if (state["status"] == "Mora"
                    and state["arrears"] > 0
                    and acct_id not in suppressed
                    and random.random() < sc_prob):

                applied          = state["arrears"]
                state["arrears"] = 0.0
                state["balance"] = round(max(0.0, state["balance"] - applied), 2)
                state["status"]  = "Activo"
                state["dpd"]     = 0

                pay_ctr += 1
                fact_payments.append({
                    "payment_id":     fmt_id("PAY", pay_ctr, 6),
                    "payment_date":   str(sim_date),
                    "payment_time":   rand_time_str(8, 17),
                    "account_id":     acct_id,
                    "ptp_id":         None,
                    "agent_id":       None,
                    "amount_paid":    round(applied, 2),
                    "payment_method": random.choices(PAY_METHODS, weights=PAY_WEIGHTS)[0],
                    "is_cured":       True,
                    "cure_flag":      "Self_Cure",
                    "dpd_at_payment": 0,
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
                  if s["status"] == "Activo" and a not in suppressed]

    # ── 3F. AGENT LOOP (Horarios de Operación y Turnos) ──────────────────────
    dia_semana = sim_date.weekday()  # 0=Lunes, 5=Sábado, 6=Domingo

    # Apagamos el Call Center los Domingos
    if dia_semana != 6:

        # Lógica de Horarios del Call Center
        if dia_semana == 5:  # Sábado (Cierra a las 18:00 / 6 PM)
            shift_start_max = 10  # Si entran a las 10am + 8 hrs = Salen a las 18:00
        else:  # Lunes a Viernes (Cierra a las 21:00 / 9 PM)
            shift_start_max = 13  # Si entran a las 1pm + 8 hrs = Salen a las 21:00

        accts_ptp_today = set()

        for agent_id in agent_ids:
            prof = agent_profile[agent_id]

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

                connected = False
                rpc_flag = False
                call_outcome = None

                for _ in range(n_att):
                    if random.random() < prof["connection_rate"]:
                        connected = True
                        adj_rpc = clamp(prof["rpc_rate"] * rpc_boost * evasion, 0.05, 0.92)

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

                agent_tht_s += aht + acw

                int_ctr += 1

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
                        and random.random() < prof["ptp_rate"]):

                    ptp_ctr += 1
                    ptp_id = fmt_id("PTP", ptp_ctr, 6)

                    p_win = random.randint(*CFG["promise_window_days"])
                    g_days = random.randint(*CFG["grace_period_days"])
                    prom_date = sim_date + timedelta(days=p_win)
                    grace_until = prom_date + timedelta(days=g_days)

                    lo = max(5.0, min(state["min_payment"] * 0.5, state["arrears"]))
                    hi = state["arrears"]
                    amt = round(random.uniform(lo, hi) if lo < hi else hi, 2)

                    kp_p = clamp(prof["kp_tendency"] + random.gauss(0, CFG["kp_noise_std"]), 0.05, 0.98)
                    kp_p = clamp(kp_p * p_factor, 0.05, 0.98)
                    will_pay = random.random() < kp_p

                    if will_pay:
                        delay = random.randint(*CFG["payment_delay_days"])
                        pay_date = next_weekday(min(sim_date + timedelta(days=delay), END))
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
            off_phone_shrinkage = random.uniform(0.05, 0.15)
            tht_hours = round(op_hrs * (1 - off_phone_shrinkage), 2)

            fact_time_log.append({
                "log_id": fmt_id("TML", len(fact_time_log) + 1, 6),
                "log_date": str(sim_date),
                "agent_id": agent_id,
                "login_time": f"{lh:02d}:{lm:02d}:00",
                "logout_time": f"{oh:02d}:{random.randint(0, 59):02d}:00",
                "break_minutes": break_mins,
                "operational_hours": op_hrs,
                "tht_hours": tht_hours,
                "utilization": round(tht_hours / op_hrs, 2),
                "schedule_hours": CFG["schedule_hours"],
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
                state.update({
                    "status":          "Mora",
                    "arrears":         new_arrears,
                    "dpd":             missed * 30,
                    "min_payment":     new_min,
                })

    # ── 3H. END-OF-MONTH SNAPSHOT ─────────────────────────────────────────
    if eom_today:
        for acct_id, state in account_state.items():
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

    logger.debug(
        f"{sim_date} | INT: {int_ctr:>7,} | PTP: {ptp_ctr:>5,} | "
        f"PAY: {pay_ctr:>5,} | MORA: {sum(1 for s in account_state.values() if s['status']=='Mora'):>5,}"
    )

logger.info("Simulation complete.")

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 3 — BUILD & FINALIZE DATAFRAMES
# ═══════════════════════════════════════════════════════════════════════════

logger.info("Finalizing fact tables...")

df_interactions = pd.DataFrame(fact_interactions)
df_payments     = pd.DataFrame(fact_payments)
df_time_log     = pd.DataFrame(fact_time_log)
df_eom          = pd.DataFrame(fact_eom_snapshots)

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
if len(df_interactions) > 0:
    n_anom   = int(len(df_interactions) * CFG["anomaly_prob"])
    anom_idx = df_interactions.sample(n=n_anom, random_state=99).index
    mul      = random.uniform(*CFG["anomaly_mul"])
    df_interactions.loc[anom_idx, "aht_seconds"] = (
        df_interactions.loc[anom_idx, "aht_seconds"].fillna(200) * mul
    ).round(0).astype("Int64")
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

# ═══════════════════════════════════════════════════════════════════════════
# SECTION 3B — ENSURE EXPLICIT DTYpes FOR CSV EXPORT
# ═══════════════════════════════════════════════════════════════════════════

# Currency columns (2 decimal places)
currency_cols = [
    "min_payment", "initial_balance", "balance", "arrears",
    "promised_amount", "amount_paid", "rpc_arrears", "rpc_arrears_at_contact",
    "annual_rate_pct", "skill_score", "risk_score", "payday_factor",
]

# Date columns (ISO 8601: YYYY-MM-DD)
date_cols = [
    "dob", "open_date", "interaction_date", "payment_date",
    "ptp_date", "promised_date", "grace_until_date", "snapshot_date",
    "log_date", "date",
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

BASE_DIR   = CFG["output_dir"]
shared_dir = os.path.join(BASE_DIR, "shared")
os.makedirs(shared_dir, exist_ok=True)

# Dimension tables → shared/ (reference data, one copy)
dims = {
    "Dim_Supervisors": dim_supervisors,
    "Dim_Agents":      dim_agents,
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

elapsed = time.time() - t_start
logger.info("Generation complete. Elapsed time: %.1f seconds", elapsed)


# ═══════════════════════════════════════════════════════════════════════════
# SECTION 5 — POST-GENERATION VALIDATION
# ═══════════════════════════════════════════════════════════════════════════

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
    for name in ["Dim_Supervisors", "Dim_Agents", "Dim_Clients",
                 "Dim_Products", "Dim_Accounts", "Dim_Calendar"]:
        path = os.path.join(shared, f"{name}.csv")
        dim_tables[name] = pd.read_csv(path)

    # ── 2. Row count checks ───────────────────────────────────────────
    logger.info("  --- Row Counts ---")
    _check("Dim_Supervisors == 8", len(dim_tables["Dim_Supervisors"]) == 8)
    _check("Dim_Agents == 80", len(dim_tables["Dim_Agents"]) == 80)
    _check("Dim_Clients == 10000", len(dim_tables["Dim_Clients"]) == 10_000)
    _check("Dim_Products == 3", len(dim_tables["Dim_Products"]) == 3)

    acct_count = len(dim_tables["Dim_Accounts"])
    acct_ok = 15_000 <= acct_count <= 25_000
    _check(f"Dim_Accounts ~20,000 (actual: {acct_count:,})", acct_ok)

    # ── 3. PK null checks ─────────────────────────────────────────────
    logger.info("  --- Primary Key Null Checks ---")
    pk_checks = {
        "Dim_Supervisors": "supervisor_id",
        "Dim_Agents": "agent_id",
        "Dim_Clients": "client_id",
        "Dim_Products": "product_id",
        "Dim_Accounts": "account_id",
    }
    for table, pk_col in pk_checks.items():
        nulls = dim_tables[table][pk_col].isna().sum()
        _check(f"{table}.{pk_col} has no nulls", nulls == 0)

    # ── 4. FK integrity checks ────────────────────────────────────────
    logger.info("  --- Foreign Key Integrity ---")

    # Dim_Agents.supervisor_id → Dim_Supervisors.supervisor_id
    sup_ids = set(dim_tables["Dim_Supervisors"]["supervisor_id"])
    agent_sup_ids = set(dim_tables["Dim_Agents"]["supervisor_id"])
    _check("All Dim_Agents.supervisor_id exist in Dim_Supervisors",
           agent_sup_ids.issubset(sup_ids))

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
    agent_ids_dim = set(dim_tables["Dim_Agents"]["agent_id"])
    acct_ids_dim = set(dim_tables["Dim_Accounts"]["account_id"])

    interactions = pd.read_csv(os.path.join(month_dir, "Fact_Interactions.csv"))
    if "agent_id" in interactions.columns:
        bad_agents = set(interactions["agent_id"].dropna()) - agent_ids_dim
        _check("All Fact_Interactions.agent_id exist in Dim_Agents",
               len(bad_agents) == 0)
    if "account_id" in interactions.columns:
        bad_accts = set(interactions["account_id"].dropna()) - acct_ids_dim
        _check("All Fact_Interactions.account_id exist in Dim_Accounts",
               len(bad_accts) == 0)

    ptp = pd.read_csv(os.path.join(month_dir, "Fact_PTP_Log.csv"))
    if "agent_id" in ptp.columns:
        bad_agents = set(ptp["agent_id"].dropna()) - agent_ids_dim
        _check("All Fact_PTP_Log.agent_id exist in Dim_Agents",
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
        _check("All Fact_Agent_Time_Log.agent_id exist in Dim_Agents",
               len(bad_agents) == 0)

    eom = pd.read_csv(os.path.join(month_dir, "Fact_EOM_Snapshot.csv"))
    if "account_id" in eom.columns:
        bad_accts = set(eom["account_id"].dropna()) - acct_ids_dim
        _check("All Fact_EOM_Snapshot.account_id exist in Dim_Accounts",
               len(bad_accts) == 0)

    logger.info("Validation result: %s", "ALL CHECKS PASSED" if passed else "SOME CHECKS FAILED")
    return passed


validation_ok = validate_output(CFG["output_dir"])
if not validation_ok:
    logger.error("Validation failed. Check logs for details.")
    sys.exit(1)
