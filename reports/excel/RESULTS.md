# Excel Multi-Account Coverage — Worked Solutions

Complete, executable answers for `TASKS.md`. Every query here was run against the loaded
database. Run them in pgAdmin's Query Tool (or any PostgreSQL 15 client) and export the
result as CSV.

> **Read the caveat first.** These reports measure **coverage** — whether an account
> received an RPC, a promise, or a payment in a week. The schema has no documentation
> field, no account-ownership table, and no call-level grouping. Do not rename a column to
> "documented". See `README.md` section 6.

```
reports/excel/RESULTS.md
Queries: 4 read-only SELECTs (no CREATE, no INSERT, no views)
Outputs: rpc.csv, promise.csv, payment.csv, agent.csv
```

---

## 0. The shared idea

Every query starts from the same two blocks:

1. **The book** — `fact_eom_snapshot` for one month, `status = 'Mora'`, joined to
   `dim_accounts` for `client_id` and `product_type`.
2. **The multi-account filter** — keep clients that have at least **2** accounts in the same
   scope (status, or bucket) in that month.

Then it attaches weekly events (interactions, promises, or payments) to those accounts and
counts how many distinct accounts per client were covered in each ISO week.

| Term | Meaning in these queries |
|---|---|
| `book_month` | The month containing the ISO week's **Thursday** |
| `expected_accounts` | The client's accounts in that scope that month |
| `covered_accounts` | How many of those accounts had the event that week |
| `tier` | `Full` (all), `Partial` (some), `None` (zero) |
| `scope` | `Status: Mora` or `Bucket: 1-30` / `31-60` / `61-90` / `90+` |

---

## 1. Query 1 — Multi-account RPC coverage

**Event:** `fact_interactions.rpc_flag = TRUE`
**Output:** `rpc.csv` — **15,996 rows**

```sql
WITH book AS (
    SELECT s.snapshot_date,
           DATE_TRUNC('month', s.snapshot_date)::date AS book_month,
           s.account_id,
           a.client_id,
           a.product_type,
           s.dpd_bucket
    FROM fact_eom_snapshot s
    JOIN dim_accounts a ON a.account_id = s.account_id
    WHERE s.status = 'Mora'
),
book_multi AS (
    SELECT b.*,
           COUNT(*) OVER (PARTITION BY b.book_month, b.client_id, b.dpd_bucket) AS expected_bucket,
           COUNT(*) OVER (PARTITION BY b.book_month, b.client_id) AS expected_status
    FROM book b
),
groups AS (
    SELECT 'Status'::text AS group_type, 'Mora'::text AS group_value,
           book_month, client_id, account_id, product_type,
           expected_status AS expected_accounts
    FROM book_multi WHERE expected_status >= 2
    UNION ALL
    SELECT 'Bucket'::text, dpd_bucket::text,
           book_month, client_id, account_id, product_type,
           expected_bucket
    FROM book_multi WHERE expected_bucket >= 2
),
multi AS (
    SELECT group_type, group_value, book_month, client_id,
           MAX(expected_accounts) AS expected_accounts,
           MIN(product_type) AS product_type,
           STRING_AGG(DISTINCT product_type, '|' ORDER BY product_type) AS product_mix
    FROM groups
    GROUP BY 1, 2, 3, 4
),
weeks AS (
    SELECT DISTINCT
           DATE_TRUNC('month', (DATE_TRUNC('week', date) + INTERVAL '3 days')::date)::date AS book_month,
           EXTRACT(isoyear FROM date)::int AS iso_year,
           EXTRACT(week FROM date)::int AS iso_week,
           DATE_TRUNC('week', date)::date AS week_start,
           (DATE_TRUNC('week', date) + INTERVAL '6 days')::date AS week_end
    FROM dim_calendar
),
group_week AS (
    SELECT m.group_type, m.group_value, m.book_month, m.client_id,
           m.expected_accounts, m.product_type, m.product_mix,
           w.iso_year, w.iso_week, w.week_start, w.week_end
    FROM multi m
    JOIN weeks w ON w.book_month = m.book_month
),
events AS (
    SELECT g.group_type, g.group_value, g.book_month, g.client_id, g.account_id,
           i.agent_id, i.interaction_date
    FROM fact_interactions i
    JOIN groups g
      ON g.account_id = i.account_id
     AND g.book_month = DATE_TRUNC('month', (DATE_TRUNC('week', i.interaction_date) + INTERVAL '3 days')::date)::date
    WHERE i.rpc_flag
),
covered AS (
    SELECT group_type, group_value, book_month, client_id,
           EXTRACT(isoyear FROM interaction_date)::int AS iso_year,
           EXTRACT(week FROM interaction_date)::int AS iso_week,
           COUNT(DISTINCT account_id) AS covered_accounts
    FROM events
    GROUP BY 1, 2, 3, 4, 5, 6
),
agent_counts AS (
    SELECT group_type, group_value, book_month, client_id,
           EXTRACT(isoyear FROM interaction_date)::int AS iso_year,
           EXTRACT(week FROM interaction_date)::int AS iso_week,
           agent_id,
           COUNT(DISTINCT account_id) AS accounts_touched,
           MAX(interaction_date) AS last_event
    FROM events
    GROUP BY 1, 2, 3, 4, 5, 6, 7
),
primary_agent AS (
    SELECT group_type, group_value, book_month, client_id, iso_year, iso_week,
           (ARRAY_AGG(agent_id ORDER BY accounts_touched DESC, last_event DESC))[1] AS agent_id
    FROM agent_counts
    GROUP BY 1, 2, 3, 4, 5, 6
)
SELECT gw.group_type,
       gw.group_type || ': ' || gw.group_value AS scope,
       gw.group_value,
       gw.book_month,
       gw.iso_year,
       gw.iso_week,
       'W' || LPAD(gw.iso_week::text, 2, '0') || '-' || gw.iso_year::text AS week_label,
       gw.week_start,
       gw.week_end,
       gw.client_id,
       gw.expected_accounts,
       COALESCE(c.covered_accounts, 0) AS covered_accounts,
       CASE WHEN COALESCE(c.covered_accounts, 0) >= gw.expected_accounts THEN 'Full'
            WHEN COALESCE(c.covered_accounts, 0) > 0 THEN 'Partial'
            ELSE 'None' END AS tier,
       pa.agent_id AS primary_agent_id,
       COALESCE(e.agent_name, 'Unassigned') AS agent_name,
       COALESCE(e.team_name, 'Unassigned') AS team_name,
       COALESCE(e.region, 'Unassigned') AS region,
       gw.product_type,
       gw.product_mix
FROM group_week gw
LEFT JOIN covered c
  ON c.group_type = gw.group_type AND c.group_value = gw.group_value
 AND c.book_month = gw.book_month AND c.client_id = gw.client_id
 AND c.iso_year = gw.iso_year AND c.iso_week = gw.iso_week
LEFT JOIN primary_agent pa
  ON pa.group_type = gw.group_type AND pa.group_value = gw.group_value
 AND pa.book_month = gw.book_month AND pa.client_id = gw.client_id
 AND pa.iso_year = gw.iso_year AND pa.iso_week = gw.iso_week
LEFT JOIN dim_employees e ON e.agent_id = pa.agent_id
ORDER BY gw.book_month, gw.group_type, gw.group_value, gw.iso_year, gw.iso_week, e.team_name, gw.client_id;
```

