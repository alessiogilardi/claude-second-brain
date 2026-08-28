#!/usr/bin/env bash
#
# [SECOND BRAIN SYSTEM] Stop-hook reminder (bash).
#
# Mirrors the exclusion logic in the bootstrapped git pre-commit hook
# (installed into the committed hooks dir, .githooks/pre-commit by
# default). A Stop hook's plain stdout on exit 0 is
# invisible to Claude, only visible to the user in transcript mode -- so
# drift is reported via the "block" JSON contract on stdout, which
# surfaces the reason to the model and stops the session once.
# stop_hook_active (present on stdin when this hook already blocked the
# current stop) guards against looping forever.
#
# The Second Brain lives under docs/second-brain/ so it never collides with
# the project's own documentation; everything else under docs/ is neither
# documentation nor source here.
#
# Project-specific filters are NOT edited here (this file is served read-only
# from the plugin cache): they live in the destination's committed
# .second-brain.conf -- SB_INCLUDE_PATTERN (allowlist), SB_EXCLUDE_EXTRA
# (added to the default denylist), SB_EXCLUDE_PATTERN (replaces it). All
# three are applied to the source side only. Keep the defaults, the
# evaluation order and the reader byte-identical with
# bootstrap/payload/git-pre-commit, bootstrap/payload/git-pre-push and
# bootstrap/payload/workflows/second-brain.yml (ADR 0002). No external
# dependencies: bash + git only (no uv, no python, no jq).
#
# This hook deliberately does NOT read SB_GATE: it is advisory (it never
# rejects anything) and it answers a different question -- uncommitted drift at
# session end, before anything is staged. Its behaviour is identical in both
# gate modes.
set -uo pipefail

DEFAULT_EXCLUDE_PATTERN='^(\.github/|docs/|.*\.lock$|package-lock\.json$|yarn\.lock$|pnpm-lock\.yaml$|poetry\.lock$|uv\.lock$|Cargo\.lock$|Gemfile\.lock$|\.claude/|\.githooks/|\.gitattributes$|\.second-brain\.conf$)|(^|/)tests?/'
DOCS_PATTERN='^docs/second-brain/|^CLAUDE\.md$'

# Read KEY from the .second-brain.conf-style file $1. Last assignment wins;
# surrounding single/double quotes and trailing blanks are stripped; a missing
# file or key yields the empty string (caller falls back to the default).
sb_conf_get() {
    [ -f "$1" ] || return 0
    sed -n "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*//p" "$1" |
        sed -e 's/[[:space:]]*$//' -e 's/^\(['"'"'"]\)\(.*\)\1$/\2/' |
        tail -n 1
}

root="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo .)}"
conf="$root/.second-brain.conf"
INCLUDE_PATTERN="$(sb_conf_get "$conf" SB_INCLUDE_PATTERN)"
EXCLUDE_PATTERN="$(sb_conf_get "$conf" SB_EXCLUDE_PATTERN)"
EXCLUDE_EXTRA="$(sb_conf_get "$conf" SB_EXCLUDE_EXTRA)"
[ -n "$EXCLUDE_PATTERN" ] || EXCLUDE_PATTERN="$DEFAULT_EXCLUDE_PATTERN"
[ -n "$EXCLUDE_EXTRA" ] && EXCLUDE_PATTERN="($EXCLUDE_PATTERN)|($EXCLUDE_EXTRA)"

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

# Evaluation order: the docs/source split runs on the RAW file list, and the
# denylist is applied to the source side only -- the same asymmetry
# INCLUDE_PATTERN already has. A filter that answers "is this a source
# change?" must not be able to remove a file from the "documentation
# changed" set; that is what lets the broad `docs/` entry in the denylist
# coexist with docs/second-brain/ (ADR 0008, amending ADR 0007).
changed="$(printf '%s\n' "${files[@]}")"
docs_changed="$(printf '%s\n' "$changed" | grep -E "$DOCS_PATTERN" || true)"
source_changed="$(printf '%s\n' "$changed" | grep -vE "$DOCS_PATTERN" || true)"
source_changed="$(printf '%s\n' "$source_changed" | grep -vE "$EXCLUDE_PATTERN" || true)"

if [ -n "$INCLUDE_PATTERN" ] && [ -n "$source_changed" ]; then
    source_changed="$(printf '%s\n' "$source_changed" | grep -E "$INCLUDE_PATTERN" || true)"
fi

if [ -n "$source_changed" ] && [ -z "$docs_changed" ]; then
    printf '%s\n' '{"decision":"block","reason":"[SECOND BRAIN SYSTEM] Uncommitted source changes with no matching docs/second-brain/ update. Run the second-brain:update skill, then stop again -- do not hand-edit docs/second-brain/ just to pass this check."}'
fi

exit 0
