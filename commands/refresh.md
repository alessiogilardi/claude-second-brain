---
description: Refresh the Second Brain system files in this repo (git pre-commit, CI workflow, and the CLAUDE.md block between its markers). Overwrites ONLY those; never touches docs/ or your own CLAUDE.md prose.
allowed-tools: Bash
---
Run the bootstrap in refresh mode exactly as written and report its output verbatim. This overwrites only the system pre-commit content (the marker-delimited block inside the committed hooks dir's `pre-commit`, `.githooks/` by default — or wherever `core.hooksPath` already points), the CI workflow (`.github/workflows/second-brain.yml`), and the marker-delimited block inside `CLAUDE.md`. It never touches `docs/`, a host hook's own logic outside our markers, or any user-written content outside the markers. Do not edit any file yourself — the script is the single source of truth.

!bash "${CLAUDE_PLUGIN_ROOT}/bootstrap/bootstrap.sh" "${CLAUDE_PROJECT_DIR}" --refresh-system