**Row split:** 12,469 `Status: Mora` + 3,527 bucket rows (193 + 1,436 + 1,094 + 804).
Distinct clients in the `Status: Mora` scope across the year: 1,734.

---

## 2. Query 2 — Multi-account promise coverage

**Event:** a row in `fact_ptp_log`, split by `status`
**Output:** `promise.csv` — **47,988 rows** (15,996 groups × 3 statuses)

```sql
WITH book AS (
    SELECT s.snapshot_date,
           DATE_TRUNC('month', s.snapshot_date)::date AS book_month,
           s.account_id,
           a.client_id,
           a.product_type,
           s.dpd_bucket
    FROM fact_eom_snapshot s
    JOIN dim_accounts a ON a.account_id = s.account_id
    WHERE s.status = 'Mora'
),
book_multi AS (
    SELECT b.*,
           COUNT(*) OVER (PARTITION BY b.book_month, b.client_id, b.dpd_bucket) AS expected_bucket,
           COUNT(*) OVER (PARTITION BY b.book_month, b.client_id) AS expected_status
    FROM book b
),
groups AS (
    SELECT 'Status'::text AS group_type, 'Mora'::text AS group_value,
           book_month, client_id, account_id, product_type,
           expected_status AS expected_accounts
    FROM book_multi WHERE expected_status >= 2
    UNION ALL
    SELECT 'Bucket'::text, dpd_bucket::text,
           book_month, client_id, account_id, product_type,
           expected_bucket
    FROM book_multi WHERE expected_bucket >= 2
),
multi AS (
    SELECT group_type, group_value, book_month, client_id,
           MAX(expected_accounts) AS expected_accounts,
           MIN(product_type) AS product_type,
           STRING_AGG(DISTINCT product_type, '|' ORDER BY product_type) AS product_mix
    FROM groups
    GROUP BY 1, 2, 3, 4
),
weeks AS (
    SELECT DISTINCT
           DATE_TRUNC('month', (DATE_TRUNC('week', date) + INTERVAL '3 days')::date)::date AS book_month,
           EXTRACT(isoyear FROM date)::int AS iso_year,
           EXTRACT(week FROM date)::int AS iso_week,
           DATE_TRUNC('week', date)::date AS week_start,
           (DATE_TRUNC('week', date) + INTERVAL '6 days')::date AS week_end
    FROM dim_calendar
),
group_week AS (
    SELECT m.group_type, m.group_value, m.book_month, m.client_id,
           m.expected_accounts, m.product_type, m.product_mix,
           w.iso_year, w.iso_week, w.week_start, w.week_end
    FROM multi m
    JOIN weeks w ON w.book_month = m.book_month
),
statuses AS (
    SELECT DISTINCT status AS ptp_status FROM fact_ptp_log
),
events AS (
    SELECT g.group_type, g.group_value, g.book_month, g.client_id, g.account_id,
           p.agent_id, p.status AS ptp_status, p.ptp_date
    FROM fact_ptp_log p
    JOIN groups g
      ON g.account_id = p.account_id
     AND g.book_month = DATE_TRUNC('month', (DATE_TRUNC('week', p.ptp_date) + INTERVAL '3 days')::date)::date
),
covered AS (
    SELECT group_type, group_value, book_month, client_id, ptp_status,
           EXTRACT(isoyear FROM ptp_date)::int AS iso_year,
           EXTRACT(week FROM ptp_date)::int AS iso_week,
           COUNT(DISTINCT account_id) AS covered_accounts
    FROM events
    GROUP BY 1, 2, 3, 4, 5, 6, 7
),
agent_counts AS (
    SELECT group_type, group_value, book_month, client_id, ptp_status,
           EXTRACT(isoyear FROM ptp_date)::int AS iso_year,
           EXTRACT(week FROM ptp_date)::int AS iso_week,
           agent_id,
           COUNT(DISTINCT account_id) AS accounts_touched,
           MAX(ptp_date) AS last_event
    FROM events
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
),
primary_agent AS (
    SELECT group_type, group_value, book_month, client_id, ptp_status, iso_year, iso_week,
           (ARRAY_AGG(agent_id ORDER BY accounts_touched DESC, last_event DESC))[1] AS agent_id
    FROM agent_counts
    GROUP BY 1, 2, 3, 4, 5, 6, 7
)
SELECT gw.group_type,
       gw.group_type || ': ' || gw.group_value AS scope,
       gw.group_value,
       gw.book_month,
       gw.iso_year,
       gw.iso_week,
       'W' || LPAD(gw.iso_week::text, 2, '0') || '-' || gw.iso_year::text AS week_label,
       gw.week_start,
       gw.week_end,
       gw.client_id,
       gw.expected_accounts,
       st.ptp_status,
       COALESCE(c.covered_accounts, 0) AS covered_accounts,
       CASE WHEN COALESCE(c.covered_accounts, 0) >= gw.expected_accounts THEN 'Full'
            WHEN COALESCE(c.covered_accounts, 0) > 0 THEN 'Partial'
            ELSE 'None' END AS tier,
       pa.agent_id AS primary_agent_id,
       COALESCE(e.agent_name, 'Unassigned') AS agent_name,
       COALESCE(e.team_name, 'Unassigned') AS team_name,
       COALESCE(e.region, 'Unassigned') AS region,
       gw.product_type,
       gw.product_mix
FROM group_week gw
CROSS JOIN statuses st
LEFT JOIN covered c
  ON c.group_type = gw.group_type AND c.group_value = gw.group_value
 AND c.book_month = gw.book_month AND c.client_id = gw.client_id
 AND c.iso_year = gw.iso_year AND c.iso_week = gw.iso_week
 AND c.ptp_status = st.ptp_status
LEFT JOIN primary_agent pa
  ON pa.group_type = gw.group_type AND pa.group_value = gw.group_value
 AND pa.book_month = gw.book_month AND pa.client_id = gw.client_id
 AND pa.iso_year = gw.iso_year AND pa.iso_week = gw.iso_week
 AND pa.ptp_status = st.ptp_status
LEFT JOIN dim_employees e ON e.agent_id = pa.agent_id
ORDER BY gw.book_month, gw.group_type, gw.group_value, gw.iso_year, gw.iso_week, st.ptp_status, e.team_name, gw.client_id;
```

