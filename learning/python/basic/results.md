# Python Basic — Results (worked solutions)

Run every solution; diff behavior against your attempt. Parity with SQL is the level's spine.

---

## Task 1 — Meet the raw files

```python
from pathlib import Path
import pandas as pd

RAW = Path("data_sources/raw")

# 1) Folder walk
month_dirs = sorted(d for d in RAW.iterdir() if d.is_dir() and d.name != "shared")
print(f"{len(month_dirs)} month dirs:", [d.name for d in month_dirs])
print("shared:", sorted(p.name for p in (RAW / "shared").iterdir()))
for d in month_dirs[:2]:
    print(d.name, "->", sorted(p.name for p in d.glob("*.csv")))

# 2) One month, safely typed where it matters
df = pd.read_csv(
    RAW / "january_2025" / "Fact_Interactions.csv",
    dtype={"agent_id": "string", "account_id": "string", "channel": "category"},
    parse_dates=["interaction_date"],
)
print(df.shape)
print(df.dtypes)
print(df.head(3))
```

**Why each part:** `dtype=` at read time prevents the classic silent damage — `EID-001` survives as string instead of becoming NaN-ridden floats; `parse_dates` makes `interaction_date` a real datetime so range masks work later. `pathlib.Path` over string paths: joins stay OS-clean.

**Verify yourself:** `interaction_date` dtype must be `datetime64[ns]`; `rpc_flag` should already be bool if the CSV stores true/false — check, and note what would break downstream if it arrived as strings.

**Traps & alternatives:** `pd.read_csv` without dtypes "works" — that's the danger. A column that's 99% numeric-looking IDs will load as float64 and corrupt every join later.

---

## Task 2 — Rebuild the year

```python
from pathlib import Path
import pandas as pd

RAW = Path("data_sources/raw")
DTYPES = {"agent_id": "string", "account_id": "string", "channel": "category"}

parts, total = [], 0
for md in sorted(d for d in RAW.iterdir() if d.is_dir() and d.name != "shared"):
    m = pd.read_csv(md / "Fact_Interactions.csv", dtype=DTYPES,
                    parse_dates=["interaction_date"])
    parts.append(m)
    total += len(m)

year = pd.concat(parts, ignore_index=True)

assert len(year) == total, f"concat lost rows: {len(year)} vs {total}"
print(f"year interactions: {len(year):,}")
```

**Why each part:** reading per-month keeps memory honest and gives you the sum-of-parts counter BEFORE concat. `ignore_index=True` because interaction_id uniqueness across files is the PK's job, not the index's. The assert turns "should be fine" into a contract.

**Verify yourself:** the printed total must match `_reference/datasets.md`'s ~1.34M fact_interactions estimate within tolerance — write the actual number next to the reference in a comment.

**Traps & alternatives:** `glob("**/*.csv")` would also swallow shared dims — filter by directory name, not pattern luck.

---

## Task 3 — RPC% by team

```python
import pandas as pd
from pathlib import Path

RAW = Path("data_sources/raw")
inter = pd.read_csv(RAW / "january_2025" / "Fact_Interactions.csv",
                    dtype={"agent_id": "string", "channel": "category"},
                    parse_dates=["interaction_date"])
emps = pd.read_csv(RAW / "shared" / "Dim_Employees.csv", dtype="string")

jan = inter[inter["interaction_date"] < "2025-02-01"]

g = (jan.merge(emps[["agent_id", "team_name"]], on="agent_id", how="left")
        .groupby("team_name")
        .agg(connected=("calls_connected", "sum"),
             rpcs=("rpc_flag", "sum")))

g["rpc_pct"] = (100 * g["rpcs"] / g["connected"]).round(1)
print(g.sort_values("rpc_pct", ascending=False))
```

**Why each part:** merge on dim FIRST then groupby mirrors the SQL join-then-group shape. Tuple-named aggs keep column names stable for later merges. Boolean sum counts TRUEs — same trick as SQL's `SUM(rpc_flag::int)`.

**Verify yourself:** parity against `v_contact_metrics WHERE month_num=1` (or your SQL-basic Task 3 numbers). Mismatch checklist: date edge (did Feb leak in?), dtype corruption on agent_id (NaN team), boolean-as-string summing.

---

