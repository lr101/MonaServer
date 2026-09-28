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

The app includes session/MFA, users, reports and notes, email and push campaign
templates, and audit views. MFA is checked at sign-in for the authenticated
session; the web app does not ask for a second code during that session.
Administrators with `users.verify` can mark a user's email as verified from
the account detail page. Verification requires that the email claim be
available and writes an audit event.
The user detail actions also let operators with `security.recovery_resend`
send a password recovery link to a verified, owned email address. The admin
endpoint requires CSRF and recent MFA and records an audit event; the current
password remains active until the user completes recovery. Eligible users can
also receive a one-time 24-hour login link from this page.
Email campaigns are personalized login email templates. Their subject and
message can use `{{username}}`, `{{email}}`, `{{login_code}}`,
`{{login_link}}`, `{{expires_in}}`, and `{{app_name}}`; the mustard variable
guide inserts them at the cursor, and the preview shows a sample recipient.
The message must include both `{{login_code}}` and `{{login_link}}`. Templates
are plain text: variable values are escaped for HTML email, the code is
rendered as text, and the login link is rendered as a safe sign-in link. Saving a
campaign as **Active · ready to send** enables the **Send login email
campaign** action. It finds non-deleted accounts with verified email and
active sign-in eligibility, including administrator accounts, then issues a
unique one-time link that expires after 24 hours. Eligibility and email
ownership are rechecked for every account. The campaign view reports queued,
failed, and processed counts while sending; progress is saved in the current
browser and partial failures can be resumed. Retries reuse the same send ID,
so recipients already queued by the server are not queued twice. Every
recipient request is bound to the campaign revision; if the campaign is
edited or archived during a send, remaining requests are rejected until the
campaign is made active again.
Push campaigns remain content records. Enable `PUBLIC_EMAIL_LOGIN` and
configure its delivery key and email provider on the Go server before sending
login emails. The separate admin bulk delivery worker remains disabled.

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
