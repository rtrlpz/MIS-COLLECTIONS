# Python Medium — Results (worked solutions)

Run, diff against SQL twins, keep the loading recipe — it recurs in every later task.

---

## Task 1 — Installment plans: per-plan truth

```python
from pathlib import Path
import pandas as pd

RAW = Path("data_sources/raw")

def load_fact(name, date_col, months):
    """Concat one fact across the given month dirs. months: list of dir names."""
    frames = []
    for m in months:
        f = pd.read_csv(RAW / m / f"{name}.csv", parse_dates=[date_col])
        frames.append(f)
    return pd.concat(frames, ignore_index=True)

Q2 = ["april_2025", "may_2025", "june_2025",
      "july_2025"]          # payments may land in July for late-June plans

ptp = load_fact("Fact_PTP_Log", "ptp_date", Q2[:3])
pay = load_fact("Fact_Payments", "payment_date", Q2)
ptp = ptp[(ptp["ptp_date"] >= "2025-04-01") & (ptp["ptp_date"] < "2025-07-01")]

totals = (pay[pay["ptp_id"].notna()]
          .groupby("ptp_id")
          .agg(paid_total=("amount_paid", "sum"),
               parts=("payment_id", "count")))

ev = ptp.merge(totals, on="ptp_id", how="left")
kept = ev[ev["status"] == "Kept"].copy()
kept["paid_total"] = kept["paid_total"].fillna(0)

underpaid = kept[kept["paid_total"] < 0.95 * kept["promised_amount"]]
assert underpaid.empty, f"kept-but-underpaid plans: {len(underpaid)}"

multi_pct = round(100 * (kept["parts"] > 1).mean(), 1)
print({"kept_plans": len(kept), "multi_installment_pct": multi_pct})
```

**Why each part:** payments load through JULY because a June 29 promise's second installment legally lands July 3 — folder boundaries are storage details, not business ones (this is N5's whole lesson). `fillna(0)` makes LEFT-merge semantics explicit: a kept plan with no payment rows would otherwise NaN-poison the comparison.

**Verify yourself:** zero `underpaid` must survive the assert. Cross-check `kept_plans` count against SQL Task 2's Q2 window and `v_promise_metrics` sums.

**Traps & alternatives:** evaluating ALL statuses here would mix Pending-between-parts plans into the share math — Kept-only for the invariant, all-statuses when you study Broken salvage (SQL medium Task 5).

---

## Task 2 — Memory discipline at full-year scale

```python
from pathlib import Path
import pandas as pd

RAW = Path("data_sources/raw")
MONTHS = [d for d in sorted(RAW.iterdir()) if d.is_dir() and d.name != "shared"]

def load_year(dtype_spec=None):
    parts = [pd.read_csv(m / "Fact_Interactions.csv", dtype=dtype_spec,
                         parse_dates=["interaction_date"])
             for m in MONTHS]
    return pd.concat(parts, ignore_index=True)

base = load_year()
base_mb = base.memory_usage(deep=True).sum() / 1024**2

OPT = {
    "agent_id": "category", "account_id": "string",
    "channel": "category", "call_outcome": "category",
    "strategy_id": "category", "rpc_flag": "bool",
}
opt = load_year(OPT)
opt_mb = opt.memory_usage(deep=True).sum() / 1024**2

assert len(base) == len(opt)
print(f"before: {base_mb:,.0f} MB   after: {opt_mb:,.0f} MB   "
      f"saving: {100*(1-opt_mb/base_mb):.0f}%")
```

**Why each part:** `deep=True` is the honest number — object columns lie without it. `category` wins whenever distinct values ≪ rows (channels, outcomes, arms); ids that are pure integers stay numeric. The assert pins row integrity so optimization can't silently drop data.

**Verify yourself:** spot-check three random rows' values before vs after (`df.sample(3)` with fixed seed twice) — identical. Write your final dtype table as the comment header of a shared `load_interactions()` helper; Tasks 3–6 reuse it.

**Traps & alternatives:** don't category `account_id` blindly if you'll merge constantly — categorical merges are fast ONLY when categories align; measure, don't evangelize.

---

## Task 3 — Two-month decline detector

