# git-cli Module — never lose work again

```
You are here: learning/git-cli/   (single level, ~30 min)
Master guide: learning/README.md
```

Every file you create in this lab is an asset: scripts, workbooks, dashboards. Analysts who don't version-control lose days to `report_final_v2_FINAL(3).xlsx` chaos — and can't answer *"what changed since last week?"* Git answers both problems: **history** (what changed, when, why) and **recovery** (undo mistakes without panic).

This is deliberately the smallest module. Git is a craft that protects everything else you learn here.

## At work, you use git when…

- You touched a working script, it broke, and you need yesterday's version back.
- Someone asks *"what exactly changed in the report logic last month?"*
- You want to try a risky change without endangering the working copy.
- A teammate needs your fix and you need to send exactly that, nothing else.

## Practice where you already are

This whole lab lives inside a real git repository (`MIS-COLLECTIONS`). That's convenient:

- The guides (`tasks.md`, `results.md`, READMEs) are **tracked** files — real history.
- Your `work/` attempts are **git-ignored** by design — personal scratch, never committed.
- For practice you'll stage and revert things that are safe to lose. Everything here is disposable; breaking things is how the lesson lands.

## This repo's git rules (learn them by using them)

1. **Never commit `.env`, passwords or secrets.**
2. **Never edit generated data** (`data_sources/raw/`).
3. Keep `work/` folders and `.ipynb_checkpoints/` ignored.
4. Commit messages: short, imperative, matching the repo's existing style (`git log --oneline` shows plenty of examples).

## Why the terminal, not a GUI

GitHub Desktop / VS Code buttons are fine for daily commits — but they hide the model underneath, and the model is what saves you when things go wrong. One terminal window, ~30 minutes of focused practice.

## What you'll be able to do afterward

Read any repo's history like a newspaper, stage and commit deliberately, branch off for experiments, and recover deleted work calmly. The tasks walk through exactly those situations.
