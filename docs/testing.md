# Testing

This project has no automated test suite yet — no `tests/` folder, no
test framework wired up for either `install.ps1` (PowerShell) or
`scripts/merge_settings.py` (Python). Verification today is manual:
running `install.ps1` against a scratch/destination project (including,
as of this onboarding, this repo itself) and checking the resulting
files, hook behavior, and idempotent re-run output by hand. This file is
intentionally left minimal — populate it if a test framework is
introduced (e.g. Pester for the PowerShell installer, `pytest` for
`merge_settings.py`).

*Last updated: 2026-07-07 — verified against commit `9ea2b62`.*
