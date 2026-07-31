# Testing

This project has no automated test framework wired up (no `tests/`
folder, no Pester/pytest). The code under test is bash + git:
`bootstrap/bootstrap.sh`, `hooks/session-reminder.sh`,
`hooks/bootstrap-reminder.sh`, and the `bootstrap/payload/git-pre-commit`
hook. Verification is manual but scriptable, and splits in two.

**Deterministic core (scriptable against a scratch git repo).** Run
`bootstrap.sh` against a throwaway `git init` repo and assert:

- **create** — `docs/` scaffold, exactly one `CLAUDE.md` marker block,
  `.githooks/pre-commit` (carrying the `# >>> BEGIN/END SECOND BRAIN SYSTEM
  pre-commit <<<` markers), `.github/workflows/second-brain.yml`, and
  `core.hooksPath=.githooks`;
- **idempotency** — a re-run reports `[SKIP]` and changes no file content
  (compare hashes; still one block);
- **pre-commit** — staging source without docs is rejected with
  `COMMIT REJECTED`; staging source + docs passes;
- **path filters** (`.second-brain.conf`, ADR 0007) — with a pristine conf
  (all keys commented out) behaviour is identical to the built-in defaults,
  and so is a run with the file deleted entirely; `SB_INCLUDE_PATTERN='^src/'`
  makes a commit touching only `app/` pass while `src/` still rejects, and
  `src/` + `docs/` must still pass (the allowlist must not filter the docs
  side); `SB_EXCLUDE_EXTRA='^vendor/'` lets a `vendor/`-only commit through
  while `src/` still rejects; values parse bare, single- or double-quoted and
  with trailing blanks; staging only `.second-brain.conf` passes (it is in
  the default denylist); the same assertions hold for the Stop hook and for
  the CI workflow's `run:` script (extract it and feed it two SHAs);
- **conf survives refresh** — a custom key added to `.second-brain.conf`
  is still there after `--refresh-system` (`[SKIP] … create-only`), and the
  file is created if it was missing;
- **configurable hooks dir** — `--hooks-dir tools/hooks` installs there and
  points `core.hooksPath` at it; an absolute path, a `..` path, or a
  missing value is rejected with `[ERROR]`;
- **resolver / backward-compat** — with a pre-existing Second Brain
  `core.hooksPath` (e.g. `.claude/hooks`) the run stays on that dir and does
  not create `.githooks`; a pre-0.3 marker-less hook is `[UPGRADE]`-replaced
  wholesale (plain run and `--refresh-system`), leaving the block markers;
- **inject into a user hook** — a foreign `pre-commit` already in the hooks
  dir gets our block prepended (host logic preserved); on a src+docs commit
  the host logic still runs, on a src-only commit the injected block
  rejects first;
- **migrate a foreign `.git/hooks/pre-commit`** — it is `[MIGRATE]`-copied
  into the hooks dir (original left in place) then injected, before the
  repoint;
- **hooksPath safety** — a pre-existing foreign `core.hooksPath` (e.g.
  `.husky`) is left untouched with a `[WARN]` (our hook is inert until
  repointed); `--force-hookspath` overrides; other real `.git/hooks/*`
  scripts about to be shadowed get a `[WARN]`;
- **LF pin** — the destination `.gitattributes` gains a
  `<hooks-dir>/pre-commit text eol=lf` rule (created if absent, appended if
  present without disturbing existing rules, skipped if already there), so
  the `#!/bin/sh` hook can't be CRLF-broken by a Windows checkout;
- **LF pin self-heal** — seed `.gitattributes` with an absolute pin
  (`C:/…/.githooks/pre-commit text eol=lf` and/or a `/unix/abs/…` one), a
  duplicate `# [SECOND BRAIN SYSTEM]` comment, and a foreign rule: the run
  reports `[FIX]`, collapses them into a single repo-relative entry under one
  comment, leaves the foreign rules untouched, and a re-run is a byte-for-byte
  no-op (`[SKIP]`). A foreign *relative* `pre-commit` pin (e.g.
  `tools/hooks/pre-commit`) must survive; with a legacy `.claude/hooks`
  install the rewritten entry must point there, not at `.githooks`;
- **Stop hook** — `session-reminder.sh` blocks on source-without-docs,
  the `stop_hook_active` loop-guard suppresses a re-block, and a clean or
  docs-including tree does not block;
- **SessionStart nudge** — `bootstrap-reminder.sh` prints the reminder in
  a fresh `git init` repo with no `CLAUDE.md` marker, is silent once the
  marker is present (post-bootstrap), and is silent (and non-erroring)
  outside a git repo;
- **refresh** — `--refresh-system` rewrites only our slice: the pre-commit
  block between its markers (preserving any host hook logic around it), the
  CI workflow, and the CLAUDE.md block between markers, preserving user
  prose around it and leaving `docs/` byte-identical.

Also check the ADR-0002 invariant: the default exclude pattern, the docs
pattern, and the `.second-brain.conf` reader are byte-identical across
`bootstrap/payload/git-pre-commit`, `hooks/session-reminder.sh`, and
`bootstrap/payload/workflows/second-brain.yml` (modulo the `_sb_` prefixes
the pre-commit block uses to stay collision-free inside a host hook).

**Plugin version bump check** (`.github/workflows/plugin-version.yml`,
repo-specific, not part of the deterministic core above since it only
runs in this repo's own CI): verify by constructing a diff/base version
pair and checking the pass/fail cases by hand — no bump alongside a
`hooks/`/`skills/`/`agents/`/`commands/` change fails; a bump that's
malformed, unchanged, or lower than the base fails; a well-formed,
increasing bump passes (see ADR 0005).

**Acceptance (needs an interactive Claude Code session / GitHub).** Not
scriptable: installing the plugin (`/plugin marketplace add .` +
`/plugin install`), the slash-command `!`-bash pre-execution, the Stop
hook firing at a real session end, and the CI workflow failing/passing on
a real PR.

If a framework is introduced later, the deterministic core above is the
natural first suite (e.g. a committed `verify.sh` or a bats test file).

*Last updated: 2026-07-31 — verified against commit `81606ed`.*
