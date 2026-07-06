# Database

> Placeholder — to be filled in during onboarding of the real project.

## Engine and connection

State the DBMS used (e.g. PostgreSQL, SQLite, MongoDB) and where the
connection configuration lives (without including credentials).

## Main schema

List the main tables/collections, their key fields, and the relationships
between them. For complex schemas, prefer a structured table-by-table list
over a single monolithic diagram.

```text
example_table
├── id (PK)
├── field_x
└── fk_other_table (FK -> other_table.id)
```

## Migrations

State the migration tool used and the naming/versioning convention
adopted.

---
*Instructions for Claude: update this file whenever tables, columns,
indexes, constraints, or relationships change. Don't leave the documented
schema out of sync with the real one.*
