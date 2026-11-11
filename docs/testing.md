# Testing and verification

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](testing.vi.md)

## CPU-only local checks

~~~bash
bundle install
RAILS_ENV=test bin/rails db:prepare
RAILS_ENV=test bin/rails test
RAILS_ENV=test bin/rails zeitwerk:check
RAILS_ENV=test bin/rails tailwindcss:build
python3 scripts/validate_repository_docs.py
~~~

The tests use PostgreSQL and mocked HTTP; no provider token or GPU is required. The end-to-end integration suite exercises HTTP controller submission through real Rails adapters, dispatch jobs, read-only polling, history, exports, glossary snapshots, idempotency, provider errors and safe recovery. These tests never make a real provider request.

For an independent clean-database acceptance run, provision three **new test-only PostgreSQL databases** for application, queue and cache, and set their respective `DATABASE_URL`, `QUEUE_DATABASE_URL` and `CACHE_DATABASE_URL` in `RAILS_ENV=test` before running `bin/rails db:prepare` and `bin/rails test`. Do not aim this command at an existing production database. Fresh test databases verify migrations and first-run configuration without requiring backup/restore or live inference.

## Browser acceptance (Chromium / Firefox / WebKit)

For an **isolated local development preview with a disposable administrator**, install Playwright and its browser separately from the Rails bundle:

~~~bash
python3 -m pip install playwright
python3 -m playwright install --with-deps chromium firefox webkit
~~~

Start Rails on localhost (for example, `bin/rails server -b 127.0.0.1 -p 3108`), then supply the disposable admin's credentials **through environment variables, not in source code or logs**:

~~~bash
BROWSER_BASE_URL=http://127.0.0.1:3108 \\
BROWSER_ADMIN_EMAIL=browser-test@example.test \\
BROWSER_ADMIN_PASSWORD='<disposable-local-password>' \\
for engine in chromium firefox webkit; do
  BROWSER_ENGINE="$engine" python3 scripts/browser_acceptance.py
done
~~~

The script refuses non-local URLs. It checks authentication, anonymous access denial, session cookie attributes, theme and locale persistence (including unsent drafts), escaped glossary CRUD, Help Center, History, mobile keyboard navigation, CSP, CSRF and absence of client-side inference POSTs. It creates and deletes a uniquely tagged glossary entry, so use a **disposable test database**. If a run is interrupted, the script prints the fixture tag for manual cleanup. Its POSTs are limited to login, preferences, glossary CRUD and a deliberately rejected CSRF probe — it never submits a translation job. The browser check is optional and runs separately from default `bin/rails test` / CI. The manual GitHub Actions workflow `.github/workflows/browser_acceptance.yml` provisions clean disposable databases, generates temporary credentials and runs all three engines when explicitly dispatched. Chromium, Firefox and WebKit have also been verified locally. The script checks for horizontal overflow at 320, 375, 390 and 768 pixels.

## Covered workflows

The existing test suite exercises admin login, wrong-password handling, SQL-backed throttling, session expiry, password reauthentication, Pundit authorization, provider adapter contracts, request idempotency and user interface preferences.

## Additional acceptance

To qualify a deployment, independently verify production-grade proxy/IP handling, HTTPS, database backups, queue workers, browser CSRF/CSP behavior, outbound endpoint controls, token rotation, provider-specific languages and live inference behavior. Live inference can incur costs and is outside normal CI.

## Evidence boundaries

CI success shows that deterministic checks passed on a specific commit; it does not establish model accuracy, uptime or readiness of an external hosting provider. Record exact commit SHA and environment when reporting issues.
