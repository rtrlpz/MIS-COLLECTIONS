# git-cli — Tasks

```
learning/
├── _reference/            ← READ FIRST: datasets.md, kpi_glossary.md, data_dictionary.md
├── git-cli/               ← YOU ARE HERE
│   ├── README.md
│   ├── tasks.md           ← current file
│   ├── results.md         ← guidance, peek AFTER attempting
│   └── work/
├── sql/  python/  notebooks/  excel/  powerbi/
└── README.md
```

**Setup:** one terminal, `cd` to the project root (you're *inside* a git repo already). Confirm with `git status`. Create scatch files under `learning/git-cli/work/` for the tasks that need a lab.

**Discipline:** attempt → run → observe → read `results.md`. Nothing here is destructive to your real work: you'll practice on disposable `work/` files.

---

## Task 1 — Read the newspaper: status, log, diff

The supervisor: *"Before you touch anything, show me you read it: what's changed, what's tracked, and what the team has committed."*

**What you'll practice:** the read-only trio — `status` (working tree), `log` (history), `diff` (uncommitted changes) — the analyst's reconnaissance.

Steps:
1. `git status` — describe in words what the three sections mean (staged / unstaged / untracked). Why is `learning/…/work/` absent from untracked?
2. `git log --oneline -15` — read the recent commits like a newspaper: what was the project doing, in what order?
3. `git diff` on a real file (touch none — just read). What does a diff *line* mean (context vs added vs removed)?
4. `git status --ignored` briefly: what's being ignored, and why does that protect the repo (secrets, generated data)?

**Guiding questions:**
- Untracked vs ignored: same-ish output, completely different meaning. When would a file be *both* wanted and unwanted?
- If you never ran git, how would you answer "what changed this week" for this repo? (That's the gap this module closes.)

**Deliverable:** `work/answers_1.md` — your words: what the three status sections mean, a 3-line summary of the repo's recent history, and what you saw in the ignore list.

---

## Task 2 — Commit like a grown-up

The supervisor: *"Ship the learning docs. Staged deliberately, message that a stranger understands, and nothing unrelated sneaks in."*

**What you'll practice:** the staging model (index vs working tree), *atomic* commits (one logical change), and a commit-message style that matches this repo.

Steps:
1. `git status` — find what's actually changed. Pick ONE logical unit (e.g., the `learning/` scaffolding docs if new).
2. Stage **only that unit** (`git add` the specific paths). Show `git status` again — what are the two zones now?
3. Commit with a message in the repo's existing voice (read `git log --oneline` first; match the imperative-tense style).
4. Check the diff of what you *staged* (`git diff --cached`) before committing — staged-but-unintended files would be the crime here.

**Guiding questions:**
- `git add -A` vs staging specific paths: when is "everything" genuinely OK, and when does it smuggle secrets or junk in?
- Why does the repo style favor short imperative messages — what does "Fixed…" vs "Fix…" communicate about *who* did the thinking?

**Deliverable:** `work/answers_2.md` — the commit message you chose and why, what you deliberately left unstaged, and the rule you'd apply to your own future commits.

---

## Task 3 — Branch without fear

The supervisor: *"Work on a report without touching the main line. Branch it, muck about, merge it back cleanly."*

**What you'll practice:** branches as *parallel realities* — `branch`, `checkout`/`switch`, `merge`, and the discipline of a clean merge vs an entangled one.

Steps:
1. Create a branch (e.g., `learning/report`) and switch to it (note: `-b` does both). Confirm with `git status`.
2. In `work/`, write two scratch files; commit them on the branch.
3. Switch back to the main branch — confirm your work is *absent* there (it is — that's the point of branches). Switch back.
4. Merge the branch into main. Review the merge with `git log` — does history look clean, and can you explain what `--no-ff`-style vs fast-forward would change?

**Guiding questions:**
- Where does a branch "live": in the files or in git's bookkeeping? (The answer explains why checking out is instant.)
- What happens to a commit that exists on both branches after a merge — duplicated files, or one history?

**Deliverable:** `work/answers_3.md` — your branch map (create → commit → switch → merge) drawn in words, plus the answer to the fast-forward question.

---

## Task 4 — Delete-proof: recovering from your own chaos

The supervisor: *"You just deleted a file you needed. Prove you can get it back — and that you can look at an old version of the repo without destroying the current one."*

**What you'll practice:** the recovery toolkit — `checkout`/`restore` for a file, `stash` for interrupted work, and `log` archaeology for deleted things.

Steps:
1. In `work/`, create+commit a scratch file, then delete it from disk. Recover it from the last commit (`git restore`-class).
2. Now modify a second scratch file but DON'T commit. `git stash` it, confirm the working tree is clean, then `git stash pop` — note where your change went and that nothing was lost.
3. Find something from history: `git log --all --oneline` — can you spot a commit whose path no longer exists? (The `learning/` history may show renamed/deleted paths — archaeology.)
4. Freedom check: which of these commands touch *history* (irreversible-ish), which touch only the *working tree* (safe)? State the rule you'll run by.

**Guiding questions:**
- Recover a *deleted file* vs recover a *bad edit*: same command family? Different? Which is riskier?
- Why is "just Ctrl+Z" a bad mental model for git? (Hint: the working tree vs the index vs HEAD — three copies of truth.)

**Deliverable:** `work/answers_4.md` — the three rescue moves demonstrated in words + your safe-vs-touching-history rule.

---

## Task 5 — The pact: secrets, ignores, and a clean repo

The supervisor: *"Final skill: the repo must NEVER ship `.env`, credentials, or generated data. Show me the protections and how you'd audit them."*

**What you'll practice:** the safety half of git — `.gitignore` (the wall), the "is it tracked" detok (the radar), and the lethal-but-preventable scenarios (committing a secret).

Steps:
1. Read `.gitignore` at the repo root: find the rules that protect `.env`, the generated CSVs, `work/` folders, and `.ipynb_checkpoints`. State each rule's purpose.
2. Check whether a file *would* be ignored before you add it: `git status --ignored` on a probe file (create `work/probe.env` → confirm it's ignored → delete it).
3. The perma-dirty question: if `.env` is already tracked (it isn't here), what does ignoring it *after* tracking do — and why is "add then ignore" the classic footgun?
4. Write your version of the pact in `work/answers_5.md`: the four lines of "what I will never commit", and the two commands you'd run on a repo you're handed to verify it's clean.

**Guiding questions:**
- Ignored ≠ untracked ≠ absent: which one actually protects a *secret that's already in history*? (Hint: only a rewrite — the hard lesson — and the prevention is refusing to commit it at all.)
- Why does this project ignore `work/` but track `tasks.md`? What does that say about *what deserves version control*?

**Deliverable:** `work/answers_5.md` — your committed-to-craft pact + the two audit commands you'd run on any repo.

---

### Finish

Attempt all five, then read `results.md`. Keep your `answers_*.md` files as your permanent git cheat-sheet-in-your-own-words.

**Move up when:** you can explain to a friend (without looking) the difference between working tree, index, and HEAD — and you *check before you add*.