# claude-second-brain-skill

A Claude Code **plugin** that exports the **"Second Brain"** documentation
system to other projects: a `docs/` structure kept in sync with the code
via two skills, a git `pre-commit` hook, and a CI backstop. The plugin
carries the runtime; a deterministic git-bash **bootstrap** scaffolds the
files that must be committed into the consuming repo.

## What's in here

```text
claude-second-brain-skill/
├── .claude-plugin/
│   ├── plugin.json                 # plugin metadata
│   └── marketplace.json            # marketplace catalog (source ".")
├── bootstrap/
│   ├── bootstrap.sh                # deterministic, create-only repo-side scaffolder
│   └── payload/                    # files the bootstrap copies into a destination
│       ├── docs/                       # placeholder doc set + adr/template.md
│       ├── git-pre-commit              # the git pre-commit hook source
│       ├── workflows/second-brain.yml  # the CI backstop source
│       └── claude-md-block.md          # the marker-delimited CLAUDE.md block
├── hooks/
│   ├── hooks.json                  # wires the Stop event to session-reminder.sh
│   └── session-reminder.sh         # bash Stop-hook mirror of the pre-commit check
├── commands/
│   ├── second-brain-bootstrap.md   # /second-brain-bootstrap  -> bootstrap.sh
│   └── second-brain-refresh.md     # /second-brain-refresh     -> bootstrap.sh --refresh-system
├── skills/
│   ├── update-second-brain/SKILL.md    # keeps docs/ in sync with the code
│   └── onboard-second-brain/SKILL.md   # bootstraps docs/ from placeholders (once)
├── agents/
│   └── second-brain-reader.md      # read-only docs/ retrieval subagent
└── README.md
```

## How to use it

**1. Install the plugin.** Add this repo as a marketplace and install:

```
/plugin marketplace add <path-or-git-url-of-this-repo>
/plugin install second-brain@second-brain-marketplace
```

This makes the skills, the `second-brain-reader` agent, and the
end-of-session Stop hook available. Nothing is written into your project
yet — a plugin is read-only and external to your repo.

**2. Bootstrap the repo-side files.** From inside the target project, run:

```
/second-brain-bootstrap
```

It runs `bootstrap/bootstrap.sh` (you can also call
`bash bootstrap/bootstrap.sh [TargetPath]` directly), which **create-only**:

1. scaffolds the `docs/` set (placeholders + `adr/template.md`) — never
   overwriting an existing file;
2. appends the marker-delimited block (`<!-- BEGIN/END SECOND BRAIN
   SYSTEM -->`) to `CLAUDE.md` if it isn't already present, leaving your
   own content untouched;
3. installs `.claude/hooks/pre-commit` and points `core.hooksPath` at
   `.claude/hooks` — unless a foreign `core.hooksPath` (e.g. husky) is
   already set, in which case it warns and leaves it (pass
   `--force-hookspath` to override);
4. copies the CI workflow to `.github/workflows/second-brain.yml`.

It never overwrites and never deletes, so an accidental re-run is a no-op.

**3. Onboard (once).** Run the `onboard-second-brain` skill before your
first commit, to replace every `docs/*.md` placeholder with real content.
Otherwise the one-time bootstrap gets triggered mid-commit the first time
the pre-commit hook rejects a source change with no matching docs update —
correct, but the worst moment to pay that cost on a large repo.

**Updating.** When a new plugin version ships, `/plugin marketplace update`
refreshes the skills/agent/Stop hook automatically. To refresh the three
*committed* system files (git pre-commit, CI workflow, `CLAUDE.md` block
between its markers) run `/second-brain-refresh` — it overwrites only those
and never touches `docs/` or your own prose.

## Enforcement is per-clone, not per-repo

`core.hooksPath` is **local git config** — it lives in `.git/config`, which
is never committed or cloned. Enforcement of the pre-commit hook only
exists on machines where the bootstrap was actually run; a fresh clone, a
teammate who skipped it, or a CI runner gets **zero** enforcement from the
local hook alone, silently.

`.github/workflows/second-brain.yml` (scaffolded into the destination by
the bootstrap) closes that gap: it re-applies the same check to the PR diff
on GitHub Actions, so it travels with the repo and can't be skipped with
`--no-verify`. Treat the local hook as fast feedback and the CI workflow as
the actual backstop — enable Actions on the destination repo (and mark the
job required in branch protection) to enforce it.

## Requirements

- **git bash** — Git for Windows / MSYS, or any POSIX `bash` on
  macOS/Linux. The bootstrap, the pre-commit hook, and the Stop hook are
  `bash` + `git` only; there is no `uv`, Python, or PowerShell dependency.
- **Claude Code** with plugin support (`/plugin`).

## Customizing the pre-commit hook

`.claude/hooks/pre-commit` is a syntactic check, not a semantic one: it
only verifies that *some* file under `docs/` or `CLAUDE.md` was staged
alongside source changes. The `EXCLUDE_PATTERN` variable at the top lists
paths ignored when deciding whether "source changed" — add more lockfiles,
generated files, or vendored paths there if the default set (tests, CI,
common lockfiles, `.claude/`) doesn't fit the project. If you change it,
keep it byte-identical across the three mirrors (the pre-commit, the
plugin's `session-reminder.sh`, and the CI workflow — see ADR 0002).
Bypassing with `git commit --no-verify` is legitimate for a WIP commit on
a private branch you'll squash later, or a doc-only follow-up commit — don't
touch `docs/` just to satisfy the hook ("doc-touch"); see the
`update-second-brain` skill for the full policy.

On a non-Windows clone the hook scripts may lack the POSIX executable bit;
Git for Windows runs them via `sh` regardless, but elsewhere run
`chmod +x .claude/hooks/pre-commit` if needed.
