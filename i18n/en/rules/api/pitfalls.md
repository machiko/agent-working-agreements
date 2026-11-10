---
source_sha256: b1efdf4dd77210de07a268b491999eda70a5b747882bec1d3562b5ac5fae1a14
category: api
tier: optional
label: "API and integration contract pitfalls"
summary: "Language-agnostic API incidents: cascading failures from external calls without timeouts, silently swallowed errors, breaking field changes, and duplicate charges from missing idempotency keys. Loaded only when touching controller and API files"
stack: api
paths:
  - "**/controllers/**"
  - "**/controller/**"
  - "**/handlers/**"
  - "**/handler/**"
  - "**/routes/**"
  - "**/route/**"
  - "**/api/**"
  - "**/services/**"
  - "**/*client*.*"
incidents:
  - "A third-party service slowed down and calls had no timeout, exhausting backend workers"
  - "Double clicks and webhook redeliveries weren't idempotent, causing duplicate point deductions and duplicate orders"
  - "An API field changed type, and many un-updated apps and partners failed to parse responses"
last_reviewed: 2026-11-10
enforced_by:
  - audit:empty-catch
---

# API and integration contract pitfalls

> Language-agnostic incidents from API design, external integrations, and inter-system communication. Format: Symptom → Root cause → How.

## External calls without timeouts cause cascading failures

- **Symptom:** A third-party SMS, e-invoice, logistics, or external webhook service slows down, all local backend threads/workers are quickly exhausted, health checks time out, and every other unrelated API goes down.
- **Root cause:** In most languages the HTTP/RPC client's default timeout is to wait forever (0 or several minutes). With even slight latency from the external service, concurrent requests rapidly exhaust local worker resources and connections.
- **How:** Explicitly set `connectTimeout` and `readTimeout` on every external network request (recommended for typical cases: connect <= 2s, read <= 5s). Critical external dependencies must have a circuit breaker or fail-fast mechanism; never let a third party hang core business flows.

## Silently swallowing exceptions

- **Symptom:** A production feature fails without warning — orders aren't created, messages aren't sent — but the server logs show no errors at all; it's a black hole you can't debug.
- **Root cause:** To turn tests green or keep the program from throwing, the agent wrapped external service calls or core logic in an empty `catch (Exception e) {}` or `except: pass`, completely hiding the root cause.
- **How:** Empty catch blocks are forbidden. When catching an exception, at minimum log an error with context (including the original stack trace and key business identifiers), or convert it into an explicitly defined domain exception and propagate it to an upper-layer handler.

## Breaking field changes kill clients

- **Symptom:** As soon as the new backend API ships, un-updated mobile apps, existing SPA pages, or partner microservices crash or fail to parse JSON en masse.
- **Root cause:** Fields in an existing API response were deleted, renamed, or changed type (e.g. numeric `id: 123` became string `id: "123"`), ignoring that external clients can't be hot-updated at will.
- **How:** Published API contracts follow an "add, never change" principle. Retiring a field must go through a deprecation process (keep the old field and document the deprecation timeline). Breaking changes require a new API version (e.g. `/v1/` to `/v2/`).

## Critical writes without idempotency keys cause duplicate charges

- **Symptom:** A user double-clicks a button on a flaky network, or an external payment webhook is redelivered, and the system deducts points twice, creates two identical orders, or hands out a gift twice.
- **Root cause:** Requests that change state such as money or inventory don't require a unique idempotency key (Idempotency-Key), so the server treats retried requests as separate transactions and executes them again.
- **How:** Endpoints for irreversible operations must require an `Idempotency-Key` header. The backend records processing state in a cache or a database unique constraint; for a duplicate key that's already completed, return the cached result directly, and for one still in progress, block the concurrent operation.
