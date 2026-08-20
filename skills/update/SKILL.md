---
name: update
description: >
  Updates the project's "Second Brain" documentation under docs/second-brain/ (e.g.
  architecture.md, database.md, patterns.md, glossary.md, layout.md,
  testing.md, docs/second-brain/README.md, plus docs/second-brain/adr/ for decisions — the exact
  set of files can grow or shrink per project) to keep it aligned with
  the code. Trigger this skill when: (1) database tables,
  columns, migrations, or schema have changed; (2) a structural refactor
  of modules, services, or packages has been done; (3) a new architectural
  decision has been made (choice of library, pattern, technology,
  significant trade-off); (4) a new design pattern or recurring convention
  has been introduced in the code; (5) the testing strategy has changed
  (new test types, new tools, new coverage policy); (6) the pre-commit
  hook rejected a commit with the message "[SECOND BRAIN SYSTEM] COMMIT
  REJECTED"; (7) at the end of a work session, before closing or handing
  off, to verify nothing was left out of sync.
---

# Update Second Brain

This skill keeps the project's technical documentation (the "second
brain") in sync with the actual state of the code, so that any future AI
agent (including yourself in a later session) can get oriented without
having to re-read the entire codebase. It is the single source of truth
for this policy — `CLAUDE.md` and `docs/second-brain/README.md` only point here, they
don't restate the rules.

## Memory routing

Before writing anything down, decide *where* it belongs. Four
destinations exist, each with a different scope and lifetime:

| What you learned | Where it goes | Why |
|---|---|---|
| Current state of the system (schema, architecture, layout, testing setup) | `docs/second-brain/*.md` (this Second Brain) | Describes "what is true now"; must stay in sync with the code, one file per concern. |
| A decision and its rationale/trade-offs | `docs/second-brain/adr/NNNN-*.md` | Decisions are point-in-time and mostly irreversible; ADRs preserve the *why*, not just the *what*. |
| An operating convention the agent must always apply in this project (e.g. "use uv, never pip", "always run X before Y") | `CLAUDE.md` / `.claude/rules/*.md` | Native, auto-loaded memory: enforced every session without relying on the agent remembering to check `docs/second-brain/`. |
| A preference or feedback about *how the user likes to work*, independent of this specific project | Claude Code's native user memory (not a project file) | Cross-project; belongs to the user-agent relationship, not to this codebase. |

Rule of thumb: if the fact describes **the code**, it goes in `docs/second-brain/`. If
it describes **a rule the agent must always follow**, it goes in
`CLAUDE.md` / `.claude/rules/`. If it describes **how the user wants to be
worked with**, it isn't a project file at all — use native user memory.
Never restate a `CLAUDE.md`/`.claude/rules/` convention inside `docs/second-brain/` (or
vice versa): pick one home per fact.

## Operating modes

- **Direct write** for every file under `docs/second-brain/` except `docs/second-brain/adr/`
  (this includes `docs/second-brain/README.md`, the standard concern files shipped by
  the template, and any project-specific file added later, e.g.
  `docs/second-brain/patterns/caching.md` — see "What not to write"). Update these
  pages in place, without asking for confirmation, because they describe
  the current state of the system and must stay accurate.
- **Proposal mode** for new files in `docs/second-brain/adr/`: a new architectural
  decision should not be written silently. Draft the content using
  `docs/second-brain/adr/template.md` as a base and present it to the user for
  confirmation before saving it (see "ADR numbering" below for the file
  name). **Unattended fallback**: if running with no user available to
  confirm (e.g. a commit rejected by the pre-commit hook mid-automation),
  write the ADR anyway with `Status: Proposed` and continue — proposal
  mode means "never silently mark a decision `Accepted`", not "block
  until a human answers". The user reviews later and flips the status to
  `Accepted`, edits it, or deletes the file.

## Procedure

If any file under `docs/second-brain/` still carries the `> Placeholder` marker
(grep this ASCII-safe prefix, not the full em-dash text — re-encoding
can silently corrupt `—` and hide the marker from a literal match), stop
here and run the `second-brain:onboard` skill instead — it owns the
one-time bootstrap from template placeholders to real content. Once no
placeholder remains, everything below applies.

