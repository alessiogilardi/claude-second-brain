#!/usr/bin/env bash
#
# [SECOND BRAIN SYSTEM] Deterministic repo-side bootstrap.
#
# Scaffolds the files that MUST live inside a destination git repository
# (committed, so they survive fresh clones / teammates who never installed
# / CI): the docs/second-brain/ set, the CLAUDE.md marker block, the git
# pre-commit and pre-push hooks (+ core.hooksPath wiring), and the CI
# workflow. The pre-push hook is inert unless SB_GATE=push is set in
# .second-brain.conf, so installing it into an existing project changes
# nothing until that switch is flipped.
#
# The doc set lives in its own subdirectory of docs/ so it never collides
# with the destination's own documentation. A repo bootstrapped before that
# change carries the doc set directly under docs/; the scaffold detects that
# layout, skips itself and prints the git mv needed to migrate, rather than
# seeding a second, empty doc set next to the populated one.
#
# Guarantees:
#   * create-only by default: an existing file is NEVER overwritten;
#   * NOTHING is ever deleted (no `rm`/`mv` on user content);
#   * idempotent: a re-run reports [SKIP] and changes nothing;
#   * core.hooksPath is set only when unset-and-ours or already ours, so an
#     existing husky/other hooksPath is never clobbered (use
#     --force-hookspath to override).
#
# The pre-commit is installed into a committed, shared hooks dir (default
# .githooks, overridable with --hooks-dir), and core.hooksPath is pointed
# at it. The dir is versioned like any other file so it survives clones.
# A pre-existing pre-commit is never overwritten: our check is injected as
# a marker-delimited block at the top of it (running first, rejecting only,
# then falling through to the host logic). A foreign pre-commit sitting in
# .git/hooks is copied into the hooks dir before injection so repointing
# core.hooksPath doesn't lose it; other .git/hooks scripts about to be
# shadowed are reported.
#
# The only overwrite path is --refresh-system, and it is scoped to exactly
# the git pre-commit and pre-push hooks, the CI workflow, and the CLAUDE.md
# block BETWEEN its markers -- docs/second-brain/, .second-brain.conf, and any user prose
# outside the markers are never touched. .second-brain.conf is where a
# destination tunes the path filters (SB_INCLUDE_PATTERN / SB_EXCLUDE_EXTRA /
# SB_EXCLUDE_PATTERN) precisely because it is create-only: filters edited
# there survive every refresh, unlike the patterns inside the refreshed
# pre-commit block and CI workflow.
#
# Usage: bootstrap.sh [TARGET_DIR] [--refresh-system] [--force-hookspath]
#                     [--hooks-dir DIR]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD="$SCRIPT_DIR/payload"

BEGIN='<!-- BEGIN SECOND BRAIN SYSTEM'
END='<!-- END SECOND BRAIN SYSTEM -->'

# Where the doc set is scaffolded, relative to the destination root. Fixed,
# not configurable: the same literal is hardcoded in the three enforcement
# points, in the CLAUDE.md block's @-import, and in the skill/agent prompts
# served read-only from the plugin cache (ADR 0008).
DOCS_DIR='docs/second-brain'

# Shell-comment markers delimiting our check inside a bootstrapped hook. Each
# hook carries its own name in the marker, so a repo can host both without the
# injector confusing one block for the other. The payload ships with them so
# the same block is used whether the whole file is installed fresh or only the
# block is injected into a host hook.
hook_markers() {
    printf '# >>> BEGIN SECOND BRAIN SYSTEM %s >>>\t# <<< END SECOND BRAIN SYSTEM %s <<<\n' "$1" "$1"
}

# --- Parse args: first non-flag is the target dir. ---
TARGET=""
REFRESH=0
FORCE_HOOKSPATH=0
HOOKS_DIR_ARG=""
DEFAULT_HOOKS_DIR=".githooks"
while [ $# -gt 0 ]; do
    case "$1" in
        --refresh-system)  REFRESH=1 ;;
        --force-hookspath) FORCE_HOOKSPATH=1 ;;
        --hooks-dir)       shift
                           HOOKS_DIR_ARG="${1:-}"
                           [ -n "$HOOKS_DIR_ARG" ] || { echo "  [ERROR] --hooks-dir requires a value" >&2; exit 2; } ;;
        --hooks-dir=*)     HOOKS_DIR_ARG="${1#--hooks-dir=}" ;;
        --*)               echo "  [WARN] unknown flag: $1" ;;
        *)                 [ -z "$TARGET" ] && TARGET="$1" ;;
    esac
    shift
done

