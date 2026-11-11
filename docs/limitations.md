# Scope and limitations

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](limitations.vi.md)

This is a Rails administrative translation interface and orchestration layer, **not** a claim of a complete production translation service or a standalone model benchmark.

- Four catalog entries are provided initially; model capability and language availability remain provider-dependent.
- Translation Gateway v1 limits a request to approximately 1,000 Unicode code points. Rails does not yet implement full document segmentation or automated long-document context management.
- The app can compare outputs and select a preferred run; automatic quality scoring, authoritative BLEU/COMET results or human-review consensus are not included.
- A compatible OpenAI chat endpoint may be used when configured; not all provider APIs or deployment platforms are interchangeable.
- Uncertain paid requests require reconciliation; automatic retry after an unknown POST outcome is intentionally avoided.
- The Security Center shows selected authentication/configuration events, not a complete enterprise SIEM.
- Public sign-up and comprehensive user-role administration are not provided. MFA and provider-token rotation automation need separate work.
- CI is CPU-only and cannot verify a sleeping GPU endpoint, hosting availability or translation quality.
- Browser acceptance, production proxy review and live provider qualification remain deployment-specific.

For the exact tested baseline, see [Implementation status](IMPLEMENTATION_STATUS.md).
