# Operations guide

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](operations.vi.md)

## Services

Run the Rails web process (`bin/rails server`) and Solid Queue worker (`bin/jobs start`) as separately monitored processes. Configure `DATABASE_URL`, `QUEUE_DATABASE_URL` and `CACHE_DATABASE_URL` for primary, queue and cache PostgreSQL roles. Protect Active Record encryption keys and application secrets through a secure environment mechanism.

## Observability

Monitor HTTP status rates, job failures, queue age, PostgreSQL connectivity, authentication events and per-provider latency. Do not write translation source text, completed translations, Bearer tokens or secret keys into routine operational logs. Avoid excessive status polling, especially when hosts wake from sleep.

## Recovery

If a provider is unavailable, leave the affected dispatch in a visible failed or uncertain state. Before another paid attempt, reconcile the remote job ID and provider response. A worker restart must not be interpreted as proof that a prior POST was never processed.

## Production startup guard

The production runtime validates its environment before accepting requests. Required values are `SECRET_KEY_BASE`, `AR_ENCRYPTION_PRIMARY_KEY`, `AR_ENCRYPTION_DETERMINISTIC_KEY`, `AR_ENCRYPTION_KEY_DERIVATION_SALT`, `DATABASE_URL`, `QUEUE_DATABASE_URL` and `CACHE_DATABASE_URL`. The three PostgreSQL connections must point to distinct databases. Do not use a preview database or test secrets as production values. The configuration check is CPU-only and does not contact inference providers.

When deploying behind HTTPS termination, accept requests only from a trusted proxy; restrict direct Rails access and sanitize `X-Forwarded-*` headers at that edge. Confirm the web and Solid Queue processes use the same production secret configuration and that SSL/cookie policies stay enabled.

## Automatic reconciliation (CPU-side only)

Solid Queue loads `config/recurring.yml` and runs `ReconcileTranslationDispatchesJob` every five minutes in development and production. The job processes at most 50 stale submissions and 50 stale accepted dispatches per sweep:

- If a provider POST was left `submitting` for over 10 minutes, mark its dispatch/run as `uncertain` (`DISPATCH_OUTCOME_UNKNOWN`). **Never enqueue or replay a paid POST.** An administrator must reconcile any unknown provider outcome before considering a new request.
- Resuming an `accepted` dispatch with a stale status check (over five minutes) uses **only `PollTranslationDispatchJob` / GET**, not POST. Because even GET can wake sleeping hosting, automatic recovery polling is disabled by default. Enable it explicitly with `TRANSLATION_RECOVERY_POLLING_ENABLED=1` only when that provider behavior and cost are acceptable. The normal provider polling started by an approved translation is unchanged.
- The sweep is bounded, rerunnable, and does not require connecting to any GPU to verify its behavior with mock providers. Confirm the Rails and Solid Queue worker processes are monitored; the recurring task depends on the queue scheduler being active.

## Maintenance

Back up primary application data together with the deployment/dispatch relationships; maintain queue and cache databases according to their respective retention needs. Review stale throttle counters, key rotation, database roles and trusted proxy configuration.

## Runbook

1. Check Rails/database/queue health and the latest security events.
2. Determine whether the incident concerns authentication, the application database, a queue worker, DNS/TLS or the remote inference host.
3. For uncertain requests, inspect persisted dispatch IDs and provider job references without re-submitting.
4. Escalate suspected credential exposure through the private security channel.

See [Troubleshooting](troubleshooting.md) and [Security](security.md).
