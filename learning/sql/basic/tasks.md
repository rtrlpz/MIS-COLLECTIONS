# SQL — Basic — Tasks

```
learning/
├── _reference/            ← READ FIRST (datasets.md, kpi_glossary.md, data_dictionary.md)
├── sql/
│   ├── README.md
│   └── basic/             ← YOU ARE HERE
│       ├── tasks.md       ← current file
│       ├── results.md     ← answers, peek AFTER attempting
│       └── work/          ← your .sql files live here
├── python/  notebooks/  excel/  powerbi/  git-cli/
└── README.md              ← master guide
```

**Setup:** DB running + data loaded (see `_reference/datasets.md` §5). Create `work/attempt_*.sql` for each task.

**Discipline:** attempt → commit to your answer → then read `results.md` to compare.

---

## Task 1 — Say hello to the star schema

The supervisor says: *"New here? First, tell me what actually lives in this database."*

**What you'll practice:** orienting yourself in a database — the single most underrated senior skill. Senior analysts can *describe* the data model from memory; juniors hunt and peck.

Steps (each with a "why" for *you* to figure out):
1. List every table in the DB.
2. For the fact tables, look at 10 rows each, see what the grain feels like.
3. Write down, in your own words, one sentence per table: *what information does each table hold? How do two tables connect?*
4. Check `_reference/data_dictionary.md` and correct your guesses.

**Guiding questions to answer in `work/attempt_1.sql` comments:**
- Why is `fact_interactions` by far the biggest table?
- Why does `fact_eom_snapshot` exist as a *snapshot* rather than a transaction log — what problem does a snapshot solve?
- `dim_calendar` is a "dimension built from nothing" — what does it give you that raw dates in facts don't?

**Deliverable:** `work/attempt_1.sql` with your exploration queries, plus a short paragraph (as SQL comments) describing the model in your own words.

**Check:** your description should name: 5 dims, 6 facts, and at least 3 join paths.

---

## Task 2 — Count, filter, sort: the classic MIS question

The supervisor asks: *"How many total interactions did we have in January? And for each team, about how many? I need it sorted."*

**What you'll practice:** `SELECT` + `WHERE` + `GROUP BY` + `ORDER BY` — the question template that covers 60% of daily analyst work.

Steps:
1. Total interactions in January 2025 (use the month folder/date you actually have — check what dates exist first; your data spans Jan–Dec 2025).
2. Now per `team_name`. WHERE should you get `team_name` from, and do you need a join?
3. Add a per-day (date) count for one slice of interest — WHY might a daily count reveal something a monthly count hides? (Hint: think weekends and `_reference/kpi_glossary.md` §6 item 7.)
4. Sort by your favorite column and justify the sort choice.

**Guiding questions:**
- When is `COUNT(*)` fine, and when must you `COUNT(DISTINCT …)`? Give a real example from step 2/3 where they'd differ.
- Why must a `WHERE` on an aggregated value in a `GROUP BY` go in `HAVING` instead of `WHERE`? (You'll feel it if you try.)

**Deliverable:** `work/attempt_2.sql` that answers the supervisor's question in ONE query, results pasted as a comment.

**Check:** does your query filter only the intended month (not the whole table)? Does it count *interactions* — one row per call — or did you accidentally count something double? A sanity cross-check: your per-team counts should roughly add up to your Jan total. If they don't, revisit the team join, not the numbers.

---

## Task 3 — Rate columns: what does RPC% really mean?

The supervisor: *"Show me RPC% by channel for January. And tell me why FICO/SMS probably don't belong in the rate."*

**What you'll practice:** computing a **rate from two numerators**, not a stored column. This is THE core analysis move — and the reasons you'll get wrong.

Steps:
1. By channel: count `calls_connected`, count RPCs (`rpc_flag = TRUE`), then RPC%.
2. Think about the denominator before writing SQL: is the rate `RPC / connected` or `RPC / attempted`? Check `_reference/kpi_glossary.md` §1 to confirm.
3. Defend, in a comment, why you chose that denominator. There is a correct answer in this project — find it, don't guess.
4. Notice which channels have few or zero RPCs and reason about whether to include them (glossary §6 item about FICO/SMS).

**Guiding questions:**
- You'll likely first write `AVG(case when rpc_flag then 1.0 else 0 end)`. Then you should realize why computing the *ratio of sums* is more correct. What breaks when you average per-row flags? (Hint: it's the same trap as "averaging daily rates" in glossary §6 item 2.)
- Integer division: why does `rpc::numeric / connected` matter here? What does `1 / 2` return in Postgres if you forget?

**Deliverable:** `work/attempt_3.sql` — channel × RPC% table, along with a comment explaining which channels you chose to include and why.

**Check:** did you compute the rate as a *ratio of sums* rather than an average of flags? Did you use the same filter window for numerator and denominator? Did you make an explicit, defended choice about FICO/SMS — and is it the choice the project's own views make? The rate should be between 0 and 1 as a proportion; if your math produces something >1, your denominators/numerators are mismatched.

---

## Task 4 — The unpaid question: who owes and how much?

The supervisor: *"List the 20 biggest delinquent accounts at month end in Mora state, and tell me how much arrears each carries, plus their product type."*

**What you'll practice:** reading the **portfolio state** table (`fact_eom_snapshot`), combining `WHERE`, `ORDER BY`, `LIMIT`, and picking the right source table for "state" vs "event" data.

Steps:
1. Identify the RIGHT table. Is an account's delinquency a *snapshot state* or a *transaction event*? Justify.
2. For the latest snapshot you have (December 2025), filter `status = 'Mora'` and order by arrears descending, top 20.
3. Bring in `product_type` — do you need `dim_accounts`? (It's denormalized; check `_reference/data_dictionary.md` §2.)
4. Add a column showing total arrears per product type among ALL Mora accounts (not just top 20) — same query family, different slice.

**Guiding questions:**
- Why is the top-20 by arrears NOT the same portfolio as "total by product type"? What logical grouping differs?
- `LIMIT` after `ORDER BY` — what happens to ties at the boundary? (Postgres is nondeterministic there — is that acceptable for a top-20 list? what would *you* do?)

**Deliverable:** `work/attempt_4.sql` — top-20 Mora accounts (account_id, product_type, arrears, balance) + a per-product-type arrears summary.

**Check:** did you pick the *state* table, not an event table? Is your filter on `status = 'Mora'` correct for the latest snapshot? Do the two deliverables (top-20 vs product-type aggregate) answer *different* questions — and can you explain, in words, what each one is for? The lesson is the contrast between "biggest individual exposures" and "largest total buckets" — they are often different portfolios, and the *why* is the point.

---

### Finish

When all four tasks are attempted (right or wrong), save each file, then read `basic/results.md` and compare. Update your files with a short note on what differed — that note is your progress log.

**Move up when:** you can write Task 2's query from memory without looking at notes.