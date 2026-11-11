# Localization, themes and access controls

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](SECURITY_AND_LOCALIZATION.vi.md)

## UI languages

The admin UI supports **English (`en`)** and **Vietnamese (`vi`)** through Rails I18n files at `config/locales/en.yml` and `config/locales/vi.yml`. This is independent of the source/target languages accepted by translation models. Locale choice is written to a signed, HTTP-only cookie (`ui_locale`), with an allowlist of `en` and `vi` and a one-year expiration. `I18n.with_locale` scopes each request to avoid cross-request leakage. The language in use when creating a translation is persisted as `translation_requests.ui_locale` so asynchronous Turbo broadcasts render their model cards in the same language. If the admin switches locale while a run is in progress, reloading the session shows the new interface locale; the in-flight broadcast continues with the request’s original locale.

## Light / dark / auto

Theme selection is `light`, `dark` or `auto` via a signed, HTTP-only cookie (`ui_theme`), also expiring in one year. All views use semantic CSS variables in the Tailwind stylesheet; `auto` follows `prefers-color-scheme` and updates on OS theme changes. The browser does not need client-side theme storage, external assets or inline scripting.

## Admin authentication and authorization

- Only users with role `admin` may access translation data, model settings, deploy credentials or run jobs.
- Two PostgreSQL-backed login throttles: IP 12 attempts / 5 minutes, and IP+normalized email 5 attempts / 10 minutes. Their keys are HMAC digests using Rails' secret key base. There is no per-account *global* lockout that an attacker can abuse to lock an administrator from every IP.
- Login errors are generic. An unknown email goes through dummy bcrypt verification to minimize account enumeration differences.
- Reauthentication is required for all sensitive settings writes (connections, deployments, model availability and connection probes). Reauth is limited to 5 attempts per 10 minutes per IP+user, and a successful verification permits changes for 10 minutes.
- Per-admin translation requests are limited to 8/minute; status refresh is limited to 12/minute; settings changes to 20/10 minutes and catalog probes to 4/minute. Counters are shared across processes in PostgreSQL.
- Sessions expire after 30 minutes without activity or 12 hours since sign-in, whichever happens first. Changing a user's `encrypted_password` invalidates old signed-in sessions (fingerprint stored in encrypted session cookie).
- Action Cable handshakes also validate the encrypted cookie, admin role, session expiry and password fingerprint before accepting Turbo stream subscriptions. Long-lived WebSockets and cross-process logout revocation still need a production architecture test.
- Cookie session: `Secure` in production, `HttpOnly`, `SameSite=Lax`. Sessions are rotated at login and reauthentication, cleared at logout. State-changing actions require Rails CSRF protection.
- Cache-Control `no-store, private` for sensitive HTML responses. CSP restricts scripts and styles to self, with session-bound nonce to support Rails importmap and Turbo. No `unsafe-inline` or `unsafe-eval`.
- Model tokens remain encrypted through Active Record Encryption and are never embedded in HTML, JavaScript, audit history or logs.

## Operational cautions

1. Configure a correct HTTPS reverse-proxy and trusted proxy chain before production so `request.remote_ip` cannot be forged through untrusted forwarded headers. Do not expose the app server directly if it trusts an ingress proxy.
2. Run `bin/rails security:prune_login_throttles` periodically via an operations scheduler to remove expired counter rows (counters are otherwise purged lazily only on reuse).
3. Throttling and short sessions reduce risk but are **not** MFA, infrastructure DDoS protection, IP reputation screening, security monitoring or a substitute for endpoint ACLs. Consider MFA for production admin accounts.
4. CSP + importmap behavior, database concurrency, session rotation, migrations, views and HTTP integration require a full Rails runtime test before production deployment.
5. Do not check live provider connectivity without explicit approval: a non-inference probe can still wake remote compute and incur charges.
