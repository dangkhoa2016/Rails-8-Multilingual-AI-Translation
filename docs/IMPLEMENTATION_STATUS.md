# Implementation and validation status

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](IMPLEMENTATION_STATUS.vi.md)

This repository provides the Rails 8 Multilingual AI Translation application, including Devise/Warden authentication, Rack::Attack and Pundit, Security Center, English/Vietnamese localization, light/dark/auto appearance, independent provider connections, encrypted tokens, and per-model translation dispatches.

## Runtime verification

Verified on Ruby **3.3.8**, Rails **8.1.4.1**, and PostgreSQL **16**:

- `bundle install` and Rails boot completed successfully.
- `bin/rails db:prepare` applied the primary and Solid Queue database migrations.
- `bin/rails test`: **114 tests, 1490 assertions, zero failures, zero errors, zero skips**.
- `bin/rails zeitwerk:check`: passed.
- `bin/rails tailwindcss:build`: passed.
- No live inference, GPU calls, or provider credentials were used during testing.

The Minitest suite covers UI preferences, session timeouts, login throttling, administrator authorization, reauthentication, endpoint safety, provider adapters and local idempotency. CSRF protection remains active in production; the test environment disables browser-token enforcement for request simulations.

## Implemented functionality

- Rails 8.1, PostgreSQL, Solid Queue, Tailwind CSS, Turbo and Stimulus.
- English/Vietnamese UI and light/dark/auto themes.
- Admin-only access, HMAC-keyed PostgreSQL login rate limits, signed session cookies, reauthentication, and authenticated Action Cable.
- Four model catalog records, reusable provider connections and encrypted Bearer credentials.
- Versioned deployment records, provider adapters and safe outbound HTTPS checks.
- Cost acknowledgment, per-model dispatches, independent result cards, copy/favorite actions, and read-only status polling.
- Request/dispatch idempotency and explicit uncertain states rather than automatic paid POST retries.
- Bounded recurring CPU-side reconciliation of stale submissions, with optional read-only polling recovery and no automatic paid inference replay; verified with four-model end-to-end tests on three fresh PostgreSQL databases.
- Paginated, filtered history with owner-only TXT/Markdown/JSON export.
- Encrypted, per-administrator terminology glossary; optional OpenAI-compatible guidance with a bounded, immutable snapshot and pre-dispatch adapter validation. Translation Gateway v1 contract is unchanged.
- English/Vietnamese Help Center covering safe use, limits, privacy, exports and uncertainty.
- Chromium, Firefox and WebKit browser acceptance for real JavaScript, preferences, glossary escaping, viewport widths 320–768 px, mobile navigation, CSRF and strict CSP; optional manual GitHub Actions browser workflow. Production fail-fast configuration validates secret/key length, distinct encryption keys and separate PostgreSQL URLs; private glossary terms/notes are excluded from request logs. Verified with three fresh PostgreSQL databases and fresh test-only keys.

## Outstanding before production

- Live inference acceptance against each configured provider, with explicit approval of potential charges.
- Independent external deployment security/penetration review and realistic reverse-proxy/TLS validation (local Chromium, Firefox and WebKit acceptance has passed).
- Production worker restart/failover drills and manual provider-side reconciliation of uncertain paid jobs (CPU-only recovery logic has been tested).
- Egress restrictions, proxy trust/real-client-IP policy, SSL termination, secret rotation, and operational monitoring.
- Optional benchmark grouping and expanded provider-specific adapters.

This is a runtime-tested application foundation, **not a production security certification**. Keep provider credentials and Rails encryption keys out of source control.
