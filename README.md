# claude-second-brain-skill

Template repository for exporting the **"Second Brain"** documentation
system to other projects: a `docs/` structure kept in sync with the code
via a Claude Code skill and a pre-commit git hook.

## What's in here

```text
claude-second-brain-skill/
├── template/
│   ├── CLAUDE.md                          # block merged into the destination's CLAUDE.md
│   ├── .claude/
│   │   ├── settings.json                  # wires the Stop-hook end-of-session reminder
│   │   ├── hooks/
│   │   │   ├── pre-commit                 # blocks code commits without a docs update
│   │   │   └── session_reminder.py        # non-blocking end-of-session reminder (uv run)
│   │   └── skills/
│   │       └── update-second-brain/
│   │           └── SKILL.md               # skill that updates the documentation
│   └── docs/
│       ├── adr/
│       │   └── template.md
│       ├── README.md
│       ├── architecture.md
│       ├── database.md
│       ├── glossary.md
│       ├── layout.md
│       ├── patterns.md
│       └── testing.md
├── scripts/
│   └── merge_settings.py                   # used only by install.ps1, not copied to destination
├── install.ps1                             # injection script for the destination project
└── README.md
```

## How to use it

From this repository, run `install.ps1` pointing at the folder of the
project where you want to install the second brain:

```powershell
# Install into the current folder (default)
.\install.ps1

# Install into another project
.\install.ps1 ..\MyProject
```

The script:

1. creates `.claude/hooks/`, `.claude/skills/update-second-brain/` and
   `docs/adr/` in the destination project;
2. checks whether `uv` is on `PATH`; if not, offers to install it via the
   official installer (interactively, or automatically with `-InstallUv`)
   — `uv` runs the end-of-session reminder hook and the `settings.json`
   merge below, so both are skipped (with a warning) if it stays missing;
3. copies the contents of `template/docs/` and `template/.claude/` without
   overwriting files that already exist in the destination project;
4. merges the Stop-hook entry into the destination's
   `.claude/settings.json` via `uv run scripts/merge_settings.py`
   (preserves any hooks/config already there; idempotent re-run);
5. merges a marker-delimited block (`<!-- BEGIN/END SECOND BRAIN
   SYSTEM -->`) into the destination's `CLAUDE.md`: creates the file if it
   doesn't exist, appends the block if the file exists without touching
   the user's existing content, or updates the block in place if it's
   already present (idempotent re-run);
6. if the destination is a Git repository, runs
   `git config core.hooksPath .claude/hooks` to hook up the pre-commit
   hook.

## Requirements

- Windows with Git for Windows (hooks run through the Bash/MSYS environment
  bundled with Git for Windows).
- PowerShell 5.1+ or PowerShell 7+.
- [uv](https://docs.astral.sh/uv/getting-started/installation/) — used to
  run the end-of-session reminder hook (`.claude/hooks/session_reminder.py`)
  and to merge `.claude/settings.json` during installation. If it's
  missing, `install.ps1` offers to install it automatically on Windows.

## Customizing the pre-commit hook

`.claude/hooks/pre-commit` is a syntactic check, not a semantic one: it
only verifies that *some* file under `docs/` or `CLAUDE.md` was staged
alongside source changes. The `EXCLUDE_PATTERN` variable at the top of the
file (already copied into the destination project, no templating happens
here) lists paths ignored when deciding whether "source changed" — add
more lockfiles, generated files, or vendored paths there if the default
set (tests, CI, common lockfiles, `.claude/`) doesn't fit the project.
Bypassing with `git commit --no-verify` is legitimate for a WIP commit on
a private branch you'll squash later, or for a doc-only commit you're
about to make immediately after — don't touch `docs/` just to satisfy the
hook ("doc-touch"); see
`.claude/skills/update-second-brain/SKILL.md` for the full policy.