```python
import numpy as np
import pandas as pd

def rpc_pivot(inter_year, emps):
    g = (inter_year.merge(emps[["agent_id", "team_name"]], on="agent_id")
         .groupby(["agent_id", "team_name", inter_year["interaction_date"].dt.to_period("M")])
         .agg(conn=("calls_connected", "sum"), rpcs=("rpc_flag", "sum"))
         .reset_index())
    g["rpc_pct"] = 100 * g["rpcs"] / g["conn"]
    return g.pivot_table(index=["agent_id", "team_name"],
                         columns=g.columns[2] if False else None)  # see note

# Cleaner explicit pivot:
def monthly_kpi_matrix(inter_year, emps, value_fn):
    df = inter_year.assign(month=inter_year["interaction_date"].dt.to_period("M"))
    out = (df.merge(emps[["agent_id", "team_name"]], on="agent_id")
             .groupby(["agent_id", "team_name", "month"])
             .apply(value_fn, include_groups=False))
    return out.unstack("month")

def _rpc(g):
    conn, rpcs = g["calls_connected"].sum(), g["rpc_flag"].sum()
    return 100 * rpcs / conn if conn else np.nan

matrix = monthly_kpi_matrix(year_interactions, employees, _rpc)   # rows=agents, cols=months
mat = matrix.sort_index(axis=1)                                   # chronological columns

def declining_agents(mat, kpi_name="rpc_pct"):
    diffs_ok = (mat.diff(axis=1) < 0)                             # month-over-month drop flags
    last, prev = mat.columns[-1], mat.columns[-2]
    two_drops = diffs_ok[last] & diffs_ok[prev]
    out = mat[two_drops][[mat.columns[-3], prev, last]].copy()
    out.columns = ["m_minus_2", "m_minus_1", "latest"]
    return out.reset_index()

print(declining_agents(mat))
```

**Why each part:** `.diff(axis=1) < 0` turns "fell" into a boolean grid; requiring drops in BOTH the last and second-to-last gaps is exactly 'two consecutive declines'. Chronological column sort BEFORE diffing is the silent killer if skipped.

