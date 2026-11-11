# Rails 8 Multilingual AI Translation

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](README.vi.md)

[![CI](https://github.com/dangkhoa2016/Rails-8-Multilingual-AI-Translation/actions/workflows/ci.yml/badge.svg)](https://github.com/dangkhoa2016/Rails-8-Multilingual-AI-Translation/actions/workflows/ci.yml) ![Rails 8.1](https://img.shields.io/badge/Rails-8.1-red) ![Ruby 3.3](https://img.shields.io/badge/Ruby-3.3.8-red) ![MIT](https://img.shields.io/badge/License-MIT-blue)

Rails 8 application for administrative translation across independently hosted AI inference services. [Tiếng Việt](README.vi.md).

## Features

- Devise 5 + Warden administrator authentication, Pundit authorization, Rack::Attack and PostgreSQL/Solid Cache rate limiting; Tailwind and Hotwire UI.
- English / Vietnamese user interface via Rails I18n (source/target translation languages remain unrestricted).
- Light / dark / auto theme selection; auto follows the OS theme using CSS media queries.
- PostgreSQL-based login attempt throttling, session expiration, password-change invalidation and password reauthentication for sensitive settings and authenticated Turbo/Action Cable connections.
- Four initial catalog entries: Hy-MT2, Index-Translate, Gemma 4, Qwen3.5.
- Reusable provider connections: URL, protocol and Active Record encrypted Bearer token.
- Historical model deployments, per-model translation dispatches, independent comparison cards.
- API adapters for the repository's asynchronous Translation Gateway v1 and optional OpenAI-compatible chat completions.
- Idempotency keys stored before network POST; no automatic retry after an uncertain paid request.
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

Example environment variable **names** are in `.env.example`. The application does not load `.env` by default, so export variables via the shell or a secret manager. Use distinct `DATABASE_URL`, `QUEUE_DATABASE_URL` and `CACHE_DATABASE_URL` in production. Never check secrets into Git.

### Configuration

Use the language selector (**English / Tiếng Việt**) and theme selector (**Light / Dark / Auto**) on the header, including the sign-in page. Preferences persist as signed HTTP-only cookies.

Go to `/login`; sign in with the admin account created by `db:seed`. Open `/admin/settings/inference` to create an enabled provider connection with a public HTTPS endpoint, protocol and Bearer token. Activate one connection and remote model identifier for each model in the catalog. Connections may be shared when several models really use the same gateway.

Gateway v1 supports up to 1,000 Unicode code points. Other adapters may use different limits; never equate provider name with protocol compatibility. A failed `UNSUPPORTED_LANGUAGE_PAIR` is only a model-reported signal.

**Costs:** Selecting 4 models can result in 4 paid model-runs. The browser asks for confirmation. Only an explicit new translation launches a provider POST. `Check catalog` uses GET but may still wake hosting resources.

**Admin protection:** Login limit is 12 attempts / 5 minutes per IP and 5 / 10 minutes per IP+account. Idle sessions expire after 30 minutes, with a 12-hour absolute maximum. Connection and model settings changes require password confirmation if the last authentication was over 10 minutes ago; you must resubmit the setting after verification. Initial admin password must have at least 14 characters. Re-running `db:seed` does not reset an existing admin password. See [Security and localization](docs/SECURITY_AND_LOCALIZATION.md) ([Tiếng Việt](docs/SECURITY_AND_LOCALIZATION.vi.md)).

### Tests

```bash
RAILS_ENV=test bin/rails db:prepare
bin/rails test
```

No live credentials or GPU calls in CI. The suite covering UI preferences, authorization, session expiration, PostgreSQL-backed throttling, inference contracts and security has been executed on Ruby 3.3.8, Rails 8.1.4.1 and PostgreSQL 16: **28 tests, 205 assertions, 0 failures, 0 errors**. The Tailwind build and Zeitwerk checks also passed. Integration tests require separate explicit configuration and approval.

### Current implementation scope

Implemented: application structure, admin authentication, database, encrypted connections, model deployment revisions, basic adapters, single-model dispatch per endpoint, safe polling, comparison UI, history, bilingual views, light/dark/auto themes, access hardening and mocked tests. Deferred: benchmark group-submit optimization, full operational reconciliation UI, interactive attempt management, provider-specific adapters beyond the supported contracts, and live acceptance testing. Rails boot, migrations, tests and assets are runtime-verified; production use still requires live provider acceptance and an independent security and operations review.

### Related inference project

[Multilingual Translation AI Inference](https://github.com/dangkhoa2016/Multilingual-Translation-AI-Inference). This Rails workspace uses HTTP only; it does not copy or run the GGUF models.

## License

MIT — © Đăng Khoa <i.am@dangkhoa.dev>. The models, inference service and external APIs retain their own licenses.
