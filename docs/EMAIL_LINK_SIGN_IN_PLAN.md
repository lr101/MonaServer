# Email-link sign-in integration plan

## Current state

Flutter has a web callback and a separate email-link request screen, but the request screen accepts only email. The password screen is provided by `flutter_login`, whose username field is dedicated to password login. The Go v3 public auth routes are feature gated and currently use an unavailable handler. Native Flutter has no email-link callback transport.

## Implementation sequence

1. Keep `FlutterLogin` for password, registration, and recovery. Keep its web email-link entry point and update the dedicated request screen to accept an email address or username. Use one generic success message and never display whether a username exists.
2. Preserve the existing `email` JSON property on `POST /api/v3/public/auth/email-link/request` for older clients. Add an optional `identifierType` field so the client can explicitly identify a username, including one shaped like an email address. Omission keeps the legacy email behavior. Resolve usernames to their owned, verified email on the server and apply the same address quota to email and username aliases, plus the existing IP quota.
3. Compose `EmailLogin`, durable delivery, and the public v3 handler in the Go runtime. Start an email-link delivery worker only when explicit keys and mail configuration are present. Keep `PUBLIC_EMAIL_LOGIN` off by default and fail closed on incomplete configuration. Leave restricted recovery completion unavailable until its delivery and client callback are implemented.
4. Exercise the request, generic response, delivery, callback exchange, and account switch flow with focused tests and local web validation. Enable the feature in a deployment only after configuring keys, callback URL, SMTP, and the flag.

## Native follow-up

The current callback parser and URL scrubber are browser specific. Native entry should stay hidden until Android App Links and iOS Universal Links can capture and scrub the token before routing, with platform link ownership configured for the deployed domain. The web flow can ship independently.

## Implementation status

The web request form, username resolution, v3 contract, production route composition, durable SMTP worker, and own-session cleanup are implemented in this change. Deployment still requires the documented environment variables and an SMTP service; the feature flag remains off by default. A live SMTP delivery and browser callback check remain before enabling the feature. Restricted recovery and native link capture are outstanding.