# A committed, shared hooks dir must be a relative path inside the repo.
if [ -n "$HOOKS_DIR_ARG" ]; then
    case "$HOOKS_DIR_ARG" in
        /*|*..*) echo "  [ERROR] --hooks-dir must be a relative path inside the repo (got: $HOOKS_DIR_ARG)" >&2; exit 2 ;;
    esac
    HOOKS_DIR_ARG="${HOOKS_DIR_ARG%/}"
fi

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

# Echo the repo-relative form of a hooks-dir path. A committed, shared hooks
# dir and the .gitattributes pattern that pins its hook to LF are both
# repo-relative by definition: an absolute value survives no clone and, as a
# .gitattributes pattern, matches nothing -- so the LF pin silently stops
# working and the #!/bin/sh shebang breaks on a CRLF Windows checkout. An
# absolute path inside the working tree is converted with git itself, which
# normalises Windows 8.3 short names and case; a relative path (the default
# and the only accepted --hooks-dir form) is echoed unchanged. A path outside
# the tree yields an empty prefix and is left as-is for the caller to reject.
relativize_hooks_dir() {
    local p="$1" rel
    case "$p" in
        /*|[A-Za-z]:/*)
            if [ -d "$p" ]; then
                rel="$(git -C "$p" rev-parse --show-prefix 2>/dev/null | sed 's:/*$::')"
                [ -n "$rel" ] && p="$rel"
            fi ;;
    esac
    printf '%s\n' "$p"
}

# Resolve the hooks dir that core.hooksPath points at and where pre-commit
# is installed. Precedence:
#   1. explicit --hooks-dir;
#   2. an existing Second Brain core.hooksPath, so installs made before the
#      configurable-dir change keep their location (e.g. .claude/hooks) and
#      --refresh-system writes there;
#   3. the default (.githooks), committed and shared like any other file.
# The value is always emitted repo-relative (see relativize_hooks_dir): an
# older install whose core.hooksPath was stored absolute is normalised here.
resolve_hooks_dir() {
    if [ -n "$HOOKS_DIR_ARG" ]; then
        printf '%s\n' "$HOOKS_DIR_ARG"
        return
    fi
    local current
    current="$(git config --get core.hooksPath 2>/dev/null || true)"
    # Deliberately still pre-commit-only, even now that a second hook exists:
    # this only needs to detect "is this hooksPath an existing Second Brain
    # install", and every install has a pre-commit hook (pre-push is optional),
    # so it remains the one reliable marker of an install regardless of which
    # other hooks are present.
    if [ -n "$current" ] && [ -f "$current/pre-commit" ] \
        && grep -qF "SECOND BRAIN SYSTEM" "$current/pre-commit" 2>/dev/null; then
        relativize_hooks_dir "$current"
        return
    fi
    printf '%s\n' "$DEFAULT_HOOKS_DIR"
}

# True if a hook file already carries our marker block.
hook_is_ours() { grep -qF "$2" "$1" 2>/dev/null; }

# True if a hook is a pre-0.3 Second Brain hook: our old standalone format,
# which carries the "SECOND BRAIN SYSTEM" tag but not the block markers. Such
# a hook is ours to replace wholesale on upgrade (no user logic to preserve).
# Only pre-commit can be legacy -- pre-push never had a marker-less format.
hook_is_legacy_ours() {
    grep -qF "SECOND BRAIN SYSTEM" "$1" 2>/dev/null && ! hook_is_ours "$1" "$2"
}

# Emit the marker-delimited block (inclusive) from a payload hook.
payload_hook_block() {
    awk -v b="$2" -v e="$3" '
        index($0, b) { p = 1 }
        p            { print }
        index($0, e) { p = 0 }
    ' "$1"
}

# Insert our block at the top of an existing (foreign) hook: right after the
# shebang if present, otherwise before the first line. The block runs first
# and only exits on rejection, so the host's own logic still runs on success.
inject_hook_block() {
    local hook="$1" payload="$2" begin="$3" end="$4" blk tmp
    blk="$(mktemp)"; tmp="$(mktemp)"
    payload_hook_block "$payload" "$begin" "$end" > "$blk"
    awk -v blockfile="$blk" '
        NR == 1 && /^#!/ {
            print
            while ((getline l < blockfile) > 0) print l
            close(blockfile)
            print ""
            next
        }
        NR == 1 {
            while ((getline l < blockfile) > 0) print l
            close(blockfile)
            print ""
            print
            next
        }
        { print }
    ' "$hook" > "$tmp"
    cat "$tmp" > "$hook"
    rm -f "$tmp" "$blk"
    echo "  [INJECT] SECOND BRAIN block added to existing $hook (runs first, rejects only, then falls through)"
}

# Replace the content between our markers in an existing hook with the
# current payload block (used by --refresh-system).
refresh_hook_block() {
    local hook="$1" payload="$2" begin="$3" end="$4" blk tmp
    blk="$(mktemp)"; tmp="$(mktemp)"
    payload_hook_block "$payload" "$begin" "$end" > "$blk"
    awk -v begin="$begin" -v end="$end" -v blockfile="$blk" '
        index($0, begin) {
            while ((getline l < blockfile) > 0) print l
            close(blockfile)
            skipping = 1
            next
        }
        skipping && index($0, end) { skipping = 0; next }
        skipping { next }
        { print }
    ' "$hook" > "$tmp"
    cat "$tmp" > "$hook"
    rm -f "$tmp" "$blk"
}

# Install one of our hooks into HOOKS_DIR without ever overwriting a user hook:
#   * HOOKS_DIR/<hook> already ours (markers) -> skip;
#   * HOOKS_DIR/<hook> is a pre-0.3 ours hook -> replace wholesale;
#   * HOOKS_DIR/<hook> exists (foreign)       -> inject block;
#   * foreign .git/hooks/<hook> present        -> copy it into HOOKS_DIR
#                                                (original untouched), inject;
#   * nothing there                            -> install the payload as-is.
install_or_inject_hook() {
    local name="$1" markers begin end payload target
    markers="$(hook_markers "$name")"
    begin="${markers%%$'\t'*}"
    end="${markers##*$'\t'}"
    payload="$PAYLOAD/git-$name"
    target="$HOOKS_DIR/$name"
    if [ -s "$target" ]; then
        if hook_is_ours "$target" "$begin"; then
            echo "  [SKIP] $target (SECOND BRAIN block already present)"
        elif hook_is_legacy_ours "$target" "$begin"; then
            cp "$payload" "$target"
            echo "  [UPGRADE] $target (replaced pre-0.3 Second Brain hook)"
        else
            inject_hook_block "$target" "$payload" "$begin" "$end"
        fi
    elif [ -s ".git/hooks/$name" ] && ! grep -qF "SECOND BRAIN SYSTEM" ".git/hooks/$name" 2>/dev/null; then
        mkdir -p "$HOOKS_DIR"
        cp ".git/hooks/$name" "$target"
        echo "  [MIGRATE] copied .git/hooks/$name -> $target (original left in place; core.hooksPath will shadow it)"
        inject_hook_block "$target" "$payload" "$begin" "$end"
    else
        mkdir -p "$HOOKS_DIR"
        cp "$payload" "$target"
        echo "  [CREATE] $target"
    fi
    chmod +x "$target" 2>/dev/null || true
}

# Repointing core.hooksPath makes git read ONLY that dir, silently disabling
# any real (non-sample) hooks still in .git/hooks. pre-commit is handled by
# install_or_inject_hook (migrated); warn about the rest so they can be
# moved into HOOKS_DIR instead of vanishing.
warn_shadowed_git_hooks() {
    local f name
    [ -d ".git/hooks" ] || return 0
    for f in .git/hooks/*; do
        [ -f "$f" ] || continue
        name="$(basename "$f")"
        case "$name" in *.sample | pre-commit | pre-push) continue ;; esac
        grep -qF "SECOND BRAIN SYSTEM" "$f" 2>/dev/null && continue
        echo "  [WARN] .git/hooks/$name will be shadowed by core.hooksPath=$HOOKS_DIR; move it into $HOOKS_DIR to keep it active"
    done
}

# Pin the installed hook to LF in the destination's .gitattributes. A hook is
# a #!/bin/sh script: if a Windows checkout (core.autocrlf=true) rewrites it
# to CRLF, the shebang breaks with "bad interpreter: ^M". Idempotent
# create-or-append, scoped to our own file so a foreign gitattributes setup
# for other paths is never disturbed.
GITATTR_COMMENT='# [SECOND BRAIN SYSTEM] keep the git hook LF so #!/bin/sh works on every platform'

# Self-heal a pin written absolute by a pre-0.3.2 install (before the hooks
# dir was normalised to repo-relative). As a .gitattributes pattern an
# absolute path matches nothing, so that pin is silently dead -- and because
# the correct relative entry is then missing, every later run appends another
# block, accumulating a dead rule plus a duplicate comment. The line is
# unambiguously ours (it pins a `*/pre-commit` to eol=lf), so it is rewritten
# in place rather than left to rot; duplicates of our entry and our comment
# collapse to the first occurrence. Nothing else in the file is touched.
normalize_gitattributes_entry() {
    local entry="$1" tmp
    [ -f .gitattributes ] || return 0
    grep -qE '^([A-Za-z]:)?/[^[:space:]]*pre-commit[[:space:]]+text[[:space:]]+eol=lf[[:space:]]*$' .gitattributes || return 0
    tmp="$(mktemp)"
    awk -v e="$entry" -v c="$GITATTR_COMMENT" '
        $0 == c { if (cseen++) next; print; next }
        $0 == e { if (eseen++) next; print; next }
        /^([A-Za-z]:)?\/[^[:space:]]*pre-commit[[:space:]]+text[[:space:]]+eol=lf[[:space:]]*$/ {
            if (eseen++) next
            print e
            next
        }
        { print }
    ' .gitattributes > "$tmp"
    cat "$tmp" > .gitattributes
    rm -f "$tmp"
    echo "  [FIX] .gitattributes (dead absolute pre-commit pin rewritten to $entry)"
}

# normalize_gitattributes_entry's self-heal regex targets `*/pre-commit …
# eol=lf` specifically -- a dead *absolute* pin can only exist for
# pre-commit, since pre-push never shipped before this multi-hook change (so
# no pre-0.3.2 install ever wrote an absolute pin for it). The regex is left
# pre-commit-only rather than generalised.
ensure_gitattributes_lf() {
    local name entry
    for name in pre-commit pre-push; do
        entry="$HOOKS_DIR/$name text eol=lf"
        normalize_gitattributes_entry "$entry"
        if [ -f .gitattributes ] && grep -qF "$entry" .gitattributes; then
            echo "  [SKIP] .gitattributes ($HOOKS_DIR/$name eol=lf present)"
        else
            {
                [ -s .gitattributes ] && printf '\n'
                printf '%s\n' "$GITATTR_COMMENT"
                printf '%s\n' "$entry"
            } >> .gitattributes
            echo "  [CREATE] .gitattributes ($HOOKS_DIR/$name eol=lf)"
        fi
    done
}

