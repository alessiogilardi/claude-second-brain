# Patterns and Conventions

## Adopted patterns

| Pattern | Where it's used | Why |
|---|---|---|
| Never-overwrite copy | `Copy-WithoutOverwrite` in `install.ps1`, for `template/docs/` and `template/.github/` | User-owned files, once created in a destination, are never touched again by a re-run — the installer must not clobber content the user has since edited. |
| Manifest-gated sync-in-place | `Sync-SystemOwnedFile` + `.claude/.second-brain-manifest.json` (SHA-256 per file) in `install.ps1` | System-owned files (hooks, skills, settings) *should* be upgraded on re-run, but only when the destination's copy is still byte-identical to what the last install wrote — a hand-edit is preserved unless `-Force` is passed. |
| Marker-delimited block merge | `Merge-SecondBrainBlock` in `install.ps1`, for the destination's `CLAUDE.md` | Injects/updates a block inside a file the destination project already owns and edits, without disturbing the surrounding user-written content; markers (`<!-- BEGIN/END SECOND BRAIN SYSTEM -->`) make the block idempotently replaceable. |
| Triple-mirrored enforcement | `EXCLUDE_PATTERN` duplicated verbatim across `template/.claude/hooks/pre-commit`, `template/.claude/hooks/session_reminder.py`, and `template/.github/workflows/second-brain.yml` | `core.hooksPath` is local git config, never cloned — a single local hook alone gives zero enforcement on a fresh clone or a skipped install, so the same syntactic check is deliberately repeated at three points (local hook, Stop hook, CI). |
| Build-time-only script, never templated | `scripts/merge_settings.py`, invoked via `uv run` from `install.ps1` | Needed only during installation to reliably round-trip JSON; explicitly excluded from `template/` so it never ends up copied into a destination project. |

## Naming conventions

- PowerShell functions: PascalCase `Verb-Noun` (`Copy-WithoutOverwrite`,
  `Sync-SystemOwnedFile`, `Get-Sha256Hash`, `Install-Uv`).
- Python (`scripts/merge_settings.py`): standard PEP 8 snake_case.
- Skill directories: kebab-case matching the skill's `name:` frontmatter
  field (`onboard-second-brain`, `update-second-brain`); the file inside
  is always `SKILL.md`.
- ADR files: `NNNN-*.md`, zero-padded to 4 digits (see
  `.claude/skills/update-second-brain/SKILL.md`'s "ADR numbering").

*Last updated: 2026-07-07 — verified against commit `9ea2b62`.*
