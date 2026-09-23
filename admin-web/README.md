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

For first-time setup, create a normal password-enabled account using the
consumer app, then configure the Go container with `ADMIN_FIRST_RUN_TOKEN`
(generate a unique value with `openssl rand -hex 32`). At the admin login page,
choose **Set up first administrator** and enter that account's username and
password plus the deployment secret. Save the displayed TOTP key in an
authenticator app before leaving the page; it is shown only once. Thereafter,
sign in with the same username, password, and authenticator code. Remove
`ADMIN_FIRST_RUN_TOKEN` from the Go container environment and recreate the
container once setup succeeds. The database permanently closes first-time
setup after enrollment, including if the first administrator is later deleted.
There is no default admin account.
