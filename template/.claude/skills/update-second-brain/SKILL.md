---
name: update-second-brain
description: >
  Updates the project's "Second Brain" documentation (docs/README.md,
  docs/architecture.md, docs/database.md, docs/patterns.md,
  docs/glossary.md, docs/layout.md, docs/testing.md, docs/adr/) to keep it
  aligned with the code. Trigger this skill when: (1) database tables,
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
for this policy — `CLAUDE.md` and `docs/README.md` only point here, they
don't restate the rules.

## Memory routing

Before writing anything down, decide *where* it belongs. Four
destinations exist, each with a different scope and lifetime:

| What you learned | Where it goes | Why |
|---|---|---|
| Current state of the system (schema, architecture, layout, testing setup) | `docs/*.md` (this Second Brain) | Describes "what is true now"; must stay in sync with the code, one file per concern. |
| A decision and its rationale/trade-offs | `docs/adr/NNNN-*.md` | Decisions are point-in-time and mostly irreversible; ADRs preserve the *why*, not just the *what*. |
| An operating convention the agent must always apply in this project (e.g. "use uv, never pip", "always run X before Y") | `CLAUDE.md` / `.claude/rules/*.md` | Native, auto-loaded memory: enforced every session without relying on the agent remembering to check `docs/`. |
| A preference or feedback about *how the user likes to work*, independent of this specific project | Claude Code's native user memory (not a project file) | Cross-project; belongs to the user-agent relationship, not to this codebase. |

Rule of thumb: if the fact describes **the code**, it goes in `docs/`. If
it describes **a rule the agent must always follow**, it goes in
`CLAUDE.md` / `.claude/rules/`. If it describes **how the user wants to be
worked with**, it isn't a project file at all — use native user memory.
Never restate a `CLAUDE.md`/`.claude/rules/` convention inside `docs/` (or
vice versa): pick one home per fact.

## Operating modes

- **Direct write** for existing technical files:
  `docs/README.md`, `docs/architecture.md`, `docs/database.md`,
  `docs/patterns.md`, `docs/glossary.md`, `docs/layout.md`,
  `docs/testing.md`. Update these pages in place, without asking for
  confirmation, because they describe the current state of the system and
  must stay accurate.
- **Proposal mode** for new files in `docs/adr/`: a new architectural
  decision should not be written silently. Draft the content using
  `docs/adr/template.md` as a base and present it to the user for
  confirmation before saving it (see "ADR numbering" below for the file
  name). **Unattended fallback**: if running with no user available to
  confirm (e.g. a commit rejected by the pre-commit hook mid-automation),
  write the ADR anyway with `Status: Proposed` and continue — proposal
  mode means "never silently mark a decision `Accepted`", not "block
  until a human answers". The user reviews later and flips the status to
  `Accepted`, edits it, or deletes the file.

## Procedure

If any file under `docs/` still carries the `> Placeholder —` marker,
stop here and run the `onboard-second-brain` skill instead — it owns the
one-time bootstrap from template placeholders to real content. Once no
placeholder remains, everything below applies.

Follow these steps every time the skill runs, whether triggered mid-session
or as an end-of-session check:

1. **Gather evidence.** Run `git diff --cached --stat` (or `git diff HEAD
   --stat` if nothing is staged yet) to get the real list of changed
   files — never rely on memory of what "felt like" a big change.
2. **Map changes to documents**, using the table in "Memory routing" above
   plus this file-level mapping:
   - migrations, schema files, ORM models -> `docs/database.md`
   - new/removed/moved packages, modules, folders -> `docs/layout.md`
   - new services, changed call graph, new external integration ->
     `docs/architecture.md`
   - a repeated structural choice (new factory, new middleware
     convention) -> `docs/patterns.md`
   - new test types, frameworks, coverage tooling -> `docs/testing.md`
   - a new domain term used in code/comments/commits -> `docs/glossary.md`
   - a decision with real alternatives and trade-offs -> new ADR (see "ADR
     numbering" below)
   - a file was added or removed under `docs/` -> also update
     `docs/README.md`'s navigation table (see "What not to write")
3. **Update, don't rewrite.** Edit only the relevant section of the target
   file; don't regenerate the whole document, and don't add a changelog
   inside status docs — git history is the changelog.
4. **Cross-check against the real code**, not against your memory of the
   session: re-read the updated section and verify every claim against the
   current files before considering it done.
5. **Refresh the freshness footer** of every file you touched (see
   "Freshness footer" below).
6. **Stage docs with the code.** `git add` the updated `docs/` files (and/or
   `CLAUDE.md`) together with the source changes, so the pre-commit hook's
   requirement is satisfied honestly, not with a token touch.

### ADR numbering

1. List `docs/adr/` and find every file matching `NNNN-*.md` (ignore
   `template.md`).
2. Take the highest `NNNN` found; the new ADR is `NNNN+1`, zero-padded to
   4 digits. If no numbered ADR exists yet, start at `0001`.
3. If the new decision replaces or invalidates a previous one, after
   creating the new ADR go back and edit the old ADR's `Status` line to
   `Superseded by ADR NNNN`. Don't delete the old file — the history of
   *why* the earlier decision was made is still valuable.

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
- If you add, remove, or rename a file under `docs/`, update
  `docs/README.md`'s navigation table in the same change: it is part of
  "direct write" scope, exactly like the other status files.

## Freshness footer

Every file in `docs/` (except `docs/README.md` and `docs/adr/*.md`) ends
with a footer line:

`*Last updated: YYYY-MM-DD — verified against commit `<short-sha>`.*`

Whenever you touch a file as part of this skill, refresh (or add, if
missing) its footer:

- `YYYY-MM-DD`: today's date.
- `<short-sha>`: output of `git rev-parse --short HEAD` at the time you
  make the edit — i.e. the last commit the doc has been checked against.
  This will always be one commit "behind" the commit that ends up
  including the edit itself; that's expected, not a bug.

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
the pre-commit hook): re-run the step-2 mapping against `git diff HEAD
--stat` and confirm every row that fires has a matching staged doc edit,
footers included. Then stage the updated documentation files together
with the code: the pre-commit hook requires every commit that changes
source code to also include a change in `docs/` or in `CLAUDE.md`.