> **`CROSS JOIN statuses`** guarantees that every group-week appears once per promise status,
> including weeks where that status has zero rows. Without it, a `Pending` filter would drop
> weeks instead of showing `None`.

---

## 3. Query 3 — Multi-account payment / cure coverage

**Event:** a row in `fact_payments`, split by `cure_flag`
**Output:** `payment.csv` — **47,988 rows** (15,996 groups × 3 cure flags)

```sql
WITH book AS (
    SELECT s.snapshot_date,
           DATE_TRUNC('month', s.snapshot_date)::date AS book_month,
           s.account_id,
           a.client_id,
           a.product_type,
           s.dpd_bucket
    FROM fact_eom_snapshot s
    JOIN dim_accounts a ON a.account_id = s.account_id
    WHERE s.status = 'Mora'
),
book_multi AS (
    SELECT b.*,
           COUNT(*) OVER (PARTITION BY b.book_month, b.client_id, b.dpd_bucket) AS expected_bucket,
           COUNT(*) OVER (PARTITION BY b.book_month, b.client_id) AS expected_status
    FROM book b
),
groups AS (
    SELECT 'Status'::text AS group_type, 'Mora'::text AS group_value,
           book_month, client_id, account_id, product_type,
           expected_status AS expected_accounts
    FROM book_multi WHERE expected_status >= 2
    UNION ALL
    SELECT 'Bucket'::text, dpd_bucket::text,
           book_month, client_id, account_id, product_type,
           expected_bucket
    FROM book_multi WHERE expected_bucket >= 2
),
multi AS (
    SELECT group_type, group_value, book_month, client_id,
           MAX(expected_accounts) AS expected_accounts,
           MIN(product_type) AS product_type,
           STRING_AGG(DISTINCT product_type, '|' ORDER BY product_type) AS product_mix
    FROM groups
    GROUP BY 1, 2, 3, 4
),
weeks AS (
    SELECT DISTINCT
           DATE_TRUNC('month', (DATE_TRUNC('week', date) + INTERVAL '3 days')::date)::date AS book_month,
           EXTRACT(isoyear FROM date)::int AS iso_year,
           EXTRACT(week FROM date)::int AS iso_week,
           DATE_TRUNC('week', date)::date AS week_start,
           (DATE_TRUNC('week', date) + INTERVAL '6 days')::date AS week_end
    FROM dim_calendar
),
group_week AS (
    SELECT m.group_type, m.group_value, m.book_month, m.client_id,
           m.expected_accounts, m.product_type, m.product_mix,
           w.iso_year, w.iso_week, w.week_start, w.week_end
    FROM multi m
    JOIN weeks w ON w.book_month = m.book_month
),
flags AS (
    SELECT DISTINCT COALESCE(cure_flag, 'No_Cure') AS cure_flag FROM fact_payments
),
events AS (
    SELECT g.group_type, g.group_value, g.book_month, g.client_id, g.account_id,
           p.agent_id,
           COALESCE(p.cure_flag, 'No_Cure') AS cure_flag,
           p.payment_date,
           p.amount_paid
    FROM fact_payments p
    JOIN groups g
      ON g.account_id = p.account_id
     AND g.book_month = DATE_TRUNC('month', (DATE_TRUNC('week', p.payment_date) + INTERVAL '3 days')::date)::date
),
covered AS (
    SELECT group_type, group_value, book_month, client_id, cure_flag,
           EXTRACT(isoyear FROM payment_date)::int AS iso_year,
           EXTRACT(week FROM payment_date)::int AS iso_week,
           COUNT(DISTINCT account_id) AS covered_accounts,
           SUM(amount_paid) AS amount_paid
    FROM events
    GROUP BY 1, 2, 3, 4, 5, 6, 7
),
agent_counts AS (
    SELECT group_type, group_value, book_month, client_id, cure_flag,
           EXTRACT(isoyear FROM payment_date)::int AS iso_year,
           EXTRACT(week FROM payment_date)::int AS iso_week,
           agent_id,
           COUNT(DISTINCT account_id) AS accounts_touched,
           MAX(payment_date) AS last_event
    FROM events
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
),
primary_agent AS (
    SELECT group_type, group_value, book_month, client_id, cure_flag, iso_year, iso_week,
           (ARRAY_AGG(agent_id ORDER BY accounts_touched DESC, last_event DESC))[1] AS agent_id
    FROM agent_counts
    GROUP BY 1, 2, 3, 4, 5, 6, 7
)
SELECT gw.group_type,
       gw.group_type || ': ' || gw.group_value AS scope,
       gw.group_value,
       gw.book_month,
       gw.iso_year,
       gw.iso_week,
       'W' || LPAD(gw.iso_week::text, 2, '0') || '-' || gw.iso_year::text AS week_label,
       gw.week_start,
       gw.week_end,
       gw.client_id,
       gw.expected_accounts,
       f.cure_flag,
       COALESCE(c.covered_accounts, 0) AS covered_accounts,
       COALESCE(c.amount_paid, 0) AS amount_paid,
       CASE WHEN COALESCE(c.covered_accounts, 0) >= gw.expected_accounts THEN 'Full'
            WHEN COALESCE(c.covered_accounts, 0) > 0 THEN 'Partial'
            ELSE 'None' END AS tier,
       pa.agent_id AS primary_agent_id,
       COALESCE(e.agent_name, 'Unassigned') AS agent_name,
       COALESCE(e.team_name, 'Unassigned') AS team_name,
       COALESCE(e.region, 'Unassigned') AS region,
       gw.product_type,
       gw.product_mix
FROM group_week gw
CROSS JOIN flags f
LEFT JOIN covered c
  ON c.group_type = gw.group_type AND c.group_value = gw.group_value
 AND c.book_month = gw.book_month AND c.client_id = gw.client_id
 AND c.iso_year = gw.iso_year AND c.iso_week = gw.iso_week
 AND c.cure_flag = f.cure_flag
LEFT JOIN primary_agent pa
  ON pa.group_type = gw.group_type AND pa.group_value = gw.group_value
 AND pa.book_month = gw.book_month AND pa.client_id = gw.client_id
 AND pa.iso_year = gw.iso_year AND pa.iso_week = gw.iso_week
 AND pa.cure_flag = f.cure_flag
LEFT JOIN dim_employees e ON e.agent_id = pa.agent_id
ORDER BY gw.book_month, gw.group_type, gw.group_value, gw.iso_year, gw.iso_week, f.cure_flag, e.team_name, gw.client_id;
```

