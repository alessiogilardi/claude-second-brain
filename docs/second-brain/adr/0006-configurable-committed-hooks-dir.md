# ADR 0006: Configurable, committed hooks dir with non-destructive injection

## Status

Accepted

## Context

The bootstrap installed the git `pre-commit` at a fixed
`.claude/hooks/pre-commit`, repointed `core.hooksPath` there, and was
strictly create-only: if a `pre-commit` already existed it was skipped.
Three problems surfaced:

1. **Location not choosable.** The path was hard-wired and buried under
   `.claude/` — a Claude Code config directory, not a conventional home for
   shared git hooks. Teams that already keep hooks under a well-known dir
   (`.githooks`, `hooks/`, …) had no say.
2. **Silent enforcement gap.** Because install was create-only, a
   destination that already had *any* `pre-commit` (husky output, a
   home-grown hook, a template) never got the Second Brain check at all —
   the bootstrap reported success while installing nothing that runs.
3. **Silent shadowing.** Repointing `core.hooksPath` makes git read *only*
   that dir, so any other hooks still in `.git/hooks` (a `pre-push`, a
   `commit-msg`) stop firing with no warning.

The request was to make the dir configurable (defaulting to `.githooks` at
the repo root), and to *combine* with an existing hook rather than skip it.
A related option — gitignoring the hooks dir — was raised and rejected: the
committed pre-commit is a deliberate design point (ADR 0002/0003 — it must
be versioned to survive fresh clones and teammates who never installed the
plugin), and committing `.githooks` is the idiomatic "shared hooks" pattern,
whereas gitignoring it is its inverse.

## Decision

1. **Committed, configurable hooks dir.** Install the pre-commit into a dir
   chosen by `--hooks-dir` (relative path, validated; no absolute/`..`),
   default `.githooks`, and repoint `core.hooksPath` at it. The dir is
   versioned like any other file — not gitignored.
2. **Resolver with backward-compat.** The effective dir is: explicit
   `--hooks-dir` > an existing Second Brain `core.hooksPath` (so pre-0.3
   installs on `.claude/hooks` keep their location and `--refresh-system`
   writes there) > `.githooks`.
3. **Never overwrite a user hook.** Our check ships inside
   `# >>> BEGIN/END SECOND BRAIN SYSTEM pre-commit <<<` markers. Against an
   existing foreign hook we *inject* that block at the top (after the
   shebang); it exits non-zero only to reject and otherwise falls through,
   so the host's own logic still runs. A foreign `.git/hooks/pre-commit` is
   copied into the hooks dir before the repoint so it isn't lost. A pre-0.3
   marker-less Second Brain hook (ours, no user logic) is replaced
   wholesale.
4. **Warn on shadowing.** Before repointing, other real (non-sample)
   `.git/hooks/*` scripts are reported so they can be moved into the dir.
5. **Exclude the dir and `.gitattributes`.** `\.githooks/` and
   `\.gitattributes$` are added to `EXCLUDE_PATTERN` in all three mirrors
   (ADR 0002) — the hooks dir and the LF-pin file are both system-managed, so
   installing or refreshing them must not trip the docs-in-sync check. The
   injected block is derived from the payload block, so the mirror stays at
   three copies, not four.
6. **Pin the hook to LF (repo-relative).** Because the committed hook is a
   `#!/bin/sh` script and a Windows checkout (`core.autocrlf=true`) would
   rewrite it to CRLF — breaking the shebang with `bad interpreter: ^M` — the
   bootstrap appends an idempotent `<hooks-dir>/pre-commit text eol=lf` rule
   to the destination's `.gitattributes` (create-or-append, scoped to our own
   file). The path is always **repo-relative**: a `.gitattributes` pattern is
   matched relative to the file, so an absolute path there matches nothing and
   the pin silently fails. The resolver normalises an older install whose
   `core.hooksPath` was stored absolute back to its repo-relative form (via
   `git rev-parse --show-prefix`, which also fixes Windows 8.3 short names)
   before it reaches either `.gitattributes` or `core.hooksPath`. That
   normalisation only fixes what is *written next*, so
   `normalize_gitattributes_entry` additionally rewrites an absolute pin an
   earlier install already left in `.gitattributes`: it is dead as a pattern,
   and because the correct relative entry is then missing, every later run
   appended another block — accumulating a dead rule plus a duplicate
   comment. Only lines pinning a `*/pre-commit` to `eol=lf` by absolute path
   are touched (they can only be ours); duplicates of our entry and our
   comment collapse to the first occurrence, and every other rule in the
   file is passed through untouched.

