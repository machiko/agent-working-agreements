---
source_sha256: f047ffd8c40e68e9eeb87caf2772b5224a67a4bb0bbf3525acdf5a25faad34cd
category: database
tier: optional
label: "Database and ORM pitfalls"
summary: "Language-agnostic database incidents: locking tables in production, non-idempotent migrations, N+1 query explosions, soft-delete dirty reads, and floating-point precision on money. Loaded only when touching database-related files"
stack: database
paths:
  - "**/*.sql"
  - "**/migrations/**"
  - "**/migration/**"
  - "**/schema/**"
  - "**/entities/**"
  - "**/models/**"
  - "**/prisma/**"
  - "**/alembic/**"
incidents:
  - "A migration failed midway and errored on rerun, blocking the deploy pipeline"
  - "Adding a column to a large table took an exclusive lock, and production APIs timed out across the board"
  - "Money was calculated with floats, and reconciliation turned up many small discrepancies"
last_reviewed: 2026-11-10
---

# Database and ORM pitfalls

> Real database incidents across languages and ORMs (applies to PostgreSQL, MySQL, SQLite, Prisma, SQLAlchemy, GORM, etc.). Format: Symptom → Root cause → How.

## Non-idempotent migrations

- **Symptom:** A migration fails halfway through a deploy due to a network drop or syntax error; after the fix, rerunning it throws `Table already exists` or `Duplicate column name`, the automated deploy pipeline is fully blocked, and someone has to clean up the schema in production by hand.
- **Root cause:** DDL scripts lack defensive existence checks (no `IF NOT EXISTS` / `IF EXISTS`), and some database engines or statements do not support transactional rollback across DDL.
- **How:** Always use defensive syntax when creating or altering columns in migrations (or the ORM's `hasTable` / `hasColumn` guards). Every migration must ship with rollback/down logic that cleanly reverts it. Do not mix large schema changes with long-running data backfills in the same migration.

## Adding a column to a large production table takes an exclusive lock

- **Symptom:** As soon as the deploy runs the migration, production requests pile up, the connection pool fills, database CPU spikes, and every API touching that table times out and fails one after another.
- **Root cause:** Running `ALTER TABLE ... ADD COLUMN ... DEFAULT 'foo'` directly on a table with millions of rows triggers a full table copy and rewrite when online DDL is unsupported or not specified, holding an exclusive lock that blocks all concurrent reads and writes.
- **How:** When adding a column to a large table, prefer allowing `NULL` without a fixed non-null default (or use the database's native instant DDL). Always build indexes with non-blocking syntax (e.g. PostgreSQL's `CONCURRENTLY`, MySQL's `ONLINE DDL`, or `gh-ost` / `pt-online-schema-change`). Move updates of a million rows or more into scheduled batch (chunking) jobs.

## Hidden ORM N+1 queries and memory blowups

- **Symptom:** Local development and unit tests with a few fake rows run very fast, but once in production, listing or exporting real data fires tens of thousands of SQL queries, knocks out the database instantly, and the backend process crashes with OOM.
- **Root cause:** Accessing a related object's attribute inside a loop (e.g. `order.customer.name`) triggers the ORM's lazy loading, so every parent row sends an extra, separate query.
- **How:** Always eager-load explicitly for list and batch queries (e.g. `with()`, `select_related`, `include`). In code review, treat any related-object access inside a loop as a performance red flag. Turn on ORM strict mode in test environments (e.g. disallow lazy loading) to catch it early.

## Soft-delete dirty reads leaking through relations

- **Symptom:** Report figures don't match, stats pages include suspended or deleted users, and raw cross-table SQL counts voided items toward revenue.
- **Root cause:** ORMs usually add the `deleted_at IS NULL` condition automatically only for the primary model being queried; once you rewrite to raw SQL, complex JOINs, or subqueries, the soft-delete filter is easily dropped.
- **How:** When writing raw SQL or multi-table JOIN reports, check every table for `deleted_at IS NULL`. Money and count statistics must have edge-case tests covering the "related item was soft-deleted" scenario.

## Precision disasters from floating-point money calculations

- **Symptom:** Each order is off by 0.01 after conversion, refund totals don't match payment totals, and after a few weeks finance reconciliation finds many small, untraceable discrepancies.
- **Root cause:** Money is stored or computed with IEEE 754 floating-point types (`float`, `double`), and binary conversion rounding errors are amplified through multiplication, division, and accumulation.
- **How:** Always store money in the database as fixed-point `DECIMAL(16, 4)` or as an integer in the smallest currency unit (e.g. cents as `BIGINT`). In application code, always compute money with a high-precision numeric library (e.g. `Decimal`, `BigNumber`); never do money math directly with floats.
