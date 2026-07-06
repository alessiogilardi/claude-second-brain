#!/usr/bin/env python3
"""Merge the Second Brain Stop-hook entry into a destination project's
.claude/settings.json without disturbing any hooks/config already there.

Used only by install.ps1 during installation (`uv run scripts/merge_settings.py
--template <path> --destination <path>`). Not copied into destination
projects -- it's a build-time tool, not a runtime hook.
"""

import argparse
import json
import sys
from pathlib import Path

MARKER = "session_reminder.py"


def stop_hook_present(settings: dict) -> bool:
    for entry in settings.get("hooks", {}).get("Stop", []):
        for hook in entry.get("hooks", []):
            if MARKER in hook.get("command", ""):
                return True
    return False


def merge(template: dict, destination: dict) -> dict:
    destination.setdefault("hooks", {})
    destination["hooks"].setdefault("Stop", [])
    destination["hooks"]["Stop"].extend(template.get("hooks", {}).get("Stop", []))
    return destination


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--template", required=True, type=Path)
    parser.add_argument("--destination", required=True, type=Path)
    args = parser.parse_args()

    try:
        template = json.loads(args.template.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"[merge_settings] failed to read template: {exc}", file=sys.stderr)
        return 1

    if not args.destination.exists():
        args.destination.parent.mkdir(parents=True, exist_ok=True)
        args.destination.write_text(
            json.dumps(template, indent=2) + "\n", encoding="utf-8"
        )
        print("created")
        return 0

    try:
        destination = json.loads(args.destination.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"[merge_settings] failed to read destination: {exc}", file=sys.stderr)
        return 1

    if stop_hook_present(destination):
        print("skip-already-present")
        return 0

    merged = merge(template, destination)
    args.destination.write_text(json.dumps(merged, indent=2) + "\n", encoding="utf-8")
    print("merged")
    return 0


if __name__ == "__main__":
    sys.exit(main())
