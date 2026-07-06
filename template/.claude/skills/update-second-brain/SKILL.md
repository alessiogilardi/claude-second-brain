---
name: update-second-brain
description: >
  Updates the project's "Second Brain" documentation (docs/architecture.md,
  docs/database.md, docs/patterns.md, docs/glossary.md, docs/layout.md,
  docs/testing.md, docs/adr/) to keep it aligned with the code. Trigger
  this skill when: (1) database tables, columns, migrations, or schema
  have changed; (2) a structural refactor of modules, services, or
  packages has been done; (3) a new architectural decision has been made
  (choice of library, pattern, technology, significant trade-off); (4) a
  new design pattern or recurring convention has been introduced in the
  code; (5) the testing strategy has changed (new test types, new tools,
  new coverage policy); (6) the pre-commit hook rejected a commit with the
  message "[SECOND BRAIN SYSTEM] COMMIT REJECTED"; (7) at the end of a work
  session, before closing or handing off, to verify nothing was left out
  of sync.
---

# Update Second Brain

This skill keeps the project's technical documentation (the "second
brain") in sync with the actual state of the code, so that any future AI
agent (including yourself in a later session) can get oriented without
having to re-read the entire codebase.

## Operating modes

- **Direct write** for existing technical files:
  `docs/architecture.md`, `docs/database.md`, `docs/patterns.md`,
  `docs/glossary.md`, `docs/layout.md`, `docs/testing.md`. Update these
  pages in place, without asking for confirmation, because they describe
  the current state of the system and must stay accurate.
- **Proposal mode** for new files in `docs/adr/`: a new architectural
  decision should not be written silently. Draft the content using
  `docs/adr/template.md` as a base and present it to the user for
  confirmation before saving it (sequential numbering, e.g.
  `0003-title.md`).

## End-of-session checklist

Before considering the work done (or before retrying a commit rejected by
the pre-commit hook), go through this checklist point by point:

- [ ] **ADR**: was a relevant architectural decision made? If so, propose
      a new file in `docs/adr/` based on `docs/adr/template.md`.
- [ ] **Database schema**: did tables, columns, relationships, or
      migrations change? Update `docs/database.md` accordingly.
- [ ] **Patterns**: was a new or recurring architectural pattern or
      convention introduced? Map it in `docs/patterns.md`.
- [ ] **Testing**: did frameworks, test types, or coverage policy change?
      Update `docs/testing.md`.
- [ ] **Overall architecture**: does the change affect the layout of
      components or main flows? Update `docs/architecture.md` and/or
      `docs/layout.md`.
- [ ] **Glossary**: were new domain terms introduced? Add them to
      `docs/glossary.md`.

Only after completing the checklist, stage the updated documentation
files together with the code: the pre-commit hook requires every commit
that changes source code to also include a change in `docs/` or in
`CLAUDE.md`.
