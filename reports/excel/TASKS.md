# Excel Multi-Account Coverage — Build Tutorial

A beginner-friendly, click-by-click guide to building four Excel reports from the
MIS-Collections database. Read `README.md` first for the data reality and limitations.

```
You are here: reports/excel/TASKS.md
Workbook:     reports/excel/work/multi_account_coverage.xlsx
Extracts:     reports/excel/data/*.csv
Solutions:    RESULTS.md (SQL, exact formulas, field wells, validation)
Rule:         the workbook must be built in Excel — openpyxl cannot create PivotTables or slicers
```

---

## How to use this guide

Work in order. Tasks 0–1 are setup, Tasks 2–5 each add one report, Tasks 6–7 polish and
refresh, Tasks 8–9 layer the Summary tab and PivotCharts on top of the verified reports.
Every task ends with a **Done when** checklist. If a step fails, read the
**Trap** note before moving on.

The four reports share one layout. Build Report 1 completely, then copy its sheet and swap
the data and controls for Reports 2–4. Do not rebuild from scratch four times.

---

## Before you start

- [ ] Docker Desktop is running and `docker ps` shows `postgres_collections`
- [ ] `http://localhost:8081` opens pgAdmin
- [ ] Excel 365 is installed (slicers do not exist in Excel Online)
- [ ] You can read `reports/excel/README.md` sections 4 and 6
- [ ] `reports/excel/data/` and `reports/excel/work/` exist

If the folders do not exist, create them now.

---

## Task 0 — Export the four extracts

📥 **Inbox:** From MIS Lead · Mon 8:00 · "give me the raw tables for the multi-account pack"

> "Four flat tables, one per report. Same grouping logic in all four: a client, the status
> or bucket they sit in, the week, how many accounts were expected, how many were covered,
> and the resulting tier. Keep the agent columns."

### 0.1 Connect pgAdmin to the database

1. Open `http://localhost:8081`.
2. Log in with `PGADMIN_DEFAULT_EMAIL` and `PGADMIN_DEFAULT_PASSWORD` from `.env`.
3. Right-click **Servers → Register → Server**.
4. **General → Name:** `MIS Collections`.
5. **Connection → Host:** `postgres` (the Docker service name, not `localhost`).
6. **Port:** `5432` (the container port; the host port `5433` is the mapping).
7. **Maintenance database:** `MIS_CollectionsDB`.
8. **Username / Password:** `POSTGRES_USER` / `POSTGRES_PASSWORD` from `.env`.
9. Save. Expand the server → Databases → `MIS_CollectionsDB` → Schemas → public → Tables.
   You should see `fact_interactions`, `fact_ptp_log`, `fact_payments`,
   `fact_eom_snapshot`, `dim_accounts`, `dim_employees`, `dim_calendar`.

> **Why host `postgres`?** pgAdmin runs inside the same Docker network as the database.
> `localhost:5433` is the port exposed to Windows; inside the network the database is
> reachable as `postgres:5432`.

### 0.2 Run the four queries

1. Open **Tools → Query Tool**.
2. Open `RESULTS.md` and copy **Query 1 — RPC coverage** (the full block).
3. Paste it into the Query Tool and press **F5**.
4. Wait for the row count to appear. Expected: **15,996 rows**.
5. Click the **Download as CSV** button in the result toolbar.
6. Save the file as `reports/excel/data/rpc.csv`.
7. Repeat for:
   - Query 2 (promise) → `promise.csv` — expected **47,988 rows**
   - Query 3 (payment) → `payment.csv` — expected **47,988 rows**
   - Query 4 (agent) → `agent.csv` — expected **4,141 rows**

> **Why these counts?** The RPC query returns 15,996 group-weeks (12,469 status + 3,527
> bucket). The promise and payment queries multiply that by their 3 status/flag values.
> The agent query returns one row per agent per week for agents with at least one
> multi-account touch (80 agents × 52 weeks minus idle weeks → 4,141).

### 0.3 Check the columns

Open each CSV in a text editor or Excel and confirm:

| File | Columns the pivot needs (the query returns more) |
|---|---|
| `rpc.csv` | `scope`, `week_label`, `tier`, `expected_accounts`, `covered_accounts`, `primary_agent_id`, `agent_name`, `team_name`, `region`, `product_type`, `product_mix` |
| `promise.csv` | the same **plus** `ptp_status` |
| `payment.csv` | the same **plus** `cure_flag`, `amount_paid` |
| `agent.csv` | `agent_name`, `team_name`, `region`, `scope`, `week_label`, `clients_touched`, `accounts_in_scope`, `accounts_covered`, `coverage_rate` |

