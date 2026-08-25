# git-cli — Results (worked commands)

Run everything. Git rewards muscle memory; reading alone teaches nothing here.

---

## Task 1 — Read the newspaper

```bash
git status                 # staged (index) / unstaged (working tree) / untracked
git log --oneline -15      # one line per commit: hash + subject
git diff                   # unstaged changes vs index (context lines start with space)
git diff -- file.sql       # scoped to one file
git status --ignored       # what .gitignore deliberately hides
```

**Reading the output:** staged = will be in next commit; unstaged = modified but not selected; untracked = git has never seen it. `work/` is ABSENT from untracked because `.gitignore` covers it — ignored ≠ invisible, it's *deliberately* unseen.

**Verify yourself:** pick any `+`/`-` pair in a diff and paraphrase the change aloud — that's the skill.

---

## Task 2 — Diff before you send

```bash
git diff work/report.sql                # classic patch view
git diff --word-diff work/report.sql    # inline word-level — catches typos best
git diff > work/review.patch            # sendable artifact for reviewers
git diff --stat                         # which files changed and how much
```

**Why each variant:** classic shows structure; word-diff surfaces a stray character inside an unchanged-looking line (`WHERE dat >= '2025-01-0'`); `--stat` is the "did I touch anything I forgot about?" sweep.

**Habit:** `git diff --stat` then full diff on anything with real changes — 30 seconds before every send.

---

## Task 3 — Commit like a grown-up

```bash
git status                       # choose ONE logical unit
git add learning/git-cli/work/report.sql
git diff --cached                # REVIEW exactly what's staged — the pre-commit gate
git commit -m "docs(learning): add MIS report query drill for git-cli track"
git log --oneline -3             # confirm shape matches repo voice
```

**Why each part:** path-scoped add beats `-A` unless you've reviewed everything; `--cached` shows the COMMIT'S future contents, not your working tree. Repo style: imperative mood ("add", not "added") — messages describe what the commit DOES to the repo.

**Verify yourself:** `git show --stat HEAD` — exactly the files you intended, nothing else.

---

## Task 4 — Branch: the new MIS variant

```bash
git switch -c feature/mis-variant-clientX     # create AND switch (modern syntax)
echo "-- clientX override" >> learning/git-cli/work/report.sql
git add learning/git-cli/work/report.sql
git commit -m "feat(learning): clientX pack variant draft"
git switch main                                # tree reverts to main's state
git branch -v                                  # both branches, last commits side by side
git switch feature/mis-variant-clientX         # back into the experiment
```

**Why each part:** branches are cheap pointers, not copies — switching swaps your working tree instantly. Main staying shippable while experiments live elsewhere IS the workflow the JD's "multiple projects simultaneously" assumes.

**Verify yourself:** after switching to main, confirm your edit is absent from the file; switch back, it returned. That disappearance act is the whole concept made visible.

---

## Task 5 — Merge conflict on report SQL

Manufacture it:

```bash
git switch main
# edit work/report.sql line 1: WHERE month = '2025-07'
git commit -am "chore: main uses July filter"
git switch feature/mis-variant-clientX
# edit SAME line: WHERE month = '2025-08' AND team = 'Team 4'
git commit -am "chore: variant uses August + Team 4"
git merge main            # CONFLICT
```

The file now contains:

```text
<<<<<<< HEAD
WHERE month = '2025-08' AND team = 'Team 4'
=======
WHERE month = '2025-07'
>>>>>>> main
```

Resolve by hand (keep BOTH intents if that's correct):

```sql
WHERE month BETWEEN '2025-07' AND '2025-08'
  AND team = 'Team 4'
```

```bash
git add learning/git-cli/work/report.sql
git commit                      # merge-resolution commit opens with default message
```

**Marker anatomy:** between `<<<<<<<` and `=======` = YOUR branch (HEAD); between `=======` and `>>>>>>>` = incoming (main). Resolution is editing the file to its true final form, then staging — git doesn't guess intent.

**Verify yourself:** `git log --graph --oneline -6` should show the two histories joining at the merge commit.

---

## Task 6 — Revert the bad load

```bash
git log --oneline -4                     # spot the bad commit hash
git revert <hash>                        # creates an INVERSE commit — history preserved
git log --oneline -6                     # bad commit still there, undone by a new one
```

Reset family (private/unpushed contexts ONLY):

```bash
git reset --soft HEAD~1   # undo commit, keep changes staged
git reset --hard HEAD~1   # undo commit AND delete the changes — destructive
```

**Why revert wins on shared branches:** rewriting history others have pulled forces everyone to untangle; revert appends truth ("this was wrong, here's the correction") — auditable, which is exactly the governance posture this JD demands.

**Verify yourself:** after revert, the working file equals pre-bad state; `git log` tells the honest story including the mistake.

---

## Task 7 — Stash under pressure

```bash
# mid-edit on next month's pack...
git stash push -m "wip: august pack draft"      # named stashes save future-you
git stash list                                   # stash@{0} visible
git status                                       # clean tree — handle the fire
# ...urgent fix + commit...
git stash pop                                    # edits return; conflicts reported if any
```

**Gotchas worth hitting once:** pop can conflict if the urgent commit touched the same lines — resolve like Task 5. Untracked files need `git stash -u`. Named messages turn `stash list` from archaeology into inventory.

**Verify yourself:** checksum your WIP file before stashing and after popping (`git diff --no-index` or eyeball) — byte-identical return.

---

## Task 8 — Tag the monthly pack release

```bash
git tag -a monthly-pack-2025-07 <commit-hash> -m "July monthly pack as shipped"
git show monthly-pack-2025-07                    # the exact state + message, forever retrievable
git log --graph --oneline -20                    # branching rhythm made visible
```

**Why annotated (-a):** carries author, date, message — a label with provenance, matching how finance archives period-end artifacts. Lightweight tags are fine for throwaway bookmarks only.

**Verify yourself:** `git show` prints the commit your pack shipped from; six months from now that command answers "what EXACTLY went out" without archaeology.
