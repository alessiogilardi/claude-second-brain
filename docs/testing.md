# Testing

This project has no automated test framework wired up (no `tests/`
folder, no Pester/pytest). The code under test is bash + git:
`bootstrap/bootstrap.sh`, `hooks/session-reminder.sh`,
`hooks/bootstrap-reminder.sh`, and the `bootstrap/payload/git-pre-commit`
hook. Verification is manual but scriptable, and splits in two.

**Deterministic core (scriptable against a scratch git repo).** Run
`bootstrap.sh` against a throwaway `git init` repo and assert:

- **create** — `docs/` scaffold, exactly one `CLAUDE.md` marker block,
  `.claude/hooks/pre-commit`, `.github/workflows/second-brain.yml`, and
  `core.hooksPath=.claude/hooks`;
- **idempotency** — a re-run reports `[SKIP]` and changes no file content
  (compare hashes; still one block);
- **pre-commit** — staging source without docs is rejected with
  `COMMIT REJECTED`; staging source + docs passes;
- **hooksPath safety** — a pre-existing foreign `core.hooksPath` (e.g.
  `.husky`) is left untouched with a `[WARN]`; `--force-hookspath`
  overrides;
- **Stop hook** — `session-reminder.sh` blocks on source-without-docs,
  the `stop_hook_active` loop-guard suppresses a re-block, and a clean or
  docs-including tree does not block;
- **SessionStart nudge** — `bootstrap-reminder.sh` prints the reminder in
  a fresh `git init` repo with no `CLAUDE.md` marker, is silent once the
  marker is present (post-bootstrap), and is silent (and non-erroring)
  outside a git repo;
- **refresh** — `--refresh-system` overwrites only the pre-commit, the CI
  workflow, and the CLAUDE.md block between markers, preserving user prose
  around the block and leaving `docs/` byte-identical.

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

*Last updated: 2026-07-09 — verified against commit `5e5b0b9`.*
