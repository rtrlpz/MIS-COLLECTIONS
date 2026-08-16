# git-cli — Results (Guidance)

```
learning/
├── _reference/            ← datasets.md, kpi_glossary.md, data_dictionary.md
├── git-cli/               ← YOU ARE HERE
│   ├── README.md
│   ├── tasks.md
│   ├── results.md         ← current file
│   └── work/
├── sql/  python/  notebooks/  excel/  powerbi/
└── README.md
```

**How to use this file:** attempt → run → read one section. This is the one module where **commands ARE the lesson** — so unlike the analysis tracks, results show the syntax and the *model* behind it. No scratch-data is permanent: everything is your `work/` scratch.

---

## Task 1 — Read the newspaper

**Thinking path:**
- `git status` has three sections, and their names ARE the model:
  - **Changes to be committed** (staged/index): you've marked them with `git add` — the index is the "next commit" proposal.
  - **Changes not staged** (working tree vs index): edited but not yet proposed.
  - **Untracked files**: exist on disk, git doesn't know them at all.
- `work/` is absent from untracked because of `.gitignore`: git knows about them but *chooses* to ignore (see Task 5) — that's why "untracked" and "ignored" are different concepts.
- `git log --oneline` is the newspaper: who (author), when, and in what order the project moved. Reading history in reverse is the analyst's habit.
- `git diff` reads as: `-` = removed, `+` = added, else context. A file diff is a *recipe* of changes, not a snapshot.

**Verification strategy:**
- After reading, `git status` should still show the repo as you found it (you touched nothing).
- Check `git status --ignored` lists `learning/**/work/*`, `.env`-relevant patterns, and `.ipynb_checkpoints/`.

**Syntax worth having:**
```
git status
git status --ignored
git log --oneline -15
git diff
git diff --cached     # staged-only diff (Task 2 uses this)
```

---

## Task 2 — Commit like a grown-up

**Thinking path:**
- The model has THREE copies of truth: **working tree** (on disk), **index/staging** (`git add`ed — the proposal), **HEAD** (last commit). A commit takes the index and freezes it as history. This is why "I edited but didn't add" produces "nothing happens" — you wrote to the working tree, not to the proposal.
- `git add -A` stages everything untracked+modified + deleted — dangerous when a repo's contract says "don't commit X". Specific-path staging is the grown-up default; `-A` is an explicit, conscious choice.
- Message voice: the repo `log` uses short imperative summaries ("Fix…", "Add…", "Update…"). Imperative = "this commit, when applied, does X" — a stable instruction to future readers. "Fixed…" narrates the past; "Fix…" describes the change.

**Verification strategy:**
- `git diff --cached` before every commit: what you're about to freeze; anything surprising = stage more surgically.
- `git status` after commit shows the proposal emptied and the file in history.

**Syntax worth having:**
```
git add learning/README.md learning/sql/basic/*
git status
git diff --cached
git commit -m "Add learning track scaffolding"
git log --oneline -3
```

---

## Task 3 — Branch without fear

**Thinking path:**
- A **branch** is just a named moving pointer to a commit — it lives in git's *bookkeeping*, not in your files. That's why switching is instant and why your `work/` files look different per branch (the pointers move; the working tree updates the checkout).
- `checkout -b` (or `switch -c`) = create + move to the new pointer. On the branch you commit normally; HEAD moves only that branch's pointer.
- Going back to main: your branch's commits are unreachable from main's pointer — your work "disappears" from the working tree but *exists* as long as the branch does. Two realities, one repo.
- Merge: git walks the history and creates a combining commit. **Fast-forward** = the target branch hasn't moved since you branched, so merge just slides the pointer forward (clean, no merge commit). `--no-ff` forces a merge commit even then (keeps the branch's shape visible). Reviewing `git log --graph` shows the branching reality.

**Verification strategy:**
- `git log --graph --oneline -10` after your merge: does the picture match your drawn branch map?
- A scratch file committed on the branch must NOT exist while on main — that absence is the proof of separation.

**Syntax worth having:**
```
git switch -c learning/report
git switch main            # work vanishes from working tree — expected!
git switch learning/report
git merge learning/report   # or: git merge --no-ff learning/report
git log --graph --oneline -10
```

---

## Task 4 — Delete-proof

**Thinking path:**
- Rescue map (the safety of each command matters more than its name):
  - **Working-tree-only ops (safe)**: `git restore <file>` (or older `checkout -- <file>`) brings a *tracked* file back to its HEAD/commit state; `git restore --staged` unstages. Working tree and index can be overwritten; **history is untouched**.
  - **Stash (interrupted work, safe)**: `git stash` shelves *uncommitted* changes (working tree + staged) into a parking lot; `git stash pop` re-applies them. Confirm your change returns exactly.
  - **History archaeology (read-only)**: `git log --all --oneline` scans all branches; a deleted file is *found* in history via the commit that last had it. Recovering a deleted *committed* file = restore it from that commit. Revoking a bad commit from history (rebasing/push --force) is the **irreversible family** — this module trains you to *never need* it.
- The three-copies mental model again: when you lose something, ask WHICH copy has it (working tree? index? HEAD? a branch? a stash?). Answering that question IS the recovery skill.

**Verification strategy:**
- After `restore`, the file exists with its committed content again.
- After stash→pop, your edit is back — confirm by diffing.
- The archaeology pass: pick a commit, `git show <sha>` read-only, no changes made.

**Syntax worth having:**
```
git restore learning/git-cli/work/probe.txt      # recovered from HEAD
git stash && git status                             # clean working tree
git stash pop
git log --all --oneline                            # archaeology scope = all branches
git show <commit-sha>                               # read-only peek
```

---

## Task 5 — The pact

**Thinking path:**
- `.gitignore` is the wall, but its blind spot: **a file only becomes ignored if it was never tracked**. "Ignored/untracked/absent" are three different protections:
  - *Untracked* = git doesn't know it (safe to commit later).
  - *Ignored* = git refuses to list/commit (wall works ❌ once committed).
  - **Once committed to history, ignoring does NOTHING** — the secret stays in `git log` forever unless you rewrite history (the hard, force-push lesson). Prevention > cure: **never add a secret in the first place**.
- The perma-dirty footgun: `git add .env && echo '.env' >> .gitignore` — the add already happened; the ignore is pretend-protection. The habit: check `.gitignore` FIRST, add SECOND.
- Reading this repo's `.gitignore` should surface: `.env`-class secrets, `data_sources/raw/` (generated — never edit), `learning/**/work/*` + `**/.ipynb_checkpoints/` (practice/noise), and the PBIX. Each rule encodes a *contract*: what may and may not enter history.

**Audit commands to run on any repo you're handed:**
```
git status --ignored                 # what's walls-protected?
git ls-files | grep -E '\.env|secrets?$'     # is a secret already TRACKED? (empty = clean)
git ls-files -- '.gitignore'         # is the ignore file itself tracked?
```

**Verification strategy:**
- `work/probe.env` shows under `--ignored` (= the wall works) and is absent from `git ls-files` (never tracked). Delete it after.
- Final pact (yours, in words): never commit `.env`/credentials; never edit or commit generated CSVs; keep `work/` out of history; check with the two audit commands before believing a repo is clean.

---

### Finish

Your `answers_*.md` files together are the cheat-sheet *in your own words* — that's the deliverable. If any command above behaved unexpectedly, that's the moment to re-read the three-copies model (Tasks 2/4) — the model, not the command, is what scales.

**Move up when:** you can explain working tree vs index vs HEAD to a friend cold, and you reach for `git status --ignored` + `git ls-files | grep` before trusting any repo.