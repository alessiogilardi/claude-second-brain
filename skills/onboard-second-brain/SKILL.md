---
name: onboard-second-brain
description: >
  One-time bootstrap of the project's "Second Brain" documentation:
  replaces every `> Placeholder` marker found anywhere under docs/ (e.g.
  architecture.md, database.md, layout.md, testing.md, patterns.md,
  glossary.md) with content verified against the real codebase. Trigger
  this skill when: (1) any file under docs/ still contains the
  `> Placeholder` marker (fresh template install never populated for
  this project); (2) the user explicitly asks to "onboard", "bootstrap",
  or "populate" the Second Brain. Once every placeholder is gone, this
  skill's job is done — all later documentation upkeep is the
  update-second-brain skill's job, not this one's.
---

# Onboard Second Brain

This skill runs exactly once per project (the first time the Second
Brain has real content to describe) and replaces the generic
placeholders shipped by the template with the actual state of this
codebase. It owns the *bootstrap* procedure only — the ongoing policy
(memory routing, freshness footer format, ADR numbering, what not to
write) is not repeated here; it lives in the `update-second-brain` skill
and applies unchanged from the moment onboarding finishes.

## When this skill is done

Check every file under `docs/` for the `> Placeholder` marker (grep this
ASCII-safe prefix, not the full em-dash text — re-encoding can silently
corrupt `—` and hide the marker from a literal match). If none remains,
onboarding is complete — don't re-run this skill "just in case"; use
`update-second-brain` for anything after this point, including the
first real edit to a file this skill just wrote.

## Procedure

1. **Detect scope.** Grep every file under `docs/` (recursively,
   excluding `docs/adr/`) for `> Placeholder` — the ASCII-safe prefix,
   not the full em-dash marker — to get the exact list of files still
   needing onboarding. Skip files already populated (e.g. a partial
   manual onboarding happened before).
2. **Explore per file concern**, then write concrete, specific content —
   never leave a generic instruction once the real answer is known:

   | File | Explore for | Where to look |
   |---|---|---|
   | `docs/layout.md` | Top-level folder tree and each folder's responsibility | repo root listing, package/module boundaries |
   | `docs/architecture.md` | Entry points, main call graph, external integrations | main/entry files, service boundaries, config for external APIs |
   | `docs/database.md` | Schema, tables, relationships, migration tooling | migration files, ORM models, schema.sql / DDL |
   | `docs/testing.md` | Test framework, how tests run, coverage tooling | test config files, CI test steps, `tests/` structure |
   | `docs/patterns.md` | Recurring idioms actually used in the code (not generic textbook patterns) | repeated structural choices across modules (factories, middleware, DI) |
   | `docs/glossary.md` | Domain terms used in code, comments, and commit history | identifier names, docstrings, `git log` messages |

   Work through the files in this order: `layout.md` first (it orients
   every later file). After that, the remaining five explorations are
   independent of each other; on non-trivial codebases run them as
   parallel read-only subagent searches (one per file concern, each
   returning verified findings) and write the files from their results
   serially afterward, instead of exploring and writing each one in a
   single long sequential pass.

   A concern that doesn't apply to this project (no database yet, no
   tests yet, patterns not established in a very young codebase) is
   still onboarded, not skipped: replace the placeholder with a one-line
   factual statement instead of fabricating content — e.g. "This project
   has no database; this file intentionally left minimal — populate it
   if one is introduced." — then add the freshness footer as usual
   (step 4). The `> Placeholder` marker must never survive onboarding,
   even when there's nothing substantial to say yet: the
   `update-second-brain` guard treats any lingering marker as
   "onboarding incomplete" and redirects back here, so leaving one
   behind — even for a legitimately empty concern — would permanently
   block all future doc updates on this project. Don't delete the file
   instead of stubbing it: the file needs to already exist, findable,
   and footer-bearing for when the concern becomes real later.
3. **Replace, don't merge.** Overwrite each placeholder section with the
   real content; don't keep the instructional prose from the template
   next to the real answer.
4. **Add the first freshness footer** to every file you populate, using
   the format defined in `update-second-brain`'s SKILL.md ("Freshness
   footer" section) — this is the first time these files get one, since
   placeholders are explicitly exempt from it.
5. **Update `docs/README.md`'s navigation table** only if the set of
   files under `docs/` changed (it shouldn't, during onboarding — the
   template already ships the full set).
6. **Propose retroactive ADRs last, in proposal mode** (see
   `update-second-brain`'s SKILL.md — same confirmation flow and
   unattended fallback apply here): only for decisions still *visible in
   the code today* (a chosen library, an established schema convention,
   a deliberate trade-off you can point to). Don't reconstruct history
   that left no trace — an absent ADR is honest; a fabricated one isn't.
7. **Resume the interrupted work, if any.** If this skill was reached
   from a pre-commit rejection or from `update-second-brain`'s
   placeholder guard, a source change is still pending (staged or
   uncommitted) that hasn't been mapped to docs yet — onboarding
   populates docs/ from the codebase as it stands, which only
   incidentally covers that specific change. Finish by running
   `update-second-brain` for that pending change, then retry the commit.

## What not to do

- Don't guess at content you haven't verified against the actual files —
  a wrong onboarded doc is worse than a placeholder, because it looks
  authoritative.
- Don't carry over any of the template's instructional/example text
  (e.g. the `_Example_` glossary row, the `example_table` schema
  snippet) into the real file.
- Don't duplicate `update-second-brain`'s policy here (memory routing
  table, freshness footer format, ADR numbering scheme) — reference it
  instead of restating it, so the two skills don't drift apart.
