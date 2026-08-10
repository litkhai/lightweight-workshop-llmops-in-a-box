# 05 — Run a Baseline Experiment

**[Previous: Datasets](04-datasets.md) · [Workshop home](README.md) · [Next: Evaluate a Change](06-evaluate-a-change.md)**

## Goal

Run the production prompt against the complete golden dataset, score each item with a deterministic evaluator, and establish a baseline for comparison.

## Why an experiment is different from a trace

A trace explains one real interaction. An experiment applies the same task to a controlled set of items and evaluates every result. This makes prompt or model changes comparable instead of anecdotal.

Every run should identify:

- dataset and dataset state
- prompt version and label
- model connection and model name
- model parameters
- evaluator versions
- run name and purpose

## Create the deterministic evaluator

In Langfuse:

1. Open **Evaluators → New evaluator → Code evaluator**.
2. Choose **TypeScript / JavaScript**.
3. Name it `workshop_keyword_recall`.
4. Paste [`assets/keyword-recall.ts`](assets/keyword-recall.ts).
5. Set the target to **Experiments**.
6. If filters are available, limit it to dataset `workshop/acme-support-golden`.
7. Use the preview against a sample experiment item.
8. Save and enable it.

The evaluator normalizes the model output and expected output, removes short/common words, and calculates the fraction of expected keywords present in the response. It is cheap and reproducible, but it does not understand meaning or factual contradictions.

## Start the baseline prompt experiment

1. Open **Datasets → workshop/acme-support-golden**.
2. Choose **Start Experiment**.
3. Choose the prompt experiment / UI experiment option.
4. Configure:

| Field | Value |
| --- | --- |
| Run name | `baseline-v1` |
| Prompt | `workshop/acme-support-agent` |
| Prompt version | the version carrying `production` (v1 at this point) |
| Connection | `Workshop LiteLLM` |
| Model | `auto` |
| Temperature | `0` or lowest supported value |
| Max tokens | `200` |
| Dataset | `workshop/acme-support-golden` |
| Evaluator | `workshop_keyword_recall` |

The dataset input keys `policy` and `question` map directly to the prompt's `{{policy}}` and `{{question}}` variables.

Start the experiment. The run may take longer with CPU inference because every dataset item becomes a model request.

## Inspect the baseline

When the run completes, inspect:

- overall `workshop_keyword_recall` average
- per-item score distribution
- failed or low-scoring items
- high-risk items separately from low-risk items
- out-of-scope behavior
- latency and token differences across items
- links to the exact prompt version

Open at least one high score and one low score. Read the output rather than trusting the number.

## Interpret the metric carefully

Keyword recall answers: “Did the output contain important words from the reviewed answer?” It does not answer:

- Are the statements factually correct?
- Did the model contradict the policy?
- Is the tone appropriate?
- Is the answer safe?
- Did the model add unsupported claims?

A high keyword score can accompany a misleading answer. A low score can accompany a valid paraphrase. This is why the workshop adds human and optional semantic evaluation later.

## Failure analysis worksheet

For the three lowest-scoring items, record:

| Item | Observed failure | Likely cause | Proposed single change | Regression risk |
| --- | --- | --- | --- | --- |
| 1 |  |  |  |  |
| 2 |  |  |  |  |
| 3 |  |  |  |  |

Choose one failure that the grounding draft from module 02 is expected to improve.

## Troubleshooting

### Run fails before model output

- Confirm prompt variables exactly match `policy` and `question`.
- Confirm the Langfuse connection Base URL is `http://litellm:4000/v1`.
- Confirm custom model name `auto` exists.
- Inspect `litellm`, `langfuse-web`, and `langfuse-worker` logs.

### Outputs exist but scores are missing

- Wait for the asynchronous evaluator queue.
- Confirm the evaluator target is Experiments, not Live Observations.
- Confirm the evaluator is enabled and applies to this dataset.
- Inspect worker logs and evaluator execution status.

### Small local model is inconsistent

Keep temperature low, reduce concurrency if the UI allows it, and treat the variation as part of the experiment evidence. Do not silently switch models.

## Checkpoint

- [ ] `baseline-v1` completed against the complete dataset.
- [ ] Every completed item has a model output.
- [ ] `workshop_keyword_recall` scores are visible.
- [ ] You inspected both high- and low-scoring outputs.
- [ ] You selected one evidence-based prompt change.

Continue to [06 — Evaluate a Change](06-evaluate-a-change.md).
