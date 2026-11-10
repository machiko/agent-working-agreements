---
source_sha256: cacb4081ee93ca263cdf44c73e5f0881ade46dc5334273099ba7d2c9e32da907
category: container
tier: optional
label: "Container and local virtualization pitfalls"
summary: "Common container and local-environment incidents: single-file bind mount inode breaks after switching branches, container processes surviving after the terminal kills the client, Xdebug/profilers slowing tests, lost file system events under macOS virtualization, reverse proxy route allowlists. Load only when touching container config"
stack: container
paths:
  - "**/Dockerfile*"
  - "**/Containerfile*"
  - "**/*compose*.yml"
  - "**/*compose*.yaml"
  - "**/nginx/**"
  - "**/.dockerignore"
incidents:
  - "After switching branches, config inside the container reverted to defaults and the queue worker disappeared"
  - "Code changed on the host, but the dev server inside the container did not hot-reload"
  - "Certificates and private keys were baked into the image and pushed to a shared registry"
last_reviewed: 2026-11-10
---

# Container and local virtualization pitfalls

> Applies to Docker, Podman, Compose, local virtualization and reverse-proxy dev environments. Format: Symptom → Root cause → How.

## Single-file bind mount inode breaks after switching branches

- **Symptom:** After `git switch`, config files inside the container (e.g. php.ini, nginx.conf, custom.cnf) revert to defaults, or the queue worker process disappears and jobs hang; the container health check may even report healthy while all external connections are refused.
- **Root cause:** Switching branches in Git, or saving in a text editor, creates a new file that replaces the original, so the host file's inode changes. A Docker single-file bind mount is bound to the underlying inode; once the inode changes, the file inside the container still points to the destroyed old inode and stops syncing or becomes empty.
- **How:**
  - Don't just use `docker compose restart` (it does not recompute mounts). Use `docker compose up -d --force-recreate <service>` to force-recreate the container's mounts.
  - Prevent it at the workflow level: one branch per independent git worktree, instead of repeatedly switching branches in the same mounted directory to run tests.

## Processes inside the container keep consuming resources after the terminal kills the client

- **Symptom:** After pressing Ctrl+C in the terminal to end `docker compose exec` or `docker run`, local CPU stays pegged, ports stay occupied, or the database stays locked by a test process that never terminated.
- **Root cause:** The terminal interrupt only kills the client connection process on the host. If the container has no init process (e.g. dumb-init, tini) to forward SIGINT/SIGTERM to child processes, processes inside the container are adopted by PID 1 as orphans and keep running in the background.
- **How:**
  - After killing the terminal session, explicitly go into the container and terminate the process with `pkill`, or run `docker kill <container_id>`.
  - Configure `init: true` or use `tini` as the entrypoint in the Dockerfile so signals are forwarded to child processes.

## Lost file system events under macOS / Windows virtualization (Inotify Drop)

- **Symptom:** You change frontend code, CSS or templates on the host, but the dev server inside the container (Vite, Webpack, Next.js) never triggers hot reload (HMR); nothing happens until the container restarts.
- **Root cause:** The cross-host file sharing layers on macOS (VirtioFS / gRPC-FUSE) and Windows (WSL2 across file systems) often fail to deliver underlying inotify change events into the VM's containers in real time.
- **How:**
  - Enable polling in the dev server config (polling fallback, e.g. Vite `server.watch.usePolling: true`, Webpack `watchOptions: { poll: 1000 }`).
  - Or manually run `touch` on the target entry file inside the container to force an update.

## Always-on profiler / debugger slows the whole test suite

- **Symptom:** The full test suite balloons from a minute or two to over 30 minutes, or the host freezes outright in CI or under highly concurrent tests.
- **Root cause:** A debugging or coverage tool (e.g. Xdebug, Python py-spy, Node --inspect) is enabled in the container and, by default, starts fully on every request or CLI run, causing huge overhead.
- **How:**
  - For local development, set the debugger to manual trigger by default (trigger mode), enabled only when an HTTP header carries the designated trigger key or an environment variable is passed on the command line.
  - When running batch or parallel tests, always turn debug mode off explicitly via an environment variable.

## Same-origin reverse proxy route allowlist not updated

- **Symptom:** When the frontend calls a new same-origin API endpoint (e.g. `/api/v2/items`), it intermittently gets 404 or 405, or the SPA's index.html comes back instead.
- **Root cause:** Local environments usually forward `/api/*` through Nginx, Traefik or Caddy to avoid CORS. If a new endpoint's path pattern doesn't match an existing proxy rule, the request falls through to the frontend static file route.
- **How:** When adjusting reverse proxy rules, prefer generic route forwarding (e.g. `location /api/ { proxy_pass ... }`) over listing each subpath by hand; after every proxy config change, run the syntax test first (e.g. `nginx -t`), then reload.

## No Certificates in Images

- **Symptom:** After the project replaces its HTTPS certificate or rotates keys, newly released containers still present the old certificate; or a private key leaks permanently once the image is pushed to a public/shared registry.
- **Root cause:** The Dockerfile build stage used `COPY ./ssl /etc/ssl` to bake certificates and private keys into the image. Even if later instructions delete or overwrite them, the private key remains in the image's read-only history layers and is easy to recover by pulling those layers.
- **How:**
  - Always mount certificates and private keys at runtime as a read-only volume (e.g. Compose's `./ssl:/etc/ssl/private:ro`), or inject them dynamically at startup via K8s Secrets / AWS Secrets Manager.
  - Make sure `.dockerignore` and `.gitignore` include `*.pem`, `*.crt`, `*.key`, so they can't accidentally end up in a build or commit history.
