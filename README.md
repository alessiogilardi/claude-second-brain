# claude-second-brain-skill

A Claude Code **plugin** that exports the **"Second Brain"** documentation
system to other projects: a `docs/` structure kept in sync with the code
via two skills, a git `pre-commit` hook, and a CI backstop. The plugin
carries the runtime; a deterministic git-bash **bootstrap** scaffolds the
files that must be committed into the consuming repo.

## What's in here

```text
claude-second-brain-skill/
├── .claude-plugin/
│   ├── plugin.json                 # plugin metadata
│   └── marketplace.json            # marketplace catalog (source ".")
├── bootstrap/
│   ├── bootstrap.sh                # deterministic, create-only repo-side scaffolder
│   └── payload/                    # files the bootstrap copies into a destination
│       ├── docs/                       # placeholder doc set + adr/template.md
│       ├── git-pre-commit              # the git pre-commit hook source
│       ├── workflows/second-brain.yml  # the CI backstop source
│       ├── second-brain.conf           # path-filter config (create-only in the destination)
│       └── claude-md-block.md          # the marker-delimited CLAUDE.md block
├── hooks/
│   ├── hooks.json                  # wires Stop -> session-reminder.sh, SessionStart -> bootstrap-reminder.sh
│   ├── session-reminder.sh         # bash Stop-hook mirror of the pre-commit check
│   └── bootstrap-reminder.sh       # bash SessionStart nudge: reminds if not yet bootstrapped
├── commands/
│   ├── bootstrap.md                 # /second-brain:bootstrap -> bootstrap.sh
│   └── refresh.md                   # /second-brain:refresh   -> bootstrap.sh --refresh-system
├── skills/
│   ├── update/SKILL.md              # second-brain:update  -- keeps docs/ in sync with the code
│   └── onboard/SKILL.md             # second-brain:onboard -- bootstraps docs/ from placeholders (once)
├── agents/
│   └── second-brain-reader.md      # read-only docs/ retrieval subagent
└── README.md
```

## How to use it

**1. Install the plugin.** Add this repo as a marketplace and install:

```
/plugin marketplace add <path-or-git-url-of-this-repo>
/plugin install second-brain@second-brain-marketplace
```

This makes the skills, the `second-brain-reader` agent, the
end-of-session Stop hook, and a `SessionStart` bootstrap reminder
available. Nothing is written into your project yet — a plugin is
read-only and external to your repo. There is no plugin post-install
hook in Claude Code, so the `SessionStart` reminder is the closest
substitute: on your next fresh session in a repo that hasn't been
bootstrapped, it nudges the model to run `/second-brain:bootstrap` (see
[ADR 0004](./docs/adr/0004-sessionstart-bootstrap-nudge.md)).

**2. Bootstrap the repo-side files.** From inside the target project, run:

```
/second-brain:bootstrap
```

It runs `bootstrap/bootstrap.sh` (you can also call
`bash bootstrap/bootstrap.sh [TargetPath] [--hooks-dir DIR]` directly):

1. scaffolds the `docs/` set (placeholders + `adr/template.md`) — create-only,
   never overwriting an existing file;
2. appends the marker-delimited block (`<!-- BEGIN/END SECOND BRAIN
   SYSTEM -->`) to `CLAUDE.md` if it isn't already present, leaving your
   own content untouched;
3. installs the git `pre-commit` into a committed, configurable hooks dir
   (`--hooks-dir`, default `.githooks`) and points `core.hooksPath` at it —
   unless a foreign `core.hooksPath` (e.g. husky) is already set, in which
   case it warns and leaves it (pass `--force-hookspath` to override). Your
   own `pre-commit` is never overwritten: the check is injected as a marker
   block at the top of it (rejecting first, then falling through to your
   logic), and a hook already sitting in `.git/hooks` is copied across
   before `core.hooksPath` is repointed so it isn't shadowed away. The hook
   is pinned to LF in your `.gitattributes` (one idempotent rule, scoped to
   its own path) so a Windows checkout can't CRLF-break the `#!/bin/sh`
   shebang;
4. copies the CI workflow to `.github/workflows/second-brain.yml`
   (create-only);
5. copies `.second-brain.conf` to the repo root (create-only) — the one
   place to tune which paths count as a source change, and the one system
   file `--refresh-system` never rewrites (see *Tuning what counts as a
   "source change"* below).

It never deletes and never overwrites your own content, so an accidental
re-run is a no-op (see [ADR 0006](./docs/adr/0006-configurable-committed-hooks-dir.md)).

**3. Onboard (once).** Run the `second-brain:onboard` skill before your
first commit, to replace every `docs/*.md` placeholder with real content.
Otherwise the one-time bootstrap gets triggered mid-commit the first time
the pre-commit hook rejects a source change with no matching docs update —
correct, but the worst moment to pay that cost on a large repo.

