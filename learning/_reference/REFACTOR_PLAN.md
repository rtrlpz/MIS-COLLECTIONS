# learning/ REFACTOR PLAN — Collections MIS Analyst JD Alignment

> **Status:** ✅ COMPLETE — all 7 phases delivered (Aug 2026) · ~95 JD-aligned tasks across 6 tracks
> **Owner:** MIS & Analytics Lead review
> **Goal:** Rewrite and expand the entire `learning/` practice lab so a new analyst is
> day-one ready for the Collections MIS Analyst role (source JD:
> `docs/unused/general_docs/mis analyst.docx` — Scotiabank GBS DR).
> This file is the execution contract: scope, templates, syllabi, delivery order.

---

## 1. Source JD → coverage map

Requirements extracted from the actual job description, and where each one is trained:

| JD requirement | Trained in |
|---|---|
| Timely, accurate MIS delivery against commitments | all tracks — every task has an inbox deadline; git-cli "diff before send"; SQL freshness check |
| Develop new MIS / adjust existing ones | Excel advanced (generator), Power BI medium/advanced, Python medium |
| **Scheduled automatic MIS generation** + client access | Excel advanced (VBA `Workbook_Open`, button pipeline, Task Scheduler notes) |
| Requirements clarity & client satisfaction | tasks are written as real requests with acceptance criteria ("Done When") |
| ETL between sources (extract/transform/store/transmit) | Python medium/advanced, reconciliation scripts, SQL auditing of project views |
| Dynamic reports in Power BI (+ intranet-style apps) | powerbi track end-to-end |
| KPI trend & root-cause analysis (portfolio + executive) | SQL medium/advanced, notebooks breakdowns |
| **Report governance / standardization** (no duplication/misuse) | SQL advanced (governance audit), Power BI advanced (theme + measure discipline) |
| Data → actionable intelligence | every track's "business reasoning" step in results.md |
| **Delinquency forecasting & roll-rate loss scenarios** | SQL advanced (LAG/LEAD roll rates), Python advanced (transition matrix + forecast), notebooks heatmap/narrative |
| **Capacity planning support** | SQL advanced + Python advanced forecast→capacity estimate |
| Security procedures documented; confidentiality | README house rules, RLS tasks, git hygiene tasks |
| SQL Server DB management + programming | SQL track (Postgres stands in; dialect-note boxes where syntax differs) |
| **Excel, VBA** deep knowledge | excel track incl. real VBA modules (`.xlsm`) |
| Retail credit products knowledge | Tarjeta/Prestamo/Hipoteca used throughout |
| BI tools (SAS/BO/PowerBI) | Power BI track (SAS/BO out of scope — noted) |

## 2. Contract changes vs the old learning style

| Rule | OLD | NEW |
|---|---|---|
| `tasks.md` | scenario + steps-with-why + guiding questions, no code/numbers | SAME, plus: inbox header block, urgency/deadline, explicit **Done When** checklist. Still zero code, zero expected numbers |
| `results.md` | guidance-only — no full runnable solutions | **Complete executable code** (query/script/DAX/VBA) + step logic + verification recipe — **but never computed outputs/result tables** |
| Language | English formal-neutral | English workplace voice (inbox-message style) |
| `_reference/` authority | yes | unchanged — every task cites datasets.md / kpi_glossary.md / data_dictionary.md sections |

`AGENTS.md` Learning Environment section must be updated to encode this new contract.

## 3. File templates

### tasks.md (per task)
```
## Task N — <short title>
📥 **Inbox:** From <sender/role> · <day, time> · <urgency>
> "<the request, verbatim, conversational>"
**Background:** business why, what happened, who needs it.
**Your job:** numbered steps — each with *why* attached.
**Guiding questions:** answered as comments in your work/ file.
**Data pointers:** exact tables/files + _reference section refs.
**Constraints:** performance, format, deadline, confidentiality.
**Done when:** [ ] acceptance criteria checkboxes.
```

### results.md (per task)
```
## Task N — <same title>
**Approach:** the reasoning path in N steps (why this way).
**Solution:** ONE complete runnable code block (SQL / pandas / DAX / VBA).
**Why each part:** line-level annotations for the non-obvious bits.
**Verify it yourself:** commands/queries to self-check correctness
    (cross-checks vs v_* views or totals) — commands only, NO printed answers.
**Traps & alternatives:** what bites, what a senior would do differently.
```