> **`COALESCE(cure_flag, 'No_Cure')`** turns the NULL cure flag (a payment that did not cure)
> into a filterable label. It does not change `amount_paid`; every payment still counts.

---

## 4. Query 4 — Agent multi-account handling

**Event:** same as Query 1 (`rpc_flag = TRUE`), aggregated per agent
**Output:** `agent.csv` — **4,141 rows**

```sql
WITH book AS (
    SELECT s.snapshot_date,
           DATE_TRUNC('month', s.snapshot_date)::date AS book_month,
           s.account_id,
           a.client_id,
           s.dpd_bucket
    FROM fact_eom_snapshot s
    JOIN dim_accounts a ON a.account_id = s.account_id
    WHERE s.status = 'Mora'
),
book_multi AS (
    SELECT b.*,
           COUNT(*) OVER (PARTITION BY b.book_month, b.client_id) AS expected_status
    FROM book b
),
multi AS (
    SELECT book_month, client_id, MAX(expected_status) AS expected_accounts
    FROM book_multi
    WHERE expected_status >= 2
    GROUP BY 1, 2
),
events AS (
    SELECT i.agent_id,
           b.book_month,
           b.client_id,
           i.account_id,
           EXTRACT(isoyear FROM i.interaction_date)::int AS iso_year,
           EXTRACT(week FROM i.interaction_date)::int AS iso_week
    FROM fact_interactions i
    JOIN book b
      ON b.account_id = i.account_id
     AND b.book_month = DATE_TRUNC('month', (DATE_TRUNC('week', i.interaction_date) + INTERVAL '3 days')::date)::date
    WHERE i.rpc_flag
),
agent_client AS (
    SELECT agent_id, book_month, client_id, iso_year, iso_week,
           COUNT(DISTINCT account_id) AS covered_accounts
    FROM events
    GROUP BY 1, 2, 3, 4, 5
)
SELECT e.agent_name,
       e.team_name,
       e.region,
       'Status: Mora' AS scope,
       a.book_month,
       a.iso_year,
       a.iso_week,
       'W' || LPAD(a.iso_week::text, 2, '0') || '-' || a.iso_year::text AS week_label,
       COUNT(DISTINCT a.client_id) AS clients_touched,
       SUM(m.expected_accounts) AS accounts_in_scope,
       SUM(a.covered_accounts) AS accounts_covered,
       ROUND(SUM(a.covered_accounts)::numeric / NULLIF(SUM(m.expected_accounts), 0), 4) AS coverage_rate
FROM agent_client a
JOIN multi m
  ON m.book_month = a.book_month AND m.client_id = a.client_id
JOIN dim_employees e ON e.agent_id = a.agent_id
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
ORDER BY a.book_month, a.iso_year, a.iso_week, e.team_name, e.agent_name;
```

