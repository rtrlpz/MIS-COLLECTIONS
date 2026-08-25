# Notebooks Advanced — Results (worked solutions)

Cell-by-cell; markdown marked `>`. Restart & Run All twice before calling anything done.

---

## Task 1 — Cures per THT hour explainer

Narrative skeleton (the code cells are small on purpose):

1. **md:** "Definition: cured accounts ÷ total handle-time hours, at agent-month grain. Scorecards weight it 20%."
2. **code:** load payments + agent_time_log for one chosen month.
3. **md:** "Worked example — agent EID-042, June 12." Pick an agent-day; show their payments with `is_cured` flags and the day's `tht_hours`.
4. **code:** running tally: distinct cured accounts that day ÷ tht hours → the day's rate. Comment each factor's SOURCE column explicitly.
5. **code:** aggregate to agent-month:

```python
cures = (pay[pay["is_cured"]]
         .groupby(["agent_id", pay["payment_date"].dt.to_period("M").astype(str)])
         ["account_id"].nunique().rename("cured_accounts"))
tht = (tl.groupby(["agent_id", tl["log_date"].dt.to_period("M").astype(str)])
          ["tht_hours"].sum().rename("tht_hours"))
rate = (cures / tht).dropna()
```

6. **code:** sanity vs official view: compare your agent-month rates against `v_recovery_metrics` cure_rate for a sample month (parity note in markdown).
7. **md:** "Three mistakes: (1) counting payment ROWS not distinct accounts — double-counts re-cures; (2) dividing by scheduled hours instead of THT — punishes efficient agents; (3) averaging daily rates instead of ratio-of-sums — weights quiet days."

**Verify yourself:** hand to a new hire; they should be able to rebuild it from definition alone.

---

## Task 2 — Roll-rate heatmap

```python
snap = load_year("Fact_EOM_Snapshot", "snapshot_date")
s = snap.sort_values(["account_id", "snapshot_date"])
s["prev"] = s.groupby("account_id")["dpd_bucket"].shift()

order = ["Current", "1-30", "31-60", "61-90", "90+"]
t = s[s["prev"].notna() & (s["snapshot_date"] >= "2025-07-01")
      & (s["snapshot_date"] < "2026-01-01")]
mat = pd.crosstab(t["prev"], t["dpd_bucket"]).reindex(index=order, columns=order)
share = mat.div(mat.values.sum()) * 100

fig, ax = plt.subplots(figsize=(6.5, 5))
sns.heatmap(share, annot=True, fmt=".1f", cmap="Blues",
            cbar_kws={"label": "% of all transitions"})
ax.set_title("Bucket transitions H2 2025 (% of transitions)")
ax.set_xlabel("to bucket"); ax.set_ylabel("from bucket")
# Emphasize worsening (below severity diagonal):
for i in range(5):
    for j in range(5):
        if i < j:
            ax.add_patch(plt.Rectangle((j, i), 1, 1, fill=False, edgecolor="#FF0000", lw=1.4))
plt.tight_layout(); plt.show()
```

Takeaway cell (board sentence): name the single largest worsened cell and whether H2 net-improved or deteriorated vs its reverse flow.

---

## Task 3 — Forecast narrative

Cells:

1. **md:** purpose + audience (finance) + data vintage line.
2. **code:** monthly Mora stock from snapshots (`status=='Mora'` counts by month-end).
3. **code:** chart history line + `proj = stock.tail(3).mean()` as dashed marker at January position; shade ±10% band via `fill_between`.

```python
hist = stock[:-0] if False else stock            # full series
fig, ax = plt.subplots(figsize=(8, 4))
hist.plot(ax=ax, marker="o", color="#262A76", label="actual Mora stock")
proj = float(hist.tail(3).mean())
ax.scatter([next_month_label], [proj], color="#FFC000", zorder=3, label="naive projection")
ax.fill_between([next_month_label], proj*0.9, proj*1.1, color="#FFC000", alpha=.25,
                label="±10% band")
ax.legend(); ax.set_title("Delinquency forecast — assumptions stated below")
```

4. **md assumptions table:** attempts/account=6 · collector productivity=3 attempts/hour · 176h/month · source comments.
5. **code:** capacity arithmetic + sensitivity DataFrame (multipliers .5/1/2).
6. **md caveat list:** seasonality ignored; December holidays; strategy changes reset history.

**Verify yourself:** every number in the markdown appears in exactly one code cell above it — no orphan claims.

---

## Task 4 — Reproducibility hardening

Header block template (first two cells):

```markdown
# <Title>
Data snapshot: generated 2025-XX-XX seed 42 (see data_sources/logs)
Expected runtime: ~90s · Env: mis-collections (pandas X.Y.z pinned in requirements.txt)
Outputs: figures only — no files written
```

```python
import numpy as np, pandas as pd, random
SEED = 42
random.seed(SEED); np.random.seed(SEED)
```

Hardening steps:
1. Restart & Run All TWICE; diff outputs — must be identical (that's why seeds exist even where you think nothing is random).
2. Kill any cell whose output depends on execution ORDER (move state into functions).
3. Pin versions note: `pip freeze | grep pandas` recorded in header, not vibes.
4. Save `work/reproducibility_checklist.md`: vintage line · seeds · runtime · restart-proof · no-order-dependence · outputs documented.

**Verify yourself:** give the hardened file + checklist to a colleague on another machine; success = they ran it without messaging you.
