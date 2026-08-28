# Testing

This project has no automated test framework wired up (no `tests/`
folder, no Pester/pytest). The code under test is bash + git:
`bootstrap/bootstrap.sh`, `hooks/session-reminder.sh`,
`hooks/bootstrap-reminder.sh`, and the `bootstrap/payload/git-pre-commit`
and `bootstrap/payload/git-pre-push` hooks. Verification is manual but
scriptable, and splits in two.

**Deterministic core (scriptable against a scratch git repo).** Run
`bootstrap.sh` against a throwaway `git init` repo and assert:

- **create** — `docs/second-brain/` scaffold (and nothing at `docs/*.md`),
  exactly one `CLAUDE.md` marker block carrying `@docs/second-brain/README.md`,
  `.githooks/pre-commit` (carrying the `# >>> BEGIN/END SECOND BRAIN SYSTEM
  pre-commit <<<` markers), `.githooks/pre-push` (carrying the
  `# >>> BEGIN/END SECOND BRAIN SYSTEM pre-push <<<` markers, per-hook so
  a repo can host both blocks without the injector confusing one for the
  other), `.github/workflows/second-brain.yml`, and
  `core.hooksPath=.githooks`;
- **idempotency** — a re-run reports `[SKIP]` and changes no file content
  (compare hashes; still one block per hook);
- **pre-commit** — staging source without docs is rejected with
  `COMMIT REJECTED`; staging source + docs passes;
- **`SB_GATE` parsing** (`bootstrap/payload/git-pre-commit`) — absent
  falls back to `commit`; explicit `commit` and explicit `push` are both
  honored as read; an unrecognized value (e.g. `SB_GATE=bogus`) falls back
  to `commit` and prints a warning to stderr — a typo must not silently
  disable the gate;
- **pre-commit under `SB_GATE=push`** — staging source without docs
  prints a non-blocking `NOTICE (SB_GATE=push)` and the commit still
  succeeds; under `SB_GATE=commit` (default) behavior is unchanged (still
  rejects with `COMMIT REJECTED`);
- **pre-push** (`bootstrap/payload/git-pre-push`, all under
  `SB_GATE=push`) — rejects a push whose range
  (`merge-base(<remote>/<default>, <pushed-sha>)..<pushed-sha>`) has
  source changes but no `docs/second-brain/`/`CLAUDE.md` change, with
  `PUSH REJECTED`; accepts once docs land anywhere in that range; a
  second push of new source-only commits on top of an *already-pushed*
  docs commit still passes, because the merge-base anchor (against the
  remote's default branch) is diffed, not the incremental
  `<remote-sha>..<local-sha>` range — an earlier push's docs commit
  remains inside `merge-base..new-tip`; a branch deletion (all-zero local
  sha on stdin) is ignored; the hook is inert under `SB_GATE=commit`
  (exits 0 immediately, reading nothing meaningful from stdin); when no
  anchor resolves (no `<remote>/HEAD`, `<remote>/main`, or
  `<remote>/master`, and the remote-side sha for that ref is also
  absent/zero — first push of a brand-new repo, or a push straight to a
  URL rather than a named remote) it prints a "no comparison base ...
  skipping the push gate" notice and allows the push, relying on the CI
  backstop (ADR 0009, AD-4);
- **bootstrap installs `pre-push` symmetrically to `pre-commit`** — a
  fresh repo gets both hooks created; an existing foreign `pre-push` gets
  the block injected at the top (host logic preserved), not overwritten;
  `--refresh-system` rewrites the marker-delimited block in both hooks
  independently; `.gitattributes` gains an LF-pin entry for both
  `<hooks-dir>/pre-commit` and `<hooks-dir>/pre-push`;
- **path filters** (`.second-brain.conf`, ADR 0007) — with a pristine conf
  (all keys commented out) behaviour is identical to the built-in defaults,
  and so is a run with the file deleted entirely; `SB_INCLUDE_PATTERN='^src/'`
  makes a commit touching only `app/` pass while `src/` still rejects, and
  `src/` + `docs/second-brain/` must still pass (no filter may reach the
  docs side — ADR 0008);
  `SB_EXCLUDE_EXTRA='^vendor/'` lets a `vendor/`-only commit through
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
  `<hooks-dir>/pre-commit text eol=lf` rule AND a
  `<hooks-dir>/pre-push text eol=lf` rule (`ensure_gitattributes_lf` loops
  over both hook names; each created if absent, appended if present
  without disturbing existing rules, skipped if already there), so the
  `#!/bin/sh` hooks can't be CRLF-broken by a Windows checkout;
- **LF pin self-heal** (pre-commit only — pre-push never shipped before
  this multi-hook change, so no pre-0.3.2 install ever wrote a dead
  absolute pin for it) — seed `.gitattributes` with an absolute pin
  (`C:/…/.githooks/pre-commit text eol=lf` and/or a `/unix/abs/…` one), a
  duplicate `# [SECOND BRAIN SYSTEM]` comment, and a foreign rule: the run
  reports `[FIX]`, collapses them into a single repo-relative entry under one
  comment, leaves the foreign rules untouched, and a re-run is a byte-for-byte
  no-op (`[SKIP]`). A foreign *relative* `pre-commit` pin (e.g.
  `tools/hooks/pre-commit`) must survive; with a legacy `.claude/hooks`
  install the rewritten entry must point there, not at `.githooks`;
- **doc-set location** (ADR 0008) — a file elsewhere under `docs/` (e.g.
  `docs/api.md`) is neutral: staged alone the commit passes, staged with a
  source change it is rejected, and it never satisfies the check. The same
  three cases must hold for the Stop hook;
- **legacy layout** — in a repo carrying the pre-1.0 set (our navigation
  map at `docs/README.md`), the docs scaffold is skipped, the `git mv` is
  printed, no `docs/second-brain/` is seeded, and the rest of the bootstrap
  still runs. A bare `mkdir docs/second-brain` must not switch the
  detection off; after a real move the warning stops, missing placeholders
  are filled in, and migrated files are not overwritten;
- **Stop hook** — `session-reminder.sh` blocks on source-without-docs,
  the `stop_hook_active` loop-guard suppresses a re-block, and a clean or
  docs-including tree does not block;
- **SessionStart nudge** — `bootstrap-reminder.sh` prints the reminder in
  a fresh `git init` repo with no `CLAUDE.md` marker, is silent once the
  marker is present (post-bootstrap), and is silent (and non-erroring)
  outside a git repo;
- **refresh** — `--refresh-system` rewrites only our slice: the
  pre-commit AND pre-push blocks between their respective markers
  (preserving any host hook logic around each), the CI workflow, and the
  CLAUDE.md block between markers, preserving user prose around it and
  leaving `docs/second-brain/` byte-identical.

Also check the ADR-0002 invariant (amended by ADR 0009): the default
exclude pattern, the docs pattern, the evaluation order, and the
`.second-brain.conf` reader function itself are byte-identical across
FOUR files — `bootstrap/payload/git-pre-commit`,
`bootstrap/payload/git-pre-push`, `hooks/session-reminder.sh`, and
`bootstrap/payload/workflows/second-brain.yml` (modulo the `_sb_`
prefixes the git-hook blocks use to stay collision-free inside a host
hook). `SB_GATE` itself is read only by the two git hooks — the Stop
hook and the CI workflow deliberately ignore it (both already evaluate a
fuller range than one commit — uncommitted drift, and the whole PR diff,
respectively — so the commit/push distinction doesn't apply to them; see
each file's own comment block and ADR 0009).

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

*Last updated: 2026-08-28 — verified against commit `8e3279c`.*
