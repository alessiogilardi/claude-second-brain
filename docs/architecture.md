# Architecture

## Overview

This repo is not an application — it's a **distribution mechanism** (a
template repo) for injecting a self-maintaining documentation system
("Second Brain") into other Git projects. There is no runtime service;
the only "execution" is `install.ps1` itself, plus the hooks and skills
it installs, which then run *inside* the destination project, not here.

## Main components

- **`install.ps1`** (PowerShell) — entry point. Creates the required
  folders in the destination, checks for `uv`, copies
  `template/docs/` and `template/.github/` without overwriting files
  that already exist (`Copy-WithoutOverwrite`), syncs system-owned
  `.claude/` files via a SHA-256 manifest that upgrades in place unless
  hand-edited (`Sync-SystemOwnedFile`), merges `.claude/settings.json`
  through `scripts/merge_settings.py`, merges a marker-delimited block
  into the destination's `CLAUDE.md`, and points `core.hooksPath` at
  `.claude/hooks`. Also supports `-Uninstall` (and `-PurgeDocs`) to
  reverse all of the above.
- **`scripts/merge_settings.py`** (Python, run via `uv run`) — merges
  only the Stop-hook entry referencing `session_reminder.py` into a
  destination's `.claude/settings.json`, leaving any other hooks/config
  untouched. Build-time tool only; never copied to a destination.
- **`template/.claude/hooks/pre-commit`** (POSIX sh) — installed git
  hook: rejects a commit that changes source files without also staging
  a `docs/` or `CLAUDE.md` change. Syntactic check only (`EXCLUDE_PATTERN`
  decides what counts as "source").
- **`template/.claude/hooks/session_reminder.py`** (Python stdlib,
  Stop hook) — mirrors the pre-commit exclusion logic but runs at
  end-of-session, catching uncommitted drift that never got staged for
  a commit.
- **`template/.github/workflows/second-brain.yml`** — re-applies the
  same check in CI against the PR diff, since `core.hooksPath` is local
  git config and isn't cloned.
- **`template/.claude/skills/{update-second-brain,onboard-second-brain}/SKILL.md`**
  — the two Claude Code skills that actually read/write `docs/` content:
  `onboard-second-brain` bootstraps a fresh destination's placeholders
  once; `update-second-brain` keeps `docs/` in sync afterward.

## Main flows

1. **Install** — from this repo, run `.\install.ps1 [TargetPath]` ->
   creates folders, copies `template/docs/` (never overwrite), syncs
   system-owned `.claude/` files (manifest-tracked upgrade-in-place),
   merges `settings.json` via `uv run scripts/merge_settings.py`, merges
   the `CLAUDE.md` block, sets `core.hooksPath`.
2. **Onboard** (once per destination) — in the destination project, run
   the `onboard-second-brain` skill: replaces every `> Placeholder`
   marker under `docs/` with real content verified against that
   destination's actual code.
3. **Ongoing enforcement** (in the destination project) — a
   source-changing commit without a matching `docs/`/`CLAUDE.md` change
   is rejected by `pre-commit` -> the `update-second-brain` skill runs,
   docs get staged with the code, commit retried. The Stop hook and the
   CI workflow catch what the local, non-cloned pre-commit hook misses.

## Relevant architectural decisions

None recorded yet in [`adr/`](./adr/) — only `adr/template.md` exists so
far. Two decisions are visible in the code today as candidates for
retroactive ADRs: the SHA-256-manifest-gated sync strategy for
system-owned files vs. never-overwrite for user-owned files, and the
triple-mirrored `EXCLUDE_PATTERN` enforcement across the local hook, the
Stop hook, and the CI workflow.

*Last updated: 2026-07-07 — verified against commit `9ea2b62`.*
