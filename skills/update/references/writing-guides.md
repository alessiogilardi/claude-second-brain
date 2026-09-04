# How to write each Second Brain file

Reference for the `second-brain:update` skill. Read this before writing
prose into `docs/second-brain/` — the routing table in SKILL.md says
*which* file a fact belongs in, this says *how* to write it there.

## The one rule behind all the others

The Second Brain is a **map, not a mirror**. Its reader is an agent with no
prior context and a limited budget, deciding where to look next. Every line
must either orient that reader or be deleted. A file that mirrors the code
is worse than no file: it costs tokens to read, it rots silently, and it
looks authoritative while being wrong.

- Don't duplicate what code or git already say better: no
  function-by-function walkthroughs, no change history inside a status
  doc (that's what `git log` is for).
- Prefer a pointer to the source (`src/payments/charge.py:42`) over
  pasting the code itself. Docs rot; line references are cheap to
  re-check and cheap to fix when they drift.
- Write the *non-obvious* half. If a competent reader would infer it from
  the file names, cut it.
- If a file grows past roughly 200 lines, that's a signal to split it
  (e.g. `patterns.md` -> `patterns.md` + `patterns/caching.md`) rather
  than let it keep growing.
- If you add, remove, or rename a file under `docs/second-brain/`, update
  `docs/second-brain/README.md`'s navigation table in the same change: it is part of
  "direct write" scope, exactly like the other status files.

## Per-file guidance

### `architecture.md` — how the parts talk

**Write**: the components and the direction of the arrows between them;
entry points; where the process boundaries are; external integrations and
what happens when they fail; the one or two invariants that hold the design
together and that a newcomer would otherwise break.

**Don't**: enumerate every module (that's `layout.md`); explain *why* a
component was chosen over an alternative (that's an ADR); describe a call
stack.

**Failure mode**: a component inventory with no arrows. If the file doesn't
say what calls what, it hasn't described an architecture.

### `layout.md` — where things live and where new code goes

**Write**: the folder tree at the depth that carries meaning, one line of
responsibility per entry; the placement conventions that decide where a new
file belongs; the directories that look optional but are load-bearing, and
why.

**Don't**: mirror `ls -R`. Depth past the point where the name is
self-explanatory is noise.

**Failure mode**: a tree with no prose. The tree answers "what exists"; the
conventions section answers "where does my new file go", which is the
question that actually gets asked.

### `database.md` — the shape of persisted state

**Write**: tables/collections and their relationships; the migration tool
and how migrations are applied; the conventions a new table must follow
(naming, keys, soft deletes, timestamps); any denormalization that exists on
purpose.

**Don't**: paste full DDL — point at the migration or schema file. Don't
list every column of every table unless the column is surprising.

**Failure mode**: documenting the schema as it was designed rather than as
it was migrated. Verify against the migration directory, not the ORM models.

### `patterns.md` — conventions to reuse

**Write**: idioms actually repeated in this codebase, each with *where it's
used* and *why*. Three columns: pattern, location, rationale. A pattern with
one occurrence is not a pattern yet.

**Don't**: textbook patterns the project doesn't use; a rule the agent must
always obey regardless of code (that's `CLAUDE.md`).

**Failure mode**: aspirational patterns. If the code contradicts the entry,
the entry is a lie with good intentions — document what is, and raise the
divergence separately.

### `testing.md` — how correctness is checked

**Write**: the framework and the exact command to run the suite; what layers
exist (unit / integration / e2e) and what each is for; fixtures and how test
data is built; the coverage policy if there is one; what is deliberately
*not* tested and why.

**Don't**: describe individual test cases.

**Failure mode**: silence about manual verification. If the project has no
automated suite, say so explicitly and describe the manual procedure — an
empty `testing.md` reads as "not yet written" rather than "intentionally
manual".

### `glossary.md` — the project's private vocabulary

**Write**: terms that mean something specific *here* — a word from the
business domain, or a common word this codebase has narrowed. One line each,
defined by what it denotes in this system.

**Don't**: define general programming terms. Don't include a term you can't
point at in the code or the commit history.

**Failure mode**: a dictionary. The test for an entry is: would a new
contributor misread code because they assumed the ordinary meaning?

### `README.md` — the navigation map

**Write**: one table row per file, keyed on *when to read it*, not on what
it contains. It is the routing surface for a reader who doesn't yet know
which file holds their answer.

**Don't**: summarize the other files' content here — that creates a second
copy that drifts.

## Freshness footer — edge cases

The format itself is in SKILL.md. The cases it doesn't cover:

- **Unborn branch.** If the repo has no commits yet (`git rev-parse --short
  HEAD` fails), write `verified against initial import` in place of the sha,
  and replace it with a real short-sha the first time the skill runs after
  the first commit exists.
- **One commit behind, always.** The sha is the last commit the doc was
  checked against, so it is necessarily one commit older than the commit
  that includes the edit itself. That's expected, not a bug.
- **Exemptions.** `docs/second-brain/README.md` and `docs/second-brain/adr/*.md` carry no
  footer — ADRs encode their lifecycle in `Status` instead. Placeholder
  files fresh from the template don't get one either; add it the first time
  real content is written in.
- **What it means.** The footer is a staleness signal, not a proof of
  correctness. A stale-looking footer (old date, code has clearly moved on
  since that commit) is a strong hint to re-run the checklist on that file.
