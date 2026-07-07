# ADR 0001: Manifest-gated sync for system-owned files, never-overwrite for user-owned files

## Status

Proposed

## Context

`install.ps1` must be safely re-runnable against a destination project
that already has a previous install. Two different kinds of files need
two different update policies:

- Files the destination project author is expected to edit (`docs/*.md`,
  `.github/workflows/`) must never be silently overwritten by a re-run,
  or the user's own edits would be destroyed.
- Files that are part of the Second Brain system itself (the pre-commit
  hook, the Stop-hook script, the two skills' `SKILL.md`) should be
  upgradable in place when the template changes, so destination projects
  can pick up fixes/improvements without a manual diff-and-merge — but
  only if the destination's copy hasn't been hand-edited, since a silent
  overwrite would destroy a legitimate local customization just as badly.

## Decision

Split installed files into two ownership classes with two distinct copy
strategies:

- **User-owned** (`Copy-WithoutOverwrite`): copy only if the destination
  file doesn't exist yet; otherwise skip unconditionally.
- **System-owned** (`Sync-SystemOwnedFile`): record a SHA-256 hash of
  each installed file in `.claude/.second-brain-manifest.json` at
  install time. On re-run, overwrite only if the destination's current
  hash still matches the last-recorded hash (i.e. untouched since
  install) or `-Force` is passed; otherwise skip with a warning.

## Alternatives considered

- **Always overwrite system-owned files**: simplest, but destroys any
  legitimate local customization to a hook or skill with no warning.
- **Always skip on re-run (treat everything as user-owned)**: safest for
  user edits, but destination projects would never receive fixes to the
  hook/skill logic without a manual copy-paste from this repo.
- **Version-stamp comment inside each file** instead of an external
  manifest: avoids a separate JSON file, but requires every system-owned
  file to carry and preserve a version marker, and breaks for any file
  format where a comment isn't easy to hide (e.g. JSON without comments).

## Consequences

- Destination projects get non-destructive upgrades to hooks/skills on
  every `install.ps1` re-run, as long as they haven't hand-edited them.
- A hand-edited system-owned file silently stops receiving upgrades
  until `-Force` is passed — this is a deliberate trade-off (safety over
  staying current), but means a destination project can drift from the
  template indefinitely without an explicit signal beyond the printed
  `[SKIP]` warning.
- The manifest itself is a new piece of installed state
  (`.claude/.second-brain-manifest.json`) that must be kept accurate;
  losing or hand-editing it degrades detection to "assume hand-edited,
  skip" for any file with no recorded hash.

*Last updated: 2026-07-07 — verified against commit `9ea2b62`.*
