---
source_sha256: 31990281540b35f3012e2d9a7bb01f241b9c26a13d486c0d357d1b94bfae3047
category: cloud
tier: optional
label: "Cloud-native, logging, and observability pitfalls"
summary: "Cross-language cloud and monitoring incidents: high-cardinality metrics exploding memory, structured logs leaking unmasked PII and tokens, connection pools not reused exhausting ephemeral ports, presigned URL permissions out of control, circular health-check deadlocks. Loaded only when touching cloud, logging, and monitoring files"
stack: cloud
paths:
  - "**/k8s/**"
  - "**/helm/**"
  - "**/terraform/**"
  - "**/*logger*.*"
  - "**/*metric*.*"
  - "**/*telemetry*.*"
  - "**/*s3*.*"
  - "**/*storage*.*"
  - "**/*cloud*.*"
  - "**/*otel*.*"
incidents:
  - "High-cardinality labels blew up monitoring-system memory and caused frequent OOMs"
  - "Logs recorded plaintext credit card numbers, tokens, and national ID numbers"
  - "Connection pools were not reused, and a flood of external calls exhausted ephemeral ports"
last_reviewed: 2026-11-10
---

# Cloud-native, logging, and observability pitfalls

> Cross-language incidents in cloud services, logging, metrics, and microservice communication. Format: Symptom → Root cause → How.

## High-cardinality metric labels bring down the monitoring system

- **Symptom:** After a new release, Prometheus, Datadog, or the OpenTelemetry Collector climbs to tens of GB of memory or restarts on OOM repeatedly, Grafana dashboard queries time out, and the monitoring bill multiplies.
- **Root cause:** A developer put a high-cardinality (dynamic, unbounded) dimension into a metric label / tag, such as `user_id`, `order_id`, a full URL path (with ID query parameters), or a random UUID. Every unique combination creates its own time series in memory.
- **How:**
  - Restrict metric tags / labels to **bounded enumerations** (e.g. HTTP method, status code class `2xx` / `4xx`, handler name, or service name).
  - Put per-request identifiers (e.g. `user_id`, `trace_id`, `request_id`) in trace span attributes or structured logs; never use them as metric tags.

## Structured logs leak unmasked PII, tokens, and request headers

- **Symptom:** A security audit or compliance scan finds Kibana / Loki / CloudWatch full of users' plaintext credit card numbers, passwords, Bearer tokens, phone numbers, or national ID numbers, exposing the company to heavy regulatory fines and mandatory breach reporting.
- **Root cause:** To make debugging easier, the agent added logging of the whole request payload or headers in a controller / middleware (e.g. `logger.info("Request received", { body: req.body, headers: req.headers })`) without filtering sensitive keys first.
- **How:**
  - Configure a global masker (Masker / Redactor) at the top of the logging framework that forces sensitive fields such as `password`, `token`, `authorization`, `credit_card`, and `secret` to `***`.
  - Before logging a request body, explicitly filter domain attributes through an allowlist or use a dedicated DTO / summary object. Never print the raw request payload in production.

## Connection pools not reused exhaust ephemeral ports and TIME_WAIT

- **Symptom:** When a service makes thousands of external HTTP / microservice calls under high traffic or in a scheduled job, it suddenly spews `connect: cannot assign requested address` or connection timeouts; the server is lightly loaded yet cannot make any outbound network request.
- **Root cause:** Every external API call does `new HttpClient()`, `http.Client{}`, or opens a new database connection, and after the request the connection enters `TIME_WAIT` (typically held for 60 seconds to 2 minutes). Under high concurrency, the local ports the OS allocates for outbound connections (ephemeral ports, usually 30,000 to 60,000) run out quickly.
- **How:**
  - Manage HTTP clients, RPC clients, and Redis/DB connection objects as singletons or connection pools, reusing the underlying TCP connections (Keep-Alive) across requests.
  - Set the pool's max connections (MaxIdleConns / MaxConnsPerHost) and connection lifetime deliberately, so new connections are not created constantly.

## Cloud object storage presigned URLs without scoped permissions and expiry

- **Symptom:** After a frontend user gets an upload or download link, unauthorized third parties keep accessing it for a long time; or a malicious user uses a signed URL to overwrite someone else's core data files, or uploads huge unknown files that fill up storage.
- **Root cause:** When generating S3 / GCS presigned URLs, the backend grants an overly long validity period (e.g. 24 hours to several days), and when signing PutObject it does not restrict `Content-Length-Range` (maximum file size) or `Content-Type`, nor limit the URL to a specific path prefix.
- **How:**
  - Set presigned URL validity to the shortest reasonable time (e.g. 5–15 minutes for uploads, 5 minutes for temporary viewing).
  - When signing uploads, enforce a file size limit (Content-Length Policy) and a MIME type allowlist, and require the path to include a random UUID or stay under the tenant's own directory.

## Circular dependencies in distributed health checks cause deadlock (Circular Healthcheck)

- **Symptom:** During a Kubernetes or cluster restart, Service A and Service B are both stuck in CrashLoopBackOff or NotReady, each waiting for the other's health endpoint to return 200 OK, deadlocked with no way to recover.
- **Root cause:** A deep health check (Deep Readiness / Liveness Probe) makes the health of non-essential external services a precondition for local readiness. When the whole cluster cold-starts, the services wait on each other's downstream responses.
- **How:**
  - **Liveness Probe:** Check only whether the local process is still alive (not deadlocked, memory normal). Never call any external dependency (database, cache, or other microservices).
  - **Readiness Probe:** Check only local core resources and the required direct database connection. For external non-core third parties, always use soft degradation or async retries; never let an external service that isn't ready block local startup.
