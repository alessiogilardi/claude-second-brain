# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

<!-- BEGIN SECOND BRAIN SYSTEM (managed by the second-brain plugin: do not edit this block by hand, edit bootstrap/payload/claude-md-block.md and re-run the bootstrap with --refresh-system) -->
## Skill: Second Brain
**Source of Truth:** `docs/` (architecture, ADRs, state).
**Full Policy:** the `second-brain:update` skill.

@docs/README.md

### Before Non-Trivial Work (MANDATORY)
Before any analysis, code review, planning, or implementation, delegate to
the `second-brain-reader` subagent to check `docs/` for existing patterns,
prior decisions, domain terms, and testing conventions. Do not read the
`docs/*.md` files yourself to answer these questions — that defeats the
subagent's purpose. Skipping this step means acting on stale assumptions
about architecture that's already been decided.

### Triggers (IMMEDIATE ACTION REQUIRED)
Run `skill: "second-brain:update"` after:
* Schema changes or structural refactors.
* New architectural decisions or recurring patterns.
* Testing-strategy changes.
* `[SECOND BRAIN SYSTEM] COMMIT REJECTED` pre-commit error.

**Exception:** IF `docs/*.md` contains `> Placeholder —`, run `second-brain:onboard` instead.

### Strict Commit Rule
Commits touching code **MUST** stage an update to `docs/` **or this file**.
If rejected: 1. Run skill -> 2. Stage docs -> 3. Retry. Never use dummy updates.
<!-- END SECOND BRAIN SYSTEM -->

## What this repo is

Not an application — a distribution mechanism for a self-maintaining
documentation system ("Second Brain") that other Git projects consume.
Distribution is hybrid: a native Claude Code **plugin** (skills, reader
agent, Stop hook — served read-only from the plugin cache) plus a
deterministic git-bash **bootstrap** (`bootstrap/bootstrap.sh`) that
scaffolds the files which must be committed into the consuming repo
(`docs/`, the `CLAUDE.md` block, the git pre-commit, the CI workflow).
There's no runtime service here; the runtime runs inside the consuming
project. This repo also dogfoods its own output (`docs/`, `.claude/` at
the root), consumed via the local marketplace.

## Commands

There is no build step, package manager, or automated test suite (see
`docs/testing.md`) — verification is manual.

- Install the plugin: `/plugin marketplace add .` then
  `/plugin install second-brain@second-brain-marketplace`.
- Scaffold the repo-side files: `/second-brain:bootstrap` (runs
  `bootstrap/bootstrap.sh`, create-only). Or directly:
  `bash bootstrap/bootstrap.sh [TargetPath]`.
- Refresh the committed system files after a plugin update:
  `/second-brain:refresh` (runs `bootstrap.sh --refresh-system`).
- Verify a change by running `bootstrap.sh` against a scratch `git init`
  folder and asserting create/idempotency/pre-commit/hooksPath/refresh by
  hand (see `docs/testing.md`).

## Working in this repo

- Requires git bash (Git for Windows / MSYS or any POSIX bash) — the
  bootstrap, the Stop hook, and the pre-commit are bash + git only, no
  `uv`/Python/PowerShell.
- Read `docs/architecture.md`, `docs/layout.md`, and `docs/patterns.md`
  before changing `bootstrap/` or anything under `hooks/`/`skills/`: the
  split between plugin-carried runtime (`skills/`, `agents/`, `hooks/`,
  served read-only from the cache) and the bootstrapped
  `bootstrap/payload/` content committed into a destination (`docs/`,
  `CLAUDE.md` block, git pre-commit, CI) is load-bearing, not incidental —
  get it wrong and a destination's hand-edits get clobbered, or a system
  update stops propagating. The default path patterns and the
  `.second-brain.conf` reader must stay byte-identical across the
  pre-commit, the Stop hook, and the CI workflow (ADR 0002); per-project
  filters belong in the destination's create-only `.second-brain.conf`,
  never inside the refreshed files (ADR 0007).
- Bump `.claude-plugin/plugin.json`'s `version` (`MAJOR.MINOR.PATCH`) on
  every change under `hooks/`, `skills/`, `agents/`, `commands/`, or `bootstrap/` —
  `/plugin marketplace update` only refreshes installed consumers when
  `version` changes. `.github/workflows/plugin-version.yml` fails a PR
  that misses this, but cannot judge which tier is correct — pick the
  tier yourself: major = breaking, minor = new backward-compatible
  capability, patch = bug fix (see ADR 0005).

