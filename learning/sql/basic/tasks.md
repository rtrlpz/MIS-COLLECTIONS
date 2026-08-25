# SQL Basic — Your Inbox (level 1 of 3)

```
You are here: learning/sql/basic/
Read first:   _reference/datasets.md and _reference/kpi_glossary.md (10 min, one time)
Your answers: work/attempt_1.sql, attempt_2.sql …  (this folder's work/ is your scratchpad)
Solutions:    basic/results.md — open ONLY after attempting, then RUN the solution yourself
```

**What this level gives you.** After these nine tasks you can answer the requests that fill a Collections MIS analyst's mornings — *"how many?", "how much?", "who are the biggest?", "is the data even fresh?"* — straight from the database, without asking anyone for help.

---

## Words you'll meet in these tasks

| Term | Plain meaning |
|---|---|
| **Table** | One spreadsheet-like dataset inside the database |
| **Fact table** | One row per *event*: a call made, a promise logged, a payment received. These tables are big |
| **Dimension table** | One row per *thing*: an agent, an account, a client, a calendar day. These tables are small |
| **Star schema** | Facts in the middle, dimensions around them, connected by ID columns |
| **Grain** | What ONE row represents ("one row per call"). Identify this before trusting any count |
| **Snapshot** | A photo of *state at a date* (every account's balance at month-end) — different from an event log |

---

## How to work through a task

1. **The request** — how it arrives at work.
2. **Your job** — steps, each with the *why* attached.
3. **Guiding questions** — answer as comments in your attempt file.
4. **Done when** — acceptance criteria. You're not done until every box ticks.

Attempt honestly → read that task's section in `results.md` → **run the solution yourself** → note what you'd do differently.

---

## Task 1 — Take inventory of the database
📥 **Inbox:** From MIS Manager · Day 1, 9:00 AM · no rush, but it gates everything else

> "Welcome aboard. Before you touch any report, show me you know the lay of the land: list every table we own, tell me which are facts and which are dimensions, and give me a one-line description of what each one is for. This becomes your cheat sheet."

**Background:** You inherited a 15-table star schema. Everyone on the team keeps a personal map of it; yours starts today.

**Your job:**
1. List all tables from the system catalog (don't type them from memory).
2. Classify each: fact vs dimension, plus the grain (what one row is).
3. For each fact, name its join keys back to dimensions.

**Guiding questions:** Why are facts big and dims small? Which fact looks suspiciously small, and what does that say about its grain? Which table exists so every other date has a home?

**Data pointers:** `_reference/data_dictionary.md`; `_reference/datasets.md` §3 (row estimates).

**Done when:**
- [ ] Catalog query lists every table (nothing typed by hand)
- [ ] Comment block classifies each: fact/dim + grain + 2–3 join keys
- [ ] Saved as `work/attempt_1.sql`

---

## Task 2 — Count January interactions by team
📥 **Inbox:** From Operations Manager · Mon 8:12 AM · "need it before the 9:30 stand-up"

> "Quick one: how many interactions did we make in January, per team? Sorted top-down. And if you have 30 seconds, per day too — I want to see the shape of the month."

**Background:** First working Monday of February. The ops manager opens stand-up with volume, every week.

**Your job:**
1. Total January interactions.
2. Per team — the team name does NOT live in the interactions table; find who carries it.
3. Bonus: same count per calendar day, chronological.

**Guiding questions:** What makes your date filter safe if this column becomes a timestamp next year? After joining to get team names, does the total still match step 1? If not, what leaked?

**Data pointers:** `fact_interactions`, `dim_employees`.

**Done when:**
- [ ] Three result sets: total, per-team (desc), per-day (asc)
- [ ] Per-team counts sum back to the total (you actually checked)
- [ ] Saved as `work/attempt_2.sql`

---

## Task 3 — RPC% by channel, done properly
📥 **Inbox:** From Dialer Vendor Manager · Wed 2:05 PM · "vendor QBR tomorrow"

> "The vendor claims our FICO-sourced accounts connect worse than dialer ones. Before tomorrow's QBR I need RPC% split by channel. Careful with the denominator — the last intern divided by attempts and made us look terrible."

**Background:** RPC% = Right-Party Contacts ÷ Connected calls. Channel records how the call was placed.

**Your job:**
1. Q1 2025: connected calls, RPCs, RPC% per channel.
2. Make division NULL-safe — one empty group must not crash the query.
3. Reconcile against the project's official contact view.

**Guiding questions:** Why `100.0 *` instead of `100 *`? Which official view already computes this — do your numbers match it exactly?

**Data pointers:** `fact_interactions` (`calls_connected`, `rpc_flag`, `channel`); `_reference/kpi_glossary.md` → RPC%; cross-check: `v_contact_metrics`.

**Done when:**
- [ ] One query: per-channel connected / RPC / RPC%
- [ ] NULL-safe division
- [ ] Reconciled against `v_contact_metrics`, difference explained in a comment

---

## Task 4 — Biggest overdue accounts at month-end
📥 **Inbox:** From Team Manager, Recoveries · Thu 4:40 PM · "allocation meeting Friday"

> "Give me the ugliest 25 accounts at March month-end: most arrears first, with product, bucket, and balance. That's who we hand to senior collectors on Friday."

**Background:** Month-end snapshots freeze every account's state — the fair basis for allocations, not today's moving numbers.

**Your job:**
1. March 31 snapshot rows only.
2. Delinquent book only, worst arrears first, cap at 25.
3. Add product type and balance for context.

**Guiding questions:** Why filter to the snapshot date instead of "latest data"? Arrears vs balance — which one ranks collection urgency, and why?

**Data pointers:** `fact_eom_snapshot`, `dim_accounts`.

**Done when:**
- [ ] Exactly 25 rows, March 31 only, Mora only, arrears desc
- [ ] Product + balance included

---

## Task 5 — The 8:40 morning pack
📥 **Inbox:** From Ops Lead · daily 8:40 AM · "numbers in my hands by 8:55"

> "Same as every morning: yesterday's contacts, connects, promises, payments. Four numbers, sticky-note format. Go."

**Background:** The most frequent request of your career. Speed comes from a saved script, not fast typing.

**Your job:**
1. One script taking a single date, returning: interactions, connected calls, promises logged, payments received.
2. Parameterize the date ONCE at the top so tomorrow you change one character.
3. Run it end-to-end in under a minute.

**Guiding questions:** Are these four numbers even in the same table? What's the cheapest correct way to combine counts from different tables? On the Tuesday after a Monday holiday, does "yesterday" mean what the boss thinks?

**Data pointers:** `fact_interactions`, `fact_ptp_log`, `fact_payments`; `_reference/datasets.md` §6 (do your four numbers feel plausible?).

**Done when:**
- [ ] One saved script, single date variable
- [ ] Exactly four numbers out, any date in
- [ ] Under a minute, end to end

---

## Task 6 — How are clients actually paying?
📥 **Inbox:** From Channel Strategy Analyst · Tue 10:15 AM · "steering deck Friday"

> "I need May payments split by method — Online vs Branch/ATM vs OFI — count and dollars. OFI is supposedly growing; prove it or kill it."

**Background:** Payment method shows where to push digital adoption. Counts alone lie: two methods can tie on volume while one triples in dollars.

**Your job:**
1. May 2025 payments by `payment_method`: count + total dollars.
2. Add each method's share of dollars.
3. Sort by dollar share descending.

**Guiding questions:** When do count-share and dollar-share disagree strongly, and what does that mean business-wise? Why cast before dividing for the percentage?

**Data pointers:** `fact_payments` (`payment_method`, `amount_paid`).

**Done when:**
- [ ] Per-method count + dollars + dollar-share
- [ ] Shares sum to ~100% (checked)

---

## Task 7 — What do we collect? Products 101
📥 **Inbox:** From New Team Member · any day · "onboarding favor"

> "You know this DB, right? One query: accounts per product plus average credit limit. And tell me if the denormalized product column makes the join unnecessary — I keep forgetting its name."

**Background:** Three retail products: Tarjeta (credit card), Prestamo (personal loan), Hipoteca (mortgage). The accounts table carries `product_type` directly — a deliberate design choice you should understand.

**Your job:**
1. Accounts per product + average credit limit.
2. Answer the favor: prove whether joining the products dimension would change anything.

**Guiding questions:** If `product_type` on the account can disagree with the product table's name, which would you trust — and how would you check? What does average credit limit tell you that count alone doesn't?

**Data pointers:** `dim_accounts` (`product_type`, `credit_limit`), `dim_products`; `_reference/data_dictionary.md`.

**Done when:**
- [ ] One query: per-product accounts + avg credit limit
- [ ] Written answer: does the dimension join add anything here?

---

## Task 8 — House rules check: weekends
📥 **Inbox:** From QA-minded Supervisor · Fri 3:30 PM · "before I sign off your onboarding"

> "Our data rules say no calls happen on weekends but payments can. I don't take rules on faith — prove both from the data, one query each."

**Background:** The generator encodes business rules; verifying them from data is how analysts catch broken pipelines early. This exact check has caught real bugs in this project's history.

**Your job:**
1. Count interactions landing on Sat/Sun (any month).
2. Count weekend payments.
3. Write one sentence stating each rule as verified true/false.

**Guiding questions:** Which date function gives you weekday without locale tricks? If weekend interactions were nonzero, what would you do first — doubt the data or doubt the rule?

**Data pointers:** `fact_interactions.interaction_date`, `fact_payments.payment_date`; `_reference/data_dictionary.md` → status/flag cheat sheet.

**Done when:**
- [ ] Two counts with a clear verdict each
- [ ] Verdicts match `_reference/datasets.md` §1 claims

---

## Task 9 — Freshness check before you hit send
📥 **Inbox:** From MIS Manager · recurring · "nothing leaves this desk without it"

> "New house rule: before ANY number leaves your desk, you run a freshness check — newest date per fact table, oldest gap flagged. Build the script once; run it forever."

**Background:** Stale-data embarrassments end careers faster than wrong formulas. The project even ships a view for this idea; your job is to build your own and then compare.

**Your job:**
1. Newest date per fact table, labeled, one result set.
2. Add days-since-that-date relative to the latest of all of them.
3. Compare your output to the official freshness view.

**Guiding questions:** Which table will always lag the others, and why is that normal? Which two tables should move together day by day — and if they ever diverge, what does that suggest?

**Data pointers:** all six fact tables' date columns; cross-check: `v_data_freshness`; `_reference/datasets.md` §4 (view inventory).

**Done when:**
- [ ] One query: per-fact max date + days-behind
- [ ] Compared against `v_data_freshness`, differences annotated
- [ ] Saved as `work/freshness_check.sql` — this one stays in your toolbox

---

## Finish

Nine scripts saved. You can now survive the morning-requests layer of this job. Next: [`../medium/tasks.md`](../medium/tasks.md) — joins with intent, CTEs, and the traps that bite at month-end.
