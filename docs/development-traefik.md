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
rule syntax and assumes the outer Traefik has a DNS-01 ACME resolver named
`letsencrypt-dns`:

```yaml
labels:
  - traefik.enable=true
  - traefik.http.routers.dev-worktrees.rule=HostRegexp(`^((api|web|storage|console)-[a-z0-9-]+)\.dev\.dell\.lr-projects\.de$`)
  - traefik.http.routers.dev-worktrees.entrypoints=websecure
  - traefik.http.routers.dev-worktrees.tls=true
  - traefik.http.routers.dev-worktrees.tls.certresolver=letsencrypt-dns
  - traefik.http.routers.dev-worktrees.tls.domains[0].main=dev.dell.lr-projects.de
  - "traefik.http.routers.dev-worktrees.tls.domains[0].sans=*.dev.dell.lr-projects.de"
  - traefik.http.routers.dev-worktrees.service=dev-worktrees
  - traefik.http.services.dev-worktrees.loadbalancer.server.port=18080
```

`tls=true` only enables TLS termination; it does not create a certificate.
The resolver name in the label must exactly match a resolver in Traefik's
static configuration. For example, the resolver above needs an outer
Traefik configuration similar to this, with the DNS provider's credentials
passed through the provider-specific environment variables:

```yaml
certificatesResolvers:
  letsencrypt-dns:
    acme:
      email: ops@example.invalid
      storage: /letsencrypt/acme.json
      dnsChallenge:
        provider: <your-dns-provider>
```

The wildcard certificate must be issued with a DNS-01 challenge. If only the
generated subdomains are needed and `dev.dell.lr-projects.de` itself has no
DNS record, use the wildcard as the main domain and omit the apex SAN:

```yaml
- traefik.http.routers.dev-worktrees.tls.domains[0].main=*.dev.dell.lr-projects.de
```

If the outer Traefik already has a wildcard certificate managed outside ACME,
load its certificate and key through Traefik's file provider instead. Labels
cannot load certificate files. The certificate must be in the global
`default` TLS store and contain `*.dev.dell.lr-projects.de`; a certificate for
`dev.dell.lr-projects.de` alone does not cover the generated hostnames.

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
      tls:
        certResolver: letsencrypt-dns
        domains:
          - main: dev.dell.lr-projects.de
            sans:
              - '*.dev.dell.lr-projects.de'
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
