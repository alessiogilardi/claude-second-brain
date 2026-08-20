# Glossary

| Term | Meaning |
|---|---|
| Second Brain | The `docs/second-brain/` + `CLAUDE.md` block + skill pair that keeps a destination project's documentation in sync with its code. |
| Plugin | The native Claude Code plugin (`.claude-plugin/plugin.json`) that carries the runtime — skills, the reader agent, the Stop hook, and the SessionStart bootstrap nudge — served read-only from `~/.claude/plugins/cache/`, external to any consuming repo. |
| Marketplace | The catalog (`.claude-plugin/marketplace.json`) that lists the plugin so it can be installed via `/plugin install`; here its single plugin `source` is `.`, the repo root. |
| Bootstrap | `bootstrap/bootstrap.sh`: the deterministic git-bash script that scaffolds the repo-side files (docs/second-brain/, CLAUDE.md block, git pre-commit, CI) into a destination working tree — create-only except for the pre-commit, which is injected without overwriting a user hook. |
| Payload | `bootstrap/payload/`: the single source of truth for every file the bootstrap copies into a destination. |
| Hooks dir | The committed, configurable directory (`--hooks-dir`, default `.githooks`) that `core.hooksPath` is repointed at and where the git `pre-commit` is installed; versioned so enforcement survives clones (ADR 0006). |
| Hook injection | Adding the Second Brain check to an existing `pre-commit` by inserting the marker-delimited block (`# >>> BEGIN/END SECOND BRAIN SYSTEM pre-commit <<<`) at the top instead of overwriting the file; the block rejects first, then falls through to the host hook's own logic. |
| Destination project | The external repo the bootstrap scaffolds into and the plugin is enabled for; distinct from this template repo. |
| Refresh | `bootstrap.sh --refresh-system` (via `/second-brain:refresh`): the opt-in rewrite of only our own content — the git pre-commit block between its markers, the CI workflow, and the CLAUDE.md block between its markers — docs/second-brain/, host hook logic, and user prose untouched. |
| `${CLAUDE_PLUGIN_ROOT}` | Claude Code variable resolving to the plugin's cache directory at run time; used by `hooks.json` and the slash commands to locate the plugin's scripts. |
| Onboarding | The one-time bootstrap (`second-brain:onboard` skill) that replaces every `> Placeholder` marker in a fresh destination's `docs/second-brain/` with real content. |
| Freshness footer | The `*Last updated: YYYY-MM-DD — verified against commit `sha`.*` line `second-brain:update` appends to every `docs/second-brain/*.md` file it touches. |
| CI backstop | `second-brain.yml`, the GitHub Actions re-check of the same pre-commit rule — needed because `core.hooksPath` is local-only and isn't cloned. |
| Doc-touch | An illegitimate edit to `docs/second-brain/` made only to satisfy the pre-commit hook, without a real corresponding source change — explicitly disallowed. |
| Proposal mode | The confirmation flow for new ADRs: drafted and shown to the user before saving, except for an unattended fallback that still writes with `Status: Proposed`. |
| Doc set | The seven files plus `adr/` that make up a Second Brain, scaffolded into `docs/second-brain/`. Fixed literal, not configurable — the same path is hardcoded in the three enforcement points, in `bootstrap.sh`, in the `CLAUDE.md` block's `@`-import and in the skill/agent prompts (ADR 0008). |
| Legacy layout | A destination bootstrapped before v1.0, carrying the doc set directly under `docs/`. `bootstrap.sh` detects it (our navigation map at `docs/README.md`, nothing at `docs/second-brain/README.md`), skips the docs scaffold and prints the `git mv`; it never moves anything itself. |
| Bootstrap nudge | `hooks/bootstrap-reminder.sh`, the plugin's `SessionStart` hook: reminds the model to run `/second-brain:bootstrap` when a repo lacks the `CLAUDE.md` marker; never runs the bootstrap itself. |
| Plugin version bump check | `.github/workflows/plugin-version.yml`: fails a PR that changes `hooks/`, `skills/`, `agents/`, or `commands/` without also bumping `plugin.json`'s `version`, and rejects a malformed or non-increasing bump. Repo-specific, not distributed to destinations (ADR 0005). |

*Last updated: 2026-08-20 — verified against commit `98b5062`.*