> **Why `SUM(m.expected_accounts)`:** each row is one agent touching one client. The agent
> gets credit for the accounts they covered, against the client's full expected accounts.
> If two agents touch the same client, both rows count the client's expected accounts, so
> **do not add rates across agents** — each row is a separate view. Likewise, the same
> account is counted once per week; grand totals are week-account counts, not unique
> accounts. Always read this report with a week selected.

---

## 5. PivotTable field wells (exact)

Build each pivot on the matching Excel Table (`tRPC`, `tPTP`, `tPAY`, `tAGENT`), top-left
cell **`A6`**.

### Report 1 — `RPC`

| Area | Field | Aggregation / label |
|---|---|---|
| Rows | `team_name` | — |
| Rows | `agent_name` | — |
| Columns | `tier` | — |
| Values | `client_id` | Count → rename `Groups` |
| Values | `expected_accounts` | Sum → rename `Accounts` |

Slicers: `scope`, `week_label`, `team_name`, `region`, `product_type`.

### Report 2 — `PTP`

Same wells as Report 1, plus slicer `ptp_status`. **Do not** put `ptp_status` in Columns.

### Report 3 — `PAY`

| Area | Field | Aggregation / label |
|---|---|---|
| Rows | `team_name` | — |
| Rows | `agent_name` | — |
| Columns | `tier` | — |
| Values | `client_id` | Count → `Groups` |
| Values | `expected_accounts` | Sum → `Accounts` |
| Values | `amount_paid` | Sum → `Paid $` |

Slicers: `scope`, `week_label`, `team_name`, `region`, `product_type`, `cure_flag`.

### Report 4 — `AGENT`

| Area | Field | Aggregation / label |
|---|---|---|
| Rows | `team_name` | — |
| Rows | `agent_name` | — |
| Values | `accounts_covered` | Sum |
| Values | `accounts_in_scope` | Sum |
| Values | `clients_touched` | Sum → rename `Touches` |
| Values | `Coverage Rate` | **Calculated field** (see below) |

> **Important:** `clients_touched` must be in **Values** or the `C4` KPI card returns
> `#REF!` — `GETPIVOTDATA` can only read fields the pivot already contains.

Slicers: `week_label`, `team_name`, `region`.

**Calculated field** — PivotTable Analyze → Fields, Items & Sets → Calculated Field:

```
Name:    Coverage Rate
Formula: =IF(accounts_in_scope=0,0,accounts_covered/accounts_in_scope)
```

Format as **Percentage, 1 decimal**.

---

## 6. Exact formulas (KPI cards)

All formulas assume the pivot's top-left cell is **`A6`**. `GETPIVOTDATA` reads the pivot's
**current filtered state**, so the cards follow the slicers.

### Reports 1, 2, 3

| Cell | Label | Formula |
|---|---|---|
| `B4` | Full % | `=IFERROR(GETPIVOTDATA("client_id",$A$6,"tier","Full")/GETPIVOTDATA("client_id",$A$6),0)` |
| `C4` | Partial % | `=IFERROR(GETPIVOTDATA("client_id",$A$6,"tier","Partial")/GETPIVOTDATA("client_id",$A$6),0)` |
| `D4` | None % | `=IFERROR(GETPIVOTDATA("client_id",$A$6,"tier","None")/GETPIVOTDATA("client_id",$A$6),0)` |
| `E4` | Groups | `=GETPIVOTDATA("client_id",$A$6)` |
| `F4` | Accounts | `=GETPIVOTDATA("expected_accounts",$A$6)` |

### Report 3 extra card

| Cell | Label | Formula |
|---|---|---|
| `G4` | Paid $ | `=GETPIVOTDATA("amount_paid",$A$6)` |

### Report 4

