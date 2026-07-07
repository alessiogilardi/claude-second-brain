# Project Layout

## Folder structure

```text
repo/
├── install.ps1                  # entry point: injects the Second Brain system into a destination project
├── scripts/
│   └── merge_settings.py        # JSON merge helper for .claude/settings.json, used only by install.ps1 (uv run); never copied to a destination
├── skills/                      # complete, non-templated skill implementations, copied byte-for-byte
│   ├── update-second-brain/SKILL.md
│   └── onboard-second-brain/SKILL.md
├── hooks/                       # complete, non-templated hook implementations, copied byte-for-byte
│   ├── pre-commit                   # blocks a commit missing a matching docs/CLAUDE.md update
│   └── session_reminder.py          # Stop-hook mirror of the pre-commit check
├── workflows/                   # complete, non-templated CI workflow, copied byte-for-byte
│   └── second-brain.yml             # CI backstop mirroring the pre-commit check
├── agents/                      # complete, non-templated Claude Code subagent(s), copied byte-for-byte
│   └── second-brain-reader.md       # read-only docs/ retrieval subagent
├── template/                    # genuinely template-like content: mergeable fragments and placeholders
│   ├── CLAUDE.md                    # block merged into the destination's CLAUDE.md
│   ├── settings.json                # Stop-hook wiring, merged (not overwritten) into the destination's settings.json
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
- `skills/`, `hooks/`, `workflows/`, and `agents/` hold complete,
  non-templated implementations copied byte-for-byte into a destination
  project — they are implementation packages, not template content, so
  they live at the repo root rather than nested under `template/`.
  Their destination paths are fixed by Claude Code/GitHub Actions
  (`.claude/skills/`, `.claude/hooks/`, `.github/workflows/`,
  `.claude/agents/` respectively) and no longer mirror the source
  layout 1:1; `install.ps1` maps each source root to its destination
  path explicitly (see the `$systemOwnedFiles` mapping and the
  `workflows/` copy step in `install.ps1`).
- `template/` holds only genuinely template-like content: fragments
  meant to be merged into a file the destination project already owns
  (`CLAUDE.md`, `settings.json`) and the placeholder `docs/` set that
  `onboard-second-brain` fills in per destination.
- Root-level files outside `template/`, `scripts/`, `skills/`, `hooks/`,
  `workflows/`, and `agents/` (`install.ps1`, `README.md`) describe or
  drive the installer itself, not a destination project.
- `docs/` and `.claude/` at the repo root (this file's own location) are
  this repo's own Second Brain install — a dogfooding instance of the
  system the repo distributes, not part of what gets templated out.

*Last updated: 2026-07-07 — verified against commit `f3092ec`.*
