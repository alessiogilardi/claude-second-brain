# ADR 0002: Triple-mirrored enforcement instead of a single shared check

## Status

Proposed

## Context

The core rule ("a commit that changes source code must also change
`docs/` or `CLAUDE.md`") needs to be enforced somewhere. The natural
place is a local git `pre-commit` hook wired via `core.hooksPath`. But
`core.hooksPath` is local git config stored in `.git/config`, which is
never committed or cloned — so a fresh clone, a teammate who never ran
`install.ps1`, or a CI runner gets zero enforcement from the local hook
alone, and the check can also be bypassed locally with
`git commit --no-verify`.

## Decision

Implement the same syntactic check (`EXCLUDE_PATTERN` regex + "source
changed without a matching docs change" logic) independently in three
places, kept mirrored by convention rather than shared code:

1. `hooks/pre-commit` (POSIX sh) — fast local feedback
   at commit time.
2. `hooks/session_reminder.py` (Python, Stop hook) —
   catches uncommitted drift at end-of-session, before anything is even
   staged.
3. `workflows/second-brain.yml` (GitHub Actions) —
   re-applies the check against the full PR diff; travels with the repo
   and can't be skipped with `--no-verify`.

## Alternatives considered

- **CI-only enforcement**: simplest to keep in sync (one implementation),
  but gives up the fast local feedback loop — a rejected commit is only
  discovered after pushing and opening a PR.
- **Local-hook-only enforcement**: fast feedback, but `core.hooksPath`
  being local-only means a fresh clone or a skipped install has *zero*
  enforcement, silently.
- **Extract the check into one shared script all three call**: would
  remove the duplication risk, but requires a portable runtime available
  identically in a POSIX git-hook shell, a `uv run` Python Stop hook, and
  a GitHub Actions `ubuntu-latest` runner — adds a dependency/invocation
  surface for marginal benefit given the check is a handful of lines.

## Consequences

- Enforcement survives a skipped or impossible-to-run local install
  (CI still catches it) while keeping the fast local feedback loop for
  developers who did run `install.ps1`.
- The three implementations must be manually kept in sync — a change to
  `EXCLUDE_PATTERN` in one file that isn't mirrored in the other two
  silently reintroduces the exact gap this design exists to close. This
  is documented at the top of all three files as an explicit maintenance
  requirement, not caught automatically.

*Last updated: 2026-07-07 — verified against commit `9f70a8a`.*
