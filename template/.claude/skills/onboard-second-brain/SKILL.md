---
name: onboard-second-brain
description: >
  One-time bootstrap of the project's "Second Brain" documentation:
  replaces every `> Placeholder —` marker in docs/architecture.md,
  docs/database.md, docs/layout.md, docs/testing.md, docs/patterns.md,
  and docs/glossary.md with content verified against the real codebase.
  Trigger this skill when: (1) any file under docs/ still contains the
  `> Placeholder —` marker (fresh template install never populated for
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
write) is not repeated here; it lives in
`.claude/skills/update-second-brain/SKILL.md` and applies unchanged from
the moment onboarding finishes.

## When this skill is done

Check every file under `docs/` for the `> Placeholder —` marker. If none
remains, onboarding is complete — don't re-run this skill "just in case";
use `update-second-brain` for anything after this point, including the
first real edit to a file this skill just wrote.

## Procedure

1. **Detect scope.** Grep `docs/*.md` for `> Placeholder —` to get the
   exact list of files still needing onboarding. Skip files already
   populated (e.g. a partial manual onboarding happened before).
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
   every later file), then `architecture.md` and `database.md` (the
   structural core), then `patterns.md`, `testing.md`, `glossary.md`.
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
