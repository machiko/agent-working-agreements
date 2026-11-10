---
source_sha256: 23b6a498993975352802082b648a52e75b4a104f735b782447679fc3fdf15d4d
category: security
tier: optional
label: "Supply-chain security and dependency pitfalls"
summary: "High-risk security incidents in AI-assisted work: package hallucination and dependency poisoning, floating versions and lockfile drift, over-permissive wildcard grants, build-time secrets left in multi-stage image layers, leaked fake test credentials. Load only when touching package config or security permissions"
stack: security
paths:
  - "package.json"
  - "package-lock.json"
  - "yarn.lock"
  - "pnpm-lock.yaml"
  - "composer.json"
  - "composer.lock"
  - "requirements.txt"
  - "pyproject.toml"
  - "poetry.lock"
  - "go.mod"
  - "go.sum"
  - "Cargo.toml"
  - "Cargo.lock"
  - "**/Dockerfile*"
  - "**/*.tf"
  - "**/*policy*.json"
  - "**/*rbac*.yaml"
incidents:
  - "The agent installed a package name the LLM hallucinated and got a squatted, poisoned malicious package"
  - "Dependencies were changed without syncing the lock file, and deployment pulled in a breaking update"
  - "A private token was left in an image history layer and found by a scanner after the push"
last_reviewed: 2026-11-10
enforced_by:
  - audit:wildcard-permissions
---

# Supply-chain security and dependency pitfalls

> Software supply-chain, dependency and permission-leak incidents that AI-agent-assisted development tends to cause. Format: Symptom → Root cause → How.

## Package Hallucination & Typosquatting

- **Symptom:** To implement a feature, the agent installs an intuitive-looking third-party open-source library on its own (e.g. `npm i date-fns-utils`). When it runs in CI or production, the server suddenly opens a reverse shell to an unknown external IP or exfiltrates secrets from environment variables.
- **Root cause:** When proposing solutions, LLMs often hallucinate package names that "sound like they should exist but were never officially published". Attackers continuously monitor NPM, PyPI and Packagist for these common hallucinated names, register them first (typosquatting), and plant trojan code.
- **How:**
  - Never let the agent install a new, unknown third-party dependency without human review.
  - Before adding any new package, manually check its official homepage, GitHub stars, recent release frequency and security advisories (e.g. Snyk, Socket.dev).

## Floating versions and Lockfile Drift

- **Symptom:** Tests pass locally for the developer, then the next day's production deploy falls over entirely; or the same code pulls a minor version with breaking changes when installed on different machines.
- **Root cause:** When adding or updating packages, the agent edited `package.json` directly (with `^` or `~` ranges) without generating or updating the lock file (`package-lock.json`, `pnpm-lock.yaml`, `composer.lock`), or used `--no-lock` to skip dependency locking.
- **How:**
  - Force strict locked installs for production deploys and CI pipelines (e.g. `npm ci`, `pnpm install --frozen-lockfile`, `composer install --locked`).
  - Every PR that changes dependencies must include the matching lockfile update; never leave it out.

## Over-privileged Wildcard IAM & RBAC

- **Symptom:** After a microservice that only needs to read public data is breached via SSRF, the attacker easily gains top-level permissions to drop every table, change security group rules, or read production secrets.
- **Root cause:** When writing AWS IAM policies, GCP roles or Kubernetes ClusterRoles, the agent reached for wildcards as a cure-all to "make sure it runs and never returns 403" (e.g. `Action: "*"`, `Resource: "*"`, `rules: [{ verbs: ["*"], resources: ["*"] }]`).
- **How:**
  - Follow the principle of least privilege strictly: grant each application or ServiceAccount only the minimal set of actions its job needs (e.g. `s3:GetObject` scoped to a specific bucket ARN).
  - Never configure global `*` grants in production or on CI runners.

## Build-time Secrets Leaking into Image (multi-stage builds)

- **Symptom:** After the project image is pushed to Docker Hub or an external container registry, a security scan digs the company's private GitHub token, NPM credentials or internal SSH private key out of the image history layers.
- **Root cause:** The Dockerfile used `ARG GITHUB_TOKEN` or `ENV TOKEN` to download private dependencies. Even though a later step `rm`s it, Docker's layered storage has already baked the secret, intact, into an earlier read-only layer.
- **How:**
  - When building images that need private credentials, always use Docker BuildKit's secret mounts (e.g. `RUN --mount=type=secret,id=token ...`); the secret is never written into an image layer.
  - Alternatively, compile dependencies in a separate builder stage and copy only the built artifacts into the final stage (production runner); never bring build-time credentials into it.

## Uncontrolled fake credentials or plaintext endpoints in test environments

- **Symptom:** Test code or mock files contain connection strings, default usernames/passwords or self-signed certificates that "look like test data but were once valid internally", and they leak through open-sourcing or collaboration, exposing the internal network.
- **Root cause:** While writing tests, the agent casually copied connection details from the real local environment into the test database or seed data (seeders).
- **How:**
  - Always use obviously fake placeholders for secrets in test config (e.g. `secret_mock_for_test_only`).
  - Run a guard script on a schedule that scans test directories and blocks real-format keys and internal-only hostnames.