## Task 4 — Month slicing like SQL ranges

```python
q1 = year[(year["interaction_date"] >= "2025-01-01")
          & (year["interaction_date"] <  "2025-04-01")]

per_month = q1.groupby(q1["interaction_date"].dt.to_period("M")).size()
assert per_month.index.tolist() == [pd.Period("2025-01"),
                                    pd.Period("2025-02"),
                                    pd.Period("2025-03")]
print(per_month)
```

**Why each part:** string comparisons against datetime64 columns are parsed to timestamps — half-open ranges behave exactly like SQL's `>= start AND < end`. `.dt.to_period("M")` groups without creating helper columns.

**Verify yourself:** the index assert proves April never leaked in. Compare January's count to Task 2's per-part number for january — equal or your slice is wrong.

**Traps & alternatives:** `.dt.strftime('%Y-%m') == '2025-01'` works until it doesn't (performance, and it invites `'2025-1'` typos); ranges are the habit that transfers to SQL and back.

---

## Task 5 — Weekend rule, files edition

```python
import pandas as pd
from pathlib import Path

RAW = Path("data_sources/raw")
pay = pd.read_csv(RAW / "january_2025" / "Fact_Payments.csv", parse_dates=["payment_date"])
# full-year payments: concat all 12 months exactly as Task 2 did
pay_year = pd.concat(
    [pd.read_csv(md / "Fact_Payments.csv", parse_dates=["payment_date"])
     for md in sorted(d for d in RAW.iterdir() if d.is_dir() and d.name != "shared")],
    ignore_index=True)

inter_jan = pd.read_csv(RAW / "january_2025" / "Fact_Interactions.csv",
                        parse_dates=["interaction_date"])

weekend_inter = int((inter_jan["interaction_date"].dt.dayofweek >= 5).sum())
weekend_pays  = int((pay_year["payment_date"].dt.dayofweek >= 5).sum())

assert weekend_inter == 0, "weekday-only rule violated!"
print({"weekend_interactions": weekend_inter, "weekend_payments": weekend_pays})
# Verdict: interactions weekday-only (0 violations); payments DO occur on weekends.
```

**Why each part:** `.dt.dayofweek` is Monday=0 … Sunday=6 — `>= 5` is the locale-proof weekend test. The assert encodes the RULE, so a future broken extract fails loudly here instead of shipping.

**Verify yourself:** verdicts must match your SQL Task 8 and `_reference/datasets.md`. A mismatch means an extract/load divergence — check `etl_load_log` freshness before blaming either side.

---

## Task 6 — The morning pack, files edition

```python
from pathlib import Path
import pandas as pd

RAW = Path("data_sources/raw")
REPORT_DATE = "2025-06-02"          # ← change ONE character-set daily

d = pd.Timestamp(REPORT_DATE)
month_dir = RAW / d.strftime("%B").lower() + f"_{d.year}"

inter = pd.read_csv(month_dir / "Fact_Interactions.csv", parse_dates=["interaction_date"])
ptp   = pd.read_csv(month_dir / "Fact_PTP_Log.csv",      parse_dates=["ptp_date"])
pay   = pd.read_csv(month_dir / "Fact_Payments.csv",     parse_dates=["payment_date"])

print("contacts :", int((inter["interaction_date"] == d).sum()))
print("connects :", int(inter.loc[inter["interaction_date"] == d, "calls_connected"].sum()))
print("promises :", int((ptp["ptp_date"] == d).sum()))
print("payments :", int((pay["payment_date"] == d).sum()))
```

**Why each part:** the month folder is DERIVED from the parameter — loading one file instead of twelve is the whole performance trick. Four independent counts, four prints: sticky-note format as requested. (Note: `Path` string-building above is intentionally naive; if you spot the cleaner `(RAW / f"{...}_{...}")` form, use it — say why in a comment.)

**Verify yourself:** run for a known date and compare to your SQL morning-pack numbers — all four must match exactly; that's the parity proof this track exists for.

**Traps & alternatives:** month-folder naming is `%B` lowercase (`june_2025`) — confirm against the walk from Task 1 rather than assuming. Payments can belong to the NEXT day's file edge cases? No — `payment_date` is authoritative regardless of folder; trust columns over folders when they disagree, then investigate.
