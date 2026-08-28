# Architecture

## Overview

This repo is not an application — it's a **distribution mechanism** for a
self-maintaining documentation system ("Second Brain") that other Git
projects consume. There is no runtime service here; distribution is
**hybrid**:

1. a native **Claude Code plugin** (marketplace-distributed, cached
   read-only in `~/.claude/plugins/`, external to the consuming repo) that
   carries the runtime: the two skills, the reader agent, the
   end-of-session Stop hook, and a session-start bootstrap nudge;
2. a deterministic **git-bash bootstrap** (`bootstrap/bootstrap.sh`,
   shipped inside the plugin) that scaffolds the files which *must* be
   committed into the consuming repo's working tree — the `docs/second-brain/` set, the
   `CLAUDE.md` block, the git `pre-commit` hook, and the CI workflow.

The split is forced by a hard constraint: a plugin cannot write into the
consuming repo's working tree, yet those four things must be committed
there to survive fresh clones, teammates who never installed the plugin,
and CI runners (see ADR 0002). Everything a plugin *can* serve read-only
lives in the plugin; everything that must be committed is bootstrapped.

## Main components

- **`.claude-plugin/plugin.json` + `marketplace.json`** — plugin metadata
  and a marketplace catalog whose single plugin `source` is `.` (the repo
  root), so this repo is simultaneously the plugin and its marketplace.
- **`bootstrap/bootstrap.sh`** (bash) — the deterministic scaffolder.
  Create-only for `docs/second-brain/`, the CI workflow and `.second-brain.conf`;
  appends the `CLAUDE.md` marker block if absent. The doc-set destination
  is the `DOCS_DIR` literal; a destination still on the pre-1.0 layout (our
  navigation map at `docs/README.md`, nothing at
  `docs/second-brain/README.md`) gets the docs scaffold skipped and the
  `git mv` printed instead, so placeholders are never seeded next to a
  populated legacy set — the move itself stays the user's (ADR 0008). Installs the git pre-commit into a committed,
  configurable hooks dir (`--hooks-dir`, default `.githooks`) and points
  `core.hooksPath` at it (only when unset-and-ours or already ours — never
  clobbers husky/other), and pins that hook to LF in the destination's
  `.gitattributes` (idempotent, scoped to its own path) so a Windows
  checkout can't CRLF-break the `#!/bin/sh` shebang. It never overwrites a
  user's pre-commit: our check
  is a marker-delimited block injected at the top of an existing hook
  (running first, rejecting only, then falling through to the host's own
  logic); a foreign `.git/hooks/pre-commit` is copied into the hooks dir
  before the repoint so it isn't lost, and a pre-0.3 Second Brain hook is
  replaced wholesale. The dir is resolved with precedence explicit
  `--hooks-dir` > an existing Second Brain `core.hooksPath` (so pre-0.3
  installs on `.claude/hooks` stay put and refresh writes there) >
  `.githooks`. `--refresh-system` is the only overwrite path for our own
  content, scoped to the pre-commit block, the CI workflow, and the
  `CLAUDE.md` block *between its markers* (see ADR 0006).
- **`bootstrap/payload/`** — the source content the bootstrap copies:
  `docs/` (the placeholder set, copied to `docs/second-brain/` in the
  destination) + `adr/template.md`, `git-pre-commit`,
  `workflows/second-brain.yml`, `claude-md-block.md`, and
  `second-brain.conf`.
- **`.second-brain.conf`** (in the destination) — the single place a
  project tunes which paths count as source: `SB_INCLUDE_PATTERN`
  (allowlist), `SB_EXCLUDE_EXTRA` (added
  to the default denylist), `SB_EXCLUDE_PATTERN` (replaces it) — all three
  applied to the source side only. Also carries `SB_GATE` (`commit`
  default, or `push`), which controls *when* the mismatch blocks rather
  than *what* counts as source: `commit` rejects in the pre-commit hook
  per commit (unchanged default behavior); `push` makes the pre-commit
  hook advisory and moves the block to a branch-wide pre-push check
  instead — this repo runs `push` on itself (see ADR 0009, amending ADR
  0002). Read — by
  parsing, never by sourcing — by all enforcement points, and
  create-only so `--refresh-system` never reverts it (see ADR 0007).
- **`hooks/hooks.json` + `hooks/session-reminder.sh`** — the plugin's Stop
  hook. `hooks.json` wires the Stop event to
  `bash "${CLAUDE_PLUGIN_ROOT}/hooks/session-reminder.sh"`. The script
  (bash, no `uv`/Python/`jq`) mirrors the pre-commit exclusion logic and
  reports uncommitted drift via the `{"decision":"block",…}` contract,
  guarded against looping by `stop_hook_active`.
- **`hooks/hooks.json` + `hooks/bootstrap-reminder.sh`** — the plugin's
  `SessionStart` hook (matcher `"startup"`). There is no plugin
  post-install lifecycle event in Claude Code, so this is the closest
  available substitute: on every fresh session it checks for the
  `<!-- BEGIN SECOND BRAIN SYSTEM` marker in `CLAUDE.md` — the exact
  marker `bootstrap.sh` itself checks — and, if absent, prints a plain
  stdout reminder to run `/second-brain:bootstrap`. It nudges only; it
  never runs the bootstrap itself (see ADR 0004).
