<!-- BEGIN SECOND BRAIN SYSTEM (managed by claude-second-brain-skill: do not edit this block by hand, edit template/CLAUDE.md and rerun install.ps1) -->
# Second Brain

This project uses the "Second Brain" documentation system: a set of files
in `docs/` describing the actual state of architecture, database,
patterns, and testing, meant to be read and maintained by AI agents. The
full policy — memory routing, when to read/write what, the update
procedure, ADR numbering, what not to write, freshness footers — lives in
a single place, not here:

`.claude/skills/update-second-brain/SKILL.md`

Invoke it with the Skill tool (`skill: "update-second-brain"`) after a
database schema change, a structural refactor, a new architectural
decision, a new recurring pattern, a testing strategy change, when the
pre-commit hook rejects a commit with "[SECOND BRAIN SYSTEM] COMMIT
REJECTED", or as an end-of-session check.

## Navigation

@docs/README.md

## Operating rule

Every commit that changes source code must come with a matching update in
`docs/` or in this file: a git hook in `.claude/hooks/pre-commit`
automatically checks this and rejects the commit otherwise. The hook is a
syntactic reminder, not a semantic guarantee — see the skill above for the
exact policy, configurable exclusions, and when bypassing it legitimately
is fine.
<!-- END SECOND BRAIN SYSTEM -->