> **Trap:** if a CSV has no header row, the PivotTable field names will be `Column1`,
> `Column2`, … Re-export with the header option enabled.

**Done when**
- [ ] Four CSVs exist in `reports/excel/data/`
- [ ] Row counts match 15,996 / 47,988 / 47,988 / 4,141
- [ ] `scope` contains exactly five values: `Status: Mora`, `Bucket: 1-30`,
      `Bucket: 31-60`, `Bucket: 61-90`, `Bucket: 90+`
- [ ] `tier` contains `Full`, `Partial`, `None`
- [ ] No CSV was created by editing the database (the queries are read-only `SELECT`s)

---

## Task 1 — Build the workbook shell

📥 **Inbox:** From MIS Lead · Mon 9:00 · "same layout on every tab"

> "One tab per report. Title, one-line definition, five KPI cards, the pivot below, the
> buttons on the right. I want to recognize the page without reading it."

### 1.1 Create the file and tabs

1. Open Excel → **Blank workbook**.
2. **File → Save As** → `reports/excel/work/multi_account_coverage.xlsx`
   (Excel Workbook `.xlsx`).
3. Create these sheets in order:
   `RPC`, `PTP`, `PAY`, `AGENT`, `Data_RPC`, `Data_PTP`, `Data_PAY`, `Data_AGENT`, `Notes`.
   (A tenth tab, `Summary`, is created later in Task 8 — only after the pivots it
   mirrors exist.)
4. Right-click each tab → **Tab Color**:
   - Report tabs: blue `#262A76`
   - Data tabs: grey
   - `Notes`: green

### 1.2 Set up a report sheet (do this once on `RPC`)

1. Select `RPC` → **View → uncheck Gridlines**.
2. **A1:** `Multi-Account RPC Coverage` — bold, 18 pt, dark blue.
3. **A2:** `Accounts in the selected status/bucket that received an RPC in the selected week. Coverage proxy — not documentation compliance.` — italic, 10 pt, grey.
4. Row 3: KPI labels in `B3:F3`:
   `Full %`, `Partial %`, `None %`, `Groups`, `Accounts`.
5. Row 4: leave blank for formulas (Task 2).
6. Select `A6` and freeze panes at `A6` (**View → Freeze Panes → Freeze Panes**).
7. Set column widths: A 22, B 28, C 14, D 14, E 12, F 14.

> **Why freeze at A6?** The pivot starts at A6. Freezing keeps the title and KPI cards
> visible while scrolling agents.

### 1.3 Write the definitions in `Notes`

Copy the "Shared calculation" block from `README.md` and the 12 limitations into the
`Notes` sheet. Every report sheet gets a one-line definition in A2; `Notes` holds the long
version.

> **Why?** A workbook without definitions becomes a rumour. Anyone opening the file must
> see that `covered` means "received an event", not "documented".

**Done when**
- [ ] Workbook saved in `work/`
- [ ] Nine tabs exist with the right colors
- [ ] `RPC` has title, definition, KPI labels, frozen header, gridlines off
- [ ] `Notes` contains the definitions and limitations

> **Note on automation:** `openpyxl` can write values, formats, and plain tables, but it
> **cannot create native PivotTables or slicers**. This workbook must be created and edited
> in Excel. Python is used only to produce the CSVs.

---

## Task 2 — Report 1: Multi-account RPC coverage

📥 **Inbox:** From Ops Manager · Tue 10:00 · "who is covering multi-account clients?"

> "For each client with more than one account in a bucket, show me whether all, some, or
> none of those accounts got a right-party contact this week. Give me the percentage and
> the counts, with buttons for bucket and week."

### 2.1 Load the data

1. Go to `Data_RPC`.
2. **Data → Get Data → From File → From Text/CSV**.
3. Select `reports/excel/data/rpc.csv` → **Import**.
4. In the preview, click **Load → Load To…**
5. Choose **Table**, **Existing worksheet**, select `Data_RPC!$A$1`, click **OK**.
6. Rename the table `tRPC` (**Table Design → Table Name**).
7. Confirm column types in the header row:
   - `week_label`, `scope`, `tier`, `agent_name`, `team_name`, `region`,
     `product_type`, `product_mix` → **Text**
   - `expected_accounts`, `covered_accounts` → **Whole Number**
   - `week_start`, `week_end` → **Date**

> **Why a Table?** PivotTables built on a Table auto-expand when the CSV refresh adds rows.
> A plain range does not.

### 2.2 Create the PivotTable