## 4. Syllabus (target task counts)

| Track | Basic | Medium | Advanced | New JD-driven additions |
|---|---|---|---|---|
| **sql/** | 7 → **9** | 5 → **8** | 4 → **9** | freshness check, payments allocation, installment reconciliation, LAG/LEAD roll rates, vintage, re-entry cohorts, scorecard audit, portfolio_cure_rate reconcile, capacity forecast baseline, recovery curve, governance audit |
| **powerbi/** | 4 → **6** | → **6** | → **5** | MTD/YTD + calc group, Dim_Targets actual-vs-target, RAG formatting, roll-rate matrix visual, SVG indicator cards, RLS via v_rls_supervisor_map + View-As testing, report governance/theme |
| **python/** | 4 → **6** | → **6** | → **5** | dtype/chunking @1.34M rows, installment-aware reconciliation, KP-decline detector, DB↔CSV checksum reconciliation, transition matrix, seasonal-naive forecast + capacity, QC assertion suite |
| **excel/** | 4 → **6** | → **6** | → **5** | formula-driven RAG, Power Query refresh, openpyxl MIS generator, VBA Workbook_Open, VBA import→refresh→PDF macro pipeline, .xlsm via keep_vba, Task Scheduler, change-log governance |
| **notebooks/** | 4 → **5** | → **5** | → **4** | explanation-first mirrors of Python topics: cure waterfall, roll-rate heatmap, forecast narrative |
| **git-cli/** | single level 5 → **8** | | | diff-before-send, MIS-variant branch, merge-conflict resolution on report SQL, revert, stash under pressure, release tagging |

Total: ~95 tasks (was ~40). Every level keeps its "Words you'll meet" primer and Finish page.

## 5. Delivery order & commit strategy

MULTI-STEP — seven phases, one commit each, reviewable track by track:

| # | Deliverable | Commit |
|---|---|---|
| 1 | `learning/README.md` rewrite + `AGENTS.md` contract update | 1 |
| 2 | `sql/` basic → medium → advanced (tasks + results) | 2 |
| 3 | `powerbi/` all levels | 3 |
| 4 | `python/` all levels | 4 |
| 5 | `notebooks/` all levels | 5 |
| 6 | `excel/` all levels (incl. VBA) | 6 |
| 7 | `git-cli/` + `_reference/kpi_glossary.md` additions (roll rate, vintage, capacity planning, forecast baseline) + final consistency sweep | 7 |

Rationale for order: matches the requested output sequence (sql → powerbi → python),
lets the reviewer approve the sql/basic tone pattern before it replicates everywhere,
and keeps each commit self-contained/revertable.

## 6. Guardrails

- `work/` folders untouched (git-ignored learner space)
- Never edit generated CSVs; DB read-only in all solutions
- No credentials anywhere; connection always via `.env`
- Numbers that disagree with the project's `v_*` views = finding to investigate, not failure
- Postgres dialect taught as-is, with a short "SQL Server says it differently" box where relevant (JD names SQL Server)

---

## 7. Progress log

| # | Phase | Status |
|---|---|---|
| 1 | README rewrite + AGENTS.md contract update | ✅ Done (Aug 2026) |
| 2 | `sql/` basic → medium → advanced | ✅ Done (Aug 2026; solutions QA-run against live DB) |
| 3 | `powerbi/` all levels | ✅ Done (Aug 2026; 17 tasks incl. SVG cards, RLS, governance) |
| 4 | `python/` all levels | ✅ Done (Aug 2026; solutions QA-run vs live CSVs+DB: row counts, team RPC% parity, 22-cell matrix match) |
| 5 | `notebooks/` all levels | ✅ Done (Aug 2026; 14 explanation-first tasks: KPI explainer, roll-rate heatmap, forecast narrative, reproducibility hardening) |
| 6 | `excel/` all levels (incl. VBA) | ✅ Done (Aug 2026; 17 tasks: openpyxl generator, Workbook_Open + one-button VBA pipeline, keep_vba flow, scheduler governance) |
| 7 | `git-cli/` + kpi_glossary additions + consistency sweep | ✅ Done (Aug 2026; 8 drills incl. conflict resolution/revert/stash/tag; glossary +2 sections: portfolio risk metrics, forecasting & capacity) |
