# Power BI Basic — Your Inbox (level 1 of 3)

```
You are here: learning/powerbi/basic/
Assumed:      sql/basic done — you know the tables and the KPI definitions
Setup:        Power BI Desktop; save attempt_*.pbix + a page screenshot per task into work/
Solutions:    basic/results.md — after attempting; then REBUILD the solution model yourself
House rule:   measures are code. Name them, describe them, keep them in one place.
```

**What this level gives you.** A working import-mode model of the collections star schema, your first correct measures, and one page a manager could actually read — plus the date-table and slicer hygiene that stops month-two pain before it starts.

---

## Words you'll meet

| Term | Plain meaning |
|---|---|
| **Import mode** | Data is copied INTO the .pbix at refresh; fast, in-memory — this project's standard |
| **Star schema** | Fact tables (events) related to dimension tables (things), one-to-many from dim to fact |
| **Measure** | A calculation computed AT QUERY TIME (`DIVIDE`, `CALCULATE`) — never a pasted column |
| **Date table** | The calendar dimension marked as THE date table so time intelligence works |
| **Slicer** | The filter dropdown/panel a manager plays with |

---

## Task 1 — The model mirrors the schema
📥 **Inbox:** From MIS Manager · Day 1 · "before any visuals"

> "Connect to the collections database, Import mode, and bring in the star: our five core dimensions and the interaction fact. Relationships should look like the database's own keys — if Power BI guessed something weird, fix it and tell me what it guessed."

**Your job:**
1. Import `dim_employees`, `dim_clients`, `dim_products`, `dim_accounts`, `dim_calendar`, `fact_interactions`.
2. Verify each relationship is dim(1) → fact(*), single direction.
3. Hide every key column from report view.

**Done when:**
- [ ] Six tables imported, relationships exactly as the SQL keys define
- [ ] No key columns visible to report authors
- [ ] Screenshot of Model view in `work/`

---

## Task 2 — First measures: RPC% that can't lie
📥 **Inbox:** From Ops Lead · Tue 9:30 · "the number everyone quotes"

> "I need RPC% as a real measure — not a calculated column. It must survive being sliced by team, channel, month, whatever. And divide-by-zero months must show blank, not infinity."

**Your job:**
1. Base measures in a dedicated empty table: Total Interactions, Connected Calls, RPC Count.
2. `RPC %` built with the safe-divide pattern.
3. Format as percentage, one decimal; write a description on every measure.

**Done when:**
- [ ] Four measures, all in `_Measures` table
- [ ] Descriptions filled; % formatting applied
- [ ] Blank shows for a slice with zero connects (you tested one)

---

## Task 3 — One honest page
📥 **Inbox:** From Operations Manager · Thu 3:00 PM · "Monday leadership sync"

> "One page: interactions trend by month, RPC% by team, a couple of KPI cards on top. Nothing clever. If I can't explain each visual in one sentence, it doesn't ship."

**Your job:**
1. Cards: interactions, connected calls, RPC count.
2. Line/column: monthly interactions trend.
3. Bar: RPC% by team, sorted worst-first (that's the point of the meeting).

**Done when:**
- [ ] Three visuals, no chartjunk, consistent colors
- [ ] Every visual has a one-sentence title saying WHAT it shows
- [ ] Screenshot saved; page passes the read-aloud test

---

## Task 4 — Formatting is not decoration
📥 **Inbox:** From MIS Manager · Fri 11:00 · "the director opened it on a projector"

> "Numbers rendered at default size are unreadable past row two. Standardize: one font story, thousands separators, aligned card labels, and titles that state the grain ('Monthly', 'by Team'). Ship me the polished page."

**Your job:**
1. Set explicit display units + decimals everywhere.
2. Consistent title format across all three visuals.
3. Align visuals to a grid; export a screenshot at presentation size.

**Done when:**
- [ ] No default-size text anywhere
- [ ] Titles carry grain info
- [ ] Projector-legible screenshot saved

---

## Task 5 — Mark the date table (or time intelligence will bite)
📥 **Inbox:** From MIS Manager · Mon 10:00 · "gate check before medium level"

> "Confirm the calendar dimension is marked as the model's date table, spans our full data range including the pre-month buffer, and that auto date/time is OFF. Then prove month sorting works: month names must order January→December, not alphabetically."

**Your job:**
1. Turn off Auto date/time for the file.
2. Mark `dim_calendar` as date table on its `date` column.
3. Add a month sort column usage: month_name sorted by month_num.

**Done when:**
- [ ] Auto date/time disabled (options screenshot)
- [ ] Date table marked
- [ ] A matrix shows months in calendar order

---

## Task 6 — Slicer hygiene
📥 **Inbox:** From Ops Lead · Wed 2:00 PM · "managers keep breaking the page"

> "Add year/month/team slicers. Single-select for month — someone always multi-picks and screenshots nonsense. And make sure slicing one visual doesn't nuke the cards people use as headline numbers."

**Your job:**
1. Three slicers wired correctly; month set to single-select.
2. Review edit-interactions: decide deliberately which visuals cross-filter.
3. Document the choice in the page footer note.

**Done when:**
- [ ] Month slicer cannot multi-select
- [ ] Interaction choices deliberate (screenshot of settings)
- [ ] Footer note explains the behavior to future users

---

## Finish

Six artifacts in `work/`. Your model now matches production's shape and your first measures are defensible. [`../medium/tasks.md`](../medium/tasks.md) makes them move through time.
