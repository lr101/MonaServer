# MonaServer admin web

This is the separate administrator web application. It is intentionally plain
HTML/CSS/JavaScript so it can be served as static files without Flutter, a
second application runtime, or a dependency install.

Serve `admin-web/` from the same origin as MonaServer, or configure the hosting
proxy so `/api` reaches the Go server. The browser uses the server's opaque
admin cookie and keeps CSRF state in memory only.

For a local static smoke check:

```sh
python3 -m http.server 4173 --directory admin-web
```

The production image is an nginx Alpine container. Build and run it locally
with:

```sh
docker build --tag monaserver-admin-web admin-web
docker run --rm --publish 8082:80 monaserver-admin-web
```

The image serves only the static application. Route `/api` to `go-server` at
the gateway or reverse proxy layer.

Pushes to `develop` and `main` publish the smoke-tested image to GitHub
Container Registry as `ghcr.io/lr101/stick-it-admin-web:<commit-sha>`. The
corresponding `:develop` and `:main` tags track the current branch head, so a
deployment can use `image: ghcr.io/lr101/stick-it-admin-web:develop` (or
`:main`) without building locally. Private packages require a registry login
with `read:packages` permission. Serve the app over HTTPS and route `/api/` to
the Go server on the same public origin; set the Go server's `ADMIN_ORIGIN` to
that exact origin.

The app includes session/MFA, users, reports and notes, campaign content
records, and audit views. Campaign saves only create or update content records;
they never schedule or deliver messages. Bulk audience actions, provider
delivery, and job execution are intentionally out of scope for this CRUD
release.

To create the first administrator, use a Go-only `.env.admin` file (not a
Compose env file shared with database or storage containers). Set
`ADMIN_BOOTSTRAP_USERNAME`, `ADMIN_BOOTSTRAP_PASSWORD` (8–256 UTF-8 bytes), and
`ADMIN_BOOTSTRAP_TOTP_SECRET` together. Generate a base32 authenticator seed
with `openssl rand 20 | base32 | tr -d '=\n'` and add that seed manually to an
authenticator app. The Go container also needs stable
`ADMIN_TOTP_ENCRYPTION_KEY` and `ADMIN_SESSION_HMAC_KEY` values. On first
startup, it creates the account and MFA membership; subsequent restarts do
not change the password or seed. Sign in with the configured username and
password, then enter the authenticator code. After setup, remove the three
bootstrap credentials from `.env.admin` and recreate the Go container. Do not
remove or rotate the encryption key: existing MFA secrets depend on it.

Alternatively, create a normal password-enabled account using the consumer
app, configure the Go container with `ADMIN_FIRST_RUN_TOKEN` (generate one with
`openssl rand -hex 32`), and choose **Set up first administrator** on the admin
login page. Save the displayed authenticator key, then remove the setup token.
Only one of these first-time paths can succeed: the database permanently
closes setup after the first enrollment, even if that administrator is later
deleted. There is no default admin account.
