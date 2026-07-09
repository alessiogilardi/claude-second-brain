# ADR 0004: SessionStart bootstrap nudge, not an install-time enforcement

## Status

Accepted

## Context

Once the plugin is installed, the repo-side bootstrap (`docs/`, the
`CLAUDE.md` block, the git pre-commit hook, the CI workflow) still
requires a manual `/second-brain:bootstrap` run — easy to forget, and
until it happens none of the enforcement (pre-commit, CI backstop) is in
place either.

Claude Code has no plugin post-install lifecycle hook (`PostInstall` /
`PluginInstalled`); only runtime events (`SessionStart`, `PreToolUse`,
`Stop`, etc.) exist. This was confirmed against the official Claude Code
hooks documentation and an open feature request
(anthropics/claude-code#11240) requesting exactly such a lifecycle event.

## Decision

Add a `SessionStart` hook (`hooks/bootstrap-reminder.sh`, wired in
`hooks/hooks.json` with matcher `"startup"`) that checks for the
`<!-- BEGIN SECOND BRAIN SYSTEM` marker in `CLAUDE.md` — the exact marker
`bootstrap.sh` itself checks to decide create-vs-skip — and, if absent,
prints a plain-stdout reminder telling the model to run
`/second-brain:bootstrap`. `SessionStart` delivers plain stdout straight
into Claude's context, so no JSON envelope is needed. The script is bash
+ git only, consistent with the rest of the system's dependency-free
hooks.

The hook only nudges; it never runs the bootstrap itself.

## Alternatives considered

- **Auto-run the bootstrap from the hook**: rejected — silently writing
  files into a repo's working tree on every session start is surprising,
  and contradicts the bootstrap's own create-only, non-destructive
  design. A hook firing in a scratch `git init` folder or an unrelated
  repo would scaffold files nobody asked for.
- **A separate marker file** (e.g. `.claude/bootstrap-completed`) to
  detect prior bootstrap: rejected — reusing the existing `CLAUDE.md`
  marker gives one source of truth instead of two signals that can drift
  apart.
- **Wait for a real post-install hook**: rejected as the sole plan —
  the feature isn't shipped and has no committed timeline; a nudge is
  available today and can be replaced later.

## Consequences

- Nudging is a soft signal: a user can still ignore it, and
  non-interactive/headless runs won't act on it unless the model reads
  and follows the injected context.
- The hook is plugin-carried (`hooks/`), not bootstrap-payload content,
  so it is active immediately on `/plugin install` — before bootstrap has
  ever run — exactly like the existing Stop hook already is.
- If Claude Code ships a true post-install lifecycle event later, this
  hook can be replaced or supplemented by it without changing the
  bootstrap's own create-only contract.