| Cell | Label | Formula |
|---|---|---|
| `B4` | Coverage Rate | `=IFERROR(GETPIVOTDATA("accounts_covered",$A$6)/GETPIVOTDATA("accounts_in_scope",$A$6),0)` |
| `C4` | Client-touches | `=GETPIVOTDATA("clients_touched",$A$6)` |
| `D4` | Accounts Covered | `=GETPIVOTDATA("accounts_covered",$A$6)` |
| `E4` | Accounts In Scope | `=GETPIVOTDATA("accounts_in_scope",$A$6)` |

Number formats: `B4:D4` percentage 1 decimal; `E4:F4` number with thousands separator;
`G4` currency.

> **Trap:** `GETPIVOTDATA` field names are the **source column names**, not the renamed
> value labels. Use `client_id` even though the column header says `Groups`.

---

## 7. Slicer settings

| Slicer | Report(s) | Columns | Notes |
|---|---|---|---|
| `scope` | 1, 2, 3 | 1 | Five values; `Status: Mora` is the broadest |
| `week_label` | 1, 2, 3, 4 | 8 | Shows `W01-2025` → `W52-2025` |
| `team_name` | 1, 2, 3, 4 | 1 | Hides `Unassigned` rows when selected |
| `region` | 1, 2, 3, 4 | 1 | — |
| `product_type` | 1, 2, 3 | 1 | First product alphabetically (`Hipoteca` → `Prestamo` → `Tarjeta`); see `product_mix` |
| `ptp_status` | 2 | 1 | Kept / Broken / Pending |
| `cure_flag` | 3 | 1 | Agent_Cure / Self_Cure / No_Cure |

Slicer caption and header: right-click a slicer → **Slicer Settings → Caption** (tick
**Display header** to show it). Set **Buttons → Columns** as above (on the **Slicer**
tab). "Hide items with no data" also lives in that **Slicer Settings** dialog — leave it
off so the week grid stays stable.

---

## 8. RAG conditional formatting

| Card | Green | Amber | Red |
|---|---|---|---|
| `Full %` | `>= 0.70` | `0.40`–`0.699` | `< 0.40` |
| `None %` | `<= 0.10` | `0.101`–`0.30` | `> 0.30` |
| `Coverage Rate` (Report 4) | `>= 0.70` | `0.40`–`0.699` | `< 0.40` |

Fills: green `#00B050` (white bold text), amber `#FFC000` (black text), red `#FF0000`
(white bold text). Apply with **Home → Conditional Formatting → New Rule → Format only
cells that contain**.

---

## 9. Validation

### 9.1 Row counts

| Extract | Rows |
|---|---|
| `rpc.csv` | 15,996 |
| `promise.csv` | 47,988 |
| `payment.csv` | 47,988 |
| `agent.csv` | 4,141 |

### 9.2 Scope and week values

| Check | Expected |
|---|---|
| Distinct `scope` | 5 |
| Distinct `week_label` | 52 (`W01-2025` → `W52-2025`) |
| Distinct `tier` | 3 |
| `covered_accounts > expected_accounts` | 0 rows in every extract |

### 9.3 Jan-2025 week 2, `Status: Mora` (419 groups)

| Report | Control | Full | Partial | None |
|---|---|---|---|---|
| RPC | — | 70 | 216 | 133 |
| PTP | Kept | 19 | 134 | 266 |
| PTP | Broken | 13 | 155 | 251 |
| PTP | Pending | 0 | 0 | 419 |
| PAY | Agent_Cure | 0 | 4 | 415 |
| PAY | Self_Cure | 0 | 0 | 419 |
| PAY | No_Cure | 28 | 158 | 233 |

Every row sums to **419**. Set the slicers to exactly `Status: Mora` + `W02-2025` and
clear team/region/product.

### 9.4 Structural checks

| Check | Expected | Why |
|---|---|---|
| `Self_Cure` rows with an agent | 0 | All 5,956 self-cures have `agent_id IS NULL`, and every `agent_id IS NULL` payment is a self-cure |
| `Pending` `Full` rows | 7, all in `W52-2025` | All 1,393 Pending promises were made 12–31 Dec 2025 and are still unresolved; before `W51` the Pending filter is 100% `None` |
| Report 4 `coverage_rate` range | 0–1 | Covered cannot exceed in-scope (verified: 0 out-of-range rows) |
| RPC `Full` at agent-client level (Jan-2025 wk 2) | 15 of 1,070 (~1.4%) | One client is usually touched by several agents |

### 9.5 Agent ambiguity (why Report 4 uses a rate)

For Jan-2025 week 2, `Status: Mora`:

| Metric | Value |
|---|---|
| Multi-account clients with ≥1 RPC | 286 |
| Of those, touched by >1 agent | 235 (82.2%) |
| Agent-client groups | 1,070 |
| Agent-client groups where the agent covered **all** accounts | 15 (1.4%) |

This is why an agent-level `Full/Partial/None` column would read as a near-constant and why
Report 4 reports a **coverage rate** instead.

---

## 10. Why the queries look the way they do