# True if this destination carries a pre-1.0 doc set directly under docs/:
# our navigation map is there, and the migrated one is not.
#
# The probe is docs/second-brain/README.md, not the directory -- an empty
# docs/second-brain/ (a half-done migration, or a plain mkdir) would
# otherwise switch the detection off and let the scaffold seed placeholders
# next to the real docs, which is the exact accident this guards against.
#
# Both "Second Brain" and "Navigation Map" must appear in docs/README.md.
# Either alone is plausible in a project's own docs index; together they are
# our template's heading. Matched with grep -F on ASCII substrings -- the
# heading's em-dash would break on a re-encoded checkout.
has_legacy_docs_layout() {
    [ -f "$DOCS_DIR/README.md" ] && return 1
    [ -f docs/README.md ] || return 1
    grep -qF "Second Brain" docs/README.md 2>/dev/null &&
        grep -qF "Navigation Map" docs/README.md 2>/dev/null
}

# Print the migration instructions for a legacy layout. Deliberately does not
# run them: bootstrap.sh never moves or deletes user content, and only the
# destination knows which files under docs/ are actually ours.
warn_legacy_docs_layout() {
    echo "  [WARN] a Second Brain doc set was found directly under docs/ (pre-1.0 layout)."
    echo "         The doc set now lives in $DOCS_DIR/, so the scaffold was SKIPPED"
    echo "         to avoid seeding an empty second copy next to your real docs."
    echo "         Migrate, then re-run this bootstrap:"
    echo ""
    echo "           mkdir -p $DOCS_DIR"
    echo "           git mv docs/README.md docs/architecture.md docs/database.md \\"
    echo "                  docs/glossary.md docs/layout.md docs/patterns.md \\"
    echo "                  docs/testing.md docs/adr $DOCS_DIR/"
    echo ""
    echo "         (drop from that list anything your project doesn't have, and"
    echo "          leave behind any file under docs/ that is your own doc, not ours)"
}

