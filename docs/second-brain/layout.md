# Project Layout

## Folder structure

```text
repo/
├── .claude-plugin/
│   ├── plugin.json                 # plugin metadata
│   └── marketplace.json            # marketplace catalog (source ".")
├── bootstrap/
│   ├── bootstrap.sh                # deterministic, create-only repo-side scaffolder
│   └── payload/                    # content the bootstrap copies into a destination
│       ├── docs/                       # placeholder doc set -> docs/second-brain/ in the destination
│       ├── git-pre-commit              # the git pre-commit hook source
│       ├── workflows/second-brain.yml  # the CI backstop source
│       ├── second-brain.conf           # path-filter config (create-only in the destination)
│       └── claude-md-block.md          # the marker-delimited CLAUDE.md block
├── hooks/                          # plugin Claude Code hooks (NOT git hooks)
│   ├── hooks.json                      # wires Stop -> session-reminder.sh, SessionStart -> bootstrap-reminder.sh
│   ├── session-reminder.sh             # bash Stop-hook mirror of the pre-commit check
│   └── bootstrap-reminder.sh           # bash SessionStart nudge: reminds if not yet bootstrapped
├── commands/                       # plugin slash commands
│   ├── bootstrap.md                    # /second-brain:bootstrap -> bootstrap.sh
│   └── refresh.md                      # /second-brain:refresh -> bootstrap.sh --refresh-system
├── skills/                         # plugin skills
│   ├── update/
│   │   ├── SKILL.md                    # second-brain:update (entry point)
│   │   └── references/                 # on-demand depth, not loaded every run
│   │       ├── writing-guides.md           # per-file guidance, editorial rules, footer edge cases
│   │       └── gate-config.md              # exclusions, SB_GATE timing, bypasses
│   ├── adr/SKILL.md                    # second-brain:adr — owns docs/second-brain/adr/
│   └── onboard/SKILL.md                # second-brain:onboard
├── agents/
│   └── second-brain-reader.md          # read-only docs/second-brain/ retrieval subagent
├── docs/second-brain/              # this repo's own Second Brain (dogfood)
├── .claude/
│   ├── hooks/pre-commit                # this repo's bootstrapped git hook (dogfood; pre-0.3 location kept by the resolver — fresh repos default to .githooks/)
│   └── settings.local.json             # per-contributor local config (gitignored)
├── .github/workflows/
│   ├── second-brain.yml                # this repo's bootstrapped CI (dogfood)
│   └── plugin-version.yml              # repo-specific: enforces plugin.json version bump
├── .gitattributes                  # forces LF on shebang'd payload/hook scripts
├── .second-brain.conf              # this repo's own path filters (dogfood; defaults, all keys commented out)
├── CLAUDE.md
└── README.md
```

## Placement conventions

- **Plugin components** live at the repo root where Claude Code
  auto-discovers them: `.claude-plugin/` (metadata), `skills/`, `agents/`,
  `hooks/` (Claude Code hooks only), `commands/`. Do not nest these under
  `.claude-plugin/` — only `plugin.json`/`marketplace.json` go there.
- **A skill is a directory, not a file.** `SKILL.md` is the entry point;
  anything conditional goes in a sibling `references/` directory and is
  read only when the situation calls for it (ADR 0010). The whole
  directory ships in the plugin cache, so a reference is addressed as
  `${CLAUDE_PLUGIN_ROOT}/skills/<skill>/references/<file>.md`. Nothing
  under `references/` may hold a trigger condition or a step of the main
  procedure — if a run always needs it, it belongs in `SKILL.md`.
- **`bootstrap/`** holds the deterministic scaffolder and its `payload/`.
  It is not a reserved plugin directory, so the plugin loader ignores it;
  the bootstrap reads its sources from `${CLAUDE_PLUGIN_ROOT}/bootstrap/…`
  at run time. `payload/` is the single source of truth for every file
  that must be *committed into a destination repo* (docs scaffold, git
  pre-commit, CI workflow, CLAUDE.md block, `.second-brain.conf`).
- The **git `pre-commit` hook and the CI workflow** live in
  `bootstrap/payload/` because they must be materialised into the
  destination working tree — the pre-commit into the committed, configurable
  hooks dir (`.githooks/pre-commit` by default) that `core.hooksPath` is
  repointed at, the workflow into `.github/workflows/`; the **Stop hook**
  (`session-reminder.sh`) and the **SessionStart hook**
  (`bootstrap-reminder.sh`) live in `hooks/` because a plugin serves them
  read-only from its cache — neither needs anything bootstrap produces to
  run.
- **`docs/second-brain/` and `.claude/` at the repo root** are this repo's own Second
  Brain — a dogfooding instance, consumed via the local marketplace, not
  part of what gets distributed. The subdirectory is not cosmetic: it is
  the literal the three enforcement points match on, so `docs/` itself is
  free for a project's own documentation and is invisible to the check
  (ADR 0008). `.claude/` keeps only the bootstrapped
  `pre-commit` (this repo predates the `.githooks` default, so the resolver
  keeps it on `.claude/hooks`; fresh destinations get `.githooks/`) and the
  gitignored `settings.local.json`; the runtime (skills, agent, Stop hook)
  comes from the installed plugin, not from `.claude/`.
- `.gitignore` excludes `.claude/settings.local.json` and `.vscode/`:
  per-contributor local config, never shared through the repo.
- **`.github/workflows/plugin-version.yml`** is hand-authored and lives
  outside `bootstrap/payload/workflows/` on purpose: it enforces this
  repo's own `plugin.json` version-bump discipline and is never
  distributed to a destination project (see ADR 0005).

*Last updated: 2026-09-04 — verified against commit `f33f197`.*