| Design choice | Reason |
|---|---|
| `book_month` = month of the ISO week's Thursday | A week belongs to the month containing its Thursday (ISO rule). It also means `2025-12-29` → `2025-12-31` map to Jan-2026, which has no snapshot, so they drop out cleanly. |
| Events joined on `book_month = month(week(event_date))` | Keeps a week that straddles two months on **one** book, so the denominator is stable. |
| `expected_status >= 2` / `expected_bucket >= 2` | Only multi-account clients are in scope; single-account clients are trivially `Full` or `None`. |
| Accounts restricted to the group (`JOIN groups`) | An RPC on an account in a different bucket must not count toward this bucket's coverage. |
| `COUNT(DISTINCT account_id)` | One account can have several interactions in a week; it counts once. |
| `CROSS JOIN statuses` / `flags` | Emits a row for every status/flag even when zero, so filters show `None` instead of dropping weeks. |
| Primary agent = most distinct accounts, then latest event | A deterministic heuristic. It is **not** ownership; 82% of multi-account clients with an RPC in Jan-2025 wk 2 were touched by more than one agent. |
| `MIN(product_type)` + `STRING_AGG(...)` | One product for the filter (first alphabetically: Hipoteca, Prestamo, Tarjeta), plus the full `product_mix` string. |
| `LEFT JOIN dim_employees` + `COALESCE(..., 'Unassigned')` | Clients with no event have no agent. `Unassigned` keeps them visible under `None`. |
| `ROUND(..., 4)` on the agent rate | Keeps the CSV readable; Excel formats it as a percentage. |

---

## 11. Data gaps and alternatives

| Gap | What the proposal wanted | What this guide does | Alternative |
|---|---|---|---|
| No documentation field | "Documented all/some/none of the client's accounts" | Event coverage as a proxy | None in this schema; would need a `documentation_flag` or notes table |
| No account ownership | "This agent left the client's other accounts uncovered" | Agent = main toucher; rate, not blame | Add an `account_assignments` table (agent, account, from, to) |
| No call-level grouping | "One call covered several accounts" | Per-account interactions | Add `call_id` to `fact_interactions` |
| Only two book statuses | `f01`/`f02`/`f03` buttons | `Activo`/`Mora` + 5 buckets | A status-code dimension |
| Month-end population | Weekly book | Static monthly denominator | Daily snapshots (not generated) |
| Max 3 accounts/client | Rich multi-account cases | 419 Mora clients in Jan-2025 | Larger synthetic book |
| Dec-2024 snapshot absent | Dec-2024 week buttons | Starts `W01-2025` | Add a Dec-2024 snapshot |

---

## 12. Excel automation caveat

`openpyxl` (installed in the `mis-collections` env, 3.1.5) can write values, formulas,
styles, and plain Excel Tables. It **cannot create native PivotTables, slicers,
PivotCharts, or `GETPIVOTDATA`-driven dashboards**. Those are Excel UI objects stored in
the workbook's binary parts.

Practical consequence: this workbook must be **built and edited in Excel**. Python is used
only to produce the CSVs (or to validate the queries). If you need a fully scripted
dashboard, use Power BI or a Python dashboard instead.

---

## 13. Summary tab — exact formulas

Built in `TASKS.md` Task 8. One sheet that reads the four report tabs and holds no pivot
of its own.

### 13.1 Mirror cards

| Summary cells | Formulas | Shows |
|---|---|---|
| `B4:F4` | `=RPC!B4` … `=RPC!F4` | Full/Partial/None %, Groups, Accounts |
| `B7:F7` | `=PTP!B4` … `=PTP!F4` | same five — inside the PTP tab's selected `ptp_status` |
| `B10:G10` | `=PAY!B4` … `=PAY!G4` | same five + `Paid $` |
| `B13:E13` | `=AGENT!B4` … `=AGENT!E4` | Coverage Rate, Client-touches, Accounts Covered, Accounts In Scope |

Labels sit one row above each block (`B3:F3`, `B6:F6`, `B9:G9`, `B12:E12`); formats
arrive by Paste Special → Formats from each report's card rows, so the RAG colors match
the tabs.

> **Why mirrors, not `GETPIVOTDATA` everywhere:** a mirror points at a cell that already
> guards with `IFERROR`, rounds, and colors itself. Duplicating that with `GETPIVOTDATA`
> doubles the maintenance for nothing. The one place `GETPIVOTDATA` earns its keep on
> this tab is the tier table below, where no per-tier card exists to mirror.

### 13.2 Cross-report tier table

Headers `B15:E15`; tiers `A16:A18`; totals in row 19:

| Summary cell | Formula |
|---|---|
| `C16` | `=IFERROR(GETPIVOTDATA("client_id",RPC!$A$6,"tier","Full"),0)` |
| `C17` | `=IFERROR(GETPIVOTDATA("client_id",RPC!$A$6,"tier","Partial"),0)` |
| `C18` | `=IFERROR(GETPIVOTDATA("client_id",RPC!$A$6,"tier","None"),0)` |
| `D16:D18` | the same three with `PTP!$A$6` |
| `E16:E18` | the same three with `PAY!$A$6` |
| `C19:E19` | `=SUM(C16:C18)` — and the equivalent for `D` / `E` |

`GETPIVOTDATA` reads each pivot's **current filtered state** across sheets — the one
cross-tab reading job the Summary keeps.

Reading rules:

| Rule | Reason |
|---|---|
| Compare rows only while `scope` + `week_label` match across RPC / PTP / PAY | The table assumes one frame; mixed frames are apples to oranges |
| `ptp_status` / `cure_flag` do **not** shrink the frame from 419 to a third of it | The extracts emit one row per group × status/flag (the `CROSS JOIN statuses` / `flags`), so the group frame stays whole — the status just picks which event flavor is counted |
| A filtered-out tier shows `0`, not `#REF!` | `IFERROR` guard, consistent with the cards |

