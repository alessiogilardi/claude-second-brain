# Second Brain — Navigation Map

This folder is the project's "second brain": the source of truth about the
actual state of architecture, data, patterns, and testing. It's meant to be
read and updated by AI agents (Claude Code) as well as human developers.

## How to find your way around

| File | When to read it |
|---|---|
| [`architecture.md`](./architecture.md) | To understand the system's main components and how they talk to each other. |
| [`database.md`](./database.md) | Before changing schema, tables, migrations, or relationships. |
| [`patterns.md`](./patterns.md) | Before writing new code, to reuse conventions already adopted. |
| [`glossary.md`](./glossary.md) | When you run into an unfamiliar domain term. |
| [`layout.md`](./layout.md) | To find your way around the folder structure and know where new code belongs. |
| [`testing.md`](./testing.md) | Before writing or changing tests. |
| [`adr/`](./adr/) | For the history of architectural decisions and their context/motivation. |

## How to keep it up to date

This documentation isn't static: it must be updated on every relevant
change via the `.claude/skills/update-second-brain` skill. A git hook
(`.claude/hooks/pre-commit`) blocks source-code commits that don't also
touch this folder or `CLAUDE.md`, precisely to prevent the documentation
from drifting away from the real code.

## Rule for AI agents

Before starting a non-trivial task, read at least `architecture.md` and
`layout.md`. Before changing the database, read `database.md`. Before
ending a work session, run the `update-second-brain` skill checklist.
