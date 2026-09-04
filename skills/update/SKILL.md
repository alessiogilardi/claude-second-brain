---
name: update
description: >
  Updates the project's "Second Brain" documentation under docs/second-brain/ (e.g.
  architecture.md, database.md, patterns.md, glossary.md, layout.md,
  testing.md, docs/second-brain/README.md — the exact
  set of files can grow or shrink per project) to keep it aligned with
  the code. Trigger this skill when: (1) database tables,
  columns, migrations, or schema have changed; (2) a structural refactor
  of modules, services, or packages has been done; (3) a new design
  pattern or recurring convention has been introduced in the code; (4) the
  testing strategy has changed (new test types, new tools, new coverage
  policy); (5) the pre-commit or pre-push hook rejected a change with the
  message "[SECOND BRAIN SYSTEM] COMMIT REJECTED" or "PUSH REJECTED";
  (6) at the end of a work session, before closing or handing off, to
  verify nothing was left out of sync. For recording a *decision* and its
  rationale as an ADR, this skill routes to second-brain:adr, which owns
  docs/second-brain/adr/.
---

# Update Second Brain

This skill keeps the project's technical documentation (the "second
brain") in sync with the actual state of the code, so that any future AI
agent (including yourself in a later session) can get oriented without
having to re-read the entire codebase. It is the entry point for that
policy — `CLAUDE.md` and `docs/second-brain/README.md` only point here,
they don't restate the rules.

It owns every file under `docs/second-brain/` **except** `adr/`, which
belongs to the `second-brain:adr` skill: status documents describe what is
true now, ADRs preserve why a choice was made. One change often needs both.

## Reference files

Depth lives next to this file, loaded when needed rather than every run
(from a plugin install, prefix with `${CLAUDE_PLUGIN_ROOT}/skills/update/`):

| File | Read it when |
|---|---|
| `references/writing-guides.md` | Before writing prose into any `docs/second-brain/` file — per-file guidance, editorial rules, freshness-footer edge cases. |
| `references/gate-config.md` | A commit/push was rejected, the gate misfired, or you're about to propose a `.second-brain.conf` change — exclusions, `SB_GATE` timing, legitimate bypasses. |

## Memory routing

Before writing anything down, decide *where* it belongs. Four
destinations exist, each with a different scope and lifetime:

| What you learned | Where it goes | Why |
|---|---|---|
| Current state of the system (schema, architecture, layout, testing setup) | `docs/second-brain/*.md` (this skill) | Describes "what is true now"; must stay in sync with the code, one file per concern. |
| A decision and its rationale/trade-offs | `docs/second-brain/adr/NNNN-*.md` — run `second-brain:adr` | Decisions are point-in-time and mostly irreversible; ADRs preserve the *why*, not just the *what*. |
| An operating convention the agent must always apply in this project (e.g. "use uv, never pip", "always run X before Y") | `CLAUDE.md` / `.claude/rules/*.md` | Native, auto-loaded memory: enforced every session without relying on the agent remembering to check `docs/second-brain/`. |
| A preference or feedback about *how the user likes to work*, independent of this specific project | Claude Code's native user memory (not a project file) | Cross-project; belongs to the user-agent relationship, not to this codebase. |

Rule of thumb: if the fact describes **the code**, it goes in `docs/second-brain/`. If
it describes **a rule the agent must always follow**, it goes in
`CLAUDE.md` / `.claude/rules/`. If it describes **how the user wants to be
worked with**, it isn't a project file at all — use native user memory.
Never restate a `CLAUDE.md`/`.claude/rules/` convention inside `docs/second-brain/` (or
vice versa): pick one home per fact.

## Operating mode

**Direct write** for every file this skill owns — `docs/second-brain/README.md`,
the standard concern files shipped by the template, and any project-specific
file added later (e.g. `docs/second-brain/patterns/caching.md`). Update these
pages in place, without asking for confirmation, because they describe the
current state of the system and must stay accurate.

ADRs are the exception, and they are not this skill's to write: a decision
goes through `second-brain:adr`, which runs in proposal mode.

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
   - a decision with real alternatives and trade-offs -> run
     `second-brain:adr` (it owns numbering, proposal mode, and superseding)
   - a file was added or removed under `docs/second-brain/` -> also update
     `docs/second-brain/README.md`'s navigation table
3. **Update, don't rewrite.** Read `references/writing-guides.md` before
   writing, then edit only the relevant section of the target file; don't
   regenerate the whole document, and don't add a changelog inside status
   docs — git history is the changelog.
4. **Cross-check against the real code**, not against your memory of the
   session: re-read the updated section and verify every claim against the
   current files before considering it done.
5. **Refresh the freshness footer** of every file you touched (see below).
6. **Stage docs with the code.** `git add` the updated `docs/second-brain/` files (and/or
   `CLAUDE.md`) together with the source changes, so the gate's
   requirement is satisfied honestly, not with a token touch. If the gate
   rejected the change and the mapping in step 2 legitimately produced no
   documentation update, read `references/gate-config.md` before doing
   anything else — never touch a doc just to pass the check.

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

Edge cases (unborn branch, exempt files, what the footer does and doesn't
prove) are in `references/writing-guides.md`.

## End-of-session check

Before considering the work done (or before retrying a rejected commit or
push): re-run the step-2 mapping against `git status --porcelain` and
confirm every row that fires has a matching staged doc edit, footers
included. Then stage the updated documentation files together
with the code: the gate requires every change to source code to also
include a change in `docs/second-brain/` or in `CLAUDE.md`.
