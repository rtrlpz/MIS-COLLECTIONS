# SQL Medium — Your Inbox (level 2 of 3)

```
You are here: learning/sql/medium/
Assumed:      you finished basic/ — filters, joins, group-bys are muscle memory now
Your answers: work/attempt_*.sql
Solutions:    medium/results.md — after attempting; then RUN the solution
New tools:    CTE chains, FILTER, window functions, per-plan logic, ratio-of-sums discipline
```

**What this level gives you.** The *"why did it change?"* questions: breakdowns that hold up under scrutiny, reconciliation against the official `v_*` views, and the two aggregation traps that embarrass analysts in front of directors.

---

## Words you'll meet

| Term | Plain meaning |
|---|---|
| **CTE** (`WITH`) | A named subquery — build your answer in readable, testable steps |
| **Window function** | An aggregate that doesn't collapse rows (`OVER (PARTITION BY …)`) |
| **`FILTER (WHERE)`** | Count/sum only matching rows inside one aggregate — no CASE gymnastics |
| **Ratio-of-sums** | Aggregate numerators and denominators FIRST, divide LAST. The correct way to weight a rate |
| **Average-of-averages** | `AVG(rate)` over groups. Almost always the wrong weighting. Learn to spot it everywhere |
| **Installment plan** | One promise paid across multiple payments; judged on cumulative ≥95% within grace |

---

## Task 1 — Daily MIS skeleton for one day
📥 **Inbox:** From MIS Manager · Mon 9:00 AM · "this becomes a template, so write it like one"

> "I need a one-day agent-level pack: contacts, connects, RPCs, promises, cures, cured dollars — one row per agent who did anything that day, team attached. You'll reuse this shape forever, so build it clean."

**Background:** This is `v_daily_mis`'s job. Yours is to rebuild its skeleton from raw tables with a CTE chain — because one day someone will ask you to modify it and you must not fear it.

**Your job:**
1. One CTE per source fact (contacts / promises / cures), each grouped by agent.
2. Join them to `dim_employees`; keep agents even if a source is empty for them.
3. Attach team name; sort by team, then RPCs descending.

**Guiding questions:** Which join type keeps an agent who took calls but logged zero promises? Where does `COALESCE(…,0)` belong? Why does each CTE reduce before joining (hint: row explosion)?

**Data pointers:** `fact_interactions`, `fact_ptp_log`, `fact_payments`, `dim_employees`; cross-check target: `v_daily_mis` for the same date.

**Done when:**
- [ ] Three CTEs + one final join; runs for any single date
- [ ] Agent rows survive missing sources (no lost agents)
- [ ] Row count matches `v_daily_mis` for that date

---

## Task 2 — Installment plans: who really kept their promise?
📥 **Inbox:** From Collections Strategy Lead · Wed 11:00 · "finance challenged our KP% again"

> "A promise can be paid across multiple installments — we judge it kept when cumulative payments reach 95% of what was promised, within grace. Someone summed per-payment last month and called half our book broken. Build the per-plan view of the world for Q2 promises."

**Background:** `fact_payments.ptp_id` links payments to plans (nullable — not every payment belongs to a promise). Status lives on the plan, not the payment.

**Your job:**
1. Sum payments per `ptp_id`.
2. Attach promise status and grace date.
3. For Kept plans: verify none sits below the 95% cumulative threshold.
4. Report how many Kept plans needed more than one payment.

**Guiding questions:** What happens if you group payments without filtering `ptp_id IS NOT NULL`? A Broken plan with partial payments — is that a data error or expected? Where would a per-row check have lied?

**Data pointers:** `fact_payments`, `fact_ptp_log`; `_reference/kpi_glossary.md` → KP%; cross-check: `v_promise_metrics` monthly `kept_pct`.

**Done when:**
- [ ] Per-plan totals joined to status; zero Kept plans under 95%
- [ ] Multi-installment share reported
- [ ] One-paragraph note: why per-row checking breaks here

---

## Task 3 — Does the treatment arm change the channel mix?
📥 **Inbox:** From Strategy Analyst · Thu 3:15 PM · "steering committee wants proof"

> "Accounts sit in three treatment arms — champion dialer plus two challengers. Each arm is *supposed* to mix channels differently. Show me actual channel mix per arm, share within arm. If SMS-first isn't SMS-heavy, the program is mis-wired."

**Background:** `dim_strategy` carries each arm's intended mix and efficacy multipliers; interactions carry which arm the account belongs to. Intended vs actual is the whole story.

**Your job:**
1. Interactions per arm × channel.
2. Share within each arm using a window function over the grouped totals.
3. Compare against `dim_strategy.channel_mix` (intended) in a comment.

**Guiding questions:** Why does `SUM(COUNT(*)) OVER (PARTITION BY …)` work while nesting aggregates doesn't? Which arm should skew Manual/FICO rather than Dialer?

**Data pointers:** `fact_interactions.strategy_id`, `dim_strategy`; `_reference/data_dictionary.md` → strategy section.

**Done when:**
- [ ] Arm × channel counts + within-arm percentages
- [ ] Actual-vs-intended verdict written per arm

---

## Task 4 — AHT vs the team benchmark
📥 **Inbox:** From Supervisor, Team 4 · Tue 8:30 · "coaching chats Thursday"

> "Give me July average handle time on RPCs for each of my agents next to the team benchmark, worst offenders first. And I want the benchmark computed the defensible way — I heard averages-of-averages got someone burned here recently."

**Background:** AHT-RPC = total handle seconds ÷ RPC count. Team benchmark = all RPC seconds ÷ all RPCs in the team (ratio-of-sums), NOT the mean of agent means.

