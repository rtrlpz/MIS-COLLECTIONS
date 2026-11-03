# Excel Reports — Multi-Account Coverage Pack

Four Excel reports built from the MIS-Collections PostgreSQL database. They copy the
**layout** of a workplace report (status buttons, week buttons, a percentage next to raw
counts) and adapt the **metric** to what this dataset actually measures.

> **Read this first.** These reports measure **coverage**: whether an account received an
> RPC, a promise, or a payment in a given week. They do **not** measure whether an agent
> documented a client's accounts. The dataset has no documentation/notes field, no
> account-ownership table, and no call-level grouping across accounts. Label the output
> "covered", never "documented".

---

## 1. What the workplace report does vs what this dataset can do

| Workplace report element | Closest equivalent here | Status |
|---|---|---|
| Accounts under a status `f01` / `f02` / `f03` | `fact_eom_snapshot.dpd_bucket`: `1-30`, `31-60`, `61-90`, `90+` (plus `Current`) | **Partial** — 5 buckets, not a status-code catalogue |
| Status buttons | Excel slicer on `scope` (`Bucket: 31-60`, `Status: Mora`, …) | **Supported** (in an Excel-built template) |
| Week buttons | Excel slicer on `week_label` (`W02-2025`) | **Supported** |
| % + actual values | `tier` share + `client_id` count + `expected_accounts` sum | **Supported** |
| Agent who spoke to the client | `fact_interactions.agent_id` where `rpc_flag = TRUE` | **Supported** |
| "Documented all / some / none of the client's accounts" | "All / some / none of the client's accounts received the event this week" | **Proxy only** |
| One conversation covering several accounts | No `call_id` or client-level call grouping | **Not available** |
| Account ownership (agent assigned to account) | No assignment table; `dim_accounts` has no `agent_id` | **Not available** |

The four reports are therefore **coverage reports**, not documentation-compliance reports.
That distinction is repeated at the top of every report sheet.

---

## 2. Folder map

```
reports/excel/
├── README.md          <- this file
├── TASKS.md           <- step-by-step build tutorial
├── RESULTS.md         <- worked solutions: SQL, field wells, formulas, validation
├── .gitignore         <- keeps extracts and the workbook out of git
├── data/              <- exported CSVs (gitignored)
└── work/              <- the Excel workbook (gitignored)
```

The workbook lives in `work/`. The extracts live in `data/`. Neither is committed.
`TASKS.md` and `RESULTS.md` are tracked.

---

## 3. Prerequisites

| Requirement | Why | Check |
|---|---|---|
| Docker Desktop + the project DB running | The extracts come from PostgreSQL | `docker ps` shows `postgres_collections` |
| pgAdmin at `http://localhost:8081` | Run the extraction queries and download CSVs | Port is `PGADMIN_PORT` in `.env` (8081); login uses `PGADMIN_DEFAULT_EMAIL` / `PGADMIN_DEFAULT_PASSWORD` |
| Excel 365 (Windows or Mac) | Native PivotTables, slicers, Get Data | Slicers are **not** available in Excel Online |
| Project `.env` | DB credentials | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `POSTGRES_PORT` |
| Optional: conda env `mis-collections` | Run the validation queries from a terminal | `conda run -n mis-collections python -c "import psycopg2"` |

pgAdmin connects to the database with **host `postgres`** (the Docker service name) and
**port `5432`** (the container port), not `localhost:5433` — that port is the host mapping.

---

## 4. Verified data facts

Every number below was checked against the loaded database, not taken from a design note.

