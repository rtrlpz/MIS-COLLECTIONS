# KPI Glossary — condensed from `docs/kpi_definitions.md`

> **Language note:** the source doc predates the star-schema rename and calls table `dialer_interactions`, etc. This condensed version uses the **live** names (`fact_interactions`, `fact_ptp_log`, `fact_payments`, `fact_agent_time_log`, `dim_accounts`). If you ever compare against the old doc, translate by those same names.
>
> Full authoritative text: `docs/kpi_definitions.md` (319 lines). This file is your working cheat-sheet for all five tracks.

---

## 1. Contact metrics (source: `fact_interactions`)

| Metric | Formula (live columns) | Benchmark / notes |
|---|---|---|
| **Total connections** | `SUM(calls_connected)` | A call that was answered — not necessarily the right party. |
| **RPC count** | `COUNT(*) WHERE rpc_flag = TRUE` | Single most important *contact quality* metric. FICO/SMS are non-dialing channels — the dialect convention is to exclude them from the RPC rate, but `v_contact_metrics` does NOT filter channels, so an excluded-channel rate differs from the view (a documented divergence, not a bug). |
| **RPC%** | `SUM(rpc_flag::int) / SUM(calls_connected)` | **35–60%** typical. Low RPC% = stale or badly segmented dialer list. |
| **RPC / Op Hr** | `SUM(rpc_count) / SUM(operational_hours)` | Efficiency per hour worked — rewards output, not logged time. |
| **RPC arrears** | `SUM(rpc_arrears)` on RPC rows | The collectible pool "exposed" through RPC activity. Denominator of Capped KP / RPC Arrears. |

## 2. Promise metrics (source: `fact_ptp_log`)

| Metric | Formula | Benchmark / notes |
|---|---|---|
| **# PTP** | `COUNT(*)` in period | Only RPCs can generate PTPs. One account can have several PTPs. |
| **PTP%** | `PTP_count / RPC_count` | **5–40%** typical on 12-mo data (median ~15). Judge low-vs-high relative to peers/period, not an absolute line. |
| **# Kept** | `COUNT(*) WHERE status = 'Kept'` | Promise honored (matching payment ≤30 days). |
| **# Broken** | `COUNT(*) WHERE status = 'Broken'` | High broken vs kept = agents overpromising to hit PTP%. |
| **KP%** | `Kept / (Kept + Broken)` | **65–90%**. *Excludes `Pending`* promises. Denominated over resolved promises only. |
| **BB Conversion** | `PTP% × KP%` | The single best end-to-end effectiveness summary. Decompose before acting. |
| **Capped KP$** | `SUM(LEAST(promised_amount, arrears)) WHERE status='Kept'` | Caps a promise at the real collectible amount — financially accurate KP$. |
| **Capped KP / RPC Arrears** | `SUM(capped_kept) / SUM(rpc_arrears)` | "Of all the money we talked about, how much did we actually get?" |

## 3. Recovery metrics (sources: `fact_payments`, `fact_agent_time_log`)

| Metric | Formula | Benchmark / notes |
|---|---|---|
| **Cures** | `COUNT(DISTINCT account_id)` with arrears eliminated | Distinct accounts — one account cured twice in a month counts once. |
| **Cured amount** | `SUM(amount_paid)` on cured payments | Gross recovery revenue; includes spontaneous (non-PTP) payments. |
| **Cures / THT** | `Cures / SUM(tht_hours)` | Core productivity. THT isolates actual on-call time. **0.02–0.20** (median ~0.16 on post-P4 12-mo data). |

## 4. Productivity (source: `fact_agent_time_log`)

| Metric | Formula | Benchmark |
|---|---|---|
| **Utilization** | column `utilization` is decimal 0–1 = actual talk-time (THT) ÷ operational hours | **30–60%** here. This is *talk-share* of an operational day — ~90% is impossible by construction. The hidden 85–97% *availability* factor that sizes op-hours is a different metric, not exposed as a KPI. |

## 5. Handle time (source: `fact_interactions`)

| Metric | Formula | Benchmark / notes |
|---|---|---|
| **AHT — RPC** | `AVG(aht_seconds) WHERE rpc_flag` | 180–480s normal; <120s = rushing. |
| **AHT — Non-RPC** | `AVG(aht_seconds) WHERE NOT rpc_flag` | 30–90s expected. |
| **ACW — RPC** | `AVG(acw_seconds) WHERE rpc_flag` | **80–180s**; >120s = wrap-up/coaching issue. |
| **ACW — Non-RPC** | `AVG(acw_seconds) WHERE NOT rpc_flag` | 10–30s expected. |

## 6. Calculation rules that bite (learn these now)

