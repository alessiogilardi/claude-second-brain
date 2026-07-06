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
│   │   ├── hooks/
│   │   │   └── pre-commit                 # blocks code commits without a docs update
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
2. copies the contents of `template/docs/` and `template/.claude/` without
   overwriting files that already exist in the destination project;
3. merges a marker-delimited block (`<!-- BEGIN/END SECOND BRAIN
   SYSTEM -->`) into the destination's `CLAUDE.md`: creates the file if it
   doesn't exist, appends the block if the file exists without touching
   the user's existing content, or updates the block in place if it's
   already present (idempotent re-run);
4. if the destination is a Git repository, runs
   `git config core.hooksPath .claude/hooks` to hook up the pre-commit
   hook.

## Requirements

- Windows with Git for Windows (hooks run through the Bash/MSYS environment
  bundled with Git for Windows).
- PowerShell 5.1+ or PowerShell 7+.
