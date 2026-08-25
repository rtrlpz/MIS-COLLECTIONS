# Excel Advanced — Your Inbox (level 3 of 3)

```
You are here: learning/excel/advanced/
Assumed:      medium/ complete — pack structure, live rollups, RAG, change log all exist
Tooling:      openpyxl for generation · REAL VBA modules in a macro-enabled .xlsm
              (openpyxl keeps VBA via keep_vba=True; you author .bas modules and import)
Solutions:    advanced/results.md — complete scripts + full VBA module listings
Theme:        automation the JD explicitly names: scheduled generation, refresh-on-open,
              one-button PDF packs, and the governance that keeps it all defensible
```

---

## Task 1 — The MIS generator script
📥 **Inbox:** From Head of MIS · Mon 9:00 · "the flagship deliverable"

> "Write `generate_daily_mis.py`: reads the daily KPI extract (CSV export of `v_daily_mis`), builds the FULL pack from your medium template — Cover, Daily, Summary, AgentLookup, Parameters, ChangeLog — with every style, formula, RAG rule, and print setting applied. One command, zero manual steps. This becomes the real `reports/` tool."

**Done when:**
- [ ] Single CLI script: input CSV path + output xlsx path
- [ ] All six sheets built with medium-level behaviors intact
- [ ] Fresh run reproduces the workbook byte-stable except timestamps

---

## Task 2 — Refresh-on-open: your first real VBA
📥 **Inbox:** From Ops Lead · Tue 8:00 · "I just want to open it and see TODAY"

> "Convert the pack to `.xlsm`. Add a `Workbook_Open` macro: stamps 'Last refreshed' with current timestamp on the Cover and forces recalculation. Security note documented — macros signed/disabled prompts are part of life."

**Done when:**
- [ ] .xlsm opens → Cover timestamp updates automatically
- [ ] Module saved as importable `.bas` in `work/`
- [ ] Note covers macro security implications honestly

---

## Task 3 — The one-button pack: CSV → refresh → PDF
📥 **Inbox:** From Site Director · Thu 4:30 PM · "8:45 email attaches this"

> "Add a 'Refresh Pack' button on the Cover wired to a VBA module: prompts for the daily CSV (or uses a fixed drop path), clears and reloads the Data sheet, recalcs, exports Daily+Summary to PDF with the date in the filename. One click, morning done."

**Done when:**
- [ ] Button runs end-to-end without touching other sheets' formulas
- [ ] PDF filename embeds the report date (`daily_mis_2025-06-30.pdf`)
- [ ] Failure path: missing CSV → clear message, no half-written file

---

## Task 4 — Generating .xlsm safely from python
📥 **Inbox:** From MIS Manager · Fri 11:00 · "the pipeline must produce the macro book"

> "Extend the generator: after building the .xlsx, inject the VBA project so the OUTPUT is the .xlsm with your modules — document exactly how openpyxl's keep_vba path works and its limits (you cannot AUTHOR VBA from python; you preserve it)."

**Done when:**
- [ ] Documented flow: template .xlsm holds VBA → openpyxl opens WITH keep_vba → sheets rebuilt → saved as .xlsm
- [ ] Macros still fire after regeneration
- [ ] Limits section written (what must stay manual)

---

## Task 5 — Scheduled generation & governance wrap-up
📥 **Inbox:** From Head of MIS · Mon 2:00 · "the JD said 'schedule automatic generation' — do it"

> "Document the scheduling layer: Windows Task Scheduler job running the generator at 08:15 weekdays, then the .xlsm opened by the duty analyst who hits the button. Plus close the governance loop: ChangeLog rows for THIS task, final checklist doc tying together every control the pack now has."

**Done when:**
- [ ] Task Scheduler XML/steps documented (trigger, action, working dir, failure alert)
- [ ] Run-of-show: what's automatic vs human-judgment
- [ ] Final checklist: RAG thresholds source, reconcile step, change log discipline, macro policy

---

## Finish

You now ship an automated, self-documenting, governed MIS pack — the exact deliverable set the job description centers on. Last stop: [`../../git-cli/tasks.md`](../../git-cli/tasks.md) — version everything you just built.