**Updating.** When a new plugin version ships, `/plugin marketplace update`
refreshes the skills/agent/Stop hook automatically. To refresh the
*committed* system content (the git pre-commit block between its markers,
the CI workflow, and the `CLAUDE.md` block between its markers) run
`/second-brain:refresh` — it rewrites only our own slices and never touches
`docs/`, your own prose, or any host hook logic wrapped around our block.

## Enforcement is per-clone, not per-repo

`core.hooksPath` is **local git config** — it lives in `.git/config`, which
is never committed or cloned. Enforcement of the pre-commit hook only
exists on machines where the bootstrap was actually run; a fresh clone, a
teammate who skipped it, or a CI runner gets **zero** enforcement from the
local hook alone, silently.

`.github/workflows/second-brain.yml` (scaffolded into the destination by
the bootstrap) closes that gap: it re-applies the same check to the PR diff
on GitHub Actions, so it travels with the repo and can't be skipped with
`--no-verify`. Treat the local hook as fast feedback and the CI workflow as
the actual backstop — enable Actions on the destination repo (and mark the
job required in branch protection) to enforce it.

## Versioning (for plugin maintainers)

`.claude-plugin/plugin.json`'s `version` follows `MAJOR.MINOR.PATCH`:

- **MAJOR** — a breaking change for already-installed consumers: a
  command, skill, or agent renamed/removed, a hook's observable behavior
  changes incompatibly, or a consumer needs to take action (re-run
  `/second-brain:bootstrap` or `--refresh-system`) beyond the normal
  `/plugin marketplace update`.
- **MINOR** — a new, backward-compatible capability: a new skill, hook,
  command, or optional behavior. Existing consumers keep working with no
  action required.
- **PATCH** — a bug fix, wording/doc fix, or internal refactor with no
  observable interface change.

`/plugin marketplace update` only refreshes an installed consumer's
plugin cache when `version` changes — a content-only change with no
version bump silently never propagates. A CI check
(`.github/workflows/plugin-version.yml`, this repo's own tooling, not
shipped to consumers) fails a PR that touches `hooks/`, `skills/`,
`agents/`, or `commands/` without also bumping `version`, and rejects a
malformed or non-increasing version. It cannot judge which tier
(major/minor/patch) is correct for a given change — that stays a human
call; see [ADR 0005](./docs/adr/0005-semver-and-ci-enforced-version-bump.md).

## Requirements

- **git bash** — Git for Windows / MSYS, or any POSIX `bash` on
  macOS/Linux. The bootstrap, the pre-commit hook, and the Stop hook are
  `bash` + `git` only; there is no `uv`, Python, or PowerShell dependency.
- **Claude Code** with plugin support (`/plugin`).

## Tuning what counts as a "source change"

The committed pre-commit (`.githooks/pre-commit` by default) is a syntactic
check, not a semantic one: it only verifies that *some* file under `docs/`
or `CLAUDE.md` was staged alongside source changes.

Which paths count is configured in **`.second-brain.conf`** at the repo
root — one file, read by all three enforcement points (the pre-commit, the
plugin's Stop hook, and the CI workflow). It is create-only: unlike the
pre-commit block and the CI workflow, it is **never** rewritten by
`/second-brain:refresh`, so this is the only place your filters survive a
plugin update. It ships with every key commented out; leaving it untouched
keeps the built-in defaults (and future improvements to them).

| Key | Effect |
|---|---|
| `SB_EXCLUDE_EXTRA` | Added to the default denylist. **The usual fix for a false positive** — e.g. `'^(vendor/\|migrations/)'`. |
| `SB_INCLUDE_PATTERN` | Allowlist: only matching paths count as source (empty = all). Applied to the source side only, so `docs/`+`CLAUDE.md` stay recognized as documentation whatever it says. |
| `SB_EXCLUDE_PATTERN` | Replaces the built-in denylist entirely (tests, CI, common lockfiles, `.claude/`, `.githooks/`, `.gitattributes`, `.second-brain.conf`). Use `'^$'` to disable exclusions. |

⚠️ **The allowlist is fail-open.** A denylist errs toward false positives —
noisy but visible. `SB_INCLUDE_PATTERN` errs the other way: a directory you
add to the project and forget to add there is never checked, and your docs
drift with nothing to tell you. Reach for `SB_EXCLUDE_EXTRA` first, and use
the allowlist only when the project's source really lives in a fixed set of
directories. See
[ADR 0007](./docs/adr/0007-externalized-path-filters-and-opt-in-allowlist.md).

Note that a PR can widen these filters as easily as it can edit the
workflow itself — review `.second-brain.conf` changes like any other
enforcement change.

Bypassing with `git commit --no-verify` is legitimate for a WIP commit on
a private branch you'll squash later, or a doc-only follow-up commit — don't
touch `docs/` just to satisfy the hook ("doc-touch"); see the
`second-brain:update` skill for the full policy.

On a non-Windows clone the hook scripts may lack the POSIX executable bit;
Git for Windows runs them via `sh` regardless, but elsewhere run
`chmod +x .githooks/pre-commit` if needed.
