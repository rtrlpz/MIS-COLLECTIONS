# Python Advanced — Results (worked solutions)

Assumes the shared loader from medium Task 2 (`load_year(OPT)` style) and parquet caches from medium Task 6. Every solution asserts parity or integrity — that's the senior habit.

---

## Task 1 — The KPI pipeline as a module

```python
"""kpi_pipeline.py — file-side KPI engine. Grain + parity target per function."""
from __future__ import annotations
import time
from pathlib import Path
import pandas as pd

RAW = Path("data_sources/raw")
OPT = {"agent_id": "category", "account_id": "string", "channel": "category",
       "call_outcome": "category", "strategy_id": "category", "rpc_flag": "bool"}

def _months() -> list[Path]:
    return sorted(d for d in RAW.iterdir() if d.is_dir() and d.name != "shared")

def load_year(table: str, date_col: str, dtypes: dict | None = None) -> pd.DataFrame:
    frames = [pd.read_csv(m / f"{table}.csv", dtype=dtypes, parse_dates=[date_col])
              for m in _months()]
    return pd.concat(frames, ignore_index=True)

def contact_kpis(inter: pd.DataFrame) -> pd.DataFrame:
    """agent-month contacts. Parity target: v_contact_metrics (monthly grain)."""
    g = inter.groupby(["agent_id", inter["interaction_date"].dt.to_period("M").astype(str)])
    out = g.agg(total_calls=("calls_attempted", "sum"),
                connected=("calls_connected", "sum"),
                rpcs=("rpc_flag", "sum"))
    out["rpc_pct"] = 100 * out["rpcs"] / out["connected"]
    return out.reset_index().rename(columns={"interaction_date": "month"})

def promise_kpis(ptp: pd.DataFrame, pay: pd.DataFrame) -> pd.DataFrame:
    """plan-level kept evaluation (cumulative >=95%). Target: v_promise_metrics."""
    totals = (pay[pay["ptp_id"].notna()]
              .groupby("ptp_id")["amount_paid"].sum().rename("paid_total"))
    ev = ptp.merge(totals, on="ptp_id", how="left")
    ev["paid_total"] = ev["paid_total"].fillna(0)
    ev["is_kept_math"] = ev["paid_total"] >= 0.95 * ev["promised_amount"]
    g = ev.groupby([ptp["ptp_date"].dt.to_period("M").astype("str"),
                    "status"]).size().unstack(fill_value=0)
    return g.add_prefix("plans_").reset_index().rename(columns={"ptp_date": "month"})

def utilization_kpis(time_log: pd.DataFrame) -> pd.DataFrame:
    """ratio-of-sums monthly utilization. Target: v_productivity_metrics."""
    g = time_log.groupby([time_log["log_date"].dt.to_period("M").astype(str), "agent_id"])
    out = g.agg(op_hours=("operational_hours", "sum"), tht_hours=("tht_hours", "sum"))
    out["utilization_pct"] = 100 * out["tht_hours"] / out["op_hours"]
    return out.reset_index().rename(columns={"log_date": "month"})

if __name__ == "__main__":
    t0 = time.perf_counter()
    inter = load_year("Fact_Interactions", "interaction_date", OPT)
    ptp   = load_year("Fact_PTP_Log", "ptp_date")
    tl    = load_year("Fact_Agent_Time_Log", "log_date")
    t1 = time.perf_counter(); print(f"load {t1-t0:.1f}s")
    ck, pk, uk = contact_kpis(inter), promise_kpis(ptp, tl.assign()), utilization_kpis(tl)
    print(f"kpis {time.perf_counter()-t1:.1f}s  "
          f"rows: {len(ck)}/{len(pk)}/{len(uk)}")
```

**Why each part:** no top-level loads (import must be free of side effects); every docstring names its parity view so QA knows what to diff; stage timings satisfy the runtime requirement and make regressions visible.

**Verify yourself:** compare `contact_kpis` January rpc_pct per agent against SQL `v_contact_metrics WHERE month_num=1 AND granularity='monthly'`; `promise_kpis` kept counts against your medium Task-1 numbers; `utilization_kpis` July against `v_productivity_metrics`.

**Traps & alternatives:** resist a god-function returning everything — separate grains (day/agent/plan) keep each function testable; compose at call sites.

---

## Task 2 — Roll-rate transition matrix

