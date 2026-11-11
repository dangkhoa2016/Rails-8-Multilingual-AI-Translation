# Troubleshooting

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](troubleshooting.vi.md)

## Sign-in returns HTTP 429

A SQL login bucket or Rack::Attack throttle may be active. Check the `Retry-After` header and Security Center; confirm the proxy forwards a trustworthy client IP. Do not clear counters reflexively on a public deployment.

## A model is disabled or unavailable

Check model activation, active deployment, enabled connection, nonempty encrypted Bearer token and remote model identifier. Validate protocol compatibility before requesting a live inference.

## Inference endpoint is rejected

Only public HTTPS base URLs on port 443 are allowed. Remove URL paths, query strings, embedded credentials and internal hostnames. Confirm DNS resolves exclusively to acceptable public IP addresses. Do not weaken the SSRF controls to work around an internal-only endpoint.

## Translation remains pending or uncertain

Check Solid Queue worker health and the persisted dispatch/remote job ID. A timeout after POST does not prove failure; use safe status retrieval or provider-side reconciliation instead of blindly retrying a chargeable request.

## Database, encryption or assets fail

Confirm that all three PostgreSQL connections are available; verify encryption environment keys without printing them. Run `RAILS_ENV=test bin/rails db:prepare` for a test installation and `bin/rails zeitwerk:check` or `bin/rails tailwindcss:build` for code/assets diagnostics.

When filing a bug, include safe logs, an exact commit SHA and reproducible steps. See [Support](../.github/SUPPORT.md).