- **`commands/bootstrap.md` / `refresh.md`** — slash commands
  (`/second-brain:bootstrap`, `/second-brain:refresh`) that run
  `bootstrap.sh` (the second with `--refresh-system`). The command
  executes the script deterministically; the model only reports its
  output.
- **`skills/{update,onboard}/SKILL.md`** — the two skills that read/write
  `docs/second-brain/`: `second-brain:onboard` bootstraps a fresh destination's
  placeholders once; `second-brain:update` keeps `docs/second-brain/` in sync
  afterward.
- **`agents/second-brain-reader.md`** — a read-only subagent that answers
  questions from `docs/second-brain/` with verbatim quotes, to save the caller's
  context. Its use is mandatory, not optional: the injected `CLAUDE.md`
  block (`bootstrap/payload/claude-md-block.md`) carries a "Before
  Non-Trivial Work" instruction directing the model to delegate to it
  before analysis, review, or planning, instead of reading `docs/second-brain/*.md`
  directly.
- **`.github/workflows/plugin-version.yml`** — this repo's own release
  hygiene, unrelated to the Second Brain system it distributes (a
  destination project never sees it, and it's not part of
  `bootstrap/payload/`). Fails a PR that changes `hooks/`, `skills/`,
  `agents/`, or `commands/` without also bumping
  `.claude-plugin/plugin.json`'s `version`, and rejects a malformed or
  non-increasing version (see ADR 0005).

The `pre-commit` hook and the CI workflow live in `bootstrap/payload/`
(bootstrapped into the consuming repo), while `session-reminder.sh` lives
in the plugin — so the triple-mirrored default patterns and conf reader
now span the plugin/repo boundary (see ADR 0002); the per-project filter
values do not, since all three read the destination's single
`.second-brain.conf` (ADR 0007).

## Main flows

1. **Install the plugin** — `/plugin marketplace add <repo-or-git-source>`
   then `/plugin install second-brain@second-brain-marketplace`. The
   skills, reader agent, Stop hook, and SessionStart nudge become
   available; nothing is written into the project working tree yet. From
   the next fresh session in any repo lacking the `CLAUDE.md` marker, the
   SessionStart hook reminds the model to bootstrap.
2. **Bootstrap the repo** — run `/second-brain:bootstrap` (which runs
   `bootstrap.sh`). Scaffolds `docs/second-brain/` (create-only), appends the `CLAUDE.md`
   block, installs the git `pre-commit` into the committed hooks dir
   (`.githooks` by default) and points `core.hooksPath` at it, and copies
   the CI workflow and `.second-brain.conf`. Safe to re-run (everything
   reports `[SKIP]`).
3. **Onboard** (once per destination) — run the `second-brain:onboard`
   skill: replaces every `> Placeholder` marker under `docs/second-brain/` with real
   content verified against that destination's code.
4. **Ongoing enforcement** — a source-changing commit without a matching
   `docs/second-brain/`/`CLAUDE.md` change is rejected by `pre-commit` → the
   `second-brain:update` skill runs, docs are staged with the code, commit
   retried. The Stop hook and the CI workflow catch what the local,
   non-cloned pre-commit hook misses.
5. **Refresh system files** — after a plugin update ships new hook/CI/block
   content, `/second-brain:refresh` (`--refresh-system`) overwrites only
   those three committed files; `docs/second-brain/`, `.second-brain.conf` and user prose
   stay untouched.

## Relevant architectural decisions

- [ADR 0009](./adr/0009-configurable-gate-timing.md) — `SB_GATE`
  (`commit`/`push`) lets the blocking check run per-commit (default) or
  branch-wide at push time; amends ADR 0002 (mirror count three -> four).
- [ADR 0008](./adr/0008-second-brain-docs-in-a-docs-subdirectory.md) — the
  doc set moved to a fixed `docs/second-brain/`, and the denylist became
  source-side only so `docs/` can be excluded without swallowing it.
- [ADR 0007](./adr/0007-externalized-path-filters-and-opt-in-allowlist.md) —
  path filters moved into a create-only `.second-brain.conf`, with an
  opt-in (and knowingly fail-open) `SB_INCLUDE_PATTERN` allowlist.
- [ADR 0006](./adr/0006-configurable-committed-hooks-dir.md) — the git
  pre-commit lives in a committed, configurable hooks dir (default
  `.githooks`), and an existing hook is extended by injecting a marker
  block rather than being overwritten.
- [ADR 0005](./adr/0005-semver-and-ci-enforced-version-bump.md) —
  three-tier semantic versioning for `plugin.json`, with a repo-specific
  CI check (not a local hook) enforcing that a bump happened.
- [ADR 0004](./adr/0004-sessionstart-bootstrap-nudge.md) — nudge, not
  enforce: a `SessionStart` hook reminds instead of auto-running the
  bootstrap, since Claude Code has no post-install lifecycle event.
- [ADR 0003](./adr/0003-hybrid-plugin-plus-bootstrap-distribution.md) —
  hybrid plugin + deterministic bootstrap distribution (supersedes 0001).
- [ADR 0002](./adr/0002-triple-mirrored-enforcement.md) — triple-mirrored
  `EXCLUDE_PATTERN`, now spanning the plugin/repo boundary.
- [ADR 0001](./adr/0001-manifest-gated-sync-for-system-owned-files.md) —
  the previous SHA-256-manifest install strategy, **superseded by 0003**.

*Last updated: 2026-08-28 — verified against commit `9bb84ec`.*