```python
import pandas as pd

snap = load_year("Fact_EOM_Snapshot", "snapshot_date")   # loader from Task 1
buckets = pd.read_csv(RAW / "shared" / "Dim_Delinquency_Bucket.csv")

s = snap.sort_values(["account_id", "snapshot_date"])
s["prev_bucket"] = s.groupby("account_id")["dpd_bucket"].shift()
h2 = s[(s["snapshot_date"] >= "2025-07-01") & (s["snapshot_date"] < "2026-01-01")
       & s["prev_bucket"].notna()]

order = dict(zip(buckets["bucket_label"], buckets["sort_order"]))
h2 = h2.assign(from_rank=h2["prev_bucket"].map(order),
               to_rank=h2["dpd_bucket"].map(order))

matrix = pd.crosstab(h2["prev_bucket"], h2["dpd_bucket"])
matrix = matrix.reindex(index=[b for b, _ in sorted(order.items(), key=lambda kv: kv[1])],
                        columns=[b for b, _ in sorted(order.items(), key=lambda kv: kv[1])])

h2["direction"] = (h2["to_rank"] > h2["from_rank"]).map({True: "worsened",
                                                         False: "improved"})
h2.loc[h2["to_rank"] == h2["from_rank"], "direction"] = "stable"
print(matrix)
print(h2["direction"].value_counts())

# Exits: accounts whose last snapshot precedes the book end
last_seen = snap.groupby("account_id")["snapshot_date"].max()
exits = last_seen[last_seen < snap["snapshot_date"].max()]
```

**Why each part:** groupby-shift is pandas' LAG — sorting first is what makes 'previous' mean previous in TIME. Reindexing both axes by severity order fixes the alphabetical-scatter failure before any human reads it.

**Verify yourself:** cell-for-cell equality with SQL advanced Task 1's matrix for H2. Exit count here uses plain disappearance — reconcile against the view's Exited convention (it also admits pre-end finals) and document the difference exactly as you did in SQL.

---

## Task 3 — Seasonal-naive forecast → capacity

```python
stock = (snap.groupby(snap["snapshot_date"].dt.to_period("M").astype(str))
              .apply(lambda m: (m["status"] == "Mora").sum(), include_groups=False)
              .rename("mora_accounts"))

proj_jan = round(stock.tail(3).mean())          # trailing-3 baseline

ATTEMPTS_PER_ACCT_MONTH = 6      # A1: dialer strategy assumption (quote source!)
ATTEMPTS_PER_COLLECTOR_HOUR = 3  # A2: connect-rate reality
COLLECTOR_HOURS_PER_MONTH = 8 * 22

hours = proj_jan * ATTEMPTS_PER_ACCT_MONTH / ATTEMPTS_PER_COLLECTOR_HOUR
fte   = hours / COLLECTOR_HOURS_PER_MONTH

sens = []
for mult in (0.5, 1.0, 2.0):
    h = proj_jan * ATTEMPTS_PER_ACCT_MONTH * mult / ATTEMPTS_PER_COLLECTOR_HOUR
    sens.append({"attempts_mult": mult, "hours": round(h), "fte": round(h / COLLECTOR_HOURS_PER_MONTH, 1)})
print(stock.tail(6)); print({"projection": proj_jan, "hours": round(hours), "fte": round(fte, 1)})
print(pd.DataFrame(sens))
```

**Why each part:** identical arithmetic to the SQL version — files vs database must not change the model, only the plumbing. Constants live as named variables with provenance comments so reviewers attack assumptions, not code.

**Verify yourself:** stock series must equal SQL advanced Task 7's numbers month-for-month. Sensitivity table is the director's first question answered preemptively.

---

## Task 4 — QC assertion suite (`qc_checks.py`)

```python
"""qc_checks.py — executable data contract over cached parquets. Exit 1 on FAIL."""
import sys
import pandas as pd

CHECKS = []
def check(name):
    def deco(fn):
        CHECKS.append((name, fn)); return fn
    return deco

@check("pk_unique_interactions")
def _(inter): return inter["interaction_id"].is_unique

@check("no_null_agent_on_interactions")
def _(inter): return inter["agent_id"].notna().all()

@check("weekday_only_interactions")
def _(inter): return int((inter["interaction_date"].dt.dayofweek >= 5).sum()) == 0

@check("kept_plans_meet_95pct", needs=("ptp", "payments"))
def _(ptp, payments):
    tot = payments[payments["ptp_id"].notna()].groupby("ptp_id")["amount_paid"].sum()
    k = ptp[ptp["status"] == "Kept"].merge(tot.rename("paid"), on="ptp_id", how="left")
    return bool((k["paid"].fillna(0) >= 0.95 * k["promised_amount"]).all())

@check("reentry_band_5_25")
def _(snap):
    s = snap.sort_values(["account_id", "snapshot_date"])
    prev = s.groupby("account_id")["status"].shift()
    cured_ids = set(s.loc[(prev == "Mora") & (s["status"] == "Activo"), "account_id"])
    mora_after = s[(s["status"] == "Mora") & (s["account_id"].isin(cured_ids))]
    reentered = mora_after.merge(
        s.loc[(prev == "Mora") & (s["status"] == "Activo"), ["account_id", "snapshot_date"]]
          .rename(columns={"snapshot_date": "cure_date"}),
        on="account_id")
    relapsed = reentered["snapshot_date"] > reentered["cure_date"]
    rate = 100 * len(reentered.loc[relapsed].drop_duplicates("account_id")) / max(len(cured_ids), 1)
    return 5 <= rate <= 25

@check("calendar_covers_2025")
def _(cal): return int(cal.query("date >= '2025-01-01' and date <= '2025-12-31'").shape[0]) >= 365

Runner (bottom of `qc_checks.py`):

```python
def main(cache: dict[str, pd.DataFrame]):
    failures = []
    for name, fn in CHECKS:
        try:
            ok = bool(fn(*[cache[a] for a in NEEDS.get(name, ())]))
        except Exception as e:
            ok, _ = False, print(f"  error in {name}: {e!r}")
        print(f"{name:<32} {'PASS' if ok else 'FAIL'}")
        if not ok:
            failures.append(name)
    sys.exit(1 if failures else 0)

