# 07 — Human Review and LLM-as-a-Judge

**[Previous: Evaluate a Change](06-evaluate-a-change.md) · [Workshop home](README.md) · [Next: ClickHouse Analytics](08-clickhouse-analytics.md)**

## Goal

Add human quality judgments, compare them with deterministic scores, and optionally configure a semantic LLM judge when the selected model path supports structured tool calling.

## Part A — Define quality dimensions

Create two score configurations in the Langfuse project. Depending on the current v4 UI, score configuration may be under **Project Settings → Scores**, **Score Configs**, or the evaluator/annotation setup flow.

### `workshop_groundedness`

- type: Categorical
- categories:
  - `grounded`
  - `partially_grounded`
  - `unsupported`
- description: `Whether every material claim is supported by the supplied policy context.`

### `workshop_answer_quality`

- type: Numeric
- range: `1` to `5`
- description: `Overall correctness, relevance, clarity, and actionability.`

Use groundedness for a focused factual dimension and answer quality for a broader reviewer judgment. Combining them into one score would make disagreement difficult to diagnose.

## Part B — Create an annotation queue

1. Open **Annotation Queues**.
2. Choose **New Queue**.
3. Name it `workshop-human-review`.
4. Attach both score configurations.
5. Add a description: `Review low-scoring Acme support experiment outputs`.
6. Assign yourself if assignment is available.

Add at least five items to the queue:

- two low `workshop_keyword_recall` experiment outputs
- one high-scoring output as a control
- the out-of-scope travel item
- one high-risk security, retention, or identity item

Items can be added from a trace/observation's **Annotate** action or by selecting rows and choosing **Actions → Add to queue**.

## Part C — Review consistently

Use this rubric:

| Dimension | Decision rule |
| --- | --- |
| grounded | Every material claim follows from the policy; no invented steps or eligibility |
| partially grounded | Core answer is supported, but a minor claim or detail is unsupported |
| unsupported | A material claim conflicts with or is absent from the policy |
| quality 5 | Correct, direct, complete, safe, and easy to act on |
| quality 4 | Correct with a small clarity or completeness issue |
| quality 3 | Useful but incomplete or unnecessarily vague |
| quality 2 | Major omission, weak actionability, or risky ambiguity |
| quality 1 | Incorrect, unsafe, irrelevant, or unsupported |

For each item:

1. Read input, policy, expected output, and actual output.
2. Assign both scores.
3. Add a short comment explaining the decision.
4. Add a corrected output when the queue supports it.
5. Complete the item and move to the next.

Review the control item carefully. Human queues are not only for failures; controls expose reviewer bias and rubric drift.

## Compare human and code scores

Find an item where human quality and keyword recall disagree.

Typical cases:

- High keyword recall, low groundedness: expected words are present, but the model invented a claim.
- Low keyword recall, high human quality: the answer is a valid paraphrase.
- Both low: likely real failure.
- Both high: likely safe control, still worth sampling.

Write one sentence describing what the disagreement teaches you about evaluator design.

## Part D — Optional LLM-as-a-Judge

This branch is recommended for Anthropic Sonnet. It may fail with a small local model because Langfuse judges require a model/gateway path that reliably supports structured tool calling.

The same `Workshop LiteLLM` connection can be used as the judge connection because it exposes the OpenAI-compatible `auto` model.

### Create a custom evaluator

1. Open **Evaluators → Set up Evaluator**.
2. Choose a managed groundedness/correctness evaluator or create a custom evaluator.
3. Name the custom evaluator `workshop_llm_groundedness`.
4. Use a Categorical result with `grounded`, `partially_grounded`, and `unsupported`.
5. Use this evaluator prompt:

```text
You are reviewing a customer-support answer.

Policy context:
{{policy}}

Customer question:
{{question}}

Assistant answer:
{{output}}

Reference answer:
{{ground_truth}}

Classify the assistant answer:
- grounded: every material claim is supported by the policy
- partially_grounded: the core answer is supported but a minor claim is not
- unsupported: a material claim is absent from or conflicts with the policy

Judge factual support, not wording similarity. Provide concise reasoning.
```

### Target experiment data

Choose offline experiment data and the Acme dataset/runs. Map variables using the UI preview:

| Variable | Source |
| --- | --- |
| `policy` | experiment item input → `policy` |
| `question` | experiment item input → `question` |
| `output` | experiment observation/trace output |
| `ground_truth` | experiment item expected output → `expected_answer` |

Preview multiple items before saving. A successful preview must show the actual values, not `null`, a full escaped object when a string was expected, or the wrong message.

Enable the evaluator for the next experiment, or select existing eligible rows and use **Actions → Evaluate** if the current UI offers backfill.

### Calibrate the judge

Compare at least five judge scores with completed human annotations:

| Item | Human groundedness | Judge groundedness | Agree? | Why? |
| --- | --- | --- | --- | --- |
| 1 |  |  |  |  |
| 2 |  |  |  |  |
| 3 |  |  |  |  |
| 4 |  |  |  |  |
| 5 |  |  |  |  |

Do not treat LLM-as-a-Judge as ground truth. Calibrate the rubric against domain experts, watch disagreement by segment, sample production traffic, and account for judge cost and latency.

### If the judge path fails

- Confirm `Workshop LiteLLM` uses model `auto` and Chat Completions.
- Confirm the selected backend supports OpenAI-format tool calls.
- Inspect the evaluator execution trace and status.
- Use Anthropic for the judge path, or skip this optional branch and retain deterministic + human evaluation.
- Do not configure an automatic fallback to a different judge.

## Checkpoint

- [ ] Two score configurations exist.
- [ ] At least five items were reviewed through `workshop-human-review`.
- [ ] Human scores include comments or corrected output.
- [ ] You found and explained one human/code disagreement.
- [ ] Optional: an LLM judge score was calibrated against human scores.

Continue to [08 — ClickHouse Analytics](08-clickhouse-analytics.md).
