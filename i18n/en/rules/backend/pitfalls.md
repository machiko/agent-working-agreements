---
source_sha256: fff9e05ee9a0a764c1bb1bc1955248e0ba5a823aafcdb09b722c82480ea49f32
category: backend
tier: optional
label: "Web backend and application service pitfalls"
summary: "Cross-language backend incidents: empty env vars overriding defaults, dev/test dependencies leaking into production, build steps tripping secret injection, OOM on exports and large jobs, access to non-standard primary keys. Loaded only when touching backend files"
stack: backend
paths:
  - "**/*.php"
  - "**/*.py"
  - "**/*.go"
  - "**/*.ts"
  - "**/*.js"
  - "**/*.java"
  - "**/*.rb"
  - "**/*.rs"
  - "composer.json"
  - "package.json"
  - "pyproject.toml"
  - "requirements.txt"
  - "go.mod"
  - "Cargo.toml"
  - "pom.xml"
incidents:
  - "An env var set to an empty string kept the default from applying, and a feature silently stopped working in one environment"
  - "A dev dependency leaked into a production code path, causing a module-not-found error after release"
  - "A bulk export loaded all data at once and the process was killed by the OOM Killer"
last_reviewed: 2026-11-10
---

# Web backend and application service pitfalls

> Applies to modern web backends and microservices in Node.js, Python, Go, PHP, Java, and similar. Format: Symptom → Root cause → How.

## Empty env var overrides the default (Empty String Overrides Default)

- **Symptom:** A service quota drops to zero, an external endpoint becomes an empty string, or a critical feature silently stops working in one environment, with no missing-config error thrown.
- **Root cause:** With config like `env('KEY', 'default_val')`, Node `process.env.KEY || 'default_val'`, or Python `os.getenv('KEY', 'default_val')`, if `.env` or the environment defines `KEY=` (an empty string `""`), the system treats the variable as "present" and returns the empty string instead of falling back to the default. Automation scripts that fill missing keys with empty values wipe out every safe default.
- **How:**
  - Guard strictly against both empty strings and undefined at the config-loading layer (e.g. `process.env.KEY?.trim() || 'default'`, or a schema validator such as Zod / Pydantic).
  - Give every key in `.env.example` a valid sample value that boots the app as-is; never leave one blank. Scripts that maintain env vars default to the sample values.

## Local/dev dependencies leaking into production (Dev-dependencies Leakage)

- **Symptom:** Production suddenly throws `ClassNotFoundException`, `Cannot find module 'faker'`, or an undefined-function error on some uncovered edge branch; or users see mock data in certain cases.
- **Root cause:** A developer used a test or local fake-data tool (Faker, a mock library, a debug toolbar) and had business code fall back to generating fake data in a `default` branch. CI and local test environments usually install every dependency, but production installs with `--production` or `--no-dev`, so those modules don't exist.
- **How:**
  - Never import dev-dependencies from production business code paths.
  - Wrap any logic that produces mocks or fake data in a strict environment check (e.g. `process.env.NODE_ENV !== 'production'`). When a normal business branch hits an unmatched case, throw an explicit error; never silently fall back to fake data.

## Build or precompile steps trigger unguarded external secret injection

- **Symptom:** Running `npm run build`, `composer dump-autoload`, or static dependency scanning in a Dockerfile suddenly aborts the build with a missing database connection string or third-party API key.
- **Root cause:** During build, command registration, or dependency-injection (DI Container) scanning, frameworks instantiate the related modules or classes. If a module's top level or a constructor insists on reading production secrets or opening a remote connection, the build environment (which usually has no production secrets mounted) crashes outright.
- **How:** For any service that needs a remote connection or sensitive secrets, use lazy initialization (Lazy Resolution) or acquire the connection only in the actual business call (e.g. `handle()`, `execute()`). Never block at module load or in the constructor.

## Large jobs or exports without streaming blow up memory (OOM)

- **Symptom:** Single-record and small-data tests pass, but halfway through the full test suite, or during a large report export in production, the process is killed without warning by the OS OOM Killer.
- **Root cause:** Report exports (Excel / CSV / PDF) or batch jobs load all the data into an in-memory array at once, instantly filling the heap.
- **How:**
  - Always process bulk data in chunks (Chunking / Paging) or stream it out record by record (Streaming / Generator / Cursor).
  - When testing large exports, focus on transformation logic and the header contract; don't generate unbounded, huge entity arrays in feature tests.

## ORM access to missing attributes or non-standard primary keys overwrites data

- **Symptom:** Cached data or records from multiple users overwrite each other, but single-user testing can't reproduce it.
- **Root cause:** A legacy table has a non-standard primary key (e.g. `user_pk` instead of `id`), and the ORM returns `undefined` / `null` silently instead of erroring when a missing attribute (e.g. `model.id`) is accessed. When building a cache key (e.g. `user:${model.id}`), everyone ends up sharing the same key.
- **How:** When building critical identifiers (cache keys, log context, audit records), always use the ORM's built-in primary-key method (e.g. `getKey()`) or an explicitly named column, and rule out silent access to nonexistent attributes.
