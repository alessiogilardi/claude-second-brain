# ADR 0008: The Second Brain doc set lives in `docs/second-brain/`, and the denylist is source-side only

## Status

Proposed

## Context

The bootstrap scaffolded the doc set straight into the destination's
`docs/` root: `architecture.md`, `database.md`, `glossary.md`, `layout.md`,
`patterns.md`, `testing.md`, `README.md` and `adr/`. Most repos that adopt
the system already keep documentation there, so the two sets interleave and
`docs/README.md` — the Second Brain navigation map the reader agent is told
to start from — collides head-on with the project's own docs index. There
is no way to tell, from a path alone, whose file it is.

The enforcement side had the mirror-image problem. `DOCS_PATTERN` was
`^docs/|^CLAUDE\.md$`, so *any* edit under `docs/` satisfied the check: a
typo fix in the project's own API reference counted as "the Second Brain
was updated". The check was weaker than it looked.

Narrowing `DOCS_PATTERN` to `^docs/second-brain/` fixes that but creates a
third problem. Under ADR 0007's evaluation order the denylist is applied to
the whole changed-file list *before* the docs/source split:

```
relevant = changed  −  EXCLUDE
docs     = relevant  ∩  DOCS_PATTERN
source   = relevant  −  DOCS_PATTERN  [∩ INCLUDE]
```

With the narrower pattern, everything else under `docs/` falls to the
source side and demands a Second Brain update — a false positive on exactly
the directory this change exists to keep clean. And there is no escape
hatch: adding `^docs/` to `SB_EXCLUDE_EXTRA` removes `docs/second-brain/`
from the docs set too, so the check can never be satisfied again. ERE has
no negative lookahead, so "exclude `docs/` but not `docs/second-brain/`"
cannot be expressed as one pattern.

## Decision

Two changes, taken together.

**1. The doc set moves to `docs/second-brain/`.** The path is a fixed
literal, hardcoded in the three enforcement points, in `bootstrap.sh`, in
the `CLAUDE.md` block's `@`-import, and in the skill and agent prompts.
`DOCS_PATTERN` becomes `^docs/second-brain/|^CLAUDE\.md$`, and `docs/`
joins the default denylist.

**2. The denylist becomes source-side only**, amending ADR 0007's
evaluation order:

```
docs   = changed  ∩  DOCS_PATTERN
source = changed  −  DOCS_PATTERN  −  EXCLUDE  [∩ INCLUDE]
```

The docs/source split now runs on the raw file list. This is the same
asymmetry `SB_INCLUDE_PATTERN` already had, and it is justified the same
way: a filter that answers "is this a source change?" must not get a vote
on whether the documentation was updated. It is also what makes the broad
`docs/` denylist entry safe — files under `docs/second-brain/` have already
left the source side via `DOCS_PATTERN` by the time the denylist is
consulted.

The net effect for a destination: `docs/second-brain/` is the Second Brain,
everything else under `docs/` is the project's own and is neutral — editing
it neither trips the check nor satisfies it.

`bootstrap.sh` detects the old layout (a `docs/README.md` containing
`Second Brain`, with no `docs/second-brain/` present), skips the docs
scaffold, and prints the `git mv` to run. It does not move anything itself:
the script never touches user content, and only the destination knows which
files under `docs/` are ours.

## Alternatives considered

- **`SB_DOCS_DIR` in `.second-brain.conf`.** The three enforcement points
  already have a conf reader and could take it. But `bootstrap.sh`, the
  `CLAUDE.md` block (`@docs/second-brain/README.md` is a literal import
  resolved by Claude Code, not a variable) and the skill/agent prompts are
  static text served read-only from the plugin cache — they cannot be
  templated per destination. Every one of them would have to be rewritten
  as "read the directory configured in `.second-brain.conf`", trading a
  hardcoded path for indirection in a dozen prompts to buy flexibility
  nobody had asked for.
- **A fixed path plus an enforcement-only `SB_DOCS_PATTERN` override**, as
  a bridge for destinations that cannot migrate immediately. Its semantics
  — affects the check but not the scaffolder and not the prompts — are hard
  to state and easy to misconfigure into a check that silently passes.
  Migration is one `git mv`; a permanent knob is a bad price for it.
- **Leaving `DOCS_PATTERN` at `^docs/` and moving only the scaffold.** Zero
  risk of regression and no breaking change, but it keeps the weakness that
  motivated the narrowing: any edit anywhere under `docs/` would keep
  satisfying the check.
- **Keeping ADR 0007's evaluation order and excluding `docs/` with an ERE
  that spares `docs/second-brain/`.** Expressible without lookahead only as
  a character-by-character alternation (`^docs/([^s]|s[^e]|se[^c]|…)`),
  which has to be written identically in three files and reviewed by hand.
  Rejected on legibility alone.

## Consequences

- **Breaking for every existing destination** — the major-version tier
  under ADR 0005 (0.5.2 → 1.0.0). After `/second-brain:refresh`, a repo
  that has not moved its docs is rejected on every commit, because the
  refreshed hook no longer recognises `docs/*.md` as documentation. The
  bootstrap's legacy detection and the README document the move; the move
  itself is manual and deliberate.
- The check gets strictly stronger: the only thing that satisfies it is a
  change to the Second Brain itself or to `CLAUDE.md`.
- A destination can keep whatever it likes under `docs/` without the
  system caring, which was the point.
- Two behaviour deltas from the reordering, both intentional: a
  documentation file that matches the denylist still counts as a docs
  change (near-unreachable now that `DOCS_PATTERN` is narrow), and
  `CLAUDE.md` can no longer be suppressed via `SB_EXCLUDE_PATTERN` /
  `SB_EXCLUDE_EXTRA` — it always counts as documentation.
- The ADR 0002 mirroring burden grows slightly: the three copies must now
  agree on the evaluation *order* as well as on the patterns and the conf
  reader. The order is spelled out in a comment at each site.
- The reader agent gains a scope rule ("`docs/second-brain/` only") so it
  cannot answer from a project doc that happens to sit next door.

*Last updated: 2026-08-20 — verified against the working tree.*