| Fact | Value | Evidence |
|---|---|---|
| Clients / accounts | 10,000 clients, 15,480 accounts | `dim_clients`, `dim_accounts` |
| Accounts per client | 5,491 clients with 1; 3,538 with 2; 971 with 3 (max 3) | `dim_accounts.client_id` |
| Month-end snapshots | 12, `2025-01-31` → `2025-12-31`; **no Dec-2024 snapshot** | `fact_eom_snapshot.snapshot_date` |
| Snapshot status values | `Activo`, `Mora` only. `WrittenOff` is allowed by the CHECK but never appears (written-off accounts exit the book) | `fact_eom_snapshot.status` |
| Bucket values | `Current`, `1-30`, `31-60`, `61-90`, `90+` | `dim_delinquency_bucket` |
| Jan-2025 Mora book | 3,942 accounts, 3,504 clients, **419 clients with 2+ Mora accounts**, 116 client-bucket groups | `fact_eom_snapshot` + `dim_accounts` |
| Full-year Mora multi-account groups | 2,859 client-months (status grain), 812 client-months (bucket grain) | same |
| RPC | `fact_interactions.rpc_flag = TRUE` — a right-party contact, not a documentation event | `fact_interactions` |
| Interaction grain | One row per **account** per interaction; no `call_id`, no `client_id` | `fact_interactions` columns |
| PTP status values | `Kept`, `Broken`, `Pending` | `fact_ptp_log.status` |
| Payment cure flags | `Agent_Cure`, `Self_Cure`, or NULL (payment did not cure) | `fact_payments.cure_flag` |
| Self-cure attribution | 5,956 `Self_Cure` payments and 5,956 payments with `agent_id IS NULL` — every self-cure has no agent | `fact_payments` |
| Agents / teams / regions | 80 agents, 8 teams, 4 regions | `dim_employees` |
| Weeks in the report | 52 (`W01-2025` → `W52-2025`) | `dim_calendar` via the `weeks` CTE (`RESULTS.md` §1) |

---

## 5. The four reports at a glance

| # | Report | Event that counts as "covered" | Status control | Extra control |
|---|---|---|---|---|
| 1 | Multi-account RPC coverage | `fact_interactions.rpc_flag = TRUE` | `scope` (status / bucket) | — |
| 2 | Multi-account promise coverage | a row in `fact_ptp_log` | `scope` | `ptp_status` = Kept / Broken / Pending |
| 3 | Multi-account payment / cure coverage | a row in `fact_payments` | `scope` | `cure_flag` = Agent_Cure / Self_Cure / No_Cure |
| 4 | Agent multi-account handling | same event as Report 1, aggregated per agent | `scope` | — (coverage rate, not tiers) |

**Shared layout:** title + definition line + KPI cards (`% Full`, `% Partial`, `% None`,
groups, accounts) + PivotTable + slicers on the right.

**Dashboard top:** a `Summary` tab (Task 8 in `TASKS.md`) mirrors all four reports at
their current filter state plus a cross-report tier table, and each report tab carries
one or two PivotCharts (Task 9). Both are Excel-UI objects — `openpyxl` cannot create
them (see `RESULTS.md` §12–§14).

**Shared calculation:**

```
group          = one client × one scope (status or bucket) × one ISO week
expected       = how many of that client's accounts sit in that scope that month
covered        = how many of those accounts received the event that week
tier           = Full (covered = expected) / Partial (0 < covered < expected) / None (0)
```

**What differs:** the event table, the status control, and (for Report 4) the measure.

---

## 6. Limitations that affect interpretation

1. **No documentation field.** `fact_interactions` does record each call's result in
   `call_outcome` (`RPC`, `Voicemail`, `Third_Party`, `No_Answer`, `Wrong_Number`,
   `Message_w_Relative`, `Busy`; `rpc_flag = TRUE` is exactly `call_outcome = 'RPC'`,
   verified row for row). But there is no notes field and nothing that records whether an
   agent documented a client's accounts — the outcome is a call result, not account
   documentation. The reports use event coverage as a proxy.
2. **No account ownership.** `dim_accounts` has no `agent_id`, and there is no assignment
   table. "This agent failed to cover the rest of the client's accounts" cannot be proven;
   only "this agent covered X of the client's Y accounts" can.
3. **No call-level grouping.** Interactions are per account. Two accounts of the same
   client touched by the same agent on the same day are not linked by a call ID. Do not
   claim they were handled in one conversation.
4. **Month-end population.** `fact_eom_snapshot` is monthly. A weekly filter slices events
   against that month's book, so the denominator is static within a month. The book is
   assigned by the ISO week's **Thursday** (see `RESULTS.md` section 10).
