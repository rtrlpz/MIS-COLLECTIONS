# KPI View Documentation

## Views (12 in `002_kpi_views.sql`; `v_agent_scorecards` in `004_agents_scorecards.sql`)

| # | View | Granularity | Purpose | Key Columns |
|---|------|-------------|---------|-------------|
| 1 | `v_contact_metrics` | agent / team / monthly | Contact KPIs: calls, connections, RPCs, RPC% | `connected_calls`, `rpc_count`, `rpc_pct`, `rpc_per_operating_hour` |
| 2 | `v_promise_metrics` | agent / team / monthly | Promise KPIs: PTPs, kept/broken, KP%, BB Conversion | `ptp_count`, `ptp_pct`, `kept_count`, `broken_count`, `kept_pct`, `bucket_conversion`, `capped_kp` |
| 3 | `v_recovery_metrics` | agent / product / monthly | Recovery KPIs: cures, cured amounts, agent vs self-cure | `cure_count`, `cured_amount`, `cure_rate`, `agent_cure_count`, `self_cure_count` |
| 4 | `v_productivity_metrics` | agent / team / monthly | Productivity KPIs: utilization, contacts per hour | `utilization_pct`, `operational_hours`, `contacts_per_agent_hour` |
| 5 | `v_handle_time_metrics` | agent / team / monthly | Handle time split by RPC/Non-RPC | `avg_aht_rpc`, `avg_aht_nonrpc`, `avg_acw_rpc`, `avg_acw_nonrpc` |
| 6 | `v_daily_mis` | agent | Consolidated daily view (all KPI categories) | All columns from views 1-5 joined on `agent_id` + `date` |
| 7 | `v_monthly_summary` | agent / team / portfolio | Monthly rollup for trend analysis | All KPIs aggregated; rates use weighted `SUM/SUM` at team/portfolio level |
| 8 | `v_etl_load_summary` | N/A | Latest ETL load per table | `table_name`, `last_loaded_at`, `rows_loaded`, `status`, `data_freshness` |
| 9 | `v_data_freshness` | N/A | Days since last data load per fact table | `table_name`, `max_date`, `days_ago` |
| 10 | `v_dpd_migration_matrix` | account | DPD bucket transitions between months | `from_bucket`, `to_bucket`, `migration_direction` (Same/Deteriorated/Improved/Cured) |
| 11 | `v_weekly_agent_summary` | agent | Weekly performance aggregation | `rpc_pct`, `avg_aht`, `avg_acw`, `accounts_contacted` |
| 12 | `v_rls_supervisor_map` | supervisor | Supervisor↔agent mapping (row-level security in PBIX) | `supervisor_id`, `supervisor_name`, `agent_id`, `agent_name` |
| 13 | `v_agent_scorecards` | agent | Composite weighted performance score | `composite_score` = RPC 25% + KP 25% + Cure 20% + Util 15% + AHT 15% |

## View Dependencies (star schema sources)

```
Fact_Interactions → v_contact_metrics, v_promise_metrics (via rpc_flag), v_handle_time_metrics
Fact_PTP_Log → v_promise_metrics
Fact_Payments → v_recovery_metrics
Fact_Agent_Time_Log → v_productivity_metrics, v_contact_metrics (op hours)
Fact_EOM_Snapshot → v_dpd_migration_matrix
Dim_Calendar → all views (date dimension)
Dim_Employees → all agent/team views
Dim_Accounts → v_recovery_metrics (via product_type)
```

## Key Business Rules

- **RPC%** = RPCs / Connected calls (not call attempts). Industry standard for collections.
- **BB Conversion** = PTP% × KP% / 100. Measures end-to-end promise-to-payment funnel.
- **Cure** = account that reached $0 past due after payment. Tracked via `COUNT(DISTINCT account_id)`.
- **Capped KP** = Kept Promise amount capped at RPC Arrears (cannot cure more than owed).
- **Handle time metrics** split by RPC vs Non-RPC to distinguish negotiation calls from simple contacts.
- **Team/portfolio rates** use weighted averages (SUM/SUM) not AVG of AVG.
