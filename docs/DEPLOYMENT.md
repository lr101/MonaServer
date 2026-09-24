# Compose deployment

The root `compose.yaml` builds the Go API, Flutter web app, and admin web app
into one image. The Go API listens internally on port 8080, the public UI on
8081, the loopback admin UI on 8082, and the private Traefik admin UI on 8083.
PostGIS and RustFS remain separate stateful containers.
Traefik routes port 8081 publicly at `app.lr-projects.de` and port 8083 only
through its private entrypoint at `admin.thinkpad.lr-project.de`. The Go
listener is never published. A second admin web listener binds to host
loopback at `127.0.0.1:8082` for local access. Both admin listeners proxy
only `/api/v3/admin/` to the internal Go listener. The private listener
preserves Traefik's sanitized client IP chain for admin quotas and audit logs;
the loopback listener discards caller-supplied forwarding headers. Admin API
CORS allows credentialed requests from any origin, so keep the private admin
listener restricted to the trusted network. The public web listener proxies
consumer `/api/` requests, rejects admin API paths, and serves signed object
downloads at `/monaserver/` on the same public origin.

1. Create a Docker network shared with your existing Traefik instance:
   `docker network create traefik` (skip if it already exists). Set
   `TRAEFIK_NETWORK` if its name differs. Traefik needs its Docker provider,
   a public `websecure` entrypoint and a separate `websecure-internal`
   entrypoint bound only to the ThinkPad/private network. Configure TLS
   certificates for both hostnames. Private DNS alone is insufficient to
   restrict access to the admin router. Keep
   Traefik's default forwarding-header trust policy, so untrusted clients
   cannot supply their own `X-Forwarded-For`. The app trusts only its local
   nginx proxy when interpreting that header.
2. Copy `.env.example` to `.env`, replace every example credential, and set
   `WEB_HOST` to the public HTTPS hostname. Keep `.env` private and back it up
   with the database and RustFS volumes. Use URL-safe characters in the
   database password because it appears in `DATABASE_URL`. Set that variable
   to the address of your PostGIS service; the image uses it as supplied. When
   unset, it builds a URL for the bundled `db` service. Both services and the
   app read values from the ignored `.env` file. Compose derives the email
   login callback as `https://${WEB_HOST}/#/email-login/callback`, so email
   links use the same public hostname as the consumer web app.
3. Run `docker compose pull app db rustfs` followed by
   `docker compose up -d --wait`. CI publishes the combined app image to
   `ghcr.io/lr101/monaserver-app:develop`; set `APP_IMAGE` to an exact commit
   tag when a fixed release is needed. To build locally, run
   `docker compose up --build -d --wait`. The first local build downloads the
   pinned Flutter SDK and compiles the Wasm and JavaScript web variants.
4. Open `https://app.lr-projects.de` publicly and
   `https://admin.thinkpad.lr-project.de` on the private network. The local
   loopback port remains available for troubleshooting.

Set `DATABASE_URL` in `.env` to use a PostGIS service outside this Compose
project; the image honors an explicit URL and only builds a URL for the bundled
`db` service when it is unset. The server creates the `monaserver` bucket and
applies migrations at startup.
Presigned image URLs use `https://WEB_HOST/monaserver/...`; the proxy preserves
the signed Host and path. The public object route permits GET and HEAD only.
The API needs the RustFS credentials from `.env`; the RustFS container receives
only its own keys. Admin bootstrap secrets can be placed in `.env` temporarily
and removed after enrollment. Keep the admin encryption and HMAC keys stable.

For upgrades, run `docker compose pull` and `docker compose up -d --wait`.
Back up both named volumes before replacing the image. Do not run
`docker compose down -v` on a live deployment.
