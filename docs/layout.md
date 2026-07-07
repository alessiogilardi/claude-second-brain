# Project Layout

## Folder structure

```text
repo/
├── install.ps1                  # entry point: injects the Second Brain system into a destination project
├── scripts/
│   └── merge_settings.py        # JSON merge helper for .claude/settings.json, used only by install.ps1 (uv run); never copied to a destination
├── template/                    # everything install.ps1 copies into a destination project, mirroring the destination's relative paths
│   ├── CLAUDE.md                    # block merged into the destination's CLAUDE.md
│   ├── .claude/
│   │   ├── settings.json            # Stop-hook wiring, merged (not overwritten) into the destination's settings.json
│   │   ├── hooks/
│   │   │   ├── pre-commit               # blocks a commit missing a matching docs/CLAUDE.md update
│   │   │   └── session_reminder.py      # Stop-hook mirror of the pre-commit check
│   │   └── skills/
│   │       ├── update-second-brain/SKILL.md
│   │       └── onboard-second-brain/SKILL.md
│   ├── .github/workflows/second-brain.yml   # CI backstop mirroring the pre-commit check
│   └── docs/                        # placeholder doc set + adr/template.md shipped to every destination
├── docs/                        # this repo's own Second Brain (installed via install.ps1 against itself)
├── .claude/                      # this repo's own installed system-owned files (same dogfooding)
├── .github/workflows/second-brain.yml
├── CLAUDE.md
└── README.md
```

## Placement conventions

- Anything meant to run only at install time, and that must **not** ship
  to a destination project, goes in `scripts/` (currently just
  `merge_settings.py`).
- Anything meant to be copied byte-for-byte into a destination project's
  tree goes under `template/`, at the exact relative path it will have
  at the destination (e.g. `template/.claude/hooks/pre-commit` ->
  destination's `.claude/hooks/pre-commit`).
- Root-level files outside `template/` and `scripts/` (`install.ps1`,
  `README.md`) describe or drive the installer itself, not a destination
  project.
- `docs/` and `.claude/` at the repo root (this file's own location) are
  this repo's own Second Brain install — a dogfooding instance of the
  system the repo distributes, not part of what gets templated out.

*Last updated: 2026-07-07 — verified against commit `9ea2b62`.*