**Your job:**
1. Per-agent AHT-RPC for July, minimum activity floor so part-timers don't distort.
2. Team benchmark via separate aggregation (sum÷sum).
3. Difference vs benchmark, sorted worst first.

**Guiding questions:** Why exclude low-volume agents from ranking but not from the benchmark math? Compute the naive AVG-of-agent-AHTs too — how far does it drift from ratio-of-sums, and why?

**Data pointers:** `fact_interactions.aht_seconds`, `rpc_flag`; `_reference/kpi_glossary.md` → AHT; cross-check: `v_handle_time_metrics`.

**Done when:**
- [ ] Agent table + team ratio-of-sums benchmark + delta
- [ ] Both benchmark methods computed side by side, difference noted

---

## Task 5 — Broken promises with money already paid
📥 **Inbox:** From Collections Manager · Fri 10:00 · "rework queue for Monday"

> "Broken promises usually get written off as dead. But some broke AFTER a first installment landed — those clients showed intent. Pull broken plans where at least something was paid: account, promised amount, amount actually collected, dates. That's my rework list."

**Background:** Installment plans stay Pending between parts; some miss the second payment and die as Broken despite real cash received. Standard broken-reporting hides them.

**Your job:**
1. Payments per plan (left side: ALL broken plans, right side: their optional totals).
2. Keep only plans with collected > 0.
3. Order by collected amount descending — biggest salvageable first.

**Guiding questions:** Why LEFT JOIN (what dies with INNER here)? Can a plan's payments exceed what was promised — and would that change how you rank it?

**Data pointers:** `fact_ptp_log.status`, `fact_payments.ptp_id`; cross-check: `v_promise_timeline.paid_amount`.

**Done when:**
- [ ] Salvage list ordered by collected desc
- [ ] Cross-checked against `v_promise_timeline` (note any definitional differences)

---

## Task 6 — Utilization for July: daily vs month-level
📥 **Inbox:** From Workforce Analyst · Mon 2:00 PM · "capacity review Wednesday"

> "I need July utilization per agent. Careful — someone last quarter averaged the daily percentages and got numbers that made no sense against scheduled hours. Whatever you do, show me BOTH ways so we can see the gap."

**Background:** `fact_agent_time_log` stores one row per agent-day with `utilization` already computed (decimal, capped 0.95), plus raw hours. Month-level utilization should be total handle-time hours ÷ total operational hours.

**Your job:**
1. Per agent for July: sum of operational hours, sum of tht hours, and ratio-of-sums utilization %.
2. Next to it, the naive `AVG(utilization)` × 100.
3. Flag rows where the two methods differ by more than a rounding hair.

**Guiding questions:** Why do the two methods disagree at all? Which agents diverge most — what pattern do their days have? Which method matches the project's official productivity view?

**Data pointers:** `fact_agent_time_log` (`operational_hours`, `tht_hours`, `utilization`, `schedule_hours`); cross-check: `v_productivity_metrics`.

**Done when:**
- [ ] Both methods side by side, divergence flagged
- [ ] Verdict written: which method is correct here and why

---

## Task 7 — Cure rate by product (the aggregation trap, formal edition)
📥 **Inbox:** From Portfolio Manager · Thu 1:30 PM · "credit risk committee packet"

> "Cured accounts as a share of paying accounts, by product, H2 2025. And I need it computed the right way at product level — last deck had Tarjeta's rate swinging depending on who built it. Make one number per product that survives questions."

**Background:** Cures are payments flagged `is_cured`. The trap: computing monthly rates then averaging them weights quiet months equal to busy months.

**Your job:**
1. Per product-month: distinct cured accounts, distinct paying accounts.
2. Product-level rate = SUM(cures) ÷ SUM(paying) across months.
3. Beside it, AVG-of-monthly-rates. Explain the gap in comments.

**Guiding questions:** Which method overweights February-type months? If a product launched mid-year with tiny early months, which method lies harder?

**Data pointers:** `fact_payments.is_cured`, `dim_accounts.product_type`; `_reference/kpi_glossary.md` → cure.

**Done when:**
- [ ] One row per product: correct ratio-of-sums + naive average + delta
- [ ] Comment naming which number goes in the committee pack

---

## Task 8 — Weekly activity summary per agent
📥 **Inbox:** From Ops Lead · Mon 7:50 AM · "Monday leadership email attachment"

> "September, week by week, per agent: interactions, RPCs, RPC%, average AHT, distinct accounts touched. Team attached, weeks ordered. Same shape every Monday from now on — save it."

**Background:** This mirrors the project's own weekly view. Rebuilding official views from raw is the core skill this track exists to teach — and your version becomes the template you edit when the business asks for "one more column".

**Your job:**
1. ISO week start date per interaction; group by week × agent.
2. Interactions, RPCs, RPC% (volume-weighted), avg AHT, distinct accounts.
3. Join team; order chronologically within team.

**Guiding questions:** Does `DATE_TRUNC('week', …)` give the week start you want (Monday)? Your weekly RPC% — computed from sums or averaged from days? Why does it matter more at week grain than day grain?

**Data pointers:** cross-check target: `v_weekly_agent_summary` for September.

**Done when:**
- [ ] One query, all five metrics, September only
- [ ] Row count reconciled against the official weekly view

---

## Finish

Eight templates saved. You now speak fluent breakdown-and-reconcile. [`../advanced/tasks.md`](../advanced/tasks.md) is where you stop consuming the official views and start auditing them.
