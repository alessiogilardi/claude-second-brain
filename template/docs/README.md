# Second Brain — Navigation Map

This folder is the project's "second brain": the source of truth about the
actual state of architecture, data, patterns, and testing. It's meant to be
read and updated by AI agents (Claude Code) as well as human developers.
The policy for when and how to update it lives in
`.claude/skills/update-second-brain/SKILL.md` — this file only maps *what*
to read *when*.

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
