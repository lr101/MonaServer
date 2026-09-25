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

The root [`compose.yaml`](../compose.yaml) packages this admin UI with the
Go API and Flutter web app. Its admin listener is routed only through a private Traefik entrypoint at
`admin.thinkpad.lr-project.de`, also binds to host loopback on port 8082,
and proxies `/api/v3/admin/` internally. See
[`docs/DEPLOYMENT.md`](../docs/DEPLOYMENT.md) for deployment and private access. The standalone `admin-web/Dockerfile` remains available for
independent image builds.

The app includes session/MFA, users, reports and notes, campaign content
records, and audit views. MFA is checked at sign-in for the authenticated
session; the web app does not ask for a second code during that session.
Administrators with `users.verify` can mark a user's email as verified from
the account detail page. Verification requires that the email claim be
available and writes an audit event.
The user detail actions also let operators with `security.recovery_resend`
send a password recovery link to a verified, owned email address. The admin
endpoint requires CSRF and recent MFA and records an audit event; the current
password remains active until the user completes recovery. Eligible users can
also receive a one-time 24-hour login link from this page.
The campaign channel selector offers Email, Push, and Login. Email and Push
campaigns save content records only. Selecting Login opens an immediate bulk
send flow: it finds non-deleted accounts with verified email and active
sign-in eligibility, including administrator accounts, shows the recipient
count, and queues a one-time sign-in link valid for 24 hours to each account.
The message is system-generated. Partial failures can be retried from the same
screen. Enable `PUBLIC_EMAIL_LOGIN` and configure its delivery key and email
provider on the Go server before using login links. The admin bulk delivery
worker remains disabled.

To create the first administrator in the combined deployment, use the
ignored root `.env` file. Set
`ADMIN_BOOTSTRAP_USERNAME`, `ADMIN_BOOTSTRAP_PASSWORD` (8–256 UTF-8 bytes), and
`ADMIN_BOOTSTRAP_TOTP_SECRET` together. Generate a base32 authenticator seed
with `openssl rand 20 | base32 | tr -d '=\n'` and add that seed manually to an
authenticator app. The Go container also needs stable
`ADMIN_TOTP_ENCRYPTION_KEY` and `ADMIN_SESSION_HMAC_KEY` values. On first
startup, it creates the account and MFA membership; subsequent restarts do
not change the password or seed. Sign in with the configured username and
password, then enter the authenticator code. After startup creates the account,
remove the three bootstrap credentials from `.env` and recreate the app
container. Do not remove or rotate the encryption key: existing MFA secrets
depend on it.

There is no default admin account. The admin login page is available after the
configured environment bootstrap creates the first administrator.
