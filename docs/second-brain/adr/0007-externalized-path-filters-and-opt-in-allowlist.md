# ADR 0007: Externalized path filters in a create-only `.second-brain.conf`, with an opt-in allowlist

## Status

Proposed

## Context

Which paths count as a "source change" was hard-coded as a single
`EXCLUDE_PATTERN` denylist, duplicated byte-identically across the three
enforcement points (ADR 0002). Two problems came out of real use:

1. **Customization did not survive.** The README told users to edit
   `EXCLUDE_PATTERN` to fit their project, but `--refresh-system`
   (`/second-brain:refresh`) rewrites the pre-commit block between its
   markers and overwrites `.github/workflows/second-brain.yml` wholesale.
   Any hand-tuned pattern was silently reverted on the next plugin
   refresh — and had to be applied in three files to begin with.
2. **A denylist alone is the wrong shape for some repos.** In a project
   with a large amount of non-source content the built-in list will never
   be complete, so the hook fires on paths that should never have
   triggered it. Enumerating what *is* source is sometimes the shorter,
   more stable statement.

The exclusions cannot simply be widened by default: the same pattern is
what keeps the check meaningful.

## Decision

Move the filters out of the three mirrored implementations and into a
**create-only `.second-brain.conf`** committed at the destination's repo
root, read by the pre-commit, the Stop hook, and the CI workflow. It ships
with every key commented out, so an untouched destination keeps using the
built-in defaults and keeps receiving improvements to them.

Three keys, all ERE (`grep -E`) regexes over repo-relative paths:

| Key | Effect |
|---|---|
| `SB_INCLUDE_PATTERN` | Allowlist. Only matching paths count as source. Empty (default) = all paths count. |
| `SB_EXCLUDE_EXTRA` | OR-ed with whichever denylist is in effect — the intended way to silence a false positive. |
| `SB_EXCLUDE_PATTERN` | Replaces the built-in denylist entirely. |

Evaluation order, identical in all three implementations:

```
relevant = staged/changed  minus  EXCLUDE
docs     = relevant  matching  ^docs/|^CLAUDE\.md$
source   = relevant  not matching  ^docs/|^CLAUDE\.md$   then  matching INCLUDE (if set)
reject if source is non-empty and docs is empty
```

`SB_INCLUDE_PATTERN` is deliberately applied to the **source side only**.
Filtering the whole file list through it would drop `docs/` and
`CLAUDE.md` from the "documentation changed" set for any allowlist that
doesn't happen to include them — turning a correct `src/` + `docs/` commit
into a rejection.

The conf is **parsed, never sourced** (`sed` extraction of
`KEY=value`, quotes and trailing blanks stripped, last assignment wins).
The CI workflow runs on `pull_request` and would otherwise evaluate shell
supplied by a fork's PR head.

`.second-brain.conf` is added to the default denylist, alongside
`.claude/`, `.githooks/` and `.gitattributes`, so tuning the filters is not
itself a source change.

## Alternatives considered

- **Add `INCLUDE_PATTERN` inline next to `EXCLUDE_PATTERN` in the three
  mirrors**: the smallest change, and what was originally asked for — but
  it inherits both defects above: still three places to edit, still wiped
  by the next `--refresh-system`.
- **Replace the denylist with the allowlist**: fewer concepts, but forces
  every destination into a fail-open posture (see Consequences) with no
  way back, and breaks every existing installation.
- **Only widen the built-in denylist**: no new mechanism, keeps the
  fail-closed default — but it can only ever chase project-specific paths
  it cannot know about, and still doesn't survive a refresh.
- **`source` the conf instead of parsing it**: trivial to implement and
  supports comments/expansion for free, at the cost of arbitrary code
  execution on the CI runner from a fork PR. Rejected outright.
- **Extend the manifest/refresh machinery to merge user edits back into
  the refreshed pre-commit block**: a three-way merge of a shell snippet,
  for a problem an unrefreshed config file solves by construction.

## Consequences

- Filters are edited in one committed file and survive every
  `/second-brain:refresh` and plugin update — the previously documented
  "edit `EXCLUDE_PATTERN`" workflow no longer loses work.
- **`SB_INCLUDE_PATTERN` is fail-open, and that is a real downgrade of the
  guarantee.** The denylist default errs toward false positives (annoying,
  visible); an allowlist errs toward false negatives (silent). A new
  top-level directory not added to the allowlist is never checked at all,
  and the docs drift with nothing to signal it. This is why the key ships
  commented out, why `SB_EXCLUDE_EXTRA` is presented as the default answer
  to a false positive, and why the warning is repeated in the conf itself.
- ADR 0002's mirror requirement is not removed but narrowed: what must
  stay byte-identical across the three files is now the *default* patterns
  plus the ~8-line conf reader, while per-project configuration is shared
  by construction rather than by convention. The reader is a third piece of
  duplicated logic, so the mirror surface grew even as the drift risk for
  the values shrank.
- A malicious PR can widen the filters and slip a source change past the
  CI backstop by editing `.second-brain.conf`. This is the same trust level
  as editing `.github/workflows/second-brain.yml` itself, which the same PR
  could also do; the file is review-worthy, and the workflow documents it.
- Each enforcement point now shells out to `sed`/`tail` per run (twice per
  key). Irrelevant at commit/CI scale, but it does add a POSIX-tool
  dependency beyond bash + git to the "dependency-free hooks" rule.
- Destinations bootstrapped before this change get `.second-brain.conf` on
  their next `/second-brain:bootstrap` or `/second-brain:refresh` (the
  refresh creates it only if missing and never rewrites it). Until then
  they run on the built-in defaults — the pre-0.4 behaviour exactly.

*Last updated: 2026-07-31 — verified against commit `81606ed`.*
