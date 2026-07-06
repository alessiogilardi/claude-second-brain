<!-- BEGIN SECOND BRAIN SYSTEM (managed by claude-second-brain-skill: do not edit this block by hand, edit template/CLAUDE.md and rerun init.ps1) -->
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

## Operating rule

Every commit that changes source code must come with a matching update in
`docs/` or in this file: a git hook in `.claude/hooks/pre-commit`
automatically checks this and rejects the commit otherwise.

When you change the DB schema, do a structural refactor, make a new
architectural decision, introduce a new pattern, or change the testing
strategy, run the `.claude/skills/update-second-brain` skill to align the
documentation before closing the session.
<!-- END SECOND BRAIN SYSTEM -->
