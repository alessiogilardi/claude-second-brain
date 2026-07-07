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


def find_marker_hook(settings: dict) -> tuple[int, int] | None:
    """Locate the (Stop-entry index, hook index) of the hook whose
    command references MARKER, or None if no such hook exists."""
    for i, entry in enumerate(settings.get("hooks", {}).get("Stop", [])):
        for j, hook in enumerate(entry.get("hooks", [])):
            if MARKER in hook.get("command", ""):
                return i, j
    return None


def template_marker_command(template: dict) -> str | None:
    location = find_marker_hook(template)
    if location is None:
        return None
    i, j = location
    return template["hooks"]["Stop"][i]["hooks"][j].get("command")


def merge(template: dict, destination: dict) -> tuple[dict, str]:
    destination.setdefault("hooks", {})
    destination["hooks"].setdefault("Stop", [])

    location = find_marker_hook(destination)
    if location is None:
        destination["hooks"]["Stop"].extend(template.get("hooks", {}).get("Stop", []))
        return destination, "merged"

    i, j = location
    existing_command = destination["hooks"]["Stop"][i]["hooks"][j].get("command")
    template_command = template_marker_command(template)
    if template_command is not None and existing_command != template_command:
        destination["hooks"]["Stop"][i]["hooks"][j]["command"] = template_command
        return destination, "updated"

    return destination, "skip-already-present"


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

    merged, status = merge(template, destination)
    if status != "skip-already-present":
        args.destination.write_text(
            json.dumps(merged, indent=2) + "\n", encoding="utf-8"
        )
    print(status)
    return 0


if __name__ == "__main__":
    sys.exit(main())
