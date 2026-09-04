# Enforcement, exclusions and gate timing

Reference for the `second-brain:update` skill. Read this when the gate
misfires, when the user asks why a commit or push was rejected, or when
you're about to propose a change to `.second-brain.conf` — not on a normal
documentation run.

## What counts as a "source change"

The pre-commit hook (installed in the committed hooks dir,
`.githooks/pre-commit` by default) and its three mirrors — the pre-push hook
(`.githooks/pre-push`, the blocking gate under `SB_GATE=push`), the Stop hook
(the second-brain plugin's `session-reminder.sh`) and the CI backstop
(`.github/workflows/second-brain.yml`) — all decide whether "source
changed" the same way: they skip lockfiles (`*.lock`,
`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `poetry.lock`,
`uv.lock`, `Cargo.lock`, `Gemfile.lock`), `.github/`, `.claude/`,
`.githooks/`, `.gitattributes`, `.second-brain.conf`, and `tests?/` at any
depth.

## Tuning it — `.second-brain.conf` only

If a project needs a different set, change it in **`.second-brain.conf`** at
the repo root — never by editing the four files, whose patterns are
rewritten by every `/second-brain:refresh`. All four read that one file:

- `SB_EXCLUDE_EXTRA` — added to the default denylist. This is the right
  answer to a recurring false positive (generated/vendored paths, a
  non-default `--hooks-dir`).
- `SB_INCLUDE_PATTERN` — allowlist; only matching paths count as source.
  Powerful but **fail-open**: anything not listed is never checked, so docs
  can drift silently. Propose it only when the user's source lives in a
  fixed set of directories, and say what the trade-off is.
- `SB_EXCLUDE_PATTERN` — replaces the built-in denylist wholesale.
- `SB_GATE` — **when** the check blocks, not what it matches. `commit`
  (default) rejects at commit time; `push` makes the pre-commit advisory and
  moves the block to a pre-push hook that checks the whole branch. Propose
  `push` when the project's work arrives as multi-commit implementation plans:
  a per-commit gate there produces doc-touch or documentation of intermediate
  states. It does **not** reduce what must eventually be documented — it moves
  the deadline from "this commit" to "before this branch is pushed", so the
  update skill still has to run, just once per branch instead of once per commit.

A repo bootstrapped before v0.4 has no `.second-brain.conf` yet; running
`/second-brain:bootstrap` or `/second-brain:refresh` creates it without
touching anything else.

## Legitimate bypasses

Two legitimate reasons to bypass with `git commit --no-verify`:

- a WIP commit on a private branch that will be squashed later;
- a doc-only follow-up commit made immediately after the source commit
  it documents.

If a project keeps reaching for `--no-verify` because its commits arrive in
batches, that is not a bypass problem — it is the wrong gate timing. Propose
`SB_GATE=push` instead: it makes those commits legal by design rather than by
exception, and keeps `--no-verify` meaning what it should (a rare, deliberate
one-off).

Never touch `docs/second-brain/` just to satisfy the hook ("doc-touch") — an edit
that doesn't correspond to a real change defeats the whole point of this
system, and a reviewer (or a later run of the update skill) will find a doc
section that doesn't match anything real.

## Known blind spot

Because `tests?/` is excluded at any depth, changes to *testing strategy*
(new test types, frameworks, coverage tooling) never trigger the pre-commit
hook or the CI backstop — only the Stop hook and the update skill's
end-of-session check catch them. That's why trigger (5) in the update
skill's frontmatter exists as its own condition: don't rely on the hook to
remind you about testing-strategy changes.