**Verify yourself:** hand-pick one flagged agent, print their three numbers from the raw pivot, confirm both deltas negative. Feed the function a KP% pivot — it must work unchanged (that's why it takes a matrix, not raw data).

**Traps & alternatives:** NaN months make `.diff` produce NaN flags → excluded from detection automatically; decide whether missing-month agents SHOULD be eligible and document the choice.

---

## Task 4 — DB ↔ files reconciliation script

```python
"""reconcile.py — CSV files vs PostgreSQL tables. Exit 1 on any mismatch.
Usage: python reconcile.py   (reads .env at project root)
"""
import os, sys
from pathlib import Path
import pandas as pd
import psycopg2
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(ROOT / ".env")

FACTS = {  # table -> (folder_glob relative name pattern, money col or None)
    "fact_interactions": ("Fact_Interactions.csv", None),
    "fact_ptp_log":      ("Fact_PTP_Log.csv",      None),
    "fact_payments":     ("Fact_Payments.csv",     "amount_paid"),
    "fact_agent_time_log": ("Fact_Agent_Time_Log.csv", None),
    "fact_eom_snapshot": ("Fact_EOM_Snapshot.csv", None),
    "fact_writeoffs":    ("Fact_Writeoffs.csv",    "writeoff_amount"),
    "fact_recoveries":   ("Fact_Recoveries.csv",   "amount_recovered"),
}

def csv_stats(raw: Path, fname: str, money_col):
    rows, money = 0, 0.0
    for md in sorted(p for p in raw.iterdir() if p.is_dir() and p.name != "shared"):
        f = md / fname
        if f.exists():
            df = pd.read_csv(f, usecols=[money_col] if money_col else None)
            rows += len(df)
            if money_col:
                money += float(df[money_col].fillna(0).sum())
    return rows, round(money, 2)

def main():
    conn = psycopg2.connect(
        host=os.getenv("POSTGRES_HOST"), port=os.getenv("POSTGRES_PORT"),
        user=os.getenv("POSTGRES_USER"), password=os.getenv("POSTGRES_PASSWORD"),
        dbname=os.getenv("POSTGRES_DB"))
    cur = conn.cursor()
    failures = []

    for table, (fname, money_col) in FACTS.items():
        rows, money = csv_stats(ROOT / "data_sources" / "raw", fname, money_col)
        cur.execute(f"SELECT COUNT(*) FROM {table}")
        db_rows = cur.fetchone()[0]
        ok = rows == db_rows
        print(f"{table:<22} csv={rows:>9,} db={db_rows:>9,} {'PASS' if ok else 'FAIL'}")
        if not ok:
            failures.append(table)
        if money_col:
            cur.execute(f"SELECT ROUND(SUM({money_col})::numeric, 2) FROM {table}")
            db_money = float(cur.fetchone()[0])
            ok_m = abs(db_money - money) < 0.01
            print(f"{'':<22} sum csv={money:>14,.2f} db={db_money:>14,.2f} "
                  f"{'PASS' if ok_m else 'FAIL'}")
            if not ok_m:
                failures.append(table + ":sum")

    conn.close()
    if failures:
        print("MISMATCHES:", failures)
        sys.exit(1)
    print("All reconciled.")

if __name__ == "__main__":
    main()
```

**Why each part:** mapping dict keeps the script declarative; exit codes make it pipeline-friendly (the JD's automation theme); money sums only where cents matter. Credentials strictly via `.env` — house rule.

**Verify yourself:** run green; then corrupt a COPY of a CSV in a scratch tree (point RAW there via a constant edit) — script must FAIL with exit 1. Restore and re-run green.

**Traps & alternatives:** row parity alone can hide compensating errors (+1/−1); that's WHY money sums exist where applicable. Extension noted in comments: compare `etl_load_log` checksums for load-level drift.

---

## Task 5 — Channel mix by arm, pivoted

```python
import pandas as pd

inter = year_interactions.copy()   # from your Task-2 loader with strategy_id kept
arms = pd.read_csv(RAW / "shared" / "Dim_Strategy.csv")

grid = (inter.merge(arms[["strategy_id", "strategy_name"]], on="strategy_id")
             .pivot_table(index="strategy_name", columns="channel",
                          values="interaction_id", aggfunc="count", fill_value=0))

share = grid.div(grid.sum(axis=1), axis=0).round(3)
assert (share.sum(axis=1).round(2) == 1.00).all()
print(grid, "\n"); print(share)
```

**Why each part:** `pivot_table` on interaction ids counts rows without a pre-groupby; `div(..., axis=0)` is vectorized within-arm normalization — no `apply` loops. The row-sum assert is the share check the deck needs.

**Verify yourself:** cell-for-cell equality against your SQL medium Task 3 counts; any drift means a merge duplicated rows — check `len(inter)` before/after merge.

---

## Task 6 — MIS-ready summary frames

```python
COLS_DAILY = ["date", "contacts", "connected_calls", "rpc_count",
              "promises", "payments"]
COLS_AGENT = ["agent_id", "team_name", "month", "rpc_pct", "utilization_pct"]

def daily_frame(inter, ptp, pay):
    d1 = inter.groupby(inter["interaction_date"].dt.normalize()).agg(
        contacts=("interaction_id", "count"),
        connected_calls=("calls_connected", "sum"),
        rpc_count=("rpc_flag", "sum"))
    d2 = ptp.groupby(ptp["ptp_date"].dt.normalize()).size().rename("promises")
    d3 = pay.groupby(pay["payment_date"].dt.normalize()).size().rename("payments")
    out = d1.join(d2, how="outer").join(d3, how="outer").fillna(0)
    out.index.name = "date"
    return out.reset_index()[COLS_DAILY].sort_values("date")

def agent_month_frame(inter, time_log, emps):
    m = inter.assign(month=inter["interaction_date"].dt.to_period("M").astype(str))
    rpc = (m.groupby(["agent_id", "month"])
             .apply(lambda g: 100 * g["rpc_flag"].sum() / max(g["calls_connected"].sum(), 0),
                    include_groups=False)
             .rename("rpc_pct"))
    util = (time_log.assign(month=time_log["log_date"].dt.to_period("M").astype(str))
            .groupby(["agent_id", "month"])
            .apply(lambda t: 100 * t["tht_hours"].sum() / max(t["operational_hours"].sum(), 0),
                   include_groups=False)
            .rename("utilization_pct"))
    out = (pd.concat([rpc, util], axis=1).reset_index()
             .merge(emps[["agent_id", "team_name"]], on="agent_id"))
    return out[COLS_AGENT].sort_values(["team_name", "agent_id", "month"])

daily = daily_frame(year_interactions, year_ptp, year_payments)
agents = agent_month_frame(year_interactions, year_time_log, employees)

assert list(daily.columns) == COLS_DAILY
assert list(agents.columns) == COLS_AGENT

daily.to_parquet("work/daily_kpis.parquet")
agents.to_parquet("work/agent_month.parquet")
```

**Why each part:** frozen column lists asserted = a contract the Excel track can consume blindly. Parquet preserves dtypes (dates stay dates) and loads ~10× faster than CSV for downstream tasks — that's the one-line rationale requested.

**Verify yourself:** re-read both parquets; dtypes intact? Compare `daily` totals for one month against SQL `v_daily_mis` rollups.
