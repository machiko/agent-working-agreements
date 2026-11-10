---
source_sha256: 508965a82aafde5126a603c3869464be4a15f814165a19c97392749e10576bd2
category: async
tier: optional
label: "Async, queue and cache pitfalls"
summary: "Cross-language async incidents: cache avalanche and stampede, poison messages retried forever, distributed locks without leases deadlocking, unbounded concurrent fan-out overwhelming downstream services, shared state races across coroutines. Load only when touching queue, worker or cache files"
stack: async
paths:
  - "**/jobs/**"
  - "**/job/**"
  - "**/queues/**"
  - "**/queue/**"
  - "**/workers/**"
  - "**/worker/**"
  - "**/tasks/**"
  - "**/task/**"
  - "**/*redis*.*"
  - "**/*cache*.*"
incidents:
  - "Cache entries expired together and the database was instantly saturated (cache stampede)"
  - "A poison message was retried forever and tied up every background worker"
  - "A batch event fired tens of thousands of requests with no concurrency limit and took down a downstream service"
last_reviewed: 2026-11-10
---

# Async, queue and cache pitfalls

> Cross-language incidents with background jobs, async tasks, distributed locks and caches. Format: Symptom → Root cause → How.

## Cache Stampede & Dogpiling

- **Symptom:** On a high-traffic home page or during a promotion, the moment the cache expires or restarts, backend database CPU jumps to 100%, the connection pool is exhausted, and the whole service goes down.
- **Root cause:** Cache keys written in bulk share exactly the same TTL, so they all expire in the same second; or the moment a single extremely hot entry expires, thousands of concurrent requests bypass the cache and hit the database to recompute it.
- **How:**
  - Add random jitter to cache TTLs (e.g. `base_ttl + rand(1, 300)` seconds) so entries don't expire en masse.
  - Protect hot-entry recomputation with a mutex (mutex / SingleFlight) or refresh it ahead of time in the background, so only one worker reloads from the database at a time; other requests wait or degrade to the stale cache (stale-while-revalidate).

## Poison Pill in Job Queue (infinite retries)

- **Symptom:** All background workers are busy and CPU spikes, tens of thousands of messages pile up in the normal queue, and the logs show just one or two specific records throwing exceptions and being rerun over and over.
- **Root cause:** Failed jobs have no retry limit (max tries) or backoff. When a worker hits malformed data, a missing foreign key, or business data that can't be recovered (a poison message), it keeps re-queuing it and rerunning it within seconds.
- **How:**
  - Configure every async job explicitly with a maximum retry count (e.g. 3) and exponential backoff (exponential backoff + jitter).
  - Once the retry limit is exceeded, move the job to a dead letter queue (DLQ) and record an alert along with the original payload; never retry forever and block the main queue.

## Distributed Lock Deadlocks (no lease)

- **Symptom:** A batch of scheduled jobs or resource-contention work suddenly stops for good; restarting a single instance doesn't help, and it only recovers after someone manually deletes a specific key in Redis.
- **Root cause:** The lock was acquired without an expiry (lease / TTL), or the process holding the lock crashed before releasing it (OOM / node restart / network partition); also, the release didn't check the holder's token and deleted a lock that another process had extended or reacquired.
- **How:**
  - Assign an expiring lease atomically when acquiring a distributed lock (e.g. Redis `SET key value NX PX 30000`); never use a lock without an expiry.
  - Releasing a lock must compare the unique token (usually via a Lua script so only the holder can release it).
  - Use lock renewal (watchdog / heartbeat) for long-running jobs.

## Unbounded Concurrency Fan-out

- **Symptom:** After a batch event fires, the code uses `Promise.all`, `go func()` or async workers to send tens of thousands of HTTP requests or DB queries in parallel at once, so a third-party API blocks you with rate limiting (429), or your own database connection pool collapses.
- **Root cause:** Parallel fan-out over a collection (array, list) had no concurrency pool (concurrency pool / semaphore / rate limiter) limiting it.
- **How:**
  - Put an explicit cap on parallelism for fan-out operations (concurrency limit, e.g. `p-limit`, a fixed worker pool, a Go channel semaphore; default to 5–10).
  - For external APIs, configure a rate limiter or token bucket that matches the provider's quota.

## Shared Mutable State Race Conditions (across coroutines/threads)

- **Symptom:** Under high concurrency, order totals are occasionally wrong, counters come up short, and multi-tenant requests show another user's session or data.
- **Root cause:** In multi-threaded or async coroutine environments (e.g. Node.js global objects, Go global variables, Python class-level static variables, PHP long-running workers such as Octane/Swoole), unlocked in-memory variables were shared, or a single request's context was stored in a singleton shared across requests.
- **How:**
  - Pass request-lifecycle state (user ID, DB transaction, tenant) through parameters or a thread/coroutine-isolated context (e.g. Go `context.Context`, Node.js `AsyncLocalStorage`).
  - If mutable state must be shared, access it through immutable data structures, atomic operations, a mutex, or a dedicated state-owning actor.