### 13.3 Control state

`scope = Status: Mora`, `week_label = W02-2025` on RPC / PTP / PAY; `ptp_status = Kept`;
`cure_flag = No_Cure`; on AGENT select `W02-2025` only (it has no scope/flag control).

| Check | Expected |
|---|---|
| RPC tier column | 70 / 216 / 133 |
| PTP tier column (`Kept`) | 19 / 134 / 266 |
| PAY tier column (`No_Cure`) | 28 / 158 / 233 |
| `Groups` row (`C19:E19`) | 419 in all three |
| AGENT mirror `Client-touches` | 1,070 agent-client groups (§9.5) |
| AGENT mirror `Coverage Rate` | between 0% and 100% |

The same control numbers as §9.3 — Task 8's checklist simply re-reads them through the
mirrors.

### 13.4 Why the Summary owns no slicers

One Excel Table per report → one pivot cache per report → a slicer connects only to
pivots inside its own cache. No slicer spans four tables. A one-screen honest sentence
beats a half-connected control strip — the same philosophy that put the limitations on
the `Notes` sheet.

---

## 14. PivotChart specs

Built in `TASKS.md` Task 9 — five PivotCharts, one helper pivot each, on the same sheet
as its report. Helper pivots start at **`A110`** (below the report pivot's unfiltered
height), the `Paid $` second helper at `A175`; charts float to their right around column
`H`. Same-table helper = same cache = the tab's existing slicers drive both pivots via
**Report Connections**.

| Sheet | Helper pivot | Field wells | PivotChart |
|---|---|---|---|
| `RPC` | `RPC!$A$110` | Rows `week_label`, Columns `tier`, Values Count of `client_id` | 100% Stacked Column — coverage mix by week |
| `PTP` | `PTP!$A$110` | same as RPC | 100% Stacked Column — mix under the selected `ptp_status` |
| `PAY` | `PAY!$A$110` | same as RPC | 100% Stacked Column — mix under the selected `cure_flag` |
| `PAY` (2nd) | `PAY!$A$175` | Rows `week_label`, Values Sum of `amount_paid` — no Columns field | Clustered Column — Paid $ by week |
| `AGENT` | `AGENT!$A$110` | Rows `team_name`, Values Sum of `accounts_covered`, `accounts_in_scope`, and the **`Coverage Rate`** calculated field | Clustered Bar — untick the two Sum series on the chart so only `Coverage Rate` draws; sorted by rate descending |

Series colors: `Full` / `Partial` / `None` → `#00B050` / `#FFC000` / `#FF0000`; the two
single-series charts (`Paid $`, team bar) → `#262A76` (theme blue, same as the report
tabs).

### 14.1 Why a helper pivot

The report pivot is team → agent rows against tier columns; charting it directly draws
80 stacked triplets. The helper holds a small week × tier (or team × values) shape the
chart renders cleanly — and because it is built from the **same Excel Table**, it shares
the pivot cache and therefore the slicers.

### 14.2 The AGENT rate rolls up correctly

`Coverage Rate` is a calculated field: `=IF(accounts_in_scope=0,0,accounts_covered/
accounts_in_scope)`. Calculated fields aggregate field by field — `Sum` of the numerator
÷ `Sum` of the denominator, a **ratio of sums**, never an average of per-agent rates. So
one team bar is the correct value for its eight agents, and sorting by the rate
descending shows the strongest teams without inventing a bogus average.

### 14.3 Connection mechanics

| Fact | Consequence |
|---|---|
| A helper shares its cache only when it is built on the same Table | Build each helper on `tRPC` / `tPTP` / `tPAY` / `tAGENT` exactly as listed above |
| Slicers list same-cache pivots in Report Connections | Tick the helper there; do not insert new slicers for one helper |
| `Data → Refresh All` preserves Report Connections | No extra refresh step |
| Deleting and rebuilding a helper pivot drops its connections | Re-tick all slicers after a rebuild |
| Charts must be **PivotCharts** | A plain chart drawn from cells would read values, not the filtered state — it would ignore the slicers |

---

## 15. Appendix — columns referenced

| Table | Columns used |
|---|---|
| `fact_eom_snapshot` | `snapshot_date`, `account_id`, `status`, `dpd_bucket` |
| `dim_accounts` | `account_id`, `client_id`, `product_type` |
| `fact_interactions` | `account_id`, `agent_id`, `interaction_date`, `rpc_flag` |
| `fact_ptp_log` | `account_id`, `agent_id`, `ptp_date`, `status` |
| `fact_payments` | `account_id`, `agent_id`, `payment_date`, `amount_paid`, `cure_flag` |
| `dim_employees` | `agent_id`, `agent_name`, `team_name`, `region` |
| `dim_calendar` | `date` |

All queries are read-only `SELECT`s. They create no tables, views, functions, or schemas,
so `migrate.sh`'s 16-view assertion is unaffected.

Note on `fact_interactions`: the schema also has `call_outcome` (call-result codes:
`RPC`, `Voicemail`, `Third_Party`, `No_Answer`, `Wrong_Number`, `Message_w_Relative`,
`Busy`). `rpc_flag = TRUE` is exactly `call_outcome = 'RPC'` — verified row for row
(426,914 rows each). These queries use `rpc_flag`; a "disposition" column exists, but it
is a call result, **not** documentation of a client's accounts.