Follow these steps every time the skill runs, whether triggered mid-session
or as an end-of-session check:

1. **Gather evidence.** Run `git status --porcelain` to get the real list
   of changed files — staged, unstaged, **and untracked** — never rely on
   memory of what "felt like" a big change. This is the same source of
   truth the Stop hook uses (the second-brain plugin's
   `session-reminder.sh`), so the skill and the hook never disagree about
   what counts as "changed"; a brand-new,
   not-yet-`git add`-ed file (a new module, migration, etc.) would
   otherwise be invisible to this step. Use `git diff HEAD --stat` only
   for the lines-changed detail on files `git status` already flagged,
   never as the file list itself.
2. **Map changes to documents**, using the table in "Memory routing" above
   plus this file-level mapping:
   - migrations, schema files, ORM models -> `docs/second-brain/database.md`
   - new/removed/moved packages, modules, folders -> `docs/second-brain/layout.md`
   - new services, changed call graph, new external integration ->
     `docs/second-brain/architecture.md`
   - a repeated structural choice (new factory, new middleware
     convention) -> `docs/second-brain/patterns.md`
   - new test types, frameworks, coverage tooling -> `docs/second-brain/testing.md`
   - a new domain term used in code/comments/commits -> `docs/second-brain/glossary.md`
   - a decision with real alternatives and trade-offs -> new ADR (see "ADR
     numbering" below)
   - a file was added or removed under `docs/second-brain/` -> also update
     `docs/second-brain/README.md`'s navigation table (see "What not to write")
3. **Update, don't rewrite.** Edit only the relevant section of the target
   file; don't regenerate the whole document, and don't add a changelog
   inside status docs — git history is the changelog.
4. **Cross-check against the real code**, not against your memory of the
   session: re-read the updated section and verify every claim against the
   current files before considering it done.
5. **Refresh the freshness footer** of every file you touched (see
   "Freshness footer" below).
6. **Stage docs with the code.** `git add` the updated `docs/second-brain/` files (and/or
   `CLAUDE.md`) together with the source changes, so the pre-commit hook's
   requirement is satisfied honestly, not with a token touch.

### ADR numbering

1. List `docs/second-brain/adr/` and find every file matching `NNNN-*.md` (ignore
   `template.md`).
2. Take the highest `NNNN` found; the new ADR is `NNNN+1`, zero-padded to
   4 digits. If no numbered ADR exists yet, start at `0001`.
3. If the new decision replaces or invalidates a previous one, after
   creating the new ADR go back and edit the old ADR's `Status` line to
   `Superseded by ADR NNNN`. Don't delete the old file — the history of
   *why* the earlier decision was made is still valuable.
4. If a merge brings in two ADRs with the same number (concurrent
   creation on parallel branches), renumber the one merged later: rename
   its file, update its title line, and update any `Superseded by`
   references that point at it. Numbers are ordinal, not stable IDs.

## Hook exclusions and legitimate bypasses

The pre-commit hook (installed in the committed hooks dir,
`.githooks/pre-commit` by default) and its two mirrors — the Stop hook (the
second-brain plugin's `session-reminder.sh`) and the CI backstop
(`.github/workflows/second-brain.yml`) — all decide whether "source
changed" the same way: they skip lockfiles (`*.lock`,
`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `poetry.lock`,
`uv.lock`, `Cargo.lock`, `Gemfile.lock`), `.github/`, `.claude/`,
`.githooks/`, `.gitattributes`, `.second-brain.conf`, and `tests?/` at any
depth.

If a project needs a different set, change it in **`.second-brain.conf`** at
the repo root — never by editing the three files, whose patterns are
rewritten by every `/second-brain:refresh`. All three read that one file:

- `SB_EXCLUDE_EXTRA` — added to the default denylist. This is the right
  answer to a recurring false positive (generated/vendored paths, a
  non-default `--hooks-dir`).
- `SB_INCLUDE_PATTERN` — allowlist; only matching paths count as source.
  Powerful but **fail-open**: anything not listed is never checked, so docs
  can drift silently. Propose it only when the user's source lives in a
  fixed set of directories, and say what the trade-off is.
- `SB_EXCLUDE_PATTERN` — replaces the built-in denylist wholesale.

A repo bootstrapped before v0.4 has no `.second-brain.conf` yet; running
`/second-brain:bootstrap` or `/second-brain:refresh` creates it without
touching anything else.

Two legitimate reasons to bypass with `git commit --no-verify`:

- a WIP commit on a private branch that will be squashed later;
- a doc-only follow-up commit made immediately after the source commit
  it documents.

Never touch `docs/second-brain/` just to satisfy the hook ("doc-touch") — an edit
that doesn't correspond to a real change defeats the whole point of this
system, and a reviewer (or a later run of this skill) will find a doc
section that doesn't match anything real.

**Known blind spot:** because `tests?/` is excluded at any depth, changes
to *testing strategy* (new test types, frameworks, coverage tooling)
never trigger the pre-commit hook or the CI backstop — only the Stop
hook and this skill's end-of-session check catch them. That's why
trigger (5) in this skill's frontmatter exists as its own condition:
don't rely on the hook to remind you about testing-strategy changes.

## What not to write

The Second Brain is a map, not a mirror. Keep it useful by keeping it
short:

- Don't duplicate what code or git already say better: no
  function-by-function walkthroughs, no change history inside a status
  doc (that's what `git log` is for).
- Prefer a pointer to the source (`src/payments/charge.py:42`) over
  pasting the code itself. Docs rot; line references are cheap to
  re-check and cheap to fix when they drift.
- If a file grows past roughly 200 lines, that's a signal to split it
  (e.g. `patterns.md` -> `patterns.md` + `patterns/caching.md`) rather
  than let it keep growing.
- If you add, remove, or rename a file under `docs/second-brain/`, update
  `docs/second-brain/README.md`'s navigation table in the same change: it is part of
  "direct write" scope, exactly like the other status files.

## Freshness footer

Every file in `docs/second-brain/` (except `docs/second-brain/README.md` and `docs/second-brain/adr/*.md`) ends
with a footer line in exactly this format:

```text
*Last updated: 2026-07-07 — verified against commit `a1b2c3d`.*
```

The asterisks are literal Markdown italics wrapping the whole line;
`<short-sha>` gets its own nested inline-code span, the rest is plain
italic text.

Whenever you touch a file as part of this skill, refresh (or add, if
missing) its footer:

- `YYYY-MM-DD`: today's date.
- `<short-sha>`: output of `git rev-parse --short HEAD` at the time you
  make the edit — i.e. the last commit the doc has been checked against.
  This will always be one commit "behind" the commit that ends up
  including the edit itself; that's expected, not a bug.
  If the repo has no commits yet (`git rev-parse --short HEAD` fails on
  an unborn branch), write `verified against initial import` in place of
  the sha, and replace it with a real short-sha the first time this
  skill runs after the first commit exists.

The footer is a staleness signal, not a proof of correctness: a
stale-looking footer (old date, code has clearly moved on since that
commit) is a strong hint to re-run this skill's checklist on that file.
ADRs don't carry this footer — their `Status` field (Proposed / Accepted /
Deprecated / Superseded by ADR NNNN) already encodes their lifecycle.

Placeholder files that haven't been filled in for a real project yet
(fresh from this template) don't need a footer either — add one the first
time you write real content into the file, not before: a footer citing
this template repo's own commit history would be meaningless once copied
into a destination project.

## End-of-session check

Before considering the work done (or before retrying a commit rejected by
the pre-commit hook): re-run the step-2 mapping against `git status
--porcelain` and confirm every row that fires has a matching staged doc
edit, footers included. Then stage the updated documentation files together
with the code: the pre-commit hook requires every commit that changes
source code to also include a change in `docs/second-brain/` or in `CLAUDE.md`.