1. Click any cell in `tRPC`.
2. **Insert → PivotTable → From Table/Range**.
3. Choose **Existing Worksheet**, location `RPC!$A$6`, click **OK**.
4. In the PivotTable Fields pane, drag:
   - `team_name` → **Rows** (first)
   - `agent_name` → **Rows** (second, below team)
   - `tier` → **Columns**
   - `client_id` → **Values** (becomes *Count of client_id*)
   - `expected_accounts` → **Values** (becomes *Sum of expected_accounts*)
5. Double-click the value headers to rename:
   - `Count of client_id` → `Groups`
   - `Sum of expected_accounts` → `Accounts`
6. **PivotTable Design → Report Layout → Show in Tabular Form**.
7. **PivotTable Design → Subtotals → Show all Subtotals at Bottom of Group**.

The pivot's top-left cell lands on `RPC!$A$6` because that is where you placed it in step 3.

> **Why two value fields?** `Groups` is the count of client-week groups. `Accounts` is the
> number of accounts those groups represent. Percentages are meaningless without the raw
> counts beside them.

### 2.3 Add the slicers (the buttons)

1. Click the pivot → **PivotTable Analyze → Insert Slicer**.
2. Tick: `scope`, `week_label`, `team_name`, `region`, `product_type` → **OK**.
3. Arrange them to the right of the pivot, starting around **I3**.
4. For each slicer: **Slicer → Options → Buttons → Columns**:
   - `scope`: 1 column
   - `week_label`: 8 columns (it becomes a week button grid)
   - `team_name`, `region`, `product_type`: 1 column
5. Resize so `week_label` shows all 52 weeks without scrolling.

> **Why slicers instead of report filters?** Slicers are the clickable buttons the workplace
> report uses. They also stay visible, so the user always knows which filters are active.

### 2.4 Build the KPI cards

With the pivot at `A6`, type these formulas in row 4:

| Cell | Label in row 3 | Formula |
|---|---|---|
| `B4` | Full % | `=IFERROR(GETPIVOTDATA("client_id",$A$6,"tier","Full")/GETPIVOTDATA("client_id",$A$6),0)` |
| `C4` | Partial % | `=IFERROR(GETPIVOTDATA("client_id",$A$6,"tier","Partial")/GETPIVOTDATA("client_id",$A$6),0)` |
| `D4` | None % | `=IFERROR(GETPIVOTDATA("client_id",$A$6,"tier","None")/GETPIVOTDATA("client_id",$A$6),0)` |
| `E4` | Groups | `=GETPIVOTDATA("client_id",$A$6)` |
| `F4` | Accounts | `=GETPIVOTDATA("expected_accounts",$A$6)` |

Format `B4:D4` as **Percentage, 1 decimal**. Format `E4:F4` as **Number, thousands
separator**.

> **Why `GETPIVOTDATA`?** It reads the pivot's current, filtered state. A `COUNTIFS` formula
> would ignore the slicers and show the unfiltered total.

> **Trap:** if the pivot's top-left is not `A6`, every formula returns `#REF!`. Click the
> pivot's first cell and update `$A$6` in all five formulas.

### 2.5 Add the RAG colors

1. Select `B4` (Full %).
2. **Home → Conditional Formatting → New Rule → Format only cells that contain**.
3. Add three rules:
   - Cell value **greater than or equal to** `0.7` → green fill `#00B050`, white bold text
   - Cell value **between** `0.4` and `0.699` → amber fill `#FFC000`, black text
   - Cell value **less than** `0.4` → red fill `#FF0000`, white bold text
4. Copy `B4` and **Paste Special → Formats** onto `C4`.
5. For `D4` (None %), invert the meaning:
   - `<= 0.10` green
   - `0.101` to `0.30` amber
   - `> 0.30` red

> **Why invert None?** A high `Full %` is good; a high `None %` is bad. Same colors, opposite
> thresholds.

### 2.6 Sort the tiers

1. **File → Options → Advanced → General → Edit Custom Lists**.
2. **NEW LIST**, type `Full`, `Partial`, `None` (one per line), **Add**, **OK**.
3. Right-click a tier column header in the pivot → **Sort → More Sort Options**.
4. **Sort options → First key sort order → Full, Partial, None → OK**.

**Done when**
- [ ] `tRPC` is an Excel Table named `tRPC`
- [ ] Pivot at A6 with rows `team_name → agent_name`, columns `tier`, values `Groups` and `Accounts`
- [ ] Five slicers connected and arranged
- [ ] Five KPI cards recalculate when a slicer changes
- [ ] Tier columns sort `Full, Partial, None`
- [ ] RAG rules applied to Full % and None %

> **Trap:** if a slicer does not change the pivot, right-click the slicer →
> **Report Connections** → tick the pivot. A slicer only controls pivots it is connected to.

