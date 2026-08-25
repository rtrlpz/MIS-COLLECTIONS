# Notebooks Medium — Results (worked solutions)

Cells given in order; markdown cells marked `>`. Run All after building.

---

## Task 1 — Standard first section

```python
# ── Standard loader (copy into every analysis notebook) ──────────────
from pathlib import Path
import pandas as pd

RAW = Path.cwd()
while not (RAW / "data_sources").exists():     # walk up to project root
    RAW = RAW.parent

OPT = {"agent_id": "category", "account_id": "string", "channel": "category",
       "strategy_id": "category", "rpc_flag": "bool"}

def load_year(table, date_col, dtypes=None):
    months = sorted(d for d in (RAW / "data_sources" / "raw").iterdir()
                    if d.is_dir() and d.name != "shared")
    return pd.concat([pd.read_csv(m / f"{table}.csv", dtype=dtypes,
                                  parse_dates=[date_col]) for m in months],
                     ignore_index=True)
```
```python
inter = load_year("Fact_Interactions", "interaction_date", OPT)
print(f"{len(inter):,} rows | {inter.memory_usage(deep=True).sum()/1024**2:,.0f} MB deep")
assert len(inter) == sum(len(pd.read_csv(m / "Fact_Interactions.csv"))
                         for m in (RAW / "data_sources" / "raw").iterdir() if m.is_dir())
```
> *Reference: `_reference/datasets.md` lists ~1.34M for fact_interactions — write the actual number beside it.*

**Why the root-walk:** notebooks live in nested folders; resolving the project root once makes every path stable regardless of where the .ipynb sits.

---

## Task 2 — Target line + amber markers

```python
import matplotlib.pyplot as plt

TARGET = 45.0
monthly = (inter.groupby(inter["interaction_date"].dt.to_period("M"))
                .apply(lambda g: 100 * g["rpc_flag"].sum()
                       / max(g["calls_connected"].sum(), 1), include_groups=False))

fig, ax = plt.subplots(figsize=(9, 4))
monthly.plot(ax=ax, marker="o", color="#262A76", label="RPC %")
ax.axhline(TARGET, color="#FF0000", ls="--", lw=1, label=f"target {TARGET:.0f}%")
under = monthly[monthly < TARGET]
ax.scatter(under.index.astype(str), under.values, color="#FFC000", zorder=3,
           label="below target")
ax.set_title("Monthly RPC % vs target — 2025"); ax.set_ylabel("RPC %")
ax.legend(); plt.tight_layout(); plt.show()
```

Takeaway cell names the under-target months explicitly and one plausible driver each.

---

## Task 3 — Reconciliation story (installments)

Narrative arc with real cells:

1. **md:** "Rule: a plan is Kept when cumulative payments ≥95% of promised within grace. Watch plan `<pick a multi-part ptp_id from Q2>`."
2. **code:** filter that plan's rows from ptp + payments; display promised/grace/status.
3. **code:** its payment rows chronologically with running cumulative column (`cumsum`) and a `% of promise` column.
4. **md:** reading — part 1 alone = X% (<95) → stays Pending; part 2 crosses threshold → Kept.
5. **code:** aggregate invariant across ALL kept plans:

```python
totals = pay[pay["ptp_id"].notna()].groupby("ptp_id")["amount_paid"].sum()
kept = ptp[ptp["status"] == "Kept"].merge(totals.rename("paid"), on="ptp_id", how="left")
assert (kept["paid"].fillna(0) >= 0.95 * kept["promised_amount"]).all()
```

6. **md takeaway:** per-row checking is why finance doubted us; per-plan is the contract.

**Verify yourself:** a colleague reads only your markdown cells — do they get it without running anything?

---

## Task 4 — Heatmap channel × arm

```python
import seaborn as sns
import numpy as np

arms = pd.read_csv(RAW / "data_sources/raw/shared/Dim_Strategy.csv".replace("data_sources/raw/shared/", "shared/")) \
    if False else pd.read_csv(RAW / "data_sources" / "raw" / "shared" / "Dim_Strategy.csv")

grid = (inter.merge(arms[["strategy_id", "strategy_name"]], on="strategy_id")
             .pivot_table(index="strategy_name", columns="channel",
                          values="interaction_id", aggfunc="count", fill_value=0))
share = grid.div(grid.sum(axis=1), axis=0) * 100
order = ["Champion_Dialer", "Challenger_SMS_First", "Challenger_FICO_Priority"]
share = share.reindex(order)

fig, ax = plt.subplots(figsize=(7, 3.5))
sns.heatmap(share, annot=True, fmt=".1f", cmap="Blues", cbar_kws={"label": "% of arm"})
ax.set_title("Channel mix within treatment arm"); ax.set_ylabel(""); ax.set_xlabel("")
plt.tight_layout(); plt.show()
```

Takeaway: compare each row's dominant cell against `dim_strategy.channel_mix` intent — verdict per arm in prose.

---

## Task 5 — Parameterize

First code cell (tagged `parameters` in notebook metadata — Jupyter: cell toolbar → Tag):

```python
MONTH = "2025-06"       # Period string
TEAM  = None            # None = all teams
```

Every downstream cell consumes only MONTH/TEAM:

```python
mask = inter["interaction_date"].dt.to_period("M").astype(str).eq(MONTH)
if TEAM:
    mask &= inter["agent_id"].isin(
        emps.loc[emps["team_name"] == TEAM, "agent_id"])
sliced = inter[mask]
```

Grep yourself: search the file for hardcoded `'2025-0` outside the parameters cell — zero hits required. Document at top: "Executed via papermill: parameters MONTH, TEAM" so future automation has its contract.