1. **KP% excludes `Pending`.** Early in a period KP% looks inflated because unresolved promises fall out of the denominator — always state the resolution window.
2. **Rates are recalculated from summed totals, never averaged from daily rates.** Averaging daily percentages distorts when daily volumes vary. (You'll prove this in Python/advanced.)
3. **Cures dedup by account.** `COUNT(DISTINCT account_id)`, not `SUM(is_cured)` — the project's own `v_recovery_metrics` was fixed exactly for this.
4. **BB Conversion = kept_pct * ptp_pct / 100** — not a raw count ratio.
5. **Capped KP$ ≠ collected amount.** One measures promise *quality*; the other measures actual *cash*, including self-cures with no PTP link.
6. **Monitoring pool:** only accounts that have ever been in Mora are dialed — you won't see clean `Activo` accounts in interactions.
7. **Weekday rule:** `fact_interactions` is Mon–Fri only; payments CAN occur on weekends (`payment_date = date made`).
8. **Scorecard weights** (used in advanced): RPC 25% · KP 25% · Cure 20% · Util 15% · AHT 15% — composite in `v_agent_scorecards`.
9. **Channel convention vs the views:** the dialect excludes FICO/SMS from RPC%, but `v_contact_metrics` (and the KPI views generally) do NOT filter channels. Exclude them in your own rate if you follow the dialect — and expect a small, *explainable* difference vs the view. Name it; don't force a match.

## 7. Goals & targets (from the DAX Dim_Targets module — reused in powerbi track)

| KPI | Target |
|---|---|
| PTP% | 80% |
| KP% | 80% |
| ACW (RPC) | 120s |
| ACW (Non-RPC) | 25s |
| Capped KP / RPC Arrears | 37% |
| Cures / THT | 2.4 |
| Utilization | 90% |

RAG colors: Green `#00B050`, Amber `#FFC000`, Red `#FF0000`.

## 8. No-TL / leadership filter

KPI views exclude non-production roles (Team Leader, Ops Sr Manager, etc.). In this synthetic dataset all 80 agents have a `supervisor_id`, so **include** them; the rule matters mostly if you re-join raw staffing data.

## 9. Cardinality cheat sheet (from `dim_accounts`)

- **`product_type`**: `Tarjeta` (credit card), `Prestamo` (personal loan), `Hipoteca` (mortgage — largest balances and arrears exposure, senior-agent handling). Delinquency rate is ~7% for all three on 12-mo data — no product dominates.
- **DPD buckets** in `fact_eom_snapshot.dpd_bucket`: `Current`, `1-30`, `31-60`, `61-90`, `90+`. Ordering is by *severity rank*, never by comparing bucket names as text.


## 10. Portfolio risk metrics (sources: `fact_eom_snapshot`, `fact_writeoffs`, `fact_recoveries`)

| Metric | Formula | Notes |
|---|---|---|
| **Roll rate** | share of accounts moving from bucket B to a WORSE bucket between consecutive month-ends | The early-warning metric for board packs. Severity order comes from `dim_delinquency_bucket.sort_order` — never alphabetically. See `v_dpd_migration_matrix`. |
| **Exited transitions** | accounts whose final month has no following month | Charged-off accounts leave the book by design; the view admits pre-end finals so exits are countable (~413 on current data). |
| **Vintage curve** | Mora% by months-on-book, one line per open-date cohort | Replaces calendar time with account age — the only fair cohort comparison. Right-edge ages are thin (censoring), not broken. |
| **Re-entry / recycle rate** | of accounts Mora at month-end M and Activo at M+1, the share Mora again by M+2 | Plausible band for this engine: **5–25%**; measured 10.4–14.3% chronologically across all twelve-month windows. |
| **Portfolio cure rate** | cured accounts this month ÷ prior month-end Mora stock | Industry definition fixed in audit I1 — denominator is delinquent STOCK, not payments. `v_monthend_portfolio` implements it with `LAG` and stores PERCENT. Current band 56–76%. |

## 11. Forecasting & capacity planning terms

| Term | Plain meaning | This project's convention |
|---|---|---|
| **Seasonal-naive baseline** | next month ≈ trailing average of recent months (or same month last year) | Deliberately simple; every assumption stated inline. December breaks it — say so. |
| **Capacity estimate** | projected delinquent accounts × attempts per account ÷ collector attempts-per-hour → hours → FTE | Constants must be named with provenance; sensitivity table (±50%) ships unprompted. |
| **Loss-impact scenario** | roll-rate shifts propagated forward to write-off dollars | Modeled from `v_dpd_migration_matrix` × write-off rates at 91+ DPD. |
