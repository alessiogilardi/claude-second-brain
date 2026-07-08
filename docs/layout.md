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
│       ├── docs/                       # placeholder doc set + adr/template.md
│       ├── git-pre-commit              # the git pre-commit hook source
│       ├── workflows/second-brain.yml  # the CI backstop source
│       └── claude-md-block.md          # the marker-delimited CLAUDE.md block
├── hooks/                          # plugin Claude Code hooks (NOT git hooks)
│   ├── hooks.json                      # wires the Stop event to session-reminder.sh
│   └── session-reminder.sh             # bash Stop-hook mirror of the pre-commit check
├── commands/                       # plugin slash commands
│   ├── second-brain-bootstrap.md       # runs bootstrap.sh
│   └── second-brain-refresh.md         # runs bootstrap.sh --refresh-system
├── skills/                         # plugin skills
│   ├── update-second-brain/SKILL.md
│   └── onboard-second-brain/SKILL.md
├── agents/
│   └── second-brain-reader.md          # read-only docs/ retrieval subagent
├── docs/                           # this repo's own Second Brain (dogfood)
├── .claude/
│   ├── hooks/pre-commit                # this repo's bootstrapped git hook (dogfood)
│   └── settings.local.json             # per-contributor local config (gitignored)
├── .github/workflows/second-brain.yml  # this repo's bootstrapped CI (dogfood)
├── .gitattributes                  # forces LF on shebang'd payload/hook scripts
├── CLAUDE.md
└── README.md
```

## Placement conventions

- **Plugin components** live at the repo root where Claude Code
  auto-discovers them: `.claude-plugin/` (metadata), `skills/`, `agents/`,
  `hooks/` (Claude Code hooks only), `commands/`. Do not nest these under
  `.claude-plugin/` — only `plugin.json`/`marketplace.json` go there.
- **`bootstrap/`** holds the deterministic scaffolder and its `payload/`.
  It is not a reserved plugin directory, so the plugin loader ignores it;
  the bootstrap reads its sources from `${CLAUDE_PLUGIN_ROOT}/bootstrap/…`
  at run time. `payload/` is the single source of truth for every file
  that must be *committed into a destination repo* (docs scaffold, git
  pre-commit, CI workflow, CLAUDE.md block).
- The **git `pre-commit` hook and the CI workflow** live in
  `bootstrap/payload/` because they must be materialised into the
  destination working tree (`.claude/hooks/pre-commit` via
  `core.hooksPath`, `.github/workflows/`); the **Stop hook**
  (`session-reminder.sh`) lives in `hooks/` because a plugin serves it
  read-only from its cache.
- **`docs/` and `.claude/` at the repo root** are this repo's own Second
  Brain — a dogfooding instance, consumed via the local marketplace, not
  part of what gets distributed. `.claude/` keeps only the bootstrapped
  `pre-commit` and the gitignored `settings.local.json`; the runtime
  (skills, agent, Stop hook) comes from the installed plugin, not from
  `.claude/`.
- `.gitignore` excludes `.claude/settings.local.json` and `.vscode/`:
  per-contributor local config, never shared through the repo.

*Last updated: 2026-07-08 — verified against commit `b595503`.*