5. **Only two statuses in the book.** `Activo` and `Mora`; `WrittenOff` accounts exit the
   snapshot. The status button is therefore less rich than the workplace `f01/f02/f03`
   catalogue — the buckets carry most of the segmentation.
6. **Agent attribution is a heuristic.** The primary agent is the one who touched the most
   distinct accounts of that client in that week (ties broken by latest event). In
   Jan-2025 week 2, 235 of the 286 multi-account clients with an RPC were touched by more
   than one agent (82%). Treat the agent column as "main toucher", not "owner".
7. **`None` cannot be assigned to an agent.** With no ownership table, a client with zero
   events has no agent. Those rows appear as `Unassigned`. Filtering a team slicer hides
   `None` rows, because `Unassigned` is not on any team.
8. **Self-cures have no agent.** All `Self_Cure` payments have `agent_id IS NULL`. They
   appear as `Unassigned` on purpose; do not read that as missing data.
9. **`Pending` promises are unresolved.** `Pending` rows exist in `fact_ptp_log` (1,393
   full-year). In a week with no pending promises, the Pending view correctly shows 100%
   `None`.
10. **Thin multi-account population.** Only 419 of 3,504 Mora clients in Jan-2025 had 2+
    Mora accounts (12%). Per-bucket groups are thinner (116). Expect small weekly counts.
11. **Product filter uses the first product alphabetically.** A client with accounts in
    several products gets one `product_type` (`Hipoteca` before `Prestamo` before
    `Tarjeta`) plus a `product_mix` string.
    Filtering by `product_type` can hide the other accounts; use `product_mix` to see them.
12. **Last three days of 2025 drop out.** `2025-12-29` → `2025-12-31` belong to ISO week 1
    of 2026, whose month (Jan-2026) has no snapshot. The report ends at `W52-2025`.

---

## 7. Source notes and how they were treated

Two design notes were supplied with this task:

1. The **workplace report description** — accounts under statuses `f01/f02/f03`, status
   buttons, week buttons, percentages plus actual values, documenting all/some/none of a
   client's accounts.
2. The **four-report proposal** — multi-account RPC coverage, promise coverage,
   payment/cure coverage, and agent multi-account handling.

Both are **design proposals, not repository facts**. Every table, column, status value,
row count, and metric in this guide was verified against the repository and the live
database. Where a proposal depends on a field that does not exist, the guide says so and
offers a data-supported alternative.

---

## 8. Quick start

1. Start the database: `docker compose --env-file .env -f database/docker-compose.yml up -d`.
2. Follow **`TASKS.md` Task 0** to run four queries in pgAdmin and export four CSVs into
   `data/`.
3. Follow **Tasks 1–6** to build the workbook in `work/`.
4. Follow **Task 7** to refresh and validate.
5. Follow **Tasks 8–9** to add the `Summary` tab and the PivotCharts.
6. Keep `TASKS.md` and `RESULTS.md`; do not commit `data/` or `work/`.

## 9. Refresh model

The workbook is **separate from the data-generation process**:

- The database is read-only from Excel's point of view. No query creates tables, views, or
  functions.
- Each CSV is a point-in-time extract. Overwrite it with a fresh export, then click
  **Data → Refresh All** in Excel.
- PivotTables are built on Excel Tables, so new rows are picked up automatically. Slicers,
  formulas, and formatting persist.
- Never rename a table or a column in `data/` — PivotTables and slicers reference those
  names.

---

## 10. Related documentation

| Doc | Use |
|---|---|
| `docs/data_dictionary.md` | Column-level reference for every table |
| `docs/KPI_VIEWS.md` | Existing KPI views and their definitions |
| `docs/kpi_definitions.md` | Metric definitions (note: it uses pre-v7 table names such as `dialer_interactions`; trust the live schema instead) |
| `learning/excel/basic/` | Excel fundamentals: workbook anatomy, lookups, pivots, validation, openpyxl |
| `learning/excel/medium/` | PivotTables, RAG formatting, refresh workflow, openpyxl shell automation |
