# Patterns and Conventions

## Adopted patterns

| Pattern | Where it's used | Why |
|---|---|---|
| Create-only scaffolding | `copy_if_absent` in `bootstrap/bootstrap.sh`, for `docs/`, the git pre-commit, and the CI workflow | An existing destination file is never overwritten and nothing is ever deleted, so an accidental re-run is a no-op — the bootstrap must not clobber content the user has since edited. |
| Marker-delimited block merge | append-if-absent (default) and between-markers replace (`--refresh-system`) for the destination's `CLAUDE.md` | Injects/updates a block inside a file the destination owns, without disturbing the surrounding user-written prose; markers (`<!-- BEGIN/END SECOND BRAIN SYSTEM -->`) make the block idempotently replaceable. |
| Opt-in, scoped system refresh | `--refresh-system` flag in `bootstrap.sh`, overwriting only the pre-commit hook, the CI workflow, and the CLAUDE.md block | The plugin cache upgrades skills/agent/Stop hook natively; the three *committed* system files need an explicit, narrowly-scoped overwrite path, while the default run stays strictly non-destructive. |
| Triple-mirrored enforcement | `EXCLUDE_PATTERN` duplicated verbatim across `bootstrap/payload/git-pre-commit`, `hooks/session-reminder.sh`, and `bootstrap/payload/workflows/second-brain.yml` | `core.hooksPath` is local git config, never cloned — a single local hook gives zero enforcement on a fresh clone or a skipped bootstrap, so the same syntactic check is repeated at three points (local hook, Stop hook, CI). See ADR 0002. |
| Plugin-carried runtime vs. bootstrapped repo files | skills/agent/Stop hook are served read-only from the plugin cache; `docs/`, the `CLAUDE.md` block, the git pre-commit, and the CI workflow are committed into the destination working tree | A plugin cannot write the working tree; the committed files must survive fresh clones, non-installers, and CI. This boundary is the core of the design (ADR 0003). |
| Dependency-free hooks | `hooks/session-reminder.sh` and `bootstrap/payload/git-pre-commit` are bash + git only (no `uv`, Python, or `jq`) | The plugin needs only bash + git; it also tightens the ADR-0002 mirror to shell in all three files, so the shared `EXCLUDE_PATTERN` is a byte-identical string everywhere. |

## Naming conventions

- Bash scripts: kebab-case with a `.sh` extension (`session-reminder.sh`,
  `bootstrap.sh`); the bootstrapped git hook is the extensionless
  `pre-commit` (git requires that exact name).
- Skill directories: kebab-case matching the skill's `name:` frontmatter
  field (`onboard`, `update`); the file inside is always `SKILL.md`.
- Slash commands: `commands/<name>.md`, kebab-case, with a `description`
  frontmatter field; the body runs the script via a leading `!`.
- Don't repeat the plugin name (`second-brain`) inside a command or skill
  filename/`name:` field — Claude Code already namespaces plugin-carried
  commands and skills as `second-brain:<name>` at invocation time
  (`/second-brain:bootstrap`, `second-brain:update`), so a name like
  `second-brain-bootstrap` would read as `second-brain:second-brain-bootstrap`.
- Agent files: kebab-case filename matching the agent's `name:` frontmatter
  field (`second-brain-reader.md`); no wrapping directory — Claude Code
  discovers agents as flat files under `agents/`.
- ADR files: `NNNN-*.md`, zero-padded to 4 digits (see the
  `second-brain:update` skill's "ADR numbering").

*Last updated: 2026-07-09 — verified against commit `94be0ce`.*