# 1. docs/second-brain/ scaffold (create-only, recursive).
if has_legacy_docs_layout; then
    warn_legacy_docs_layout
else
    while IFS= read -r -d '' f; do
        copy_if_absent "$f" "$DOCS_DIR/${f#"$PAYLOAD"/docs/}"
    done < <(find "$PAYLOAD/docs" -type f -print0)
fi

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

# 3. git pre-commit hook (never overwrites a user hook) + core.hooksPath
#    wiring into the committed, configurable hooks dir.
HOOKS_DIR="$(resolve_hooks_dir)"
echo "  [GIT] hooks dir: $HOOKS_DIR"
install_or_inject_hook "pre-commit"
install_or_inject_hook "pre-push"

if git rev-parse --git-dir >/dev/null 2>&1; then
    ensure_gitattributes_lf
    current="$(git config --get core.hooksPath || true)"
    # Compare on the repo-relative form so an older install that stored the
    # path absolute is recognised as ours (not mistaken for a foreign hook
    # manager) and rewritten to the portable relative form.
    current_rel="$(relativize_hooks_dir "$current")"
    if [ -z "$current" ]; then
        warn_shadowed_git_hooks
        git config core.hooksPath "$HOOKS_DIR"
        echo "  [GIT] core.hooksPath set to $HOOKS_DIR"
    elif [ "$current_rel" = "$HOOKS_DIR" ]; then
        if [ "$current" = "$HOOKS_DIR" ]; then
            echo "  [GIT] core.hooksPath already set to $HOOKS_DIR"
        else
            git config core.hooksPath "$HOOKS_DIR"
            echo "  [GIT] core.hooksPath normalized to relative $HOOKS_DIR (was $current)"
        fi
    elif [ "$FORCE_HOOKSPATH" = 1 ]; then
        warn_shadowed_git_hooks
        git config core.hooksPath "$HOOKS_DIR"
        echo "  [GIT] core.hooksPath overwritten to $HOOKS_DIR (--force-hookspath)"
    else
        # Another hook manager (husky, lefthook, ...) owns core.hooksPath.
        # Our hook now sits in $HOOKS_DIR but git won't read it until this
        # is repointed; don't clobber their setup silently.
        echo "  [WARN] core.hooksPath is '$current' (another hook manager?); left untouched, so $HOOKS_DIR/pre-commit is inert (re-run with --force-hookspath to override)"
    fi
