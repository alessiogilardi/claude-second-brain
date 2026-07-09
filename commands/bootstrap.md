---
description: Scaffold the Second Brain repo-side files into this repo (docs/, CLAUDE.md block, git pre-commit, CI). Create-only; never overwrites or deletes.
allowed-tools: Bash
---
Run the deterministic bootstrap exactly as written and report its output verbatim. Do not hand-create or edit any of these files yourself — the script is the single source of truth. It is create-only: it never overwrites an existing file and never deletes anything, so re-running it is safe.

!bash "${CLAUDE_PLUGIN_ROOT}/bootstrap/bootstrap.sh" "${CLAUDE_PROJECT_DIR}"