---

## Task 3 — Report 2: Multi-account promise coverage

📥 **Inbox:** From Ops Manager · Wed 9:30 · "same report, promises instead of calls"

> "Same layout. A client is covered if the account has a promise-to-pay that week. Add a
> button for promise status — I want to see kept, broken, and pending separately."

### 3.1 Load the promise extract

1. Go to `Data_PTP`.
2. Repeat **Task 2.1** with `reports/excel/data/promise.csv`, loading into
   `Data_PTP!$A$1`.
3. Name the table `tPTP`.

### 3.2 Reuse the layout

1. Right-click the `RPC` tab → **Move or Copy → Create a copy** → rename it `PTP`.
2. Delete the old PivotTable and all slicers on the copy (select → Delete).
3. Click inside `tPTP` → **Insert → PivotTable → From Table/Range → Existing
   Worksheet → `PTP!$A$6`**.
4. Rebuild the field wells exactly as Task 2.2 — columns stay `tier` only.
5. Re-add slicers: `scope`, `week_label`, `team_name`, `region`, `product_type`,
   **and `ptp_status`**.
6. Rebuild the KPI formulas (they are identical; the pivot reference may have moved).

> **Why `ptp_status` is a slicer, not a column:** a second column field splits every tier
> into three sub-columns and makes the KPI formulas ambiguous. As a slicer it filters the
> whole pivot, so the five KPI cards always describe one status at a time.

### 3.3 What changes and why

| Element | Report 1 | Report 2 |
|---|---|---|
| Event | `rpc_flag = TRUE` | a row in `fact_ptp_log` |
| Extra slicer | — | `ptp_status`: Kept / Broken / Pending |
| Meaning of `Full` | all the client's accounts got an RPC | all got a promise of that status |

> **Why `Pending` shows 100% None in some weeks:** `Pending` means the promise is not yet
> resolved. In a week with no pending promises, every group is correctly `None`. This is not
> a bug; it is the status filter doing its job.

**Done when**
- [ ] `tPTP` table loaded
- [ ] Pivot columns are `tier` only; `ptp_status` is a slicer
- [ ] Six slicers present
- [ ] KPI cards recalculate
- [ ] Selecting `Pending` on an early week shows `None = 100%` (expected; all Pending
      promises were made in Dec-2025 — see `RESULTS.md` 9.4)

---

## Task 4 — Report 3: Multi-account payment / cure coverage

📥 **Inbox:** From Finance · Wed 2:00 · "same report, money instead of promises"

> "A client is covered if the account had a payment that week. Add a button for cure type:
> agent cure, self cure, or a payment that did not cure. Keep the amount visible."

### 4.1 Load the payment extract

1. Go to `Data_PAY`.
2. Repeat **Task 2.1** with `reports/excel/data/payment.csv`, loading into
   `Data_PAY!$A$1`.
3. Name the table `tPAY`.

### 4.2 Reuse the layout

1. Copy the `RPC` sheet → rename `PAY`.
2. Delete the old pivot and slicers.
3. Click inside `tPAY` → **Insert → PivotTable → From Table/Range → Existing
   Worksheet → `PAY!$A$6`**. Build it with:
   - Rows: `team_name → agent_name`
   - Columns: `tier` only
   - Values: `client_id` (Count), `expected_accounts` (Sum), `amount_paid` (Sum)
4. Add slicers: `scope`, `week_label`, `team_name`, `region`, `product_type`, `cure_flag`.
5. Add a sixth KPI card: label `G3` = `Paid $`, value `G4` =
   `=GETPIVOTDATA("amount_paid",$A$6)`. Format `G4` as currency.

### 4.3 What changes and why

| Element | Report 3 |
|---|---|
| Event | a row in `fact_payments` |
| Extra slicer | `cure_flag`: `Agent_Cure`, `Self_Cure`, `No_Cure` |
| Extra measure | `Sum of amount_paid` |
| `No_Cure` | a payment that did **not** clear the delinquency |
| `Self_Cure` | a payment with **no agent** — appears as `Unassigned` |

> **Why `Self_Cure` is all `Unassigned`:** every self-cure payment has `agent_id IS NULL`
> (5,956 of 5,956). It is not missing data; it is a payment the client made without an
> agent. Filtering by team hides these rows — leave the team slicer clear when reviewing
> self-cures.

**Done when**
- [ ] `tPAY` table loaded
- [ ] Pivot columns are `tier` only; `cure_flag` is a slicer
- [ ] `amount_paid` appears in the values
- [ ] `Self_Cure` rows show `agent_name = Unassigned`
- [ ] Paid $ card recalculates

---

