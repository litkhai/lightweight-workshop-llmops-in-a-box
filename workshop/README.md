# LLMOps in a Box Workshop

**[Repository overview](https://github.com/litkhai/lightweight-workshop-llmops-in-a-box) · [Start workshop](00-setup.md) · [Instructor guide](instructor-guide.md) · [Docker validation](docker-validation.md)**

This English-only workshop is a self-guided tour of the AI engineering quality loop on open-source, self-hosted Langfuse v4. You will generate real model traffic, inspect traces, manage prompts, turn failures into a dataset, run repeatable experiments, add automated and human scores, and query the resulting quality signals directly in ClickHouse.

The course uses a fictional **Acme Cloud Support Assistant**. No proprietary customer data is required.

## The quality loop

```text
Observe production-like traffic
        │
        ▼
Find a failure ──► version a prompt ──► build a golden dataset
      ▲                                          │
      │                                          ▼
human review ◄── automated scores ◄── run an experiment
      │                                          │
      └──────────── compare, decide, deploy ◄────┘

All traces, generations, and scores are available for ClickHouse analysis.
```

## Course map

| Module | Topic | Primary surface | Time | Outcome |
| --- | --- | --- | ---: | --- |
| [00](00-setup.md) | Setup and LLM connection | Terminal + Langfuse UI | 15–25 min | Healthy stack and `auto` model connection |
| [01](01-observability.md) | Tracing and observability | LibreChat + Langfuse UI | 15 min | Read a generation end to end |
| [02](02-prompt-management.md) | Prompt management | Langfuse UI | 15 min | Versioned chat prompt with a deployment label |
| [03](03-monitoring-and-scores.md) | Monitoring and deterministic scores | Langfuse UI | 15–20 min | Live evaluator and score-based filtering |
| [04](04-datasets.md) | Golden datasets | Langfuse UI | 15 min | Curated support dataset with expected outputs |
| [05](05-experiments.md) | Prompt experiments | Langfuse UI | 15–25 min | Baseline experiment with per-item scores |
| [06](06-evaluate-a-change.md) | Evaluate a change | Langfuse UI | 15 min | Side-by-side evidence for a prompt decision |
| [07](07-human-and-llm-evaluation.md) | Human review and LLM-as-a-Judge | Langfuse UI | 20–30 min | Calibrated human and optional semantic scores |
| [08](08-clickhouse-analytics.md) | ClickHouse quality analytics | SQL | 15–20 min | Cross-cutting trace and score analysis |
| [09](09-wrap-up.md) | Production design and cleanup | Discussion + terminal | 10 min | An adoption plan and clean shutdown |

The core path takes about two hours. Modules can also be used independently after module 00.

Maintainers and instructors can use the [Docker Validation Report](docker-validation.md) as a reproducible pre-delivery runbook. It records the four-way deployment matrix, live model and evaluator checks, ClickHouse evidence, known validation boundaries, and customer-session sign-off checklist.

## UI-first, with reproducible assets

The learner performs most work directly in Langfuse and LibreChat. The repository includes small assets for steps that are easier to reproduce than to retype:

- [`assets/acme-support-dataset.csv`](assets/acme-support-dataset.csv) — importable golden dataset
- [`assets/all-caps-signal.ts`](assets/all-caps-signal.ts) — live deterministic monitor
- [`assets/keyword-recall.ts`](assets/keyword-recall.ts) — experiment evaluator
- [`sql/quality-loop.sql`](sql/quality-loop.sql) — ClickHouse analysis workbook

These are not opaque setup scripts. Each module explains what the asset does and asks you to inspect the result in the UI.

## Open-source scope

The workshop intentionally uses the open-source self-hosted product:

- tracing and token/cost metadata
- prompt versioning, labels, Playground, and prompt experiments
- datasets and experiment comparison
- scores, TypeScript code evaluators, LLM-as-a-Judge, and annotation queues
- dashboards and direct ClickHouse access

The local Compose stack enables Langfuse's `insecure-local` code-evaluator dispatcher. It executes evaluator code inside the Langfuse worker and is appropriate only for a trusted laptop workshop. It is not a security sandbox and is not the recommended production execution model.

## Model-path expectations

The model alias is always `auto`, but there is no fallback:

- Anthropic setup: `auto → sonnet`
- Local setup: `auto → the Ollama model selected during setup`

Basic Playground and prompt experiments work on either path. LLM-as-a-Judge requires reliable structured tool calling. Anthropic Sonnet is the recommended judge path; small local models may not satisfy that contract. The deterministic evaluator and human-review modules work without a judge model.

## Workshop completion evidence

Keep a simple evidence log as you work. At the end you should have:

1. A trace or generation showing input, output, model, latency, and usage.
2. At least two versions of `workshop/acme-support-agent`.
3. A `production` label pointing to the version you chose.
4. A `workshop/acme-support-golden` dataset.
5. Two comparable experiment runs.
6. At least one automated score and one human score.
7. One ClickHouse query result that combines traces or observations with scores.
8. A written ship/no-ship decision based on evidence.

## Source material

This course adapts the structure of the [official Langfuse workshop](https://langfuse.com/workshop) and the repository-local `clickhouse-hols/usecase/langfuse-eval` quality-loop lab. The implementation is tailored to this stack: LibreChat produces traffic, LiteLLM provides one OpenAI-compatible `auto` route, Langfuse is OSS/self-hosted, and ClickHouse can be local or Cloud.

Continue to [00 — Setup](00-setup.md).
