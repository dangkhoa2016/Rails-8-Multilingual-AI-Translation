# Rails 8 Multilingual AI Translation

[![CI](https://github.com/dangkhoa2016/Rails-8-Multilingual-AI-Translation/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/dangkhoa2016/Rails-8-Multilingual-AI-Translation/actions/workflows/ci.yml)
![Rails](https://img.shields.io/badge/Rails-8.1-CC0000)
![Ruby](https://img.shields.io/badge/Ruby-3.3.8-CC342D)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-336791)
![Devise](https://img.shields.io/badge/Auth-Devise%205-425EAA)
![Security](https://img.shields.io/badge/Security-Rack%3A%3AAttack%20%2B%20Pundit-4C9977)
![Language](https://img.shields.io/badge/Docs-EN%20%2F%20VI-2B76C4)
![License](https://img.shields.io/badge/License-MIT-blue)

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](README.vi.md)

Rails 8 administrative platform for comparing translations from independently deployed AI model endpoints. Provider credentials are configurable per model; this application does not host the models itself.

## Features

- Devise 5 + Warden administrator authentication, Pundit authorization, Rack::Attack and PostgreSQL/Solid Cache rate limiting; Tailwind and Hotwire UI.
- English / Vietnamese user interface via Rails I18n (source/target translation languages remain unrestricted).
- Dashboard with database-only activity statistics and model configuration guidance; responsive navigation drawer, collapsible sidebar, breadcrumbs, custom SVG icons, and light / dark / auto themes.
- Translation Studio with free-form language labels, language swap, Unicode character counter, protocol-aware length cautions, and 1–4 model selection. Comparison offers responsive 2-/4-column layouts and optional line-level differences without additional inference requests.
- PostgreSQL-based login attempt throttling, session expiration, password-change invalidation and password reauthentication for sensitive settings and authenticated Turbo/Action Cable connections.
- Four initial catalog entries: Hy-MT2, Index-Translate, Gemma 4, Qwen3.5.
- Reusable provider connections: URL, protocol and Active Record encrypted Bearer token.
- Historical model deployments, per-model translation dispatches, independent comparison cards.
- Paginated history with account-scoped filters for language labels, session UUID, status and date range. Export saved sessions as TXT, Markdown or allowlisted JSON without provider calls; source and result text remain private to the authorized account.
- Per-administrator terminology glossary with encrypted term pairs and notes, active/inactive entries, bilingual management and opt-in translation guidance for OpenAI-compatible chat endpoints. Matching terms are frozen in an encrypted snapshot before dispatch; Gateway v1 does not support this feature.
- Built-in bilingual Help Center covering translation limits, glossary matching, snapshot safety, privacy, downloads and uncertain paid requests.
- Reproducible browser acceptance in **Chromium, Firefox and WebKit**, including EN/VI draft-preserving preferences, responsive navigation at 320–768 px, glossary CRUD/XSS, CSRF and strict CSP. A manually dispatched GitHub Actions workflow runs all three engines on disposable databases, without inference. See [testing guide](docs/testing.md).
- API adapters for the repository's asynchronous Translation Gateway v1 and optional OpenAI-compatible chat completions.
- Idempotency keys stored before network POST; no automatic retry after an uncertain paid request.
- Solid Queue recurring reconciliation marks stale `submitting` dispatches as uncertain without re-posting; stale accepted polls may resume through GET only after explicit `TRANSLATION_RECOVERY_POLLING_ENABLED=1` opt-in (GET may wake hosting). CPU-only end-to-end tests cover full four-model translation flow and clean PostgreSQL initialization.
- SSRF defenses: HTTPS-only port 443, public DNS resolution on save and before requests, pinned destination IP, TLS verification, no redirects and bounded response size.
- Background status polling by GET, no paid POST while opening history/settings/translation result pages.

## Requirements

Ruby 3.3+, Rails 8.1 dependencies, PostgreSQL 15+, a running Solid Queue worker. No GPU is necessary to run the Rails app itself.

## First-time setup

```bash
bundle install
# Create PostgreSQL databases and configure DB connection in your local environment.
bin/rails db:encryption:init  # generate your own application encryption keys; never commit them
# Export AR_ENCRYPTION_PRIMARY_KEY, AR_ENCRYPTION_DETERMINISTIC_KEY, AR_ENCRYPTION_KEY_DERIVATION_SALT
# Export ADMIN_EMAIL and ADMIN_PASSWORD only for seed/bootstrap
bin/setup
bin/rails server
# In another terminal:
bin/jobs start
```

Example environment variable **names** are in `.env.example`. The application does not load `.env` by default, so export variables via the shell or a secret manager. Production startup requires `SECRET_KEY_BASE`, three distinct Active Record Encryption keys, and distinct PostgreSQL `DATABASE_URL`, `QUEUE_DATABASE_URL`, `CACHE_DATABASE_URL`; missing, short or conflicting configuration fails fast. Never check secrets into Git.

### Configuration

Use the language selector (**English / Tiếng Việt**) and theme selector (**Light / Dark / Auto**) on the header, including the sign-in page. Preferences persist as signed HTTP-only cookies.

Go to `/login`; sign in with the admin account created by `db:seed`. Open `/admin/settings/inference` to create an enabled provider connection with a public HTTPS endpoint, protocol and Bearer token. Activate one connection and remote model identifier for each model in the catalog. Connections may be shared when several models really use the same gateway.

Gateway v1 supports up to 1,000 Unicode code points. Translation Studio shows known per-model limits and blocks a mixed-model submission if any configured selected adapter cannot accept the source length, before storing the request or scheduling paid inference. Other adapters may have different or unknown limits. Rails independently enforces a 20,000-code-point application safety cap; long input is not automatically split. Never equate provider name with protocol compatibility. A failed `UNSUPPORTED_LANGUAGE_PAIR` is only a model-reported signal.

**Costs:** Selecting 4 models can result in 4 paid model-runs. The browser asks for confirmation. Only an explicit new translation launches a provider POST. `Check catalog` uses GET but may still wake hosting resources.

**Admin protection:** Login limit is 12 attempts / 5 minutes per IP and 5 / 10 minutes per IP+account. Idle sessions expire after 30 minutes, with a 12-hour absolute maximum. Connection and model settings changes require password confirmation if the last authentication was over 10 minutes ago; you must resubmit the setting after verification. Initial admin password must have at least 14 characters. Re-running `db:seed` does not reset an existing admin password. See [Security and localization](docs/SECURITY_AND_LOCALIZATION.md) ([Tiếng Việt](docs/SECURITY_AND_LOCALIZATION.vi.md)).

### Tests

```bash
RAILS_ENV=test bin/rails db:prepare
bin/rails test
```

No live credentials or GPU calls in CI. The suite covering UI preferences, authorization, session expiration, PostgreSQL-backed throttling, inference contracts and security has been executed on Ruby 3.3.8, Rails 8.1.4.1 and PostgreSQL 16: **114 tests, 1490 assertions, 0 failures, 0 errors**. The Tailwind build and Zeitwerk checks also passed. Live inference acceptance requires separate explicit configuration and approval; the optional local browser acceptance does not call providers.

### Current implementation scope

Implemented: application structure, admin authentication, database, encrypted connections, model deployment revisions, basic adapters, single-model dispatch per endpoint, safe polling, comparison UI, history, opt-in encrypted glossary and Help Center, bilingual views, light/dark/auto themes, access hardening and mocked tests. Deferred: benchmark group-submit optimization, full operational reconciliation UI, interactive attempt management, provider-specific adapters beyond the supported contracts, and live acceptance testing. Rails boot, migrations, tests and assets are runtime-verified; production use still requires live provider acceptance and an independent security and operations review.

## Documentation

The guides follow the repository's English/Vietnamese documentation convention, with a language switch on every Markdown page:

- [Documentation index](docs/README.md) — navigate the full technical documentation.
- [Architecture](docs/architecture.md) — Rails, PostgreSQL, queues, adapters and trust boundaries.
- [Configuration](docs/configuration.md) — local setup, database URLs and provider connections.
- [Translation workflow](docs/translation-workflow.md) and [API integration](docs/api.md) — model dispatch, polling and idempotency.
- [Security](docs/security.md) and [Operations](docs/operations.md) — authentication, credentials and production safeguards.
- [Testing](docs/testing.md), [Limitations](docs/limitations.md), [Troubleshooting](docs/troubleshooting.md) and [Implementation status](docs/IMPLEMENTATION_STATUS.md).

Project resources: [Changelog](CHANGELOG.md) · [Contributing](.github/CONTRIBUTING.md) · [Security policy](.github/SECURITY.md) · [Support](.github/SUPPORT.md).

### Related inference project

[Multilingual Translation AI Inference](https://github.com/dangkhoa2016/Multilingual-Translation-AI-Inference). This Rails workspace uses HTTP only; it does not copy or run the GGUF models.

## License

MIT — © Đăng Khoa <i.am@dangkhoa.dev>. The models, inference service and external APIs retain their own licenses.
