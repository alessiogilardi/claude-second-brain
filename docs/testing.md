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

Also check the ADR-0002 invariant: `EXCLUDE_PATTERN` is byte-identical
across `bootstrap/payload/git-pre-commit`, `hooks/session-reminder.sh`,
and `bootstrap/payload/workflows/second-brain.yml`.

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

*Last updated: 2026-07-28 — verified against commit `00727a6`.*
