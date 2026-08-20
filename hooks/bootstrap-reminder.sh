#!/usr/bin/env bash
#
# [SECOND BRAIN SYSTEM] SessionStart-hook bootstrap nudge (bash).
#
# Fires once per fresh session (matcher: "startup") and checks whether this
# repo has ever run the second-brain bootstrap, using the exact marker
# bootstrap.sh itself checks for (the BEGIN marker in CLAUDE.md) so the two
# never disagree about what counts as "bootstrapped". If missing, prints a
# plain stdout reminder -- SessionStart delivers plain stdout straight into
# Claude's context, no JSON envelope required. No external dependencies:
# bash + git only (no uv, no python, no jq).
set -uo pipefail

BEGIN='<!-- BEGIN SECOND BRAIN SYSTEM'

# Not a git repo (e.g. a scratch folder) -- nothing to bootstrap into.
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

if [ ! -f CLAUDE.md ] || ! grep -qF "$BEGIN" CLAUDE.md; then
    echo "[SECOND BRAIN SYSTEM] This repo has not been bootstrapped yet. Run /second-brain:bootstrap to scaffold docs/second-brain/, the CLAUDE.md block, the git pre-commit hook, and the CI workflow."
fi

exit 0
