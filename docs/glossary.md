# Glossary

| Term | Meaning |
|---|---|
| Second Brain | The `docs/` + `CLAUDE.md` block + skill pair that keeps a destination project's documentation in sync with its code. |
| Plugin | The native Claude Code plugin (`.claude-plugin/plugin.json`) that carries the runtime — skills, the reader agent, the Stop hook, and the SessionStart bootstrap nudge — served read-only from `~/.claude/plugins/cache/`, external to any consuming repo. |
| Marketplace | The catalog (`.claude-plugin/marketplace.json`) that lists the plugin so it can be installed via `/plugin install`; here its single plugin `source` is `.`, the repo root. |
| Bootstrap | `bootstrap/bootstrap.sh`: the deterministic, create-only git-bash script that scaffolds the repo-side files (docs/, CLAUDE.md block, git pre-commit, CI) into a destination working tree. |
| Payload | `bootstrap/payload/`: the single source of truth for every file the bootstrap copies into a destination. |
| Destination project | The external repo the bootstrap scaffolds into and the plugin is enabled for; distinct from this template repo. |
| Refresh | `bootstrap.sh --refresh-system` (via `/second-brain:refresh`): the opt-in overwrite of only the git pre-commit, the CI workflow, and the CLAUDE.md block between its markers — docs/ and user prose untouched. |
| `${CLAUDE_PLUGIN_ROOT}` | Claude Code variable resolving to the plugin's cache directory at run time; used by `hooks.json` and the slash commands to locate the plugin's scripts. |
| Onboarding | The one-time bootstrap (`second-brain:onboard` skill) that replaces every `> Placeholder` marker in a fresh destination's `docs/` with real content. |
| Freshness footer | The `*Last updated: YYYY-MM-DD — verified against commit `sha`.*` line `second-brain:update` appends to every `docs/*.md` file it touches. |
| CI backstop | `second-brain.yml`, the GitHub Actions re-check of the same pre-commit rule — needed because `core.hooksPath` is local-only and isn't cloned. |
| Doc-touch | An illegitimate edit to `docs/` made only to satisfy the pre-commit hook, without a real corresponding source change — explicitly disallowed. |
| Proposal mode | The confirmation flow for new ADRs: drafted and shown to the user before saving, except for an unattended fallback that still writes with `Status: Proposed`. |
| Bootstrap nudge | `hooks/bootstrap-reminder.sh`, the plugin's `SessionStart` hook: reminds the model to run `/second-brain:bootstrap` when a repo lacks the `CLAUDE.md` marker; never runs the bootstrap itself. |

*Last updated: 2026-07-09 — verified against commit `4e50f09`.*
