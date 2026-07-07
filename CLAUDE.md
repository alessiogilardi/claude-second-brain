# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

<!-- BEGIN SECOND BRAIN SYSTEM (managed by claude-second-brain-skill: do not edit this block by hand, edit template/CLAUDE.md and rerun install.ps1) -->
## Skill: Second Brain
**Source of Truth:** `docs/` (architecture, ADRs, state).
**Full Policy:** `.claude/skills/update-second-brain/SKILL.md`

@docs/README.md

### Triggers (IMMEDIATE ACTION REQUIRED)
Run `skill: "update-second-brain"` after:
* Schema changes or structural refactors.
* New architectural decisions or recurring patterns.
* Testing-strategy changes.
* `[SECOND BRAIN SYSTEM] COMMIT REJECTED` pre-commit error.

**Exception:** IF `docs/*.md` contains `> Placeholder —`, run `onboard-second-brain` instead.

### Strict Commit Rule
Commits touching code **MUST** stage an update to `docs/` **or this file**.
If rejected: 1. Run skill -> 2. Stage docs -> 3. Retry. Never use dummy updates.
<!-- END SECOND BRAIN SYSTEM -->

## What this repo is

Not an application — a template/distribution mechanism that injects a
self-maintaining documentation system ("Second Brain") into *other* Git
projects via `install.ps1`. There's no runtime service; the only
"execution" is `install.ps1` itself plus the hooks/skills it installs,
which then run inside the destination project, not here. This repo also
dogfoods its own output (`docs/`, `.claude/` at the root are its own
Second Brain install).

## Commands

There is no build step, package manager, or automated test suite (see
`docs/testing.md`) — verification is manual.

- Install/refresh the system into a project (defaults to the current folder):
  `.\install.ps1 [TargetPath] [-InstallUv] [-ForceHooksPath] [-Force]`
- Remove it: `.\install.ps1 [TargetPath] -Uninstall [-PurgeDocs]`
- Verify a change to `install.ps1`, a hook, or a skill by running
  `install.ps1` against a scratch destination folder (or re-running it
  against this repo itself) and inspecting the copied/merged files and
  hook output by hand.
- `scripts/merge_settings.py` runs only via `uv run` from inside
  `install.ps1` — never standalone, never shipped to a destination.

## Working in this repo

- Requires Windows + Git for Windows + PowerShell (hooks run through the
  bundled Bash/MSYS environment) — don't assume a cross-platform shell.
- Read `docs/architecture.md`, `docs/layout.md`, and `docs/patterns.md`
  before changing `install.ps1` or anything under `hooks/`/`skills/`:
  the split between byte-for-byte-copied implementation packages
  (`skills/`, `hooks/`, `workflows/`, upgraded in place via a SHA-256
  manifest) and mergeable, never-overwritten `template/` content
  (`CLAUDE.md`, `settings.json`, `docs/`) is load-bearing, not
  incidental — get it wrong and a destination project's hand-edits get
  silently clobbered, or a system update silently stops propagating.

