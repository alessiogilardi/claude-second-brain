<!-- BEGIN SECOND BRAIN SYSTEM (managed by the second-brain plugin: do not edit this block by hand, edit bootstrap/payload/claude-md-block.md and re-run the bootstrap with --refresh-system) -->
## Skill: Second Brain
**Source of Truth:** `docs/` (architecture, ADRs, state).
**Full Policy:** the `update-second-brain` skill.

@docs/README.md

### Triggers (IMMEDIATE ACTION REQUIRED)
Run `skill: "update-second-brain"` after:
* Schema changes or structural refactors.
* New architectural decisions or recurring patterns.
* Testing-strategy changes.
* `[SECOND BRAIN SYSTEM] COMMIT REJECTED` pre-commit error.

**Exception:** IF `docs/*.md` contains `> Placeholder —`, run `onboard-second-brain` instead.

### Strict Commit Rule
Commits touching code **MUST** stage an update to `docs/` **or this file**.
If rejected: 1. Run skill -> 2. Stage docs -> 3. Retry. Never use dummy updates.
<!-- END SECOND BRAIN SYSTEM -->
