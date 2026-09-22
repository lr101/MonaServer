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

The app currently includes the session shell and bounded read projections. The
remaining feature work is tracked in
[`docs/plans/web-admin-and-email-login.md`](../docs/plans/web-admin-and-email-login.md).
