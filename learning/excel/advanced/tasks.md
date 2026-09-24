# Excel Advanced — Your Inbox (level 3 of 3)

```
You are here: learning/excel/advanced/
Assumed:      medium/ complete — pack structure, live rollups, RAG, Power Query all warm
Tooling:      openpyxl for generation · REAL VBA modules in a macro-enabled .xlsm
               (openpyxl keeps VBA via keep_vba=True; you author .bas modules and import)
Solutions:    advanced/results.md — manual Excel steps, complete scripts + full VBA module listings
Theme:        automation the JD explicitly names: scheduled generation, refresh-on-open,
               one-button PDF packs, and the governance that keeps it all defensible
```

**How to work through this level.** Phase A (Tasks 1–2) is Excel-native: you build the full dashboard manually in Excel — every formula, every pivot, every chart, every slicer placed by hand. This is the "what" the automation must reproduce. Phase B (Tasks 3–7) teaches you to automate it with Python + VBA, turning the manual workbook into a self-running pipeline.

The rule: **if you can't build it manually in Excel, you can't automate it correctly.**

---

## ═══ PHASE A — Excel-Native Skills ═══

*These tasks teach you to build the complete daily MIS dashboard entirely with Excel's UI — formulas, pivots, charts, slicers, conditional formatting, Power Query. This is what the VBA automation later reproduces.*

---

## Task 1 — Build the complete dashboard manually

📥 **Inbox:** From Operations Manager · Tue 2:00 · "the director wants the full pack, now"

> "Before we automate anything, build the FULL daily MIS pack manually in Excel. Every sheet. Every formula. Every chart. Every RAG indicator. The director needs to see what 'done' looks like — and you need to understand it before you make it self-run."

**Your job (Excel only — NO Python):**
1. **Cover sheet:** Title, owner, generation timestamp (formula off a cell), navigation lines for each tab. Tab color coded.
2. **Daily sheet:** All daily data rows. XLOOKUP/VLOOKUP for agent names. Data validation dropdowns. Freeze panes.
3. **Summary sheet:** SUMIFS rollup by month, RPC% column, MoM delta. RAG conditional formatting referencing Parameters thresholds.
4. **PivotDaily sheet:** PivotTable from the Daily data. Rows = Team, Values = SUM of all KPIs, Filter = Month.
5. **PivotChart + Slicer:** PivotChart showing RPC% trends. Slicer on Team. Dashboard sheet layout.
6. **Power Query connection:** Load the daily extract via Power Query → Refresh on open configured.
7. **ChangeLog sheet:** Pre-populate with ≥3 entries documenting this workbook's creation.
8. **Print setup:** Every sheet configured for landscape, fit-to-width, repeating headers. Print preview.
9. **Save as `work/daily_mis_manual.xlsx`.** This IS the reference — the automation must reproduce it.

**Done when:**
- [ ] All sheets built manually in Excel (no Python)
- [ ] Every formula typed by hand (SUMIFS, XLOOKUP, VLOOKUP, IFERROR, TEXT)
- [ ] PivotTable + PivotChart + Slicer all functional
- [ ] Power Query refresh works
- [ ] RAG conditional formatting referencing Parameters thresholds
- [ ] ChangeLog has ≥3 entries
- [ ] Print setup verified via preview
- [ ] Saved to `work/daily_mis_manual.xlsx`

---

## Task 2 — Understand the pivot cache

📥 **Inbox:** From MIS Manager · Wed 10:00 · "why does my pivot freeze?"

> "The pivot table on the dashboard isn't updating when we add new rows. I need to understand why — and fix it. This is the kind of thing that wastes half a morning if you don't know how pivots work under the hood."

