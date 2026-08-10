# 06 — Evaluate a Prompt Change

**[Previous: Experiments](05-experiments.md) · [Workshop home](README.md) · [Next: Human and LLM Evaluation](07-human-and-llm-evaluation.md)**

## Goal

Promote one evidence-based prompt change, rerun the same dataset, compare both runs, and make an explicit ship/no-ship decision.

## Inspect before changing

Open `baseline-v1` and read the lowest-scoring outputs. Confirm that the proposed change addresses a real observed behavior. Do not edit the prompt merely because a new wording sounds better.

The candidate draft from module 02 adds a grounding rule:

```text
If the policy context does not support an answer, say that the information is unavailable instead of guessing.
```

If your baseline revealed a different failure, create a new prompt version with one focused rule that addresses it. Keep all other model parameters unchanged.

## Promote the candidate

1. Open **Prompts → workshop/acme-support-agent**.
2. Review the diff between baseline and candidate.
3. Add a meaningful commit message describing the intended behavior.
4. Move the `production` label to the candidate version.
5. Confirm the old version remains available by its version number.

Deployment labels are pointers. Promotion does not erase history and rollback means moving the label back.

## Run the candidate experiment

Repeat the UI experiment with the same configuration as module 05, changing only:

| Field | Value |
| --- | --- |
| Run name | `candidate-v2` |
| Prompt version | new `production` version |

Keep dataset, model `auto`, connection, temperature, max tokens, and evaluator unchanged. If more than one variable changes, the comparison cannot attribute the result to the prompt.

## Compare side by side

Open the dataset's Runs/Experiments view and compare `baseline-v1` with `candidate-v2`.

Inspect:

- aggregate score change
- item-level improvements
- item-level regressions
- high-risk item results
- out-of-scope behavior
- latency and token changes
- errors or incomplete outputs

Do not stop at the average. One severe regression in a high-risk security case may outweigh several small improvements.

## Decision record

Complete this record in your notes:

```text
Change:
Baseline prompt version:
Candidate prompt version:
Dataset/version:
Model route:
Evaluator version:

Aggregate result:
Improved items:
Regressed items:
High-risk findings:
Latency/token impact:

Decision: SHIP / DO NOT SHIP / NEEDS MORE EVIDENCE
Reason:
Rollback plan:
Next dataset case to add:
```

## If the candidate loses

A failed experiment is a useful result. Choose one:

- Move `production` back to the baseline version.
- Refine the prompt with a narrower rule and create a third run.
- Correct a flawed expected output, creating a new dataset version, then rerun both variants fairly.
- Add a semantic or human score because keyword recall is measuring the wrong dimension.

Never delete the losing prompt version or run merely to make the dashboard cleaner. The history explains why the final version exists.

## Checkpoint

- [ ] Two runs use the same dataset, model path, and parameters.
- [ ] The runs link to different prompt versions.
- [ ] You reviewed per-item regressions, not only averages.
- [ ] You wrote a ship/no-ship decision and rollback plan.
- [ ] The `production` label points to the version justified by evidence.

Continue to [07 — Human Review and LLM-as-a-Judge](07-human-and-llm-evaluation.md).
