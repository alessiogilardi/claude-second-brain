# Glossary

| Term | Meaning |
|---|---|
| Second Brain | The `docs/` + `CLAUDE.md` + skill pair that keeps a destination project's documentation in sync with its code. |
| Destination project | The external repo `install.ps1` is pointed at (`TargetPath`); distinct from this template repo. |
| System-owned file | A file installed by `install.ps1` that's expected to be upgraded in place on re-run (hooks, skills, `settings.json`) — tracked via `.claude/.second-brain-manifest.json`'s SHA-256 hashes. |
| User-owned file | A file installed once and never overwritten again (`docs/*.md`, `.github/workflows/`) — handled by `Copy-WithoutOverwrite`. |
| Manifest | `.claude/.second-brain-manifest.json`: maps each system-owned file's relative path to the SHA-256 hash recorded at the last install, used to detect hand-edits before deciding whether to overwrite. |
| Onboarding | The one-time bootstrap (`onboard-second-brain` skill) that replaces every `> Placeholder` marker in a fresh destination's `docs/` with real content. |
| Freshness footer | The `*Last updated: YYYY-MM-DD — verified against commit `sha`.*` line `update-second-brain` appends to every `docs/*.md` file it touches. |
| CI backstop | `second-brain.yml`, the GitHub Actions re-check of the same pre-commit rule — needed because `core.hooksPath` is local-only and isn't cloned. |
| Doc-touch | An illegitimate edit to `docs/` made only to satisfy the pre-commit hook, without a real corresponding source change — explicitly disallowed. |
| Proposal mode | The confirmation flow for new ADRs: drafted and shown to the user before saving, except for an unattended fallback that still writes with `Status: Proposed`. |

*Last updated: 2026-07-07 — verified against commit `9ea2b62`.*
