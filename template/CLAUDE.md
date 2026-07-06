<!-- BEGIN SECOND BRAIN SYSTEM (managed by claude-second-brain-skill: do not edit this block by hand, edit template/CLAUDE.md and rerun install.ps1) -->
# Second Brain

This project uses the "Second Brain" documentation system: a set of files
in `docs/` describing the actual state of architecture, database, patterns,
and testing, meant to be read and maintained by AI agents.

## Documentation map

Always check `docs/README.md` as the entry point. In short:

- `docs/architecture.md` — architecture overview
- `docs/database.md` — database schema and relationships
- `docs/patterns.md` — design patterns and recurring conventions in the code
- `docs/glossary.md` — domain terms glossary
- `docs/layout.md` — folder structure and module responsibilities
- `docs/testing.md` — testing strategy and tools
- `docs/adr/` — Architecture Decision Records (one decision per file)

## Skills

- **update-second-brain** (`.claude/skills/update-second-brain/SKILL.md`) —
  keeps the Second Brain documentation aligned with the code (architecture,
  database schema, patterns, glossary, layout, testing, ADRs).
  Trigger: after a database schema change, a structural refactor, a new
  architectural decision, a new recurring pattern, a testing strategy
  change, when the pre-commit hook rejects a commit with
  "[SECOND BRAIN SYSTEM] COMMIT REJECTED", or as an end-of-session check.
  Invoke it with the Skill tool (`skill: "update-second-brain"`) before
  closing the session.

## How to use Second Brain

- Before starting a non-trivial task, read `docs/architecture.md` and
  `docs/layout.md`.
- Before touching the database, read `docs/database.md`.
- Before writing new code, check `docs/patterns.md` for existing
  conventions to reuse.
- Before ending a session — or before retrying a commit rejected by the
  pre-commit hook — run the `update-second-brain` skill checklist.
- New architectural decisions go through the skill's "proposal mode": draft
  the ADR from `docs/adr/template.md` and confirm it with the user before
  saving it.

## Operating rule

Every commit that changes source code must come with a matching update in
`docs/` or in this file: a git hook in `.claude/hooks/pre-commit`
automatically checks this and rejects the commit otherwise.
<!-- END SECOND BRAIN SYSTEM -->
