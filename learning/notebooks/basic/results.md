# Notebooks Basic — Results (worked solutions)

Notebook solutions are given as ordered CELLS (markdown `>` / code). Rebuild, then Restart & Run All — the honest test.

---

## Task 1 — Anatomy check

**Cell 1 (markdown):**
```markdown
# June Interactions — First Look
Question: what does one month of call activity look like structurally?
```
**Cell 2 (markdown):** `## Setup`
**Cell 3 (code):**
```python
from pathlib import Path
import pandas as pd

RAW = next(p for p in [Path.cwd(), *Path.cwd().parents]
           if (p / "data_sources" / "raw").is_dir()) / "data_sources" / "raw"
```
> *This walks up from the notebook's working directory until it finds the repo root. It is execution-location independent — no `../../` counting, no absolute paths.*

**Cell 4 (code):**
```python
june = pd.read_csv(RAW / "june_2025" / "Fact_Interactions.csv",
                   dtype={"agent_id": "string"}, parse_dates=["interaction_date"])
print(june.shape); print(june.dtypes); display(june.head(3))
```
**Cell 5 (markdown):** takeaway, e.g., "One month ≈ 100K rows; ids are strings; flags already boolean."

**Verify yourself:** Kernel → Restart & Run All → zero errors, sequential execution numbers.

---

## Task 2 — Self-explaining bar chart

```python
import matplotlib.pyplot as plt

jan = pd.read_csv(next((RAW / "january_2025").glob("Fact_Interactions.csv")),
                  dtype={"agent_id": "string"}, parse_dates=["interaction_date"])
emps = pd.read_csv(RAW / "shared" / "Dim_Employees.csv", dtype="string")

by_team = (jan.merge(emps[["agent_id", "team_name"]], on="agent_id")
              .groupby("team_name")["interaction_id"].count()
              .sort_values(ascending=False))

ax = by_team.plot.bar(figsize=(8, 4), color="#262A76")
ax.set_title("January 2025 interactions per team")
ax.set_xlabel(""); ax.set_ylabel("interactions")
for c in ax.containers:
    ax.bar_label(c, fontsize=8)
plt.tight_layout(); plt.show()
```

**Cell after (markdown):** "Team X led January volume at ~N calls; the spread between top and bottom is ~Y% — allocation follows headcount." *(Write YOUR numbers; never paste someone else's.)*

**Why each part:** `bar_label` puts values ON bars so nobody squints at axes; color matches the project palette; `tight_layout` stops label clipping.

---

## Task 3 — Narrative sandwich

Cell order is the answer: **md question → code → md reading-of-table → code chart → md 'so what'**. Example arc for RPC%:

1. *"Does connect quality differ by channel?"*
2. groupby channel sums (reuse SQL-basic Task 3 logic)
3. *"Dialer leads volume; FICO trails — but rates are what matter…"*
4. RPC% bar with labels
5. *"So what: channel mix is arm-driven (see strategy dim); QBR should compare arms, not raw channels."*

**Verify yourself:** delete all outputs, hand the file to a colleague cold — if they ask "where did this number come from?", a narrative cell is missing.

---

## Task 4 — Annotated monthly trend

```python
dirs = sorted((d for d in RAW.iterdir() if d.is_dir() and d.name != "shared"),
              key=lambda d: pd.to_datetime(d.name, format="%B_%Y"))
vol = []
for mdir in dirs:
    dfm = pd.read_csv(mdir / "Fact_Interactions.csv", usecols=["interaction_id"])
    vol.append(len(dfm))

months = pd.PeriodIndex([pd.Period(pd.to_datetime(d.name, format="%B_%Y"), freq="M")
                         for d in dirs], freq="M")
s = pd.Series(vol, index=months)

fig, ax = plt.subplots(figsize=(9, 4))
s.plot(ax=ax, marker="o", color="#262A76")
ax.set_title("Monthly interaction volume — 2025"); ax.set_ylabel("calls")
imax, imin = s.idxmax(), s.idxmin()
ax.annotate(f"peak {s[imax]:,.0f}", (imax, s[imax]), xytext=(0, 8),
            textcoords="offset points", ha="center")
ax.annotate(f"trough {s[imin]:,.0f}", (imin, s[imin]), xytext=(0, -14),
            textcoords="offset points", ha="center")
plt.tight_layout(); plt.show()
```

Takeaway cell names the driver: G7 seasonal wiring makes volume follow `seasonal_volume[m]` — peak/trough are designed, not accidents.

---

## Task 5 — Ship-shape audit

Checklist cell (top of each notebook):

```python
AUDIT = {
    "restart_run_all_clean": True,   # verified via Kernel menu
    "outputs_trimmed": True,
    "execution_counts_sequential": True,
    "no_dead_cells": True,
}
assert all(AUDIT.values()), AUDIT
```

Fixes that matter: Cell → All Output → Clear (then Run All regenerates honestly); right-click → Delete Cells for dead ends; if execution counts jump (e.g., [37] after [3]), restart and re-run before sharing.
