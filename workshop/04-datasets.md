# 04 — Build a Golden Dataset

**[Previous: Monitoring](03-monitoring-and-scores.md) · [Workshop home](workshop-overview.md) · [Next: Experiments](05-experiments.md)**

## Goal

Create a reusable test set with representative inputs and reviewed expected outputs. Add one observed failure so the dataset connects production evidence to pre-release testing.

## What makes a dataset golden

A log export is not automatically a golden dataset. A useful evaluation dataset has:

- a clear purpose and scope
- representative normal, boundary, and failure cases
- expected outputs reviewed by someone who understands the domain
- stable input shape
- enough metadata to segment results
- version history and an owner

The supplied Acme dataset is synthetic and safe for a workshop. In a real system, redact sensitive fields before promoting production traces into evaluation data.

## Create the dataset

In Langfuse:

1. Open **Datasets**.
2. Select **New dataset**.
3. Name it `workshop/acme-support-golden`.
4. Describe it as `Golden support cases for the self-service quality-loop workshop`.

The slash creates a logical folder in Langfuse.

## Import the CSV

Use **Import CSV** and select [`assets/acme-support-dataset.csv`](assets/acme-support-dataset.csv).

Map columns as follows:

| CSV column | Dataset destination | Resulting key |
| --- | --- | --- |
| `question` | Input | `question` |
| `policy` | Input | `policy` |
| `expected_answer` | Expected output | `expected_answer` |
| `category` | Metadata | `category` |
| `risk` | Metadata | `risk` |

The final item shape should resemble:

```json
{
  "input": {
    "question": "How do I reset my password?",
    "policy": "Passwords are reset from Settings..."
  },
  "expectedOutput": {
    "expected_answer": "Open Settings, select Security..."
  },
  "metadata": {
    "category": "account",
    "risk": "low"
  }
}
```

Do not map `expected_answer` into Input. Prompt variables need `question` and `policy`; the evaluator needs a separate expected output.

## Inspect dataset coverage

Open at least three items:

1. a common account request
2. a billing or retention request
3. the out-of-scope travel request

Answer these questions:

- Is the policy sufficient to answer the question?
- Is the expected answer supported only by the policy?
- Is risk metadata useful for slicing experiment results?
- Would a plausible model failure be observable in the expected output comparison?

## Add a case from observed traffic

Return to the observations table and open the edge case from module 01 or the flagged all-caps case from module 03.

Depending on the current UI, use **Add to dataset** from the item action menu or select one/more observations and use **Actions → Add to dataset**.

Add it to `workshop/acme-support-golden` and edit the new item:

- Input: preserve only the safe, relevant question and add policy context.
- Expected output: replace the model answer with the reviewed answer you wanted.
- Metadata: add a category and set `source` to `observed-workshop-trace` if the editor allows it.
- Keep the source trace/observation link when offered.

This is the most important loop in the workshop: an observed failure becomes a regression test.

## Optional: add schemas

If the dataset editor exposes input and expected-output schemas, use:

### Input schema

```json
{
  "type": "object",
  "properties": {
    "question": {"type": "string", "minLength": 1},
    "policy": {"type": "string", "minLength": 1}
  },
  "required": ["question", "policy"],
  "additionalProperties": false
}
```

### Expected-output schema

```json
{
  "type": "object",
  "properties": {
    "expected_answer": {"type": "string", "minLength": 1}
  },
  "required": ["expected_answer"],
  "additionalProperties": false
}
```

Schemas catch malformed imports before a CI or experiment run fails.

## Understand versioning

Adding, updating, archiving, or deleting an item creates a new dataset version. Record the current item count and version time in your evidence notes. Experiments should state which dataset state they used so results remain reproducible.

## Checkpoint

- [ ] `workshop/acme-support-golden` exists.
- [ ] CSV columns were mapped into structured input, expected output, and metadata.
- [ ] The dataset contains normal, boundary, and out-of-scope cases.
- [ ] At least one item came from an observed workshop trace or was added manually as a discovered failure.
- [ ] You can explain why expected output must be reviewed rather than copied blindly from a model.

Continue to [05 — Experiments](05-experiments.md).
