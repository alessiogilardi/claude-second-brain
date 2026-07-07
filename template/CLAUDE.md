<!-- BEGIN SECOND BRAIN SYSTEM (managed by claude-second-brain-skill: do not edit this block by hand, edit template/CLAUDE.md and rerun install.ps1) -->
# Second Brain

`docs/` is the source of truth for the system's current state
(architecture, database, patterns, testing, layout, glossary, ADRs),
maintained by AI agents. The full policy — memory routing, update
procedure, ADR numbering, freshness footers, hook exclusions and
legitimate bypasses — lives only in
`.claude/skills/update-second-brain/SKILL.md`.

Invoke it (Skill tool, `skill: "update-second-brain"`) after: schema
changes, structural refactors, new architectural decisions, new recurring
patterns, testing-strategy changes, a "[SECOND BRAIN SYSTEM] COMMIT
REJECTED" pre-commit rejection, or as an end-of-session check. If any
`docs/*.md` file still carries the `> Placeholder —` marker, run
`onboard-second-brain` instead — the one-time bootstrap from template
placeholders to real content.

@docs/README.md

**Commit rule**: a commit touching source code must also stage an update
to `docs/` or this file — enforced syntactically by
`.claude/hooks/pre-commit`. On rejection: run the skill, stage the docs
with the code, retry. Never touch `docs/` just to pass the hook.
<!-- END SECOND BRAIN SYSTEM -->