else
    echo "  [GIT] no git repository here; skipping hook wiring"
fi

# 4. CI workflow (create-only).
copy_if_absent "$PAYLOAD/workflows/second-brain.yml" ".github/workflows/second-brain.yml"

# 5. Path-filter config (create-only, and deliberately NOT refreshed below:
#    it is the destination's own file, read by all three enforcement points).
copy_if_absent "$PAYLOAD/second-brain.conf" ".second-brain.conf"

# 6. --refresh-system: overwrite ONLY the two system files and the
#    CLAUDE.md block between its markers. docs/second-brain/,
#    .second-brain.conf and user prose untouched.

# Refresh one of our hooks in place: rewrite the marker-delimited block from
# the current payload. Install, pre-0.3 upgrade and injection into a foreign
# hook all happen earlier, in install_or_inject_hook (step 3).
refresh_hook() {
    local name="$1" markers begin end payload hook
    markers="$(hook_markers "$name")"
    begin="${markers%%$'\t'*}"
    end="${markers##*$'\t'}"
    payload="$PAYLOAD/git-$name"
    hook="$HOOKS_DIR/$name"
    # Step 3 (install_or_inject_hook) runs unconditionally, and before this,
    # in the same invocation -- so by the time a refresh reaches here the hook
    # exists and carries our markers in every case: a missing hook was just
    # created, a pre-0.3 marker-less one replaced wholesale, a foreign one
    # injected. Only the block rewrite is reachable. Anything else means the
    # script's own step order was broken, so fail loudly rather than write a
    # malformed hook.
    if [ ! -f "$hook" ] || ! hook_is_ours "$hook" "$begin"; then
        echo "  [ERROR] $hook is missing or carries no SECOND BRAIN block at refresh time (did the install step run?)" >&2
        exit 1
    fi
    refresh_hook_block "$hook" "$payload" "$begin" "$end"
    echo "  [REFRESH] $hook (block between markers)"
    chmod +x "$hook" 2>/dev/null || true
}

if [ "$REFRESH" = 1 ]; then
    echo ""
    echo "  Refreshing system files ..."

    refresh_hook "pre-commit"
    refresh_hook "pre-push"

    mkdir -p ".github/workflows"
    cp "$PAYLOAD/workflows/second-brain.yml" ".github/workflows/second-brain.yml"
    echo "  [REFRESH] .github/workflows/second-brain.yml"

    if [ -f ".second-brain.conf" ]; then
        echo "  [SKIP] .second-brain.conf (create-only; your path filters are preserved)"
    else
        cp "$PAYLOAD/second-brain.conf" ".second-brain.conf"
        echo "  [CREATE] .second-brain.conf (was missing)"
    fi

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
