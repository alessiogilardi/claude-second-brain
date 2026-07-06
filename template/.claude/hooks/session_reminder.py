#!/usr/bin/env python3
"""[SECOND BRAIN SYSTEM] Stop-hook reminder (non-blocking).

Mirrors the exclusion logic in .claude/hooks/pre-commit but never blocks
the agent from stopping -- it only prints a reminder when there is
uncommitted, doc-relevant source drift. Run via `uv run` from
.claude/settings.json; stdlib only, no dependencies.
"""

import re
import subprocess
import sys

EXCLUDE_PATTERN = re.compile(
    r"^(tests?/|\.github/|.*\.lock$|package-lock\.json$|yarn\.lock$|"
    r"pnpm-lock\.yaml$|poetry\.lock$|uv\.lock$|Cargo\.lock$|"
    r"Gemfile\.lock$|\.claude/)"
)
DOCS_PATTERN = re.compile(r"^docs/|^CLAUDE\.md$")


def changed_files() -> list[str]:
    result = subprocess.run(
        ["git", "status", "--porcelain"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        return []
    files = []
    for line in result.stdout.splitlines():
        # porcelain format: "XY path" (or "XY orig -> path" for renames)
        path = line[3:].split(" -> ")[-1].strip()
        if path:
            files.append(path)
    return files


def main() -> int:
    files = changed_files()
    if not files:
        return 0

    relevant = [f for f in files if not EXCLUDE_PATTERN.match(f)]
    source_changed = [f for f in relevant if not DOCS_PATTERN.match(f)]
    docs_changed = [f for f in relevant if DOCS_PATTERN.match(f)]

    if source_changed and not docs_changed:
        print(
            "[SECOND BRAIN SYSTEM] Reminder: uncommitted source changes "
            "with no matching docs/ update. Consider running the "
            "update-second-brain skill before ending the session."
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