## Alternatives considered

- **Gitignore the hooks dir**: makes the hook a machine-local, regenerated
  artifact. Rejected — contradicts the committed-artifact design (ADR
  0002/0003), weakens local enforcement for teammates who clone but don't
  re-bootstrap, and is the opposite of the idiomatic shared-hooks pattern.
- **Keep create-only skip on an existing `pre-commit`**: never touches user
  files, but leaves the silent enforcement gap (problem 2) — a hook that
  reports success yet installs no running check.
- **A `pre-commit.d/` dispatcher** (turn `pre-commit` into a runner over a
  directory, drop our check as one entry, migrate the existing hook in):
  most robust for many coexisting hooks, but the most invasive change and
  over-engineered for a check that is a handful of lines. Rejected in favor
  of the marker-block injection already used for `CLAUDE.md`.
- **Keep `.claude/hooks` as the fixed location**: rejected — not
  configurable, and `.claude/` is Claude Code config, not a natural home for
  hooks the team is expected to share.

## Consequences

- Enforcement is now a committed, shared artifact under a conventional dir;
  it survives clones for anyone who sets `core.hooksPath`. `core.hooksPath`
  itself is still local git config and isn't cloned, so CI remains the real
  clone-time backstop (ADR 0002) — unchanged.
- Injecting mutates a user-owned file. This is a deliberate, narrow
  exception to the bootstrap's "never touch user content" stance: it is
  reversible (marker-delimited, removable), and the alternative is zero
  local enforcement. It assumes the host hook is POSIX-sh and does not
  `exit` before our block (we insert at the top, after the shebang).
- A non-default `--hooks-dir` is *not* auto-added to `EXCLUDE_PATTERN` —
  only the `.githooks/` default is baked in; a custom dir must be added by
  hand, as the pattern's own comment already instructs.
- Pre-0.3 installs are upgraded in place: the resolver keeps them on
  `.claude/hooks`, and the marker-less hook is replaced wholesale on the
  next bootstrap or `--refresh-system`.
- `--refresh-system` now rewrites only the pre-commit *block* between its
  markers (not the whole file), so it preserves any host hook logic wrapped
  around an injected block.
- The bootstrap now writes into the destination's `.gitattributes` (a
  user-owned file) — additively and idempotently, one rule scoped to its own
  hook path — to keep the committed hook executable across platforms. It
  never rewrites rules it didn't add, with one deliberate exception: an
  absolute `*/pre-commit text eol=lf` pin left by an older install is
  rewritten in place (see Decision 6). That is a narrow break with the
  "create-only, never modify user content" guarantee, accepted because the
  line is provably ours, is inert where it stands, and otherwise multiplies
  on every run. A non-default `--hooks-dir` is pinned at its own path.
  `.gitattributes` is itself excluded from the docs-in-sync check, so the
  append never rejects the commit that installs it.
- The hooks dir is always resolved to a repo-relative path, even when an
  older install had stored `core.hooksPath` absolute: such a value is
  normalised back to relative (and `core.hooksPath` rewritten to match) so it
  survives clones and the `.gitattributes` pin actually applies. A foreign,
  non-Second-Brain absolute `core.hooksPath` (another hook manager) is still
  left untouched — normalisation only fires for our own marked hook.
