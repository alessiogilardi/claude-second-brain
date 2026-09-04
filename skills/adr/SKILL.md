---
name: adr
description: >
  Records an architectural decision as an ADR under docs/second-brain/adr/:
  picks the next NNNN number, drafts the file from
  docs/second-brain/adr/template.md, presents it for confirmation
  (proposal mode), and maintains the Status lifecycle
  (Proposed / Accepted / Deprecated / Superseded by ADR NNNN). Trigger this
  skill when: (1) a decision with real alternatives and trade-offs has been
  made (choice of library, pattern, technology, protocol, storage layout);
  (2) the user asks to "write an ADR", "document this decision", or "record
  why we chose X"; (3) a new decision replaces or invalidates an earlier
  ADR and the old one must be marked superseded; (4) the
  second-brain:update skill routed a decision here. For updating the
  current-state documents (architecture.md, database.md, layout.md,
  patterns.md, testing.md, glossary.md) use second-brain:update instead —
  this skill owns docs/second-brain/adr/ only.
---

# Write an ADR

This skill owns one directory: `docs/second-brain/adr/`. Everything else
under `docs/second-brain/` belongs to the `second-brain:update` skill,
which describes *what is true now*; an ADR is the complementary artifact —
it preserves *why* a choice was made, at the moment it was made, including
the alternatives that were rejected and what they would have cost.

The distinction is load-bearing: a status document is rewritten whenever
reality moves, an ADR is append-only history. Never migrate content between
the two — a decision's rationale does not belong in `architecture.md`, and
the current shape of the system does not belong in an ADR.

## Is this actually an ADR?

Write one only when all three hold:

1. **There were real alternatives.** If there was one obvious way to do it,
   there is no decision to record — describe the result in the relevant
   status document and stop.
2. **The choice is expensive to reverse.** Storage engine, distribution
   model, enforcement strategy, public interface shape. A choice you can
   undo in an afternoon is a preference, not a decision.
3. **The rationale will not be recoverable from the code later.** The code
   shows *what* was built; if a reader six months out could not reconstruct
   *why* the rejected options were rejected, that gap is the ADR.

Things that are **not** ADRs: a recurring code convention (that's
`patterns.md`), a rule the agent must always follow (that's `CLAUDE.md` /
`.claude/rules/`), a bug fix, a refactor with no alternative worth naming,
or a restatement of a decision an existing ADR already covers — extend or
supersede that one instead of adding a near-duplicate.

## Proposal mode

A new architectural decision is never written silently. Draft the content,
present it to the user, and save only after confirmation.

**Unattended fallback**: if no user is available to confirm (a commit
rejected by the pre-commit hook mid-automation, a background run), write the
ADR anyway with `Status: Proposed` and continue. Proposal mode means "never
silently mark a decision `Accepted`", not "block until a human answers". The
user reviews later and flips the status to `Accepted`, edits it, or deletes
the file.

Only a human moves an ADR to `Accepted`. If the user confirms the draft in
the same conversation, that counts — write `Accepted`. If you inferred the
decision from the diff without being told, it stays `Proposed`.

## Numbering

1. List `docs/second-brain/adr/` and find every file matching `NNNN-*.md`
   (ignore `template.md`).
2. Take the highest `NNNN` found; the new ADR is `NNNN+1`, zero-padded to
   4 digits. If no numbered ADR exists yet, start at `0001`.
3. The filename is `NNNN-kebab-case-summary.md` — the summary is the
   decision, not the problem (`0009-configurable-gate-timing.md`, not
   `0009-commits-are-too-granular.md`). The first line of the file is
   `# ADR NNNN: <Decision title>` with the same number.

Numbers are **ordinal, not stable IDs**. If a merge brings in two ADRs with
the same number (concurrent creation on parallel branches), renumber the one
merged later: rename its file, update its title line, and update any
`Superseded by` references that point at it.

## Superseding and amending

If the new decision **replaces** a previous one, after creating the new ADR
go back and edit the old ADR's `Status` line to `Superseded by ADR NNNN`.
Never delete the old file — the history of why the earlier decision was made
is still valuable, and the new ADR's Context usually only makes sense
against it.

If the new decision **narrows or extends** a previous one without
invalidating it, say so in the new ADR's Context ("amends ADR NNNN") and
leave the old status as `Accepted`. Reserve `Superseded by` for the case
where following the old ADR today would be wrong.

## Writing the sections

Base the file on `docs/second-brain/adr/template.md` and keep its four
sections. What separates a useful ADR from a ceremonial one:

| Section | Write | Avoid |
|---|---|---|
| **Context** | The forces that made a decision necessary — the constraint, the failure mode observed, the thing that stopped working. Point at concrete evidence (`src/x.py:42`, a rejected commit, a specific incident). | Restating the decision as if it were the problem. Generic background the reader already has. |
| **Decision** | One verifiable statement of what was chosen, in the present tense, specific enough to check against the code. | Hedging ("we will probably"), or bundling three unrelated decisions into one ADR — split them. |
| **Alternatives considered** | Each real option and the concrete reason it lost. This is the section that pays for the whole file; an ADR whose alternatives are strawmen is worse than none. | Options nobody actually weighed. "Do nothing" unless it was genuinely on the table. |
| **Consequences** | What this makes harder, not only easier. Name the debt being accepted knowingly and what would force a revisit. | Listing only benefits — that's a pitch, not a record. |

Keep it tight: an ADR is read once, months later, by someone deciding
whether it still applies. Length is not evidence of rigor.

ADRs do **not** carry the freshness footer that status documents use —
their `Status` field already encodes their lifecycle.

## Staging

`git add` the new (or edited) ADR together with the source change it
documents, so the enforcement gate is satisfied honestly. `docs/second-brain/adr/`
counts as `docs/second-brain/` for every enforcement point.

If the same change also moved the current state of the system, the status
documents still need updating — that is `second-brain:update`'s job, and an
ADR does not substitute for it.
