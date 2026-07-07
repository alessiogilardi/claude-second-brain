#!/usr/bin/env python3
"""[SECOND BRAIN SYSTEM] Stop-hook reminder.

Mirrors the exclusion logic in .claude/hooks/pre-commit. Stop hooks only
feed the model plain stdout printed on exit 0 is invisible to Claude, only
visible to the user in transcript mode -- so drift is reported via the
"block" JSON contract instead, which surfaces the reason to the model and
stops the session once. `stop_hook_active` (present on stdin when this
hook already blocked the current stop) guards against looping forever.
Run via `uv run --no-project` from .claude/settings.json; stdlib only, no
dependencies.
"""

import json
import re
import subprocess
import sys

EXCLUDE_PATTERN = re.compile(
    r"^(\.github/|.*\.lock$|package-lock\.json$|yarn\.lock$|"
    r"pnpm-lock\.yaml$|poetry\.lock$|uv\.lock$|Cargo\.lock$|"
    r"Gemfile\.lock$|\.claude/)|(^|/)tests?/"
)
# tests?/ intentionally matches at any depth, not just top-level, so
# nested test dirs (e.g. src/pkg/tests/) are excluded too. That means
# testing-*strategy* changes (new test types, frameworks, coverage
# tooling) are covered only by this reminder and the skill's
# end-of-session pass -- never by pre-commit, since test-content commits
# never reach it. Narrow this pattern to flag test *config* files
# specifically (pytest.ini, conftest.py, CI test steps) if stronger
# enforcement is needed.
DOCS_PATTERN = re.compile(r"^docs/|^CLAUDE\.md$")


def changed_files() -> list[str]:
    result = subprocess.run(
        ["git", "status", "--porcelain", "-z"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        return []

    # -z output is NUL-separated and never quotes/escapes paths. Renames
    # and copies are the one special case: the record carrying the R/C
    # status holds the *origin* path, and the new path follows as its
    # own record with no status prefix.
    records = result.stdout.split("\0")
    files = []
    i = 0
    while i < len(records):
        record = records[i]
        if not record:
            i += 1
            continue
        status, path = record[:2], record[3:]
        if "R" in status or "C" in status:
            i += 1
            if i < len(records) and records[i]:
                path = records[i]
        files.append(path)
        i += 1
    return files


def stop_hook_already_fired() -> bool:
    try:
        payload = json.loads(sys.stdin.read() or "{}")
    except json.JSONDecodeError:
        return False
    return bool(payload.get("stop_hook_active"))


def main() -> int:
    if stop_hook_already_fired():
        return 0

    files = changed_files()
    if not files:
        return 0

    relevant = [f for f in files if not EXCLUDE_PATTERN.match(f)]
    source_changed = [f for f in relevant if not DOCS_PATTERN.match(f)]
    docs_changed = [f for f in relevant if DOCS_PATTERN.match(f)]

    if source_changed and not docs_changed:
        print(json.dumps({
            "decision": "block",
            "reason": (
                "[SECOND BRAIN SYSTEM] Uncommitted source changes with no "
                "matching docs/ update. Run the update-second-brain skill, "
                "then stop again."
            ),
        }))
    return 0


if __name__ == "__main__":
    sys.exit(main())
