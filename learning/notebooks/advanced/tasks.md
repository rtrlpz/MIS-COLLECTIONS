# Notebooks Advanced — Your Inbox (level 3 of 3)

```
You are here: learning/notebooks/advanced/
Assumed:      medium/ complete — parameterized, target-lined, reconciled
Solutions:    advanced/results.md — cell-by-cell; Run All is the contract
Theme:        teaching artifacts and forecasts — the notebooks a senior ships
```

---

## Task 1 — "How Cures per THT hour works" (the explainer)
📥 **Inbox:** From MIS Manager · Mon 10:00 · "new-hire onboarding artifact"

> "Our composite scorecards include 'cures per THT hour' and new hires always mis-build it. Produce the canonical explainer notebook: define numerator and denominator from raw tables, walk ONE agent-day as a worked example, then the portfolio invariant, ending with the three mistakes people make."

**Done when:**
- [ ] Worked example traced at row level with commentary
- [ ] Aggregate check vs official recovery metrics view logic
- [ ] 'Three mistakes' section names real traps (double counting, wrong denominator, averaging rates)

---

## Task 2 — Roll-rate heatmap notebook
📥 **Inbox:** From Credit Risk Director · Tue 2:00 · "board visual"

> "Your SQL/python transition matrix as an annotated heatmap: severity-ordered axes, worsened cells visually distinct, one-year view with H2 highlighted. End with the risk sentence for the board pack."

**Done when:**
- [ ] Matrix built via groupby-shift (no SQL)
- [ ] Heatmap annotated; worsening emphasized by design
- [ ] One-sentence board takeaway in markdown

---

## Task 3 — Delinquency forecast narrative
📥 **Inbox:** From Site Director · Thu 4:00 · "budget notebook"

> "Same projection as python advanced Task 3 but AS A STORY: stock series chart, projection overlay with shaded uncertainty band, assumptions table as markdown, sensitivity mini-table. This notebook goes to finance — every claim traceable to a cell."

**Done when:**
- [ ] Chart shows history + naive forecast + stated caveat
- [ ] Assumptions block readable without code
- [ ] Sensitivity table computed in-notebook

---

## Task 4 — Reproducibility hardening
📥 **Inbox:** From Head of MIS · Fri 3:30 · "six months from now this must still run"

> "Harden your best notebook: pinned environment note, seeds everywhere randomness could appear, no hidden state between cells (Restart & Run All proof), and a header block stating data snapshot date + expected runtime. Deliver the hardened notebook + your personal reproducibility checklist."

**Done when:**
- [ ] Restart & Run All passes twice consecutively
- [ ] Header documents data vintage + runtime + env
- [ ] Checklist saved as `work/reproducibility_checklist.md`

---

## Finish

You now write notebooks that teach, persuade, and reproduce. The remaining track — [`../excel/`](../excel/) — ships these numbers to people who never open any of this.
