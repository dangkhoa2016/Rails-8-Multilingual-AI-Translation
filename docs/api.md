# Provider API integration

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](api.vi.md)

## Supported adapters

- `translation_gateway_v1`: asynchronous service contract used by the related [inference repository](https://github.com/dangkhoa2016/Multilingual-Translation-AI-Inference). Status polling is a GET operation.
- `openai_chat_completions`: optional adapter for a provider offering a compatible chat-completions contract. Compatibility must be established by the provider, not assumed from the hosting brand.

The adapter is selected on the connection record; remote model identifiers belong to a deployment. A provider name such as Modal or Lightning.ai is not an API protocol.

## Local application routes

- `GET /login` and `POST /login`: administrator sign-in.
- `DELETE /logout`: sign out.
- `GET /admin/translations/new`, `POST /admin/translations`: create a translation request.
- `GET /admin/translations/:id`: view independent model results.
- `POST /admin/translations/:id/refresh_status`: request safe status polling.
- `PATCH /admin/translations/:id/prefer`: record preferred completed result.
- `GET /admin/settings/inference`: manage connections and model deployments.
- `GET /admin/security`: security summary.

These are authenticated Rails application routes, **not** a publicly documented general-purpose translation REST API.

## Network and credentials

Connection base URLs must use a public HTTPS host on port 443, without embedded credentials, query or fragments. The client performs DNS/IP checks and TLS verification, pins the destination and disallows redirects. The token is encrypted in PostgreSQL, never embedded into a browser response.

## Failure semantics

A model-reported unsupported pair can be surfaced as `UNSUPPORTED_LANGUAGE_PAIR`. Timeouts and uncertain results are distinct from definitive provider failure. Do not auto-replay a potentially billable POST; status GETs may be retried under bounded polling policies.

For exact request fields, error codes and limits, consult the server adapters and the related inference repository. The Rails adapter is the integration authority for the specific code revision.
