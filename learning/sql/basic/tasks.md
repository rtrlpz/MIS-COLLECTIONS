# SQL Basic — Tasks (level 1 of 3)

```
You are here: learning/sql/basic/
Read first:   _reference/datasets.md and _reference/kpi_glossary.md (10 min, one time)
Your answers: work/attempt_1.sql, attempt_2.sql …  (this folder's work/ is your scratchpad)
Guidance:     basic/results.md — open ONLY after attempting each task
```

**What this level gives you.** After these four tasks you can answer the most common analyst requests straight from the database — *"how many?", "how much?", "who are the biggest?"* — which covers a large share of day-to-day reporting work.

---

## Words you'll meet in these tasks

Plain definitions — the reference docs go deeper:

| Term | Plain meaning |
|---|---|
| **Table** | One spreadsheet-like dataset inside the database |
| **Fact table** | One row per *event*: a call made, a promise logged, a payment received. These tables are big |
| **Dimension table** | One row per *thing*: an agent, an account, a client, a calendar day. These tables are small |
| **Star schema** | The standard analytics layout: facts in the middle, dimensions around them, connected by ID columns |
| **Grain** | What ONE row represents ("one row per call"). Always identify this before trusting any count |
| **Snapshot** | A photo of *state at a date* (e.g., every account's balance at month-end) — different from an event log |

---

## How to work through a task

Each task has the same shape:

1. **The request** — how it would arrive at work (message from your supervisor).
2. **Steps** — what to do, with the *why* attached.
3. **Guiding questions** — answer them as comments in your attempt file; they're where the real learning is.
4. **Deliverable + Done when** — what to produce and how you know it's right.

Discipline: write your honest attempt first, then read that task's section in `results.md`. Keep "wrong" files — the fix is the lesson.

---

## Task 1 — Take inventory of the database

> **The request.** First week on the job. Your lead says: *"Before you touch anything, tell me what data we actually have here."*

You'll practice the most underrated senior skill: orienting yourself in an unfamiliar database quickly.

Steps:

1. Ask the database for its list of tables. Every client shows it somehow — DBeaver's sidebar tree, pgAdmin's browser, or a catalog query in `psql`. *Why:* never memorize a schema from documentation alone; look at the live thing.
2. Preview about ten rows from each fact table. *Why:* grain can't be learned from column names — you feel it by seeing rows.
3. Write one sentence per table in your own words: what it holds, and which other tables it connects to.
4. Only now open `_reference/data_dictionary.md` and correct your guesses.

Guiding questions (answer in comments):

- Why is the interactions table so much bigger than everything else?
- Why does the month-end snapshot exist as a *snapshot* instead of logging events like the payment table does? What problem does each style solve?
- The calendar table was built from nothing — every analyst could generate dates themselves. What does having it as a proper dimension buy you?

**Deliverable:** `work/attempt_1.sql` — your exploration queries, plus a short paragraph (as comments) describing the model in your own words.

**Done when:** your description names the 5 dimensions, the 6 facts, and at least 3 connections between tables — and another person could join two tables correctly using only your description.

---

## Task 2 — Count January by team

> **The request.** Monday standup: *"How many calls did we make in January — total, and per team? Sorted so I can read it."*

You'll practice the classic pattern behind most daily reporting: filter to a period, split by a category, order the result.

Steps:

1. Total interactions for January 2025. First check what dates actually exist in the data. *Why:* filtering on an assumed range is how reports silently miss rows.
2. Now the same number per team. Find where team names live before joining anything. *Why:* fact tables carry IDs, not labels — knowing where labels live tells you whether a join is needed at all.
3. Add a per-day count for one team you find interesting. *Why:* a monthly total hides the shape of the month; daily numbers reveal quiet days and spikes.
4. Sort the result and be ready to say why you sorted that way. *Why:* sort order is how you decide what the reader sees first.

Guiding questions:

- When is counting all rows fine, and when must you count distinct values instead? Give a concrete example from this data where the two differ.
- If you want to keep only groups above some size, why can't that condition go in the same place as your date filter? (Try putting it there and read the error.)

**Deliverable:** `work/attempt_2.sql` — one query answering the supervisor's full question, with results pasted as comments.

**Done when:** your per-team counts roughly add up to your January total (if not, the join leaked or duplicated rows — revisit the join, not the numbers).

---

## Task 3 — Compute RPC% by channel properly

> **The request.** *"Show me RPC% by channel for January. And tell me whether FICO and SMS belong in that rate."*

RPC% = Right Party Contact % — of the relevant denominator, the share of contacts where the agent reached the right person. You'll practice THE core analysis move: building a rate from two counts, correctly.

Steps:

1. Before writing any query: define in plain words what the top of the fraction counts and what the bottom counts. *Why:* most wrong rates are wrong because the denominator was chosen carelessly.
2. Confirm the official definition in `_reference/kpi_glossary.md`. There is a documented correct answer — don't guess.
3. By channel: count connected calls, count RPCs, compute the rate. Watch out for integer math truncating your division.
4. Look at which channels have almost no activity and make a deliberate, written decision about including them.

Guiding questions:

- Averaging a per-row yes/no flag feels equivalent to computing a rate — but it isn't when groups have very different sizes. Why not? (Same reason averaging daily rates misleads.)
- What happens if numerator and denominator use slightly different filters — and what would that do to your rate?

**Deliverable:** `work/attempt_3.sql` — channel × RPC% table, plus a comment explaining your channel decision.

**Done when:** you computed the rate as total-over-total (not an average of flags), both sides use the same filters, your defended channel choice matches the project's own convention, and every rate sits sensibly between zero and one.

---

## Task 4 — Biggest overdue accounts at month-end

> **The request.** Month-end review: *"List our 20 biggest delinquent accounts ('Mora' status) at December month-end — arrears amount and product type. Also, which product type carries the most total arrears overall?"*

You'll practice choosing the right *kind* of table — state vs events — and see two different business questions come from the same data.

Steps:

1. Decide which table answers "who is delinquent at month-end": a state snapshot or an event log? Write your justification down. *Why:* picking the wrong table type is the classic beginner error, and the reasoning transfers to every future project.
2. Filter to the latest snapshot, Mora status only, biggest arrears first, take twenty.
3. Bring in product type. Check the dictionary — you may not need to hop through the products table at all.
4. Separately compute total arrears per product across ALL Mora accounts (not just the top twenty). Notice these are two different questions.

Guiding questions:

- Why can the "top 20 individual exposures" list tell a different story than the "total per bucket" summary? Who in the business cares about each one?
- Taking exactly the top N quietly drops ties — is that acceptable here? What would you change for an official list?
- Why should the snapshot date be pinned explicitly rather than "whatever rows happen to be there"?

**Deliverable:** `work/attempt_4.sql` — the top-20 list plus the per-product totals, with your two-lenses explanation in comments.

**Done when:** you used the snapshot table (and can say why), pinned the latest date explicitly, have no duplicate accounts in the top-20, and your per-product totals sum to the grand total over all Mora accounts.

---

## Finish

Attempt all four (right or wrong), then read `basic/results.md` and compare approaches. For each task add a short note in your file: *what differed between my approach and the guidance.* That note trail is your progress log — and interview material.

**Move up to medium when:** you can write Task 2's query from memory, no notes.
