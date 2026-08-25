# git-cli — Your Inbox (single level)

```
You are here: learning/git-cli/
Setup:    one terminal at the project root — you ARE inside a repo already (`git status` to confirm)
Lab:      disposable practice files go in work/ (git-ignored); nothing here can hurt real work
Solutions:results.md — after attempting; run every command yourself
Why:      the JD's world runs on versioned deliverables — "show me what changed" is a daily question
```

---

## Task 1 — Read the newspaper
📥 **Inbox:** From MIS Manager · Day 1 · "recon before you touch anything"

> "Before your first commit here, prove you can read the room: what's changed in the working tree, what's the project been doing lately, and what's deliberately ignored. Words, not screenshots."

**Your job:** `status` (three zones explained) · `log --oneline -15` (3-sentence history summary) · `diff` on an untouched-but-modified file (context vs +/− lines) · `status --ignored` (why generated data/secrets live there).

**Done when:** `work/answers_1.md` covers all four reads in plain words.

---

## Task 2 — Diff before you send
📥 **Inbox:** From Head of MIS · recurring · "house rule now"

> "New rule: no report or query ships until YOU have read its own diff end to end. Practice on a scratch file: make three edits (one typo, one real change, one debug line), then produce the exact diff command that would have caught all three."

**Your job:** craft changes in `work/report.sql` · review via diff variants (`git diff`, `git diff --word-diff`, redirecting to a file) · write which variant catches what.

**Done when:** answers note which edit each diff style surfaces best.

---

## Task 3 — Commit like a grown-up
📥 **Inbox:** From MIS Manager · Day 2 · "atomic or nothing"

> "Ship ONE logical change from your work area: stage only it, inspect what's staged BEFORE committing, message in this repo's imperative voice. Nothing unrelated smuggles in."

**Your job:** stage specific paths (never blanket `-A` reflexively) · `git diff --cached` review · commit matching `git log` style · show the resulting one-line log entry.

**Done when:** answers_3.md: chosen message + why, what stayed unstaged, your personal staging rule.

---

## Task 4 — Branch: the new MIS variant
📥 **Inbox:** From Operations Manager · Tue 10:00 · "experimental version, don't break main"

> "We're piloting a variant of the monthly pack for one client. Do that work on a BRANCH — main stays shippable. Show me branch creation, a commit landing there, and how you'd flip between the two worlds."

**Your job:** create `feature/mis-variant-clientX` from main · add a file + commit on it · switch back/forth and observe the working tree change · `git branch -v` reading.

**Done when:** answers_4.md: commands used + what surprised you switching branches.

---

## Task 5 — Merge conflict on report SQL
📥 **Inbox:** From MIS Manager · Wed 2:00 · "this WILL happen on the team someday"

> "Deliberately manufacture a merge conflict: same lines edited on two branches, then merge. Resolve it CORRECTLY (both intents preserved where sensible), commit the resolution, and explain the conflict markers."

**Your job:** edit the same SELECT differently on two branches · merge → observe the conflict · open the file, decode `<<<<<<< ======= >>>>>>>` · resolve, add, commit.

**Done when:** answers_5.md: marker anatomy + your resolution rationale.

---

## Task 6 — Revert the bad load
📥 **Inbox:** From Ops Lead · Thu 9:30 · "yesterday's commit broke the pack query"

> "A committed change turned out wrong. Undo it PUBLICLY (history stays honest — no history rewriting), then explain why revert beats reset on shared branches."

**Your job:** make a bad commit on your practice branch · `git revert` it · inspect log before/after · also try `git reset --soft` vs `--hard` on throwaway commits to feel the difference.

**Done when:** answers_6.md: revert output explained + when reset IS acceptable (private, unpushed).

---

## Task 7 — Stash under pressure
📥 **Inbox:** From Operations Manager · any day 8:20 · "urgent ask mid-work"

> "You're mid-edit on next month's pack when an urgent request lands. Park your half-done work safely, handle the fire on a clean tree, then restore exactly where you left off."

**Your job:** start edits in work/ · `git stash` (+ `list`, `show`) · verify clean tree · do a trivial urgent commit · `git stash pop` and confirm your edits returned intact.

**Done when:** answers_7.md: stash workflow + one gotcha you hit (conflicts on pop, untracked files flag).

---

## Task 8 — Tag the monthly pack release
📥 **Inbox:** From Head of MIS · month-end · "which exact files went out?"

> "The July pack shipped. Mark that exact state so we can retrieve it forever: annotated tag, pushed meaningfully, found again. Then read the project's history shape with log --graph."

**Your job:** create annotated tag `monthly-pack-2025-07` on a chosen commit · `git show <tag>` retrieval drill · `git log --graph --oneline -20` interpretation.

**Done when:** answers_8.md: tag/show outputs summarized + what --graph taught you about branching rhythm.

---

## Finish

Eight drills. Git is now a tool you think WITH, not around. Revisit [`../README.md`](../README.md) — every track assumes these habits.
