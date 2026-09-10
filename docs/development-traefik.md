# Development worktree routing

The native development stack has one stable ingress point per dev container:
the nginx gateway listens on `0.0.0.0:18080`. Each worktree starts
its API and RustFS listeners on random loopback ports, then writes one temporary
nginx snippet containing the four host routes:

```text
api-<slug>.dev.dell.lr-projects.de       -> local Go API
web-<slug>.dev.dell.lr-projects.de       -> local Flutter build
storage-<slug>.dev.dell.lr-projects.de   -> local RustFS S3 API
console-<slug>.dev.dell.lr-projects.de   -> local RustFS console
```

The snippets are generated and removed by
`scripts/dev/start-nginx-worktree.sh`. They are runtime state, not checked-in
configuration. Nginx reloads atomically after a worktree is added or removed,
so multiple worktrees can stay active through the same gateway at the same
time. A dynamic nginx config is still needed for the host-to-random-port
registry; generating a small snippet is safer and simpler than embedding a
custom Lua/OpenResty router or exposing every backend port to Traefik.

## Outer Traefik

Wildcard DNS should point `*.dev.dell.lr-projects.de` at the outer Traefik
instance, and its certificate should cover that wildcard. Traefik needs one
service pointing to the dev container's nginx port. It must not point at the
random API or RustFS ports.

For a Docker-provider setup where the outer Traefik can see the dev container,
these are the labels to put on that container. This example uses Traefik v3
rule syntax:

```yaml
labels:
  - traefik.enable=true
  - traefik.http.routers.dev-worktrees.rule=HostRegexp(`^((api|web|storage|console)-[a-z0-9-]+)\.dev\.dell\.lr-projects\.de$`)
  - traefik.http.routers.dev-worktrees.entrypoints=websecure
  - traefik.http.routers.dev-worktrees.tls=true
  - traefik.http.routers.dev-worktrees.service=dev-worktrees
  - traefik.http.services.dev-worktrees.loadbalancer.server.port=18080
```

If the outer Traefik uses the v2 named-capture rule syntax, use this router
rule instead:

```yaml
- traefik.http.routers.dev-worktrees.rule=HostRegexp(`{subdomain:(api|web|storage|console)-[a-z0-9-]+}.dev.dell.lr-projects.de`)
```

When Traefik cannot discover the container through Docker, configure the same
router and a load-balancer server through its file provider. Replace the
address with the reachable address of the dev container layer:

```yaml
http:
  routers:
    dev-worktrees:
      rule: "HostRegexp(`^((api|web|storage|console)-[a-z0-9-]+)\\.dev\\.dell\\.lr-projects\\.de$`)"
      entryPoints:
        - websecure
      tls: {}
      service: dev-worktrees
  services:
    dev-worktrees:
      loadBalancer:
        servers:
          - url: http://DEV_CONTAINER_REACHABLE_ADDRESS:18080
```

The nginx gateway preserves the public host and forwarded scheme for the API,
proxies S3 traffic and CORS to RustFS, and serves Flutter's generated static
files with an SPA fallback. Flutter is built with
`--dart-define=API_HOST=https://api-<slug>.dev.dell.lr-projects.de`, so the
browser never receives a loopback or random backend URL. RustFS remains HTTP
inside the container; the Go server uses `RUSTFS_EXTERNAL_USE_SSL=true` when
Traefik publishes HTTPS URLs for presigned objects.

## Start a worktree

After native PostgreSQL, RustFS, and `.env.dev` are ready:

```bash
DEV_SLUG=feature-a \
  /root/.codex/skills/serve-dev-worktree/scripts/start_stack.sh \
  --repo-root /absolute/path/to/MonaServer
```

The helper is foreground-oriented and stops at most 24 hours later. Set
`DEV_STACK_MAX_SECONDS` to a shorter value when appropriate. The default shared
nginx runtime is under `${XDG_RUNTIME_DIR:-/tmp}/serve-dev-worktree/nginx`;
use `DEV_NGINX_RUNTIME_DIR` and `DEV_PORT_STATE_DIR` to choose another shared
location when several dev containers do not share that runtime directory.
