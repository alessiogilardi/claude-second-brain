# ADR 0010: Split skills by lifecycle phase, keep conditional depth in `references/`

## Status

Accepted

## Context

`skills/update/SKILL.md` had grown to 255 lines carrying five unrelated
concerns: memory routing, the sync procedure, ADR numbering and proposal
mode, the `.second-brain.conf` / `SB_GATE` gate configuration, and the
freshness-footer format. Roughly 100 of those lines are needed only in
specific situations — the gate section only when a commit or push is
rejected, the ADR section only when a decision is being recorded — yet
every invocation paid for all of them.

Two properties of Claude Code skills constrain any fix:

1. A skill's `description` frontmatter is a **trigger surface**. Multiple
   skills whose descriptions overlap compete, and the failure mode is
   silent: nothing fires, or the wrong one does. The
   `[SECOND BRAIN SYSTEM] COMMIT REJECTED` / `PUSH REJECTED` path named by
   all four enforcement points needs one deterministic entry point.
2. Invoking a skill **injects its whole `SKILL.md` into the caller's
   context**; there is no call/return and no isolation. Decomposition
   therefore does not reduce what a run loads unless the split lines up
   with what a run actually needs.

The repo also had no recorded position on skill granularity at all, so
each change to `skills/` re-argued it from scratch.

## Decision

Skills are split by **lifecycle phase**, and depth that only some runs need
lives in a `references/` directory beside the skill's `SKILL.md`.

Three skills, one per phase:

- `second-brain:onboard` — one-time bootstrap from placeholders (unchanged).
- `second-brain:update` — ongoing sync of the status documents; the entry
  point every enforcement point names.
- `second-brain:adr` — owns `docs/second-brain/adr/`: numbering, proposal
  mode, superseding, and what makes a decision ADR-worthy.

`update` and `adr` carry explicit pointers to each other, so a change that
is both a state change and a decision is recovered from either entry point.
Trigger (3) ("a new architectural decision") was removed from `update`'s
description and now lives only in `adr`'s, so the two do not compete.

`skills/update/references/` holds `writing-guides.md` (per-file guidance,
editorial rules, freshness-footer edge cases) and `gate-config.md`
(exclusions, `SB_GATE` timing, legitimate bypasses). A reference may never
hold a trigger condition or a step of the main procedure: if every run needs
it, it belongs in `SKILL.md`.

## Alternatives considered

- **One skill per Second Brain document** (`write-architecture`,
  `write-database`, `write-patterns`, …) with `update` as a pure
  orchestrator — the shape originally proposed. Rejected on all three
  counts: a typical run touches 2–4 documents, so it would load the
  orchestrator plus several sub-skills instead of one file; the genuinely
  large material (routing, gate config, footer, editorial rules) is
  cross-cutting and would have to be duplicated across seven files or
  referenced from a shared one, adding a fifth duplication axis to the
  four this repo already maintains by hand (ADR 0002); and seven competing
  descriptions fragment the trigger surface the rejection path depends on.
- **Dispatch each document to a subagent.** This is the only variant that
  gives real context isolation, but a subagent does not have the session's
  history of *what changed and why* — that would have to be serialized into
  each prompt, which is both lossy and more expensive than the material it
  avoids loading.
- **Leave `SKILL.md` monolithic.** Cheapest, but the per-file writing
  guidance the system actually lacked had nowhere to go: adding it inline
  would have pushed the file past 400 lines, all of it loaded every run.

## Consequences

- A routine `update` run loads ~155 lines instead of 255, and the material
  it skips is precisely the material it doesn't need.
- There is now a place to grow depth without taxing every run — the
  per-file writing guidance is the first occupant.
- The cost is indirection: a reference that is never read is worse than no
  reference. `SKILL.md` must name each one at the exact step that needs it,
  and that pointer is now a load-bearing line — deleting it silently
  disables the content.
- Cross-skill pointers between `update` and `adr` are a second thing that
  can drift. The mitigation is that either entry point recovers the other's
  scope, so a stale pointer degrades to "one extra hop", not to lost work.
- `skills/onboard/SKILL.md` no longer points at `update` for ADR policy; it
  points at `adr`. Any future skill added to this plugin must justify itself
  as a distinct lifecycle phase, not as a distinct output file.
