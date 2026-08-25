# Notebooks Basic — Your Inbox (level 1 of 3)

```
You are here: learning/notebooks/basic/
Assumed:      python/basic done — the loading code exists; your job is the EXPLANATION
Setup:        Jupyter Lab/VS Code · save work/attempt_*.ipynb · Restart & Run All before shipping
Solutions:    basic/results.md — after attempting; then Run All and compare narrative quality
Rule:         a notebook is a DOCUMENT. If a stranger can't read it top to bottom, it's not done.
```

**What this level gives you.** The JD's "explain how a number is calculated, step by step, with charts" — starting with clean anatomy: one notebook = one story, markdown between cells, charts that label themselves.

---

## Words you'll meet

| Term | Plain meaning |
|---|---|
| **Cell (code/markdown)** | The two building blocks: runnable code vs written explanation |
| **Restart & Run All** | The honesty test — a notebook only counts if it works top-to-bottom from scratch |
| **Chart hygiene** | Title, axis labels, units — every plot labels itself |
| **Narrative arc** | Question → evidence → chart → one-sentence takeaway |

---

## Task 1 — Anatomy check: load and peek
📥 **Inbox:** From MIS Manager · Day 1 · "notebooks 101"

> "One notebook, three sections with markdown headers: Setup, Load, Look. Load June's interactions file (reuse your python track loader), show shape/dtypes/head, and end each section with a one-sentence markdown takeaway."

**Done when:**
- [ ] Runs top-to-bottom on fresh kernel
- [ ] Three markdown sections; takeaways in prose not comments
- [ ] Saved `work/attempt_1.ipynb`

---

## Task 2 — First chart that explains itself
📥 **Inbox:** From Ops Lead · Tue 10:00 · "for the new-hire deck"

> "Bar chart: January interactions per team. It must be readable WITHOUT you in the room — title says what/when, bars labeled, teams ordered by value."

**Done when:**
- [ ] Self-labeled chart (title, axis names)
- [ ] Sorted descending; values annotated on bars
- [ ] Markdown cell after it stating the headline in words

---

## Task 3 — The narrative sandwich
📥 **Inbox:** From MIS Manager · Thu 2:00 · "writing matters as much as code"

> "Take any KPI you computed in SQL (pick RPC%). Build a 5-cell mini-notebook: question in markdown → query-equivalent pandas → small table → chart → 'So what?' paragraph. No orphan cells."

**Done when:**
- [ ] Every code cell has prose above or below it
- [ ] Ends with an actionable sentence, not a number dump

---

## Task 4 — Monthly trend with annotations
📥 **Inbox:** From Operations Manager · Fri 11:00 · "year-in-one-picture"

> "Line chart of monthly interaction volume across 2025. Annotate the peak month and the trough directly ON the chart. Reader should get the story without reading numbers off axes."

**Done when:**
- [ ] One line, all twelve months, labeled axes
- [ ] Peak/trough annotations via annotate/text
- [ ] Takeaway cell: what drives the shape (hint: seasonality wiring)

---

## Task 5 — Ship-shape notebooks
📥 **Inbox:** From MIS Manager · Mon 9:30 · "before these go to colleagues"

> "House style for sharing: Restart & Run All passes, no giant raw dumps in outputs (head() suffices), execution count sequential, no dead cells. Audit your four existing notebooks against this list and fix them."

**Done when:**
- [ ] All four restart cleanly
- [ ] Outputs trimmed; dead cells deleted
- [ ] A short checklist cell at the top of each notebook confirming the audit

---

## Finish

Five documents people can actually read. Medium level makes them analytical: [`../medium/tasks.md`](../medium/tasks.md).