## Task 5 — Report 4: Agent multi-account handling

📥 **Inbox:** From Ops Manager · Thu 8:00 · "now per agent"

> "Same population, but I want to see, for each agent, how much of the multi-account
> clients they touched did they actually cover. A rate, not a tier — I know one client can
> be touched by several agents."

### 5.1 Load the agent extract

1. Go to `Data_AGENT`.
2. Repeat **Task 2.1** with `reports/excel/data/agent.csv`, loading into
   `Data_AGENT!$A$1`.
3. Name the table `tAGENT`.

### 5.2 Build the pivot

1. Click inside `tAGENT` → **Insert → PivotTable → From Table/Range → Existing
   Worksheet → `AGENT!$A$6`**.
2. Drag:
   - `team_name` → Rows
   - `agent_name` → Rows
   - `accounts_covered` → Values (Sum)
   - `accounts_in_scope` → Values (Sum)
   - `clients_touched` → Values (Sum, rename to `Touches`)
3. Add a calculated field:
   - **PivotTable Analyze → Fields, Items & Sets → Calculated Field**
   - Name: `Coverage Rate`
   - Formula: `=IF(accounts_in_scope=0,0,accounts_covered/accounts_in_scope)`
   - **Add**
4. Format `Coverage Rate` as **Percentage, 1 decimal**.
5. Add slicers: `week_label`, `team_name`, `region`.

### 5.3 KPI cards

| Cell | Label | Formula |
|---|---|---|
| `B4` | Coverage Rate | `=IFERROR(GETPIVOTDATA("accounts_covered",$A$6)/GETPIVOTDATA("accounts_in_scope",$A$6),0)` |
| `C4` | Client-touches | `=GETPIVOTDATA("clients_touched",$A$6)` |
| `D4` | Accounts Covered | `=GETPIVOTDATA("accounts_covered",$A$6)` |
| `E4` | Accounts In Scope | `=GETPIVOTDATA("accounts_in_scope",$A$6)` |

> **Why a rate instead of Full/Partial/None?** An agent almost never handles every account
> of a client: in Jan-2025 week 2, only 15 of 1,070 agent-client groups were "Full" (1.4%).
> A tier column would read as a near-constant and hide the differences. The rate shows how
> much of each touched client the agent covered.

> **Why `accounts_in_scope` can exceed the client count:** if two agents touch the same
> client, each agent's row counts that client's full expected accounts. The rates are
> per-agent views, not additive shares. Do not sum them across agents. The same applies
> across weeks: an account is counted once per week, so grand totals are week-account
> counts, not unique accounts.

**Done when**
- [ ] `tAGENT` table loaded
- [ ] Pivot shows team → agent with `Coverage Rate`
- [ ] Rate is between 0% and 100%
- [ ] Three slicers work
- [ ] `Notes` explains why Report 4 has no tier column

---

## Task 6 — Polish and protect the layout

1. Align all slicers to the same left edge; set equal heights.
2. Add a report-date cell on each sheet: `=TODAY()` formatted `yyyy-mm-dd`.
3. Add a **Clear Filters** note: each slicer has a funnel-with-red-X icon in its header.
4. Set print area: **Page Layout → Print Area → Set Print Area** (title + pivot).
5. **Page Layout → Width: 1 page**, **Height: Automatic**.
6. On `Notes`, add the validation table from Task 7.
7. Optional: protect report sheets (**Review → Protect Sheet**) after locking formula
   cells, so users cannot overwrite the KPI cards.

**Done when**
- [ ] Every report sheet prints on one page wide
- [ ] Report date appears on every sheet
- [ ] Slicers are aligned and readable
- [ ] `Notes` contains the validation table

---

## Task 7 — Refresh and validate

### 7.1 Refresh checklist

1. [ ] Database is running (`docker ps`).
2. [ ] Re-run each of the four queries in pgAdmin.
3. [ ] Download each result and **overwrite** the matching CSV in `data/` with the same
       filename.
4. [ ] In Excel: **Data → Refresh All**.
5. [ ] Confirm the row counts in each `Data_*` sheet (status bar `Count` or `COUNTA`).
6. [ ] Confirm the pivot totals still equal the KPI cards.
7. [ ] Save the workbook.

> **Why overwrite instead of rename?** The Excel Table is linked to the file path. A new
> filename breaks the link and forces a rebuild.

### 7.2 Validation table

Set `scope = Status: Mora` and `week_label = W02-2025`. The tier counts must match:

