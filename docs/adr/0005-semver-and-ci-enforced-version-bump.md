# ADR 0005: Semantic versioning for plugin.json, enforced by CI

## Status

Accepted

## Context

`.claude-plugin/plugin.json`'s `version` field is how `/plugin
marketplace update` decides whether an installed consumer's plugin cache
needs refreshing: a content-only change to `hooks/`, `skills/`,
`agents/`, or `commands/` with no version bump silently never propagates
to consumers who already installed the plugin (discovered the hard way —
see the `0.2.1` bump commit, which had no semantic meaning attached to
what changed). There was no documented rule for what the three version
components mean, and no enforcement that a bump happens at all.

A natural place to enforce "bump when runtime changes" would be the
local `pre-commit` hook that already enforces docs-sync
(`.claude/hooks/pre-commit`). But that file is bootstrap-payload-managed
content — copied from `bootstrap/payload/git-pre-commit` and unconditionally
overwritten by `bootstrap.sh --refresh-system`. Hand-adding version-bump
logic there would work until the next refresh silently deleted it (the
exact footgun already documented in root `CLAUDE.md` for payload-managed
files). It also isn't a rule a *destination* project should inherit —
destination repos have no `plugin.json` and don't publish a plugin.

## Decision

1. **Adopt three-tier semantic versioning** for `plugin.json`'s
   `version`, `MAJOR.MINOR.PATCH`:
   - **MAJOR** — breaking for already-installed consumers: a command,
     skill, or agent renamed/removed, a hook's observable behavior
     changes incompatibly, or a consumer must take action beyond the
     normal `/plugin marketplace update`.
   - **MINOR** — a new, backward-compatible capability (new skill, hook,
     command, optional behavior); existing consumers keep working
     unchanged.
   - **PATCH** — a bug fix, wording/doc fix, or internal refactor with no
     observable interface change.

2. **Enforce the bump — not the tier — via a repo-specific CI workflow**
   (`.github/workflows/plugin-version.yml`, hand-authored, deliberately
   outside `bootstrap/payload/` so it is never distributed to
   consumers). On every pull request and on every push to `main` it
   fails if `hooks/`, `skills/`, `agents/`, or `commands/` changed
   without `.claude-plugin/plugin.json` also changing, and separately
   validates that a changed version is
   well-formed `MAJOR.MINOR.PATCH` and strictly greater than the base
   branch's version. It cannot and does not judge whether the *tier*
   chosen matches the nature of the change — that stays a human call for
   the author and reviewer, same as this repo already leaves ADR
   proposal/acceptance to a human.

## Alternatives considered

- **Local `pre-commit` check** (extend `.claude/hooks/pre-commit`):
  rejected — that file is payload-managed and `--refresh-system`
  overwrites it unconditionally, so any hand-added logic would be
  silently lost on the next refresh.
- **A repo-specific `pre-push` hook** (`.claude/hooks/pre-push` — a
  different git hook *name*, so it wouldn't collide with the
  payload-managed `pre-commit`): technically viable, and would give
  faster local feedback than CI. Deferred as unnecessary complexity for
  a low-frequency check (version bumps happen once per PR, not once per
  commit); CI alone is consistent with how this repo already treats
  docs-sync CI as "the actual backstop" when a local hook isn't
  available or reliable.
- **Automatically inferring and bumping the tier from the diff**:
  rejected — "is this breaking" requires semantic judgment (e.g. a hook
  message wording change vs. a hook contract change) that a syntactic
  diff check cannot make reliably; a wrong auto-bump is worse than
  requiring a manual, reviewed one.
- **Always bump PATCH on any change, ignore MAJOR/MINOR distinction**:
  rejected — collapses the version into a no-op counter, giving
  consumers no signal about whether an update is safe to pull
  automatically.

## Consequences

- Contributors must remember to pick the correct tier by hand; CI only
  catches "no bump at all" or "malformed/non-increasing," not "wrong
  tier."
- Unlike docs-sync (which has both a local `pre-commit` hook and a CI
  backstop), version-bump enforcement exists only in CI. The workflow
  runs on both pull requests and direct pushes to `main`, so the
  solo/direct-commit workflow this repo actually uses is covered too —
  it isn't just a PR-only backstop. A contributor working entirely
  offline still gets no local warning until that push or PR reaches CI.
- `.github/workflows/plugin-version.yml` is intentionally excluded from
  `bootstrap/payload/workflows/`; a destination project never sees it,
  and this repo's own `EXCLUDE_PATTERN`-mirroring rule (ADR 0002) does
  not apply to it.
