# Translation lifecycle

> 🌐 Language / Ngôn ngữ: **English** | [Tiếng Việt](translation-workflow.vi.md)

## Submit

1. An administrator enters source text, source/target language labels and formatting preference.
2. One to four **configured** models are selected. Language fields are not hard-coded to a whitelist.
3. A cost confirmation is required; multiple selected models may trigger multiple paid model-runs.
4. The planner persists a translation request and distinct model dispatch records, each with an idempotency key, before external submission.
5. Solid Queue performs remote requests and records accepted, completed or uncertain outcomes.

## Compare results

The result page presents a card per selected model, with independent status and translation output. Admins can review history, mark a preferred result and inspect model-specific failures. An unsupported language pair is reported when the provider returns `UNSUPPORTED_LANGUAGE_PAIR`; the Rails application does not claim to know every model's supported language catalog in advance.

## Provider performance data

The Translation Gateway V1 adapter keeps optional per-attempt `usage`, `timings`, and `resources` from authenticated job GET. Technical details show model token counts, worker and queue durations, and best-effort CPU/GPU samples. A GPU snapshot is not an average or peak, and missing fields are not zero. Rails-observed dispatch time includes polling and must not be compared with model inference time. Only whitelisted numeric fields are saved in encrypted response snapshots.

## Retry and reconciliation

Opening history or comparison views must not submit inference again. Polling accepted jobs uses remote GET. If a paid POST may have reached the provider but the response was lost, the operation remains uncertain until explicit reconciliation; blindly retrying could create duplicate charges.

## Current boundaries

The current application does not yet expose a full manual attempt/reconciliation console or batch document translation. The gateway v1 integration has a 1,000-Unicode-code-point input constraint; editing and splitting long text into semantic chunks is not an implemented automatic document pipeline. Refer to [Limitations](limitations.md).