| Report | Control value | Full | Partial | None |
|---|---|---|---|---|
| RPC | (none) | 70 | 216 | 133 |
| PTP | `Kept` | 19 | 134 | 266 |
| PTP | `Broken` | 13 | 155 | 251 |
| PTP | `Pending` | 0 | 0 | 419 |
| PAY | `Agent_Cure` | 0 | 4 | 415 |
| PAY | `Self_Cure` | 0 | 0 | 419 |
| PAY | `No_Cure` | 28 | 158 | 233 |

Each row sums to **419** groups. If your numbers differ, check that the slicers are exactly
`Status: Mora` and `W02-2025`, and that no team/region/product filter is active.

### 7.3 Structural checks

- [ ] `covered_accounts` is never greater than `expected_accounts`
- [ ] `scope` has exactly five values
- [ ] `week_label` has exactly 52 values (`W01-2025` → `W52-2025`)
- [ ] `tier` has exactly three values
- [ ] Every `Self_Cure` row has `agent_name = Unassigned`
- [ ] Report 4 `coverage_rate` is between 0 and 1
- [ ] No formula returns `#REF!` or `#DIV/0!`

**Done when**
- [ ] All validation rows match
- [ ] All structural checks pass
- [ ] Workbook saved and reopened without errors

---

## Task 8 — Summary dashboard tab

📥 **Inbox:** From MIS Lead · Thu 9:00 · "one screen across the four reports"

> "I don't want to click four tabs every morning. Give me one Summary page that shows the
> headline numbers of all four reports side by side, and updates when we filter the
> reports."

The Summary **reads** the four report tabs — it owns no filters of its own. Each report
pivot sits on a different Excel Table (`tRPC`, `tPTP`, `tPAY`, `tAGENT`), so each has its
own slicer cache: one slicer cannot drive four pivots across four tables. Be honest about
that on the sheet — filter on the report tabs, view here.

### 8.1 Create the tab

1. New sheet → name `Summary` → tab color blue `#262A76` → move it to the **leftmost**
   position.
2. **View → uncheck Gridlines**.
3. **A1:** `Multi-Account Coverage — Summary` — bold, 18 pt, dark blue.
4. **A2:** `One screen across the four reports. The cards below mirror each report tab at
   its current slicer state. Filter on RPC / PTP / PAY / AGENT — this tab has no buttons.`
   — italic, 10 pt, grey.
5. **H1:** `=TODAY()` formatted `yyyy-mm-dd` (report date, same convention as Task 6.2).
6. Column widths: A 22, B 28, C–H 14.

### 8.2 Mirror the KPI cards

Type the labels one row above each block, then the plain cross-sheet formulas. The
formula inherits the card's own `IFERROR`: a filtered-out state shows `0`, never `#REF!`.

| Labels | Value cells | Formulas |
|---|---|---|
| `B3:F3` — `Full %`, `Partial %`, `None %`, `Groups`, `Accounts` | `B4:F4` | `=RPC!B4` … `=RPC!F4` |
| `B6:F6` — same five labels | `B7:F7` | `=PTP!B4` … `=PTP!F4` |
| `B9:G9` — same five **plus** `Paid $` | `B10:G10` | `=PAY!B4` … `=PAY!G4` |
| `B12:E12` — `Coverage Rate`, `Client-touches`, `Accounts Covered`, `Accounts In Scope` | `B13:E13` | `=AGENT!B4` … `=AGENT!E4` |

Then carry the formatting over — the RAG colors travel with it:

1. Select `RPC!B3:F4` → Copy → select `Summary!B3:F4` → **Paste Special → Formats**.
2. Repeat: `PTP!B3:F4` → `B6:F7`, `PAY!B3:G4` → `B9:G10`, `AGENT!B3:E4` → `B12:E13`.
3. **B8** note (9 pt, grey): `PTP row reflects the ptp_status selected on the PTP tab.`

> **Why plain mirrors instead of `GETPIVOTDATA` everywhere?** `=RPC!B4` points at a card
> that already rounds, guards itself with `IFERROR`, and colors itself. Rebuilding all of
> that with `GETPIVOTDATA` would double the maintenance for no extra meaning —
> `GETPIVOTDATA` keeps exactly one job on this tab, in the table below.

### 8.3 Build the cross-report tier table

The Summary's real dashboard piece: the three "did the client's accounts get the event"
reports side by side, **each at its own current filter state**.

1. Row 15 headers: `B15` `Tier`, `C15` `RPC`, `D15` `PTP`, `E15` `PAY` — bold.
2. Column A, rows 16–18: `Full`, `Partial`, `None`. Formulas:

| Cell | Formula |
|---|---|
| `C16` | `=IFERROR(GETPIVOTDATA("client_id",RPC!$A$6,"tier","Full"),0)` |
| `C17` / `C18` | same with `"Partial"` / `"None"` |
| `D16:D18` | the same three, source `PTP!$A$6` |
| `E16:E18` | the same three, source `PAY!$A$6` |