**Your job:**
1. Open `work/daily_mis_manual.xlsx`. Add a new row to the Data sheet below the table.
2. **Right-click the pivot → Refresh** → confirm the new row appears.
3. **Check the pivot cache:** go to **PivotTable Analyze → Options → Data** → see the cache range.
4. **Problem:** if the cache doesn't auto-expand, new rows are invisible to the pivot.
5. **Fix options:**
   - Option A: Convert the data range to an Excel Table (cache auto-expands)
   - Option B: Manually update the cache range in PivotTable Options
   - Option C: Use Power Query as the pivot source (cache refreshes with the query)
6. **Test each fix:** add rows → refresh → confirm.
7. **Note which fix works best** and why (Power Query is the enterprise answer).
8. *Then* read results.md for how the openpyxl generator handles pivot cache.

**Done when:**
- [ ] Pivot cache behavior understood (why it freezes)
- [ ] All three fix options tested
- [ ] Enterprise recommendation written
- [ ] Can explain pivot cache to a colleague

---

## ═══ PHASE B — Automate with Python & VBA ═══

*These tasks take the manual dashboard you built in Phase A and make it self-running. The manual workbook is the spec; the automation is the implementation.*

---

## Task 3 — The MIS generator script

📥 **Inbox:** From Head of MIS · Mon 9:00 · "the flagship deliverable"

> "Write `generate_daily_mis.py`: reads the daily KPI extract (CSV export of `v_daily_mis`), builds the FULL pack from your Phase A manual workbook — Cover, Daily, Summary, AgentLookup, Parameters, ChangeLog — with every style, formula, RAG rule, pivot-ready data layout, and print setting applied. One command, zero manual steps."

**Your job:**
1. Assemble everything from basic/medium/Phase A into a single CLI script.
2. Input: CSV path + output xlsx path.
3. All behaviors intact: structured references (Excel Table), SUMIFS formulas, RAG conditional formatting, validation dropdowns, XLOOKUP formulas, print setup, Power Query-ready Data sheet layout.
4. **Key test:** the generated workbook must be functionally identical to `work/daily_mis_manual.xlsx` — same formulas, same structure, same pivot-ready layout.
5. Fresh run reproduces the workbook byte-stable except timestamps.
6. Add reconciliation step (compare generated numbers against SQL `v_daily_mis`).

**Done when:**
- [ ] Single CLI script: input CSV path + output xlsx path
- [ ] Generated workbook matches manual dashboard functionally
- [ ] Byte-stable reruns except timestamps
- [ ] Reconciliation step included

---

## Task 4 — Refresh-on-open: your first real VBA

📥 **Inbox:** From Ops Lead · Tue 8:00 · "I just want to open it and see TODAY"

> "Convert the pack to `.xlsm`. Add a `Workbook_Open` macro: stamps 'Last refreshed' with current timestamp on the Cover and forces recalculation. Security note documented — macros signed/disabled prompts are part of life."

**Your job:**
1. Save the generated .xlsx as .xlsm template.
2. Add VBA module `modRefresh`:
   - `Workbook_Open` event stamps Cover timestamp
   - `Application.CalculateFullRebuild` forces recalc
3. Save `.bas` module in `work/`.
4. Note: `Workbook_Open` belongs in **ThisWorkbook**, not a `.bas` module. The `.bas` holds helper code.
5. Document macro security implications honestly — users must click "Enable Content."
6. **Test:** close & reopen → timestamp changes to now; F9-recalc visibly refreshed.

**Done when:**
- [ ] .xlsm opens → Cover timestamp updates automatically
- [ ] Module saved as importable `.bas`
- [ ] Macro security implications documented honestly

---

## Task 5 — The one-button pack: CSV → refresh → PDF

📥 **Inbox:** From Site Director · Thu 4:30 PM · "8:45 email attaches this"

> "Add a 'Refresh Pack' button on the Cover wired to a VBA module: prompts for the daily CSV (or uses a fixed drop path), clears and reloads the Data sheet, recalcs, exports Daily+Summary to PDF with the date in the filename. One click, morning done."

**Your job:**
1. Write VBA module `modPackPipeline`:
   - `RefreshPack` sub: find newest CSV in drop path, load into Data sheet via QueryTable, recalc, export PDF
   - Failure path: missing CSV → message box, no partial write
