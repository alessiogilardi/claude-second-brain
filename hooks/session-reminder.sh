#!/usr/bin/env bash
#
# [SECOND BRAIN SYSTEM] Stop-hook reminder (bash).
#
# Mirrors the exclusion logic in the bootstrapped git pre-commit hook
# (.claude/hooks/pre-commit). A Stop hook's plain stdout on exit 0 is
# invisible to Claude, only visible to the user in transcript mode -- so
# drift is reported via the "block" JSON contract on stdout, which
# surfaces the reason to the model and stops the session once.
# stop_hook_active (present on stdin when this hook already blocked the
# current stop) guards against looping forever.
#
# Keep EXCLUDE_PATTERN byte-identical with bootstrap/payload/git-pre-commit
# and bootstrap/payload/workflows/second-brain.yml (ADR 0002). No external
# dependencies: bash + git only (no uv, no python, no jq).
set -uo pipefail

EXCLUDE_PATTERN='^(\.github/|.*\.lock$|package-lock\.json$|yarn\.lock$|pnpm-lock\.yaml$|poetry\.lock$|uv\.lock$|Cargo\.lock$|Gemfile\.lock$|\.claude/)|(^|/)tests?/'
DOCS_PATTERN='^docs/|^CLAUDE\.md$'

# Loop guard: if we already blocked this stop, do nothing.
payload="$(cat)"
if printf '%s' "$payload" | grep -qE '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
    exit 0
fi

# git status --porcelain -z is NUL-separated and never quotes/escapes
# paths. Renames/copies are the special case: the record carrying the R/C
# status holds the origin path, and the new path follows as its own record
# with no status prefix -- we track the new path, mirroring the previous
# Python implementation.
files=()
skip_next=0
while IFS= read -r -d '' record; do
    if [ "$skip_next" = 1 ]; then
        files+=("$record")
        skip_next=0
        continue
    fi
    [ -z "$record" ] && continue
    status="${record:0:2}"
    case "$status" in
        *R*|*C*) skip_next=1 ;;
        *)       files+=("${record:3}") ;;
    esac
done < <(git status --porcelain -z 2>/dev/null)

[ "${#files[@]}" -eq 0 ] && exit 0

changed="$(printf '%s\n' "${files[@]}")"
relevant="$(printf '%s\n' "$changed" | grep -vE "$EXCLUDE_PATTERN" || true)"
[ -z "$relevant" ] && exit 0

source_changed="$(printf '%s\n' "$relevant" | grep -vE "$DOCS_PATTERN" || true)"
docs_changed="$(printf '%s\n' "$relevant" | grep -E "$DOCS_PATTERN" || true)"

if [ -n "$source_changed" ] && [ -z "$docs_changed" ]; then
    printf '%s\n' '{"decision":"block","reason":"[SECOND BRAIN SYSTEM] Uncommitted source changes with no matching docs/ update. Run the second-brain:update skill, then stop again."}'
fi

exit 0
