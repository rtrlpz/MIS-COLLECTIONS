# git-cli Module — README

```
learning/
├── _reference/            ← READ FIRST: datasets.md, kpi_glossary.md, data_dictionary.md
├── git-cli/               ← YOU ARE HERE (single level)
│   ├── README.md
│   ├── tasks.md
│   ├── results.md
│   └── work/
├── sql/  python/  notebooks/  excel/  powerbi/
└── README.md             ← MASTER GUIDE
```

## Why git is in a data portfolio

Every file you've created is an *asset*: your `work/` scripts, the MIS workbook, the dashboard. Analysts who don't version control lose weeks to "final_v2_FINAL.xlsx" chaos. This is the smallest module on purpose — **git is a craft, not a career** — but it's the craft that keeps the rest of the track from evaporating.

## Run it inside THIS repo

The whole `learning/` tree lives inside `MIS-COLLECTIONS`, which is already a git repo. That means:
- your `tasks.md` / `results.md` are **tracked** (they're documentation),
- your `work/` attempts are **git-ignored** (by design — they're personal practice scratch).

So for practice you'll occasionally stage something you'll *revert* — that's the point: git practice is safe because everything here is disposable.

## The project's git laws (you're also learning this repo's rules)

1. **Never commit `.env`, credentials, or secrets** (tracked-in-ignore).
2. **Never edit generated CSVs** (`data_sources/raw/`).
3. **`work/` folders + `.ipynb_checkpoints/` are ignored** — keep them that way.
4. Commit messages: concise, imperative, matching this repo's existing style (read `git log --oneline` to absorb it).

## What you'll be able to do afterward

Walk into any repo — yours or a team's — and read its history like a newspaper, stage and commit deliberately, branch a report without fear, and *recover* when you've deleted something you shouldn't have.

## Take colorful shortcuts

A GUI (GitHub Desktop, VS Code source control) is *fine* — but this module trains the **CLI** first: the GUI hides the model, and the model is what saves you. One terminal window, ~30 minutes of practice.