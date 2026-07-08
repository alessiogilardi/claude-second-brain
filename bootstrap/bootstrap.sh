#!/usr/bin/env bash
#
# [SECOND BRAIN SYSTEM] Deterministic repo-side bootstrap.
#
# Scaffolds the files that MUST live inside a destination git repository
# (committed, so they survive fresh clones / teammates who never installed
# / CI): the docs/ set, the CLAUDE.md marker block, the git pre-commit hook
# (+ core.hooksPath wiring), and the CI workflow.
#
# Guarantees:
#   * create-only by default: an existing file is NEVER overwritten;
#   * NOTHING is ever deleted (no `rm`/`mv` on user content);
#   * idempotent: a re-run reports [SKIP] and changes nothing;
#   * core.hooksPath is set only when unset-and-ours or already ours, so an
#     existing husky/other hooksPath is never clobbered (use
#     --force-hookspath to override).
#
# The only overwrite path is --refresh-system, and it is scoped to exactly
# the git pre-commit hook, the CI workflow, and the CLAUDE.md block BETWEEN
# its markers -- docs/ and any user prose outside the markers are never
# touched.
#
# Usage: bootstrap.sh [TARGET_DIR] [--refresh-system] [--force-hookspath]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD="$SCRIPT_DIR/payload"

BEGIN='<!-- BEGIN SECOND BRAIN SYSTEM'
END='<!-- END SECOND BRAIN SYSTEM -->'

# --- Parse args: first non-flag is the target dir. ---
TARGET=""
REFRESH=0
FORCE_HOOKSPATH=0
for a in "$@"; do
    case "$a" in
        --refresh-system)  REFRESH=1 ;;
        --force-hookspath) FORCE_HOOKSPATH=1 ;;
        --*)               echo "  [WARN] unknown flag: $a" ;;
        *)                 [ -z "$TARGET" ] && TARGET="$a" ;;
    esac
done

[ -n "$TARGET" ] || TARGET="${CLAUDE_PROJECT_DIR:-}"
[ -n "$TARGET" ] || TARGET="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$TARGET"

echo "=== Second Brain bootstrap ==="
echo "Target: $TARGET"
[ "$REFRESH" = 1 ] && echo "Mode:   --refresh-system (overwrites system files only)"
echo ""

# create-only: copy a single file only if the destination doesn't exist.
copy_if_absent() {
    if [ -e "$2" ]; then
        echo "  [SKIP] $2 (exists)"
    else
        mkdir -p "$(dirname "$2")"
        cp "$1" "$2"
        echo "  [CREATE] $2"
    fi
}

# 1. docs/ scaffold (create-only, recursive).
while IFS= read -r -d '' f; do
    copy_if_absent "$f" "docs/${f#"$PAYLOAD"/docs/}"
done < <(find "$PAYLOAD/docs" -type f -print0)

# 2. CLAUDE.md marker block: append if the block isn't already present.
#    Never replaces an existing block on a plain run (only --refresh-system
#    below does, and only between the markers).
if [ -f CLAUDE.md ] && grep -qF "$BEGIN" CLAUDE.md; then
    echo "  [SKIP] CLAUDE.md block (markers already present)"
else
    {
        [ -s CLAUDE.md ] && printf '\n\n'
        cat "$PAYLOAD/claude-md-block.md"
        printf '\n'
    } >> CLAUDE.md
    echo "  [CREATE] CLAUDE.md block appended"
fi

# 3. git pre-commit hook (create-only) + core.hooksPath wiring.
copy_if_absent "$PAYLOAD/git-pre-commit" ".claude/hooks/pre-commit"
chmod +x ".claude/hooks/pre-commit" 2>/dev/null || true

if git rev-parse --git-dir >/dev/null 2>&1; then
    current="$(git config --get core.hooksPath || true)"
    legacy=".git/hooks/pre-commit"
    if [ -z "$current" ]; then
        if [ -f "$legacy" ] && ! grep -qF "SECOND BRAIN SYSTEM" "$legacy" && [ "$FORCE_HOOKSPATH" = 0 ]; then
            echo "  [WARN] existing .git/hooks/pre-commit is not ours; NOT setting core.hooksPath (re-run with --force-hookspath to override)"
        else
            git config core.hooksPath .claude/hooks
            echo "  [GIT] core.hooksPath set to .claude/hooks"
        fi
    elif [ "$current" = ".claude/hooks" ]; then
        echo "  [GIT] core.hooksPath already ours"
    elif [ "$FORCE_HOOKSPATH" = 1 ]; then
        git config core.hooksPath .claude/hooks
        echo "  [GIT] core.hooksPath overwritten to .claude/hooks (--force-hookspath)"
    else
        echo "  [WARN] core.hooksPath is '$current' (husky/other?); left untouched (re-run with --force-hookspath to override)"
    fi
else
    echo "  [GIT] no git repository here; skipping hook wiring"
fi

# 4. CI workflow (create-only).
copy_if_absent "$PAYLOAD/workflows/second-brain.yml" ".github/workflows/second-brain.yml"

# 5. --refresh-system: overwrite ONLY the two system files and the
#    CLAUDE.md block between its markers. docs/ and user prose untouched.
if [ "$REFRESH" = 1 ]; then
    echo ""
    echo "  Refreshing system files ..."

    mkdir -p ".claude/hooks"
    cp "$PAYLOAD/git-pre-commit" ".claude/hooks/pre-commit"
    chmod +x ".claude/hooks/pre-commit" 2>/dev/null || true
    echo "  [REFRESH] .claude/hooks/pre-commit"

    mkdir -p ".github/workflows"
    cp "$PAYLOAD/workflows/second-brain.yml" ".github/workflows/second-brain.yml"
    echo "  [REFRESH] .github/workflows/second-brain.yml"

    if [ -f CLAUDE.md ] && grep -qF "$BEGIN" CLAUDE.md; then
        tmp="$(mktemp)"
        awk -v begin="$BEGIN" -v end="$END" -v blockfile="$PAYLOAD/claude-md-block.md" '
            index($0, begin) {
                while ((getline line < blockfile) > 0) print line
                close(blockfile)
                skipping = 1
                next
            }
            skipping && index($0, end) { skipping = 0; next }
            skipping { next }
            { print }
        ' CLAUDE.md > "$tmp"
        cat "$tmp" > CLAUDE.md
        rm -f "$tmp"
        echo "  [REFRESH] CLAUDE.md block (between markers)"
    else
        echo "  [SKIP] CLAUDE.md block (no markers present)"
    fi
fi

echo ""
echo "=== Second Brain bootstrap complete: $TARGET ==="
