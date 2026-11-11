# Security policy

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](SECURITY.vi.md)

## Supported scope

Security fixes target the current default branch when a vulnerability is confirmed. Historical commits and untagged snapshots are not automatically maintained as supported releases.

## Private vulnerability reporting

Please do **not** create a public issue containing an exploit, leaked API token, credential or customer translation text. Use GitHub private vulnerability reporting if enabled, or email **i.am@dangkhoa.dev** with:

- affected commit SHA, Rails version and deployment setup;
- clear reproduction steps and expected impact;
- a redacted proof of concept or safe logs;
- suggested mitigation if available.

Do not include active production credentials in the report. Reports are reviewed as availability permits; no response-time SLA is promised.

## Relevant attack surfaces

The application contains administrator sessions, encrypted provider Bearer tokens, inference URL configuration, user-generated source text and potentially chargeable outbound requests. Important boundaries include Pundit authorization, rate limits, SSL/TLS validation, public-IP-only endpoints, SSRF defenses and no blind paid retries.

## Deployment responsibility

Run HTTPS with trusted proxy configuration, protect secret keys, isolate database privileges, restrict egress and back up application records. A successful CI run does not certify an internet-facing production deployment. See [technical security guide](../docs/security.md).
