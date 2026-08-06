<!-- BEGIN SECOND BRAIN SYSTEM (managed by the second-brain plugin: do not edit this block by hand, edit bootstrap/payload/claude-md-block.md and re-run the bootstrap with --refresh-system) -->
## Skill: Second Brain
**Source of Truth:** `docs/` (architecture, ADRs, state).
**Full Policy:** the `second-brain:update` skill.

@docs/README.md

### Before Non-Trivial Work (MANDATORY)
Before any analysis, code review, planning, or implementation, delegate to
the `second-brain:second-brain-reader` subagent to check `docs/` for existing patterns,
prior decisions, domain terms, and testing conventions. Do not read the
`docs/*.md` files yourself to answer these questions — that defeats the
subagent's purpose. Skipping this step means acting on stale assumptions
about architecture that's already been decided.

### Triggers (IMMEDIATE ACTION REQUIRED)
Run `skill: "second-brain:update"` after:
* Schema changes or structural refactors.
* New architectural decisions or recurring patterns.
* Testing-strategy changes.
* `[SECOND BRAIN SYSTEM] COMMIT REJECTED` pre-commit error.

**Exception:** IF `docs/*.md` contains `> Placeholder —`, run `second-brain:onboard` instead.

### Strict Commit Rule
Commits touching code **MUST** stage an update to `docs/` **or this file**.
If rejected: 1. Run skill -> 2. Stage docs -> 3. Retry. Never use dummy updates.
**Never hand-edit `docs/*.md` to satisfy the pre-commit check.** The check
is syntactic only — it just confirms *some* file under `docs/` changed, it
cannot tell whether the change is real. Always go through
`skill: "second-brain:update"`, which routes the fact to the right file,
proposes an ADR when warranted, and refreshes the freshness footer.
A hand-edit that skips these steps passes the check but leaves the docs
wrong or stale, defeating the whole point of the system.
<!-- END SECOND BRAIN SYSTEM -->
