# Patterns and Conventions

## Adopted patterns

| Pattern | Where it's used | Why |
|---|---|---|
| Create-only scaffolding | `copy_if_absent` in `bootstrap/bootstrap.sh`, for `docs/`, the CI workflow and `.second-brain.conf` | An existing destination file is never overwritten and nothing is ever deleted, so an accidental re-run is a no-op — the bootstrap must not clobber content the user has since edited. |
| Non-destructive hook install into a committed, configurable dir | `install_or_inject_precommit` in `bootstrap/bootstrap.sh`; the pre-commit goes into `--hooks-dir` (default `.githooks`, committed) and `core.hooksPath` is repointed there | The hooks dir is versioned like any other file so enforcement survives clones (rejected gitignoring it — see ADR 0006). A user's own `pre-commit` is never overwritten: our check ships inside `# >>> BEGIN/END SECOND BRAIN SYSTEM pre-commit <<<` markers and is injected at the top of the existing hook, exiting only to reject and otherwise falling through to the host logic; a foreign `.git/hooks/pre-commit` is copied into the dir before the repoint (so it isn't shadowed away), and a pre-0.3 marker-less Second Brain hook is replaced wholesale. |
| Marker-delimited block merge | append-if-absent (default) and between-markers replace (`--refresh-system`) for the destination's `CLAUDE.md` (`<!-- BEGIN/END SECOND BRAIN SYSTEM -->`), and the same technique for the git pre-commit (`# >>> BEGIN/END SECOND BRAIN SYSTEM pre-commit <<<`) when injecting into a host hook | Injects/updates a block inside a file the destination owns, without disturbing the surrounding user-written content; markers make the block idempotently replaceable and let `--refresh-system` rewrite only our slice. |
| Opt-in, scoped system refresh | `--refresh-system` flag in `bootstrap.sh`, overwriting only the pre-commit hook, the CI workflow, and the CLAUDE.md block | The plugin cache upgrades skills/agent/Stop hook natively; the three *committed* system files need an explicit, narrowly-scoped overwrite path, while the default run stays strictly non-destructive. |
| Triple-mirrored enforcement | The default path patterns and the `.second-brain.conf` reader, duplicated verbatim across `bootstrap/payload/git-pre-commit` (inside the injectable block, the canonical copy for both a fresh hook and an injected one), `hooks/session-reminder.sh`, and `bootstrap/payload/workflows/second-brain.yml` | `core.hooksPath` is local git config, never cloned — a single local hook gives zero enforcement on a fresh clone or a skipped bootstrap, so the same syntactic check is repeated at three points (local hook, Stop hook, CI). Deriving the injected block from the payload keeps the mirror at three, not four. See ADR 0002. |
| Config in a create-only file, never in a refreshed one | `.second-brain.conf` at the destination root (`SB_INCLUDE_PATTERN` / `SB_EXCLUDE_EXTRA` / `SB_EXCLUDE_PATTERN`), read by all three enforcement points | Anything the destination is expected to tune must live outside the files `--refresh-system` rewrites, or the customization is silently reverted on the next plugin refresh. Ships with every key commented out, so untouched destinations keep inheriting improved defaults. The conf is parsed with `sed`, never `source`d — the CI backstop runs on `pull_request`, where the file comes from an untrusted fork head. See ADR 0007. |
| Allowlist filtering on the source side only | `SB_INCLUDE_PATTERN` is applied after `docs/`/`CLAUDE.md` have been split off, in all three implementations | Filtering the whole file list through the allowlist would drop the docs files from the "documentation changed" set whenever the pattern doesn't happen to list them, turning a correct `src/` + `docs/` commit into a rejection. |
| Plugin-carried runtime vs. bootstrapped repo files | skills/agent/Stop hook are served read-only from the plugin cache; `docs/`, the `CLAUDE.md` block, the git pre-commit, and the CI workflow are committed into the destination working tree | A plugin cannot write the working tree; the committed files must survive fresh clones, non-installers, and CI. This boundary is the core of the design (ADR 0003). |
| Dependency-free hooks | `hooks/session-reminder.sh` and `bootstrap/payload/git-pre-commit` are bash + git only, plus POSIX `sed`/`tail` for the conf reader (no `uv`, Python, or `jq`) | The plugin needs only bash + git; it also tightens the ADR-0002 mirror to shell in all three files, so the shared default patterns are byte-identical strings everywhere. |
| Nudge, don't enforce, at session start | `hooks/bootstrap-reminder.sh` (`SessionStart`, matcher `"startup"`) checks for the same `<!-- BEGIN SECOND BRAIN SYSTEM` marker `bootstrap.sh` checks, and prints a plain-stdout reminder if absent — it never runs the bootstrap itself | Claude Code has no plugin post-install lifecycle event, so a hook is the closest substitute; auto-writing into a repo's working tree on every session start would be surprising and contradicts the bootstrap's own create-only, non-destructive philosophy. See ADR 0004. |
| Semantic versioning + CI-enforced bump | `.claude-plugin/plugin.json`'s `version` (`MAJOR.MINOR.PATCH`: major = breaking for installed consumers, minor = new backward-compatible capability, patch = bug fix/no interface change); enforced by `.github/workflows/plugin-version.yml` whenever `hooks/`, `skills/`, `agents/`, `commands/`, or `bootstrap/` change (all of them ship in the plugin cache) | `/plugin marketplace update` refreshes an installed plugin's cache only when `version` changes, so a content-only change with no bump silently never propagates. There is no safe local hook slot for this check (`.claude/hooks/pre-commit` is payload-managed and gets clobbered by `--refresh-system`), so CI is the sole enforcement point; it can verify a bump happened, is well-formed, and increased, but not which tier is correct — see ADR 0005. |

## Naming conventions

- Bash scripts: kebab-case with a `.sh` extension (`session-reminder.sh`,
  `bootstrap-reminder.sh`, `bootstrap.sh`); the bootstrapped git hook is
  the extensionless `pre-commit` (git requires that exact name).
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
  discovers agents as flat files under `agents/`. Same namespacing trap as
  above applies to invocation, not just the filename: Claude Code exposes
  a plugin agent's `subagent_type` as `second-brain:<name>`
  (`second-brain:second-brain-reader`), never the bare `name:` value —
  confirmed empirically (a bare `second-brain-reader` subagent_type errors
  with "Agent type not found"). Any prose instructing a model to delegate
  to this agent (`CLAUDE.md`, `bootstrap/payload/claude-md-block.md`) must
  spell out the namespaced form, or the delegation silently falls through
  to the calling model's own session model instead of the agent's
  `model: haiku`.
- ADR files: `NNNN-*.md`, zero-padded to 4 digits (see the
  `second-brain:update` skill's "ADR numbering").

*Last updated: 2026-08-03 — verified against commit `cd8293d`.*