3. Row 19: `B19` `Groups`; `C19` `=SUM(C16:C18)`, `D19` `=SUM(D16:D18)`,
   `E19` `=SUM(E16:E18)` — bold.
4. Format `C16:E19` as **Number, thousands separator**.
5. **B21** note (9 pt, grey): `Rows are comparable only while scope + week match across
   RPC / PTP / PAY. ptp_status / cure_flag choose which event flavor is counted — Groups
   stays 419 either way.`
6. **View → Freeze Panes** at `A3` (title and report date stay visible).
7. **Page Layout → Print Area → Set Print Area** over `A1:H21`.

> **Trap:** `GETPIVOTDATA` arguments go field name first, filter pairs after:
> `("client_id",$A$6,"tier","Full")`. A transposed pair returns `#REF!`.

### 8.4 Done when

- [ ] `Summary` is leftmost, blue, gridlines off
- [ ] Changing a slicer on `RPC` moves both the Summary RPC block and its tier column
- [ ] PTP note and comparability note present
- [ ] Report date shows today
- [ ] Print area set; no `#REF!` anywhere on the sheet

Run the control check — same numbers as Task 7.2, read through the mirrors:

1. On `RPC`: `scope = Status: Mora`, `week_label = W02-2025`, no other filter.
2. On `PTP`: also `ptp_status = Kept`. On `PAY`: also `cure_flag = No_Cure`.
   On `AGENT`: `week_label = W02-2025` only (no scope/flag control exists).
3. On `Summary`, expect:

| Check | Expected |
|---|---|
| RPC tier column | 70 / 216 / 133 |
| PTP tier column (`Kept`) | 19 / 134 / 266 |
| PAY tier column (`No_Cure`) | 28 / 158 / 233 |
| `Groups` row (`C19:E19`) | 419 in all three columns |
| `AGENT` mirror `Client-touches` | 1,070 (agent-client groups, `RESULTS.md` §9.5) |
| `AGENT` mirror `Coverage Rate` | between 0% and 100% |

> If the `AGENT` tab is left unfiltered, its mirrors span the whole year (all 4,141
> agent-week rows) — select the week there first.

---

## Task 9 — PivotCharts

📥 **Inbox:** From MIS Lead · Thu 10:00 · "add the charts for the meeting"

> "Same report tabs, with a week trend at the bottom of each and a team bar for agents.
> Excel charts, not screenshots — they have to move when I press the buttons."

Each chart is a **PivotChart** fed by a small **helper pivot** built on the same Excel
Table as the report's pivot. Same Table → same cache → the tab's existing slicers can be
reconnected to the helper through **Report Connections**, and one set of buttons drives
the report and its chart.

> **Placement:** helper pivots start at **`A110`** — below the report pivot's unfiltered
> height (~95 rows: 80 agents + 8 team subtotal rows + grand total). The charts float to
> their right around **`H110`**. If a pivot grows taller, push helpers and charts further
> down; if a chart overlaps it, drag — charts float over cells.

### 9.1 RPC — coverage mix by week

1. Click inside `tRPC` → **Insert → PivotTable → Existing Worksheet → `RPC!$A$110`**.
2. Field wells: `week_label` → Rows, `tier` → Columns, `client_id` → Values (Count).
3. **PivotTable Design → Report Layout → Show in Tabular Form**, then
   **Subtotals → Do Not Show**.
4. Click the helper pivot → **PivotTable Analyze → PivotChart → 100% Stacked Column**.
5. Drag the chart to about `H110:M132` — clear of the helper pivot, the slicers, and the
   main pivot's column range.
6. Select each existing slicer → **Slicer** tab → **Report Connections** → tick the
   helper pivot **as well as** the main pivot. Do this for all five slicers.
7. Colors: click the chart's `Full` series → shape fill `#00B050`; `Partial` →
   `#FFC000`; `None` → `#FF0000`.

### 9.2 PTP — coverage mix by week

Same as 9.1 on `PTP!$A$110` with `tPTP` — and connect **all six** slicers (including
`ptp_status`) to the helper.

### 9.3 PAY — coverage mix by week + Paid $ by week

1. Coverage mix: same as 9.1 on `PAY!$A$110` with `tPAY`; connect all six slicers.
2. Paid $ trend: second helper at **`PAY!$A$175`** (the mix helper is ~52 week rows
   tall) — `week_label` → Rows, `amount_paid` → Values (Sum). **No Columns field.**
