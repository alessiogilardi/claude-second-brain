# ADR 0002: Triple-mirrored enforcement instead of a single shared check

## Status

Proposed

## Context

The core rule ("a commit that changes source code must also change
`docs/` or `CLAUDE.md`") needs to be enforced somewhere. The natural
place is a local git `pre-commit` hook wired via `core.hooksPath`. But
`core.hooksPath` is local git config stored in `.git/config`, which is
never committed or cloned — so a fresh clone, a teammate who never ran the
bootstrap, or a CI runner gets zero enforcement from the local hook alone,
and the check can also be bypassed locally with `git commit --no-verify`.

After the plugin migration (ADR 0003) the three implementations no longer
share a single home: the local pre-commit and the CI workflow are
scaffolded into the destination repo (from `bootstrap/payload/`), while
the Stop hook is served read-only from the plugin cache. The mirror
requirement now spans that plugin/repo boundary.

## Decision

Implement the same syntactic check (`EXCLUDE_PATTERN` regex + "source
changed without a matching docs change" logic) independently in three
places, kept mirrored by convention rather than shared code:

1. `bootstrap/payload/git-pre-commit` (POSIX sh) — bootstrapped into the
   destination as `.claude/hooks/pre-commit`; fast local feedback at
   commit time.
2. `hooks/session-reminder.sh` (bash, plugin Stop hook) — served from the
   plugin cache; catches uncommitted drift at end-of-session, before
   anything is even staged. Bash + git only (no `uv`/Python/`jq`), so its
   `EXCLUDE_PATTERN` is a byte-identical shell string to the pre-commit's.
3. `bootstrap/payload/workflows/second-brain.yml` (GitHub Actions,
   bootstrapped into `.github/workflows/`) — re-applies the check against
   the full PR diff; travels with the repo and can't be skipped with
   `--no-verify`.

## Alternatives considered

- **CI-only enforcement**: simplest to keep in sync (one implementation),
  but gives up the fast local feedback loop — a rejected commit is only
  discovered after pushing and opening a PR.
- **Local-hook-only enforcement**: fast feedback, but `core.hooksPath`
  being local-only means a fresh clone or a skipped bootstrap has *zero*
  enforcement, silently.
- **Extract the check into one shared script all three call**: would
  remove the duplication risk, but requires a portable runtime reachable
  identically from a git-hook shell, a plugin-cache Stop hook, and a
  GitHub Actions runner — and the pre-commit/CI copies must be committed
  into the destination regardless, so a shared script couldn't live only
  in the plugin. Adds an invocation surface for marginal benefit given the
  check is a handful of lines.

## Consequences

- Enforcement survives a skipped or impossible-to-run local bootstrap (CI
  still catches it) while keeping the fast local feedback loop for
  developers who did bootstrap.
- The three implementations must be manually kept in sync — a change to
  `EXCLUDE_PATTERN` in one file that isn't mirrored in the other two
  silently reintroduces the exact gap this design exists to close. This is
  documented at the top of all three files as an explicit maintenance
  requirement, not caught automatically.
- The mirror now crosses a distribution boundary: an `EXCLUDE_PATTERN` fix
  reaches the plugin's Stop hook via `/plugin marketplace update`, but the
  committed pre-commit and CI copies in *already-bootstrapped* destinations
  only pick it up when someone runs `/second-brain:refresh`
  (`--refresh-system`). A drift window therefore exists per destination
  until refreshed.

*Last updated: 2026-07-08 — verified against commit `b595503`.*