2. Cover button: Insert → Shapes → rectangle → Assign Macro → `RefreshPack`
3. PDF filename: `daily_mis_YYYY-MM-DD.pdf`
4. **Test:** drop two CSVs with different timestamps — correct one loads. Remove all CSVs — message box.
5. Verify formulas on Summary intact after refresh (spot-check).

**Done when:**
- [ ] Button runs end-to-end without touching other sheets' formulas
- [ ] PDF filename embeds report date
- [ ] Missing CSV → clear message, no half-written file

---

## Task 6 — Generating .xlsm safely from python

📥 **Inbox:** From MIS Manager · Fri 11:00 · "the pipeline must produce the macro book"

> "Extend the generator: after building the .xlsx, inject the VBA project so the OUTPUT is the .xlsm with your modules — document exactly how openpyxl's keep_vba path works and its limits (you cannot AUTHOR VBA from python; you preserve it)."

**Your job:**
1. Document the flow:
   - Step 1: Build template `.xlsm` ONCE manually (ThisWorkbook stub + imported `.bas` modules)
   - Step 2: Generator flow: `load_workbook("pack_template.xlsm", keep_vba=True)` → rebuild sheet contents → save as `.xlsm`
   - Step 3: LIMITS section (you cannot CREATE or EDIT VBA from python — only preserve it)
2. **Limits to document:**
   - Cannot author VBA from python; only preserve existing project
   - Sheet-level code (event handlers on renamed/deleted sheets) can orphan
   - Keep sheet NAMES stable so ThisWorkbook/module references survive
3. **Test:** open generated file → Alt+F11 shows modules intact → Workbook_Open fires → button works. Break test deliberately: rename Data sheet in a copy → observe what orphans.

**Done when:**
- [ ] Documented flow with template → rebuild → save
- [ ] Macros still fire after regeneration
- [ ] Limits section written

---

## Task 7 — Scheduled generation & governance wrap-up

📥 **Inbox:** From Head of MIS · Mon 2:00 · "the JD said 'schedule automatic generation' — do it"

> "Document the scheduling layer: Windows Task Scheduler job running the generator at 08:15 weekdays, then the .xlsm opened by the duty analyst who hits the button. Plus close the governance loop: ChangeLog rows for THIS task, final checklist doc tying together every control the pack now has."

**Your job:**
1. **Task Scheduler documentation:**
   - Trigger: Weekdays 08:15
   - Action: python.exe → `generate_daily_mis.py --input C:\collections\drops\daily_*.csv --out C:\collections\output\daily_mis.xlsx`
   - Start in: project directory
   - Failure: email via task history + fallback manual run
2. **Run-of-show:** what's automatic vs human-judgment:
   - Automatic: data generation, workbook build
   - Human: open .xlsm → Enable Content → RefreshPack → mail PDF
3. **Final governance checklist:**
   - [ ] RAG thresholds live ONLY on Parameters (strategy-editable)
   - [ ] Reconcile step ran before send
   - [ ] ChangeLog row exists for every change since last send
   - [ ] Macro policy stated on Cover (signed/enable-click)
   - [ ] PDF filename carries report date; archive folder per month
   - [ ] Pivot cache understood and refreshed (Task 2 knowledge)
4. **Dry-run:** one full morning — scheduler fires, button pressed, PDF attached, log rows written.

**Done when:**
- [ ] Task Scheduler steps documented
- [ ] Run-of-show complete
- [ ] Governance checklist signed off
- [ ] Dry-run completed

---

## Finish

You now ship an automated, self-documenting, governed MIS pack — the exact deliverable set the job description centers on. You built it manually first (Phase A) so you understand every formula, every pivot cache, every RAG rule — then automated it (Phase B). Last stop: [`../../git-cli/tasks.md`](../../git-cli/tasks.md) — version everything you just built.