NEEDS = {
    "pk_unique_interactions":      ("interactions",),
    "no_null_agent_on_interactions": ("interactions",),
    "weekday_only_interactions":   ("interactions",),
    "kept_plans_meet_95pct":       ("ptp", "payments"),
    "reentry_band_5_25":           ("snapshots",),
    "calendar_covers_2025":        ("calendar",),
}

if __name__ == "__main__":
    cache = {
        "interactions": load_year("Fact_Interactions", "interaction_date", OPT),
        "ptp":          load_year("Fact_PTP_Log", "ptp_date"),
        "payments":     load_year("Fact_Payments", "payment_date"),
        "snapshots":    load_year("Fact_EOM_Snapshot", "snapshot_date"),
        "calendar":     pd.read_csv(RAW / "shared" / "Dim_Calendar.csv",
                                    parse_dates=["date"]),
    }
    main(cache)
```

**Why each part:** decorator registry + NEEDS map keep checks declarative and independently runnable; business rules (95% threshold, weekend rule, re-entry band) sit beside structural ones — an executable data contract, exactly what the JD's governance theme wants.

**Verify yourself:** run green; then inject one duplicate interaction_id into a scratch cache — suite FAILS naming the rule; fix, green again. Re-entry check must agree with SQL advanced Task 3's band verdict — same data, two languages.

---

## Task 5 — Batch processing & timing benchmark

```python
import time, tracemalloc
import pandas as pd

def path_full():
    df = load_year("Fact_Interactions", "interaction_date", OPT)
    g = df.groupby(df["interaction_date"].dt.to_period("M").astype(str))
    return 100 * g["rpc_flag"].sum() / g["calls_connected"].sum()

def path_chunked(chunksize=250_000):
    acc: dict[str, list[int]] = {}
    for md in _months():
        for chunk in pd.read_csv(md / "Fact_Interactions.csv",
                                 dtype=OPT, parse_dates=["interaction_date"],
                                 chunksize=chunksize):
            key = str(chunk["interaction_date"].dt.to_period("M").iloc[0])
            c = acc.setdefault(key, [0, 0])
            c[0] += int(chunk["calls_connected"].sum())
            c[1] += int(chunk["rpc_flag"].sum())
    return pd.Series({k: 100 * r / max(c, 1) for k, (c, r) in acc.items()})

tracemalloc.start(); t0 = time.perf_counter()
a = path_full()
t_full, mem_full = time.perf_counter() - t0, tracemalloc.get_traced_memory()[1]
tracemalloc.reset_peak()

t0 = time.perf_counter()
b = path_chunked()
t_chunk, mem_chunk = time.perf_counter() - t0, tracemalloc.get_traced_memory()[1]

assert a.round(6).equals(b.round(6)), "paths disagree!"
print(f"full: {t_full:.1f}s peak={mem_full/1024**2:.0f}MB | "
      f"chunked: {t_chunk:.1f}s peak={mem_chunk/1024**2:.0f}MB")
```

**Why each part:** the chunked path accumulates SUMS per month and divides ONCE at the end — ratio-of-sums discipline makes partial aggregation identical to full-frame math; averaging per-chunk percentages would fail the assert BY DESIGN (that's the pedagogical trap).

**Verify yourself:** assert passes → same answer via both paths. Record wall-times + peak MB with machine context in comments; write your measured verdict honestly — chunking wins memory headroom, full-load often wins raw speed when RAM allows. Neither is universally "faster"; the benchmark exists so you stop guessing.
