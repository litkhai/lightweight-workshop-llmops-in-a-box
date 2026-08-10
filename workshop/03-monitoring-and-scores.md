# 03 — Monitor Live Traffic with Scores

**[Previous: Prompt Management](02-prompt-management.md) · [Workshop home](workshop-overview.md) · [Next: Datasets](04-datasets.md)**

## Goal

Turn a simple, objective failure signal into an automated score and use that score to find the traces worth reviewing.

## Start with a signal, not a dashboard

Production systems generate too many traces to read one by one. Monitoring starts by defining a signal that should pull an interaction into review.

For this lab, an all-caps run of six or more English letters is a cheap proxy for frustration. It is intentionally imperfect: a score is evidence to investigate, not automatically a business truth.

## Create a TypeScript code evaluator

The Compose stack enables Langfuse's trusted local TypeScript dispatcher. In Langfuse:

1. Open **Evaluators**.
2. Choose **New evaluator → Code evaluator**.
3. Select **TypeScript / JavaScript**.
4. Name it `workshop_all_caps_signal`.
5. Open [`assets/all-caps-signal.ts`](assets/all-caps-signal.ts), read it, and paste it into the editor.

The evaluator searches the serialized generation input for a run matching `[A-Z]{6,}` and returns a Boolean score with a comment.

## Configure the target

Choose live observations and target the workshop generation:

- observation type: `generation`
- observation name:
  - `sonnet/response` for Anthropic mode
  - `local/response` for local-model mode
- sampling: `100%` for the workshop
- environment: leave broad unless your UI shows a specific workshop environment

Use the preview/test action before enabling the evaluator. Check that `ctx.observation.input` contains the message payload you saw in module 01.

Enable the evaluator.

## Trigger both outcomes

Send two new messages through LibreChat:

```text
How can an application team reduce LLM latency?
```

```text
NOTHINGWORKS and I need help with my invoice right now.
```

Wait for asynchronous evaluation, then find the two newest generations. Expected scores:

| Request | `workshop_all_caps_signal` |
| --- | --- |
| normal sentence | `false` |
| `NOTHINGWORKS` | `true` |

If the score remains pending, refresh after several seconds and inspect worker logs:

```bash
docker compose logs --since=5m langfuse-worker
```

## Use the score operationally

In the tracing table:

1. Add or expose the score column.
2. Filter `workshop_all_caps_signal = true`.
3. Open the flagged generation.
4. Read the full input/output before deciding whether the customer was actually frustrated.
5. Bookmark the trace or add it to the dataset created in the next module.

This separates **detection** from **judgment**. The evaluator detects a cheap signal; a human or semantic evaluator determines whether it represents a real problem.

## Optional dashboard view

If the current Langfuse v4 UI exposes custom dashboards/metrics, create a workshop view with:

- generation count over time
- p50/p95 latency
- input and output token totals
- count or rate of `workshop_all_caps_signal = true`
- split by observation name or model

Use a short time range while the dataset is small. A dashboard is useful only after its metric has a clear definition.

## Security note

`insecure-local` executes trusted evaluator code inside the Langfuse worker. Never paste evaluator code from an untrusted source. Production deployments should use an isolated dispatcher such as the supported Lambda runner and apply normal code review.

## Checkpoint

- [ ] `workshop_all_caps_signal` is enabled for the correct generation name.
- [ ] One false and one true Boolean score exist.
- [ ] You filtered traces using the score.
- [ ] You can explain why the signal is useful and why it is not ground truth.

Continue to [04 — Golden Datasets](04-datasets.md).
