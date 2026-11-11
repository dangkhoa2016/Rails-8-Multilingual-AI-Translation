# Contributing

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](CONTRIBUTING.vi.md)

Thank you for considering a contribution to Rails 8 Multilingual AI Translation. Keep changes focused, testable and safe to review.

## Local setup

Use Ruby 3.3+, PostgreSQL 15+ and the versions in `Gemfile.lock`.

~~~bash
bundle install
RAILS_ENV=test bin/rails db:prepare
RAILS_ENV=test bin/rails test
python3 scripts/validate_repository_docs.py
~~~

No paid inference calls or provider credentials are required to validate a normal contribution.

## Coding and security standards

- Use Rails conventions, focused services and database migrations for persisted changes.
- Protect administrator routes through Pundit and server-side access controls.
- Never embed Bearer tokens, secrets, real translated customer text or private endpoints.
- Do not automatically replay a billable POST after an ambiguous timeout.
- Add regression tests for changed behavior and keep CI GPU-free.

## Documentation policy

All tracked Markdown documentation must have an English/Vietnamese pair in the same directory: `file.md` and `file.vi.md`. Both include a reciprocal language switch at the top. Update both sides together, and keep relative links valid. Repository CI enforces this rule.

## Commit hygiene

Use descriptive subjects and bullet bodies; keep functional changes reviewable and generally under 600 changed lines per commit. A substantial bilingual document pair may be longer when splitting it would make the document incoherent. Do not falsify test results, release evidence or commit timestamps.

## Contributions

A proposed change should describe purpose, affected components, test commands and security/cost impact. See [Pull request template](PULL_REQUEST_TEMPLATE.md) and [Support](SUPPORT.md). Report security issues privately through [Security Policy](SECURITY.md).
