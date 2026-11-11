# Security model

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](security.vi.md)

## Identity and access

Devise/Warden authenticates an administrator using encrypted password hashes. Public sign-up is disabled. Pundit and server-side role checks gate privileged actions; individual translation records are scoped to their creator. Sensitive settings updates require recent password verification.

Browser sessions are signed/encrypted and have idle and absolute time limits. Password changes invalidate prior session fingerprints. Interface locale/theme cookies are separate from credentials.

## Request throttling

Rack::Attack provides middleware-level limits; a PostgreSQL `LoginThrottle` additionally enforces atomic login and admin-operation limits across processes. In production, Solid Cache must be backed by a shared cache database, not per-worker memory. Reverse-proxy configuration must prevent spoofed client IP addresses.

## Provider secrets and network

Bearer tokens use Active Record Encryption. Do not expose tokens in logs, errors, templates, CI artifacts or browser JavaScript. Endpoint validation rejects internal or non-public destinations. Defense in depth still requires network-level egress policy, trusted DNS/proxy infrastructure and TLS termination.

## Production configuration and secrets

In `RAILS_ENV=production`, the app fails early unless `SECRET_KEY_BASE`, all three Active Record Encryption variables, and `DATABASE_URL`, `QUEUE_DATABASE_URL`, `CACHE_DATABASE_URL` are present. Encryption keys must be long enough and distinct; the three PostgreSQL URLs must identify separate database locations, preventing queue/cache tables from accidentally sharing the primary database. Error messages contain variable names only, never secrets or connection-string values.

Do not place secrets in Git, workflows or browser-visible HTML. When deploying behind a reverse proxy, terminate TLS at a trusted edge, reject direct untrusted traffic to Rails and sanitize incoming forwarded headers. `assume_ssl` and `force_ssl` are enabled in production; session cookies use Secure/HttpOnly/SameSite=Lax. Endpoint SSRF prevention includes hostname checks, public-IP DNS validation, IP-pinned TLS connections and redirect refusal; a network egress firewall remains necessary defense in depth.

Rails parameter filtering also redacts glossary source/target terms, private notes, snapshots, translation text, provider responses and request keys to avoid leaking them in request logs. Ensure external error reporting and server logs also respect these filters.

## Browser controls and CSP

The application enforces CSRF tokens for state-changing requests; uses HttpOnly, SameSite=Lax session cookies; scopes private resources to authenticated administrators; and serves private pages with no-store caching. CSP disallows `unsafe-inline` and `unsafe-eval`, and blocks framing. Turbo's fixed progress-bar stylesheet is allowlisted by its exact SHA-256 hash, **not** by relaxing `style-src` to unsafe-inline. Recheck the hash after a Turbo upgrade. See the [optional Playwright browser acceptance](testing.md#browser-acceptance-chromium--playwright), which verifies these controls and safe rendering of untrusted glossary terms without invoking inference.

## Reporting

For suspected vulnerabilities, use the private reporting channel described in [GitHub Security Policy](../.github/SECURITY.md). Never open a public issue containing exploit details or secrets.

## Residual risk

MFA, comprehensive security analytics, browser-based penetration testing, and deployment-specific operational verification are not implied by the current automated test suite. See [Security and localization](SECURITY_AND_LOCALIZATION.md) and [Implementation status](IMPLEMENTATION_STATUS.md).
