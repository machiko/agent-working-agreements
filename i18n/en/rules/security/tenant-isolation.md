---
source_sha256: 6aeec9a6da48f5d6ce91af1696e9b933f59ef8d3fe2a919a258530a3359bb859
category: security
tier: optional
label: "Multi-tenant and export data isolation"
summary: "Guards against BOLA / IDOR authorization flaws: lists, statistical reports, and async exports must enforce tenant/user scope filtering, and background jobs must pass authorization context explicitly"
incidents:
  - "Report and export features missed the tenant scope, exposing other tenants' data (BOLA/IDOR)"
  - "A background worker had no request context, assumed it could get the current logged-in user, and overstepped its authorization"
last_reviewed: 2026-11-10
---

# Multi-tenant and export data permission isolation (Tenant Isolation & Data Scope)

## 1. Bind lists, statistical reports, and data exports to the tenant scope (Enforce Tenant Scope Across All Exits)

In any system with multi-tenancy, organization isolation, or permission roles, **every list query, statistical report, and bulk data export (CSV/Excel/JSON) must enforce tenant or user scope filtering**.

**Why:**
This is the top item in the OWASP API Security Top 10 (BOLA / IDOR). Developers and AI usually remember to apply the current tenant scope when building frontend lists, but when the requirement involves "data export" or "complex chart statistics", they often reach for raw SQL, a standalone export service, or a third-party reporting tool for performance or convenience, bypassing the framework's model scope. Low-privilege users, or even outside competitors, can then export sensitive data from every other tenant in the system.

**How:**
- **Export services only receive pre-filtered data**: export classes only turn an already permission-filtered dataset into a file; they must never query whole tables themselves or bypass the authorization layer.
- **Raw SQL must include isolation conditions**: for any raw SQL, check that the WHERE clause includes the tenant or user foreign key (e.g. `tenant_id`, `org_id`, or `user_id`); never drop it to optimize a query.
- **Separate list authorization from detail authorization**: seeing a summary in a list does not grant permission to edit or view full PII details; verify the two independently.

---

## 2. Async background jobs must pass authorization context explicitly (Explicit Tenant Context in Async Jobs)

Async queue jobs (workers / jobs) that generate reports, send bulk notifications, or export files must explicitly serialize the authorization and tenant filter conditions into the job parameters at dispatch time.

**Why:**
Background workers run in a separate CLI process, **with no HTTP request context and no session / token for the current logged-in user**. AI agents often wrongly assume the worker can resolve "the current user" automatically, or fall back inside the worker to re-querying with system-wide top privileges (system scope), causing serious cross-tenant data mix-ups and leaks.

**How:**
- Before the controller (controller / handler) dispatches the job, explicitly extract the current user's `tenant_id`, permission scope, and filter conditions, and pass them to the job as serializable parameters.
- Once the worker receives the parameters, restrict every query to that `tenant_id`; full table scans with empty conditions are forbidden.
- After updating worker code, restart the container or process (e.g. `systemctl restart` or a container rebuild) to make sure the latest code is fully loaded.

---

## 3. Use stable string codes for permissions across environments; never hardcode numeric IDs (Use Stable Slugs Over Auto-increment IDs)

When checking roles, permissions, or system constants in business logic or SQL, always use stable English identifier strings (slug / code); never hardcode the database's auto-increment numeric primary keys.

**Why:**
Across development, test, staging, and production, auto-increment primary keys (e.g. `role_id = 3`) usually differ in order and value between database instances. AI agents tend to hardcode numeric IDs, so local tests pass, but in production admin permissions get misassigned to regular users.

**How:**
- Use string identifiers for roles and permissions (e.g. `role: 'finance_manager'`, `permission: 'export_invoices'`).
- Magic numbers like `if (user.role_id === 2)` are forbidden in business logic.
