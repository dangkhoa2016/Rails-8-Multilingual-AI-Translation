# System architecture

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](architecture.vi.md)

## Components

The application is a Rails 8.1 server-rendered administrative workspace using PostgreSQL, Devise/Warden, Pundit, Rack::Attack, Solid Queue, Solid Cache, Turbo, Stimulus and Tailwind CSS.

~~~text
Administrator browser
  -> HTTPS / Rails controller / authorization
  -> PostgreSQL: users, translation requests, runs, dispatches, deployments
  -> Solid Queue: dispatch and status polling jobs
  -> Outbound HTTP client: independently hosted provider endpoints
  <- provider response or remote job state
  -> Turbo Streams: refreshed comparison cards
~~~

Rails does not download or execute the translation models. Provider services may be hosted separately on Modal, Lightning.ai or another compatible platform.

## Core records

- `User`: administrator identity and encrypted-password authentication.
- `InferenceConnection`: provider, adapter protocol, public HTTPS base URL and encrypted Bearer token.
- `TranslationModel`: stable model catalog identity; active deployment is configured independently.
- `ModelDeployment`: versioned connection/model identifier mapping, preserving history after configuration changes.
- `TranslationRequest`: source text, language labels, selection and cost acknowledgement.
- `TranslationDispatch`: one remote submission with idempotency key and recorded state.
- `TranslationRun`: individual model result, status and evidence.
- `SecurityEvent` and `InferenceSettingEvent`: recorded authentication and configuration events.

## Trust boundaries

The browser never receives Bearer tokens or Rails encryption keys. Only validated endpoints are contacted by the HTTP adapter. Active Record encryption protects provider credentials at rest; HTTPS validation and server-side network policies protect outbound requests. Deployment administrators must configure trusted proxies and restrict network egress.

## Asynchronous behavior

A new translation request may dispatch one to four independent model runs. A status refresh polls remote state using GET without issuing a second paid POST. An uncertain POST is not retried blindly. See [Translation workflow](translation-workflow.md) and [API integration](api.md).
