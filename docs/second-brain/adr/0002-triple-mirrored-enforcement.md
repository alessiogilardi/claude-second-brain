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

Implement the same syntactic check (path-filter regexes + "source changed
without a matching docs change" logic) independently in three places, kept
mirrored by convention rather than shared code. Since ADR 0007 the mirrored
part is the *default* patterns plus the `.second-brain.conf` reader —
per-project filters live in that single committed file and are therefore
shared by construction, not by convention:

1. `bootstrap/payload/git-pre-commit` (POSIX sh) — bootstrapped into the
   destination's committed hooks dir (`.githooks/pre-commit` by default, or
   injected as a marker block into an existing hook — see ADR 0006); fast
   local feedback at commit time. The check lives inside the hook's
   `# >>> BEGIN/END SECOND BRAIN SYSTEM pre-commit <<<` block, which is the
   canonical copy of the default patterns for both a freshly installed hook
   and an injected one, so the mirror stays at three files, not four.
2. `hooks/session-reminder.sh` (bash, plugin Stop hook) — served from the
   plugin cache; catches uncommitted drift at end-of-session, before
   anything is even staged. Bash + git only (no `uv`/Python/`jq`), so its
   default patterns are byte-identical shell strings to the pre-commit's.
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
- The three implementations must be manually kept in sync — a change to a
  default pattern (or to the conf reader) in one file that isn't mirrored
  in the other two silently reintroduces the exact gap this design exists
  to close. This is documented at the top of all three files as an explicit
  maintenance requirement, not caught automatically.
- The mirror now crosses a distribution boundary: a default-pattern fix
  reaches the plugin's Stop hook via `/plugin marketplace update`, but the
  committed pre-commit and CI copies in *already-bootstrapped* destinations
  only pick it up when someone runs `/second-brain:refresh`
  (`--refresh-system`). A drift window therefore exists per destination
  until refreshed. Per-project filters are exempt: they live in the
  destination's single `.second-brain.conf` (ADR 0007), so they cannot drift
  between the three points and are never rewritten by a refresh.

### Amended by ADR 0009

[ADR 0009](./0009-configurable-gate-timing.md) adds a fourth mirrored
implementation, `bootstrap/payload/git-pre-push`, and changes one property
of this ADR's Consequences that no longer holds unconditionally:

- The mirror is **four files**, not three:
  `bootstrap/payload/git-pre-commit`, `bootstrap/payload/git-pre-push`,
  `hooks/session-reminder.sh`, and
  `bootstrap/payload/workflows/second-brain.yml`. The maintenance burden
  above ("must be manually kept in sync") now spans all four.
- "Fast local feedback at commit time" (this ADR's stated benefit of the
  local pre-commit hook) is **mode-dependent**, not a given: it holds only
  under the default `SB_GATE=commit`. Under `SB_GATE=push`, the
  pre-commit hook downgrades to a non-blocking notice and the actual
  blocking check moves to `pre-push`, evaluating the whole branch range
  instead of one commit — trading that fast per-commit feedback for a
  coarser, branch-wide check. See ADR 0009 for the rationale and
  trade-offs of that mode.

*Last updated: 2026-08-28 — verified against commit `8e3279c`.*
