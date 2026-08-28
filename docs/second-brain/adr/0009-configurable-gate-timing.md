# ADR 0009: Configurable gate timing (`SB_GATE`) — commit-level or push-level enforcement

## Status

Proposed

## Context

Every enforcement point (the pre-commit hook, the Stop hook, the CI
workflow — ADR 0002) rejects at the granularity of **one commit**: staged
source changes without a matching `docs/second-brain/`/`CLAUDE.md` change in
the *same commit* are blocked.

That granularity assumes the unit of work and the unit of documentation
coincide. They don't for a project driven by multi-commit implementation
plans (this repo's own `docs/superpowers/plans/` workflow among them): a
plan's task boundaries are commit boundaries, but the architectural
decision the Second Brain needs to capture is usually only clear once
several tasks have landed together. A per-commit gate on that workflow
forces one of two bad outcomes:

- **doc-touch**: edit `docs/second-brain/` on every task-commit just to
  satisfy the hook, even when nothing has actually changed enough to
  document yet — exactly the anti-pattern the hook's own "NOTE
  (anti-gaming)" comment warns against.
- **premature/overturned documentation**: document an intermediate state
  truthfully, only to have a later commit in the same plan change it,
  leaving a doc edit in history that never described the final shape of
  anything.

The gate exists to keep the Second Brain aligned with the code — not to
force alignment to be re-declared on every single commit of a change that
was never meant to be reviewed one commit at a time.

## Decision

Add a `.second-brain.conf` key, `SB_GATE`, with two values:

- `commit` (default, and the only behavior before this ADR): the
  pre-commit hook rejects here, per commit — unchanged.
- `push`: the pre-commit hook downgrades to a **non-blocking notice**
  (staged source changes with no docs change print a warning but do not
  stop the commit), and the blocking check moves to a **pre-push** hook
  that evaluates the whole branch range
  (`merge-base(<remote>/<default>, HEAD)..HEAD`) instead of one commit —
  the same unit the CI backstop already checks.

An unrecognized `SB_GATE` value falls back to `commit` and prints a
warning: a typo in the conf must not silently disable the gate.

`SB_GATE` is read via the existing `_sb_conf_get` reader, alongside
`SB_INCLUDE_PATTERN` / `SB_EXCLUDE_EXTRA` / `SB_EXCLUDE_PATTERN` (ADR
0007) — it is orthogonal to those: the include/exclude keys decide *what
counts as source*, `SB_GATE` decides *when the source/docs mismatch is
allowed to block*.

This repo adopts `SB_GATE=push` for itself (`.second-brain.conf`), since
its own work arrives as multi-commit plans and would otherwise hit the
doc-touch/overturned-documentation problem described above.

### Amends ADR 0002

ADR 0002's mirror count goes from three implementations to **four**:
`bootstrap/payload/git-pre-commit`, `bootstrap/payload/git-pre-push` (new),
`hooks/session-reminder.sh`, and `bootstrap/payload/workflows/second-brain.yml`.
The local git-hook-based gate is no longer strictly commit-level — in
`push` mode it becomes branch-level, matching the range the CI backstop
already evaluates. The default patterns, evaluation order and conf reader
stay mirrored across all four exactly as ADR 0002 requires; `SB_GATE`
itself becomes part of that mirrored surface.

## Alternatives considered

- **Always gate at push time**: simpler (one behavior, no conf key), but
  removes the fast per-commit feedback loop ADR 0002 explicitly values for
  projects that *do* want doc alignment enforced on every commit. Not
  every consumer of this system works in multi-commit plans.
- **Gate on a configurable N-commit window instead of push**: doesn't map
  to a real boundary (a plan can be any number of commits), and is harder
  to reason about than "the whole branch, same as CI" — which is a
  boundary the project already has a mental model for.
- **Squash-merge only, keep commit-level gating**: would sidestep the
  problem without a new key, but forces a specific git workflow
  (squash-merge) on every consumer of the system, which this project does
  not otherwise mandate.

## Consequences

- `push` mode trades fast, per-commit rejection for a coarser, branch-wide
  check — a source change can sit undocumented across several local
  commits before anything blocks. The CI backstop and the pre-push hook
  (Task 3) are what actually close that window; `commit` mode remains the
  tighter default for projects that want it.
- The mirror maintenance burden (already manual per ADR 0002) grows by one
  file (`git-pre-push`) and by one more piece of state (`_sb_gate`) that
  must stay consistent across all four implementations.
- `SB_GATE` is fail-closed on a bad value (falls back to `commit`, the
  strictest mode) rather than fail-open, consistent with the project's
  existing bias for enforcement mistakes to default to *more* blocking,
  not less.

*Last updated: 2026-08-28 — verified against commit `9bb84ec`.*