3. **PivotChart → Clustered Column**; float it at about `H175:M198`, right of its helper.
4. Connect all six slicers to **both** helpers.

### 9.4 AGENT — coverage rate by team

1. Click inside `tAGENT` → **Insert → PivotTable → Existing Worksheet → `AGENT!$A$110`**.
2. Field wells: `team_name` → Rows (**team only** — team × agent bars with 80 agents are
   unreadable), `accounts_covered` → Values (Sum), `accounts_in_scope` → Values (Sum).
3. Add **`Coverage Rate`** to Values. The calculated field already belongs to this cache
   (built in Task 5) — do not redefine it, just tick it.
4. **PivotChart → Clustered Bar.** On the chart, open the field buttons (top-right) and
   untick `Sum of accounts_covered` and `Sum of accounts_in_scope` — the chart then draws
   only `Coverage Rate`. All three fields would be three bars of wildly different scales.
5. Bar color: `#262A76` (theme blue).
6. Sort the helper: right-click a team row → **Sort → More Sort Options → Descending →
   `Coverage Rate`**.
7. Connect `week_label`, `team_name`, `region` to the helper.
8. Float the chart at about `H110:M130`.

### 9.5 Print and polish

1. The report print areas (title + pivot, Task 6.4) do **not** change — helpers and
   charts are for the screen. Print preview must still show one page wide.
2. `Data → Refresh All` keeps Report Connections intact. Deleting and rebuilding a
   helper pivot drops them — re-tick after any rebuild.

**Done when**
- [ ] Five PivotCharts exist (mix × 3, Paid $ trend, team rate bar)
- [ ] Every chart moves when its tab's slicers change
- [ ] Tier series are green / amber / red; the two single-series charts are blue
- [ ] Helper pivots sit below the report pivots, outside the print areas
- [ ] AGENT chart shows one bar per team, sorted by rate descending

> **Why a helper pivot instead of charting the report pivot directly?** The report pivot
> is team → agent rows against tier columns; charting it draws 80 stacked triplets. The
> helper holds a small week × tier (or team × values) shape that renders cleanly, while
> the shared cache keeps the buttons alive.

---

## Traps

| Symptom | Cause | Fix |
|---|---|---|
| KPI cards show `#REF!` | Pivot moved; `$A$6` is wrong | Update the reference in all formulas |
| Slicer does nothing | Not connected to the pivot | Right-click slicer → Report Connections |
| `GETPIVOTDATA` returns `#REF!` | Field name mismatch | Use exact names: `client_id`, `expected_accounts`, `amount_paid` |
| Percentages over 100% | `covered_accounts` joined to the wrong grain | Re-run the query; do not edit the CSV |
| Team filter hides `None` | `None` rows are `Unassigned` | Clear the team slicer when reviewing `None` |
| Pivot does not see new rows | Pivot built on a range, not a Table | Rebuild from the Table |
| `week_label` sorts across years | Text sort on `W##-YYYY` is chronological only when zero-padded with one ISO year (this extract: all 2025) | If a future extract spans ISO years, sort Rows by `week_start` instead |
| CSV opens with one column | Wrong delimiter | Import as comma-delimited in Get Data |
| `Pending` is all `None` | No pending promises that week | Expected behaviour |
| Self-cures are `Unassigned` | `agent_id IS NULL` by design | Expected behaviour |
| Summary card shows `0` | The report tab's current filter has no rows (e.g., `Pending` on an early week); the card's `IFERROR` masks it | Check the report tab, not the Summary |
| Summary tier cell `#REF!` | Tier absent from that pivot's current state, or `tier` dropped from Columns, or filter pair written in the wrong order | Keep `tier` in Columns; field name first, then filters |
| Chart ignores a slicer | Helper pivot not ticked in Report Connections | Slicer → Report Connections → tick the helper |
| AGENT chart draws three bars per team | The two Sum series are still ticked on the chart | Chart field buttons → untick `Sum of accounts_covered` / `Sum of accounts_in_scope` |
| Slicer can't drive another tab's pivot | Slicers are cache-specific; a `tRPC` slicer never controls `tPTP` pivots | Each tab owns its buttons; the `Summary` reads, it does not filter |
| Helper pivot overlaps the slicers or the chart float | Placed above the report pivot's full height | Helpers start at `A110` / `A175`, below the unfiltered pivot; push lower if it grows |

---

## What to hand over

- `work/multi_account_coverage.xlsx` — the workbook (reports, `Summary` tab from Task 8, PivotCharts from Task 9)
- `data/*.csv` — the four extracts (regenerate on refresh)
- `Notes` sheet — definitions and limitations
- This guide and `RESULTS.md` — so the next person can rebuild it
