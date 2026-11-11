# Configuration

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](configuration.vi.md)

## Requirements

- Ruby 3.3 or later and dependencies from `Gemfile.lock`.
- PostgreSQL 15 or later, with application, queue and cache databases.
- Rails 8.1, Solid Queue worker and network reachability to configured HTTPS inference endpoints.
- No GPU is needed for the Rails web server.

## Local bootstrap

~~~bash
bundle install
bin/rails db:encryption:init
# Export the three generated AR_ENCRYPTION_* values securely.
# Export ADMIN_EMAIL and a unique strong ADMIN_PASSWORD for initial seeding.
bin/setup
bin/rails server
~~~

Start `bin/jobs start` in a second terminal. The app does not automatically import `.env`; the file `.env.example` documents variable names only. Do not commit live credentials.

## Database layout

`DATABASE_URL` holds application data. `QUEUE_DATABASE_URL` is reserved for Solid Queue. `CACHE_DATABASE_URL` serves shared Solid Cache counters in production. Each URL must refer to an appropriately permissioned PostgreSQL database.

## Model/provider settings

After signing in at `/login`, open `/admin/settings/inference`. Create an enabled provider connection with protocol `translation_gateway_v1` or `openai_chat_completions` and an HTTPS base URL. Enter the Bearer token via the protected settings form. Assign an active deployment and a remote model identifier for each catalog model.

The provider label and adapter protocol are separate concepts: a Modal-hosted model may expose a different protocol than a Lightning.ai-hosted one. A model can be reassigned to another connection without deleting old deployment history.

## Production checklist

Run under HTTPS, set encryption keys through a secret manager, configure trusted proxy addresses, isolate PostgreSQL roles, keep a queue worker running, configure outbound egress restrictions and arrange backups. Read [Security](security.md) and [Operations](operations.md) before exposing the service publicly.
