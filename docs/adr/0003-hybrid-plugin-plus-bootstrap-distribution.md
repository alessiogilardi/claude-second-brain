# ADR 0003: Hybrid distribution — Claude Code plugin + deterministic git-bash bootstrap

## Status

Proposed

Supersedes [ADR 0001](./0001-manifest-gated-sync-for-system-owned-files.md).

## Context

The system was originally distributed by `install.ps1`: a PowerShell
script that copied skills/hooks/agent into a destination's `.claude/`,
merged `settings.json` via `uv run scripts/merge_settings.py`, merged a
`CLAUDE.md` block, scaffolded `docs/`, wired `core.hooksPath`, and tracked
upgradable "system-owned" files with a SHA-256 manifest (ADR 0001). This
was Windows-only, carried bespoke merge/manifest machinery, and had no
native update channel — every fix required re-running the script by hand.

Claude Code plugins offer native distribution and updates (marketplace +
`/plugin marketplace update`), but a plugin is **read-only and external**
to the consuming repo (it lives in `~/.claude/plugins/cache/`) and
**cannot write into the consuming project's working tree**. Yet the core
of the Second Brain — the committed `docs/`, the `CLAUDE.md` block, the git
`pre-commit` hook, and the CI workflow — *must* live in that working tree
to survive fresh clones, teammates who never installed, and CI runners
(the ADR 0002 rationale). A plugin alone therefore cannot replace
`install.ps1`.

## Decision

Split distribution into two native mechanisms:

1. **A Claude Code plugin** (`.claude-plugin/plugin.json` + a local
   `marketplace.json`) carrying everything a plugin can serve read-only:
   the two skills, the `second-brain-reader` agent, and the Stop hook
   (`hooks/hooks.json` → `hooks/session-reminder.sh`, referenced via
   `${CLAUDE_PLUGIN_ROOT}`). This removes the `settings.json` merge and
   `scripts/merge_settings.py` entirely (the plugin declares the Stop hook)
   and retires the SHA-256 manifest (the plugin cache versions and upgrades
   these files natively).

2. **A deterministic git-bash bootstrap** (`bootstrap/bootstrap.sh`,
   shipped inside the plugin, invoked by the `/second-brain-bootstrap`
   slash command) that scaffolds the must-be-committed files from
   `bootstrap/payload/` into the destination working tree. It is
   **create-only**: it never overwrites an existing file and never deletes
   anything, so an accidental re-run is a no-op. The only overwrite path is
   `--refresh-system` (via `/second-brain-refresh`), scoped to exactly the
   git pre-commit, the CI workflow, and the `CLAUDE.md` block between its
   markers — `docs/` and user prose are never touched.

Supporting decisions:

- **Bootstrap in git bash, not PowerShell**, and **the Stop hook rewritten
  from Python (`session_reminder.py`, `uv run`) to bash
  (`session-reminder.sh`)** — so the whole system needs only `bash` + `git`
  (no `uv`/Python/`jq`), and the ADR-0002 mirror becomes a byte-identical
  shell string across the pre-commit and the Stop hook.
- **Invocation via a slash command** that runs the script directly, so the
  scaffolding is deterministic (the script is the source of truth) rather
  than left to the model's judgment.

## Alternatives considered

- **Keep `install.ps1` as the sole mechanism**: no native distribution or
  update channel, Windows-only, and bespoke merge/manifest machinery to
  maintain.
- **Plugin only, no bootstrap**: impossible — a plugin cannot write the
  `docs/`, `CLAUDE.md` block, git hook, or CI into the consuming repo.
- **Plugin + a bootstrap *skill*** (let the model create the files):
  rejected for non-determinism; a script guarantees identical, idempotent
  output.
- **Keep the SHA-256 manifest for the two committed system files** (git
  pre-commit, CI): rejected as overkill for two files; create-only plus an
  explicit `--refresh-system` honors the non-destructive priority without
  new persistent state.

## Consequences

- Native install/update: `/plugin install` and `/plugin marketplace
  update` replace re-running a script; no manifest, no `settings.json`
  merge, no `uv` dependency.
- Two mechanisms to understand instead of one, and the ADR-0002 mirror now
  spans the plugin/repo boundary (see ADR 0002's drift-window consequence).
- The must-be-committed files (`docs/`, `CLAUDE.md` block, git pre-commit,
  CI) still land in the destination working tree — that is intrinsic to the
  system's value, not incidental.
- This repo dogfoods the result: it is simultaneously the plugin and its
  marketplace (`source: "."`), consumed locally; its `.claude/` keeps only
  the bootstrapped `pre-commit` and the gitignored `settings.local.json`.

*Last updated: 2026-07-08 — verified against commit `b595503`.*
