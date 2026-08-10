# 02 — Manage and Test a Prompt

**[Previous: Observability](01-observability.md) · [Workshop home](workshop-overview.md) · [Next: Monitoring](03-monitoring-and-scores.md)**

## Goal

Move behavior out of an ad-hoc prompt and into a versioned Langfuse chat prompt. Test it through the `Workshop LiteLLM` connection and deploy it with a label.

## Why prompt management

A prompt embedded in application code is difficult to inspect, compare, approve, or roll back. A managed prompt adds:

- immutable versions
- human-readable diffs
- deployment labels such as `production`
- runtime retrieval and caching patterns
- links between prompt versions and model observations
- Playground and experiment reuse

## Create version 1

In Langfuse, open **Prompt Management / Prompts** and create a new **chat prompt**.

Use this name:

```text
workshop/acme-support-agent
```

Add two messages.

### System message

```text
You are the Acme Cloud Support Assistant.
Answer the customer question clearly and briefly.
Use the supplied policy context when it is useful.
```

### User message

```text
Policy context:
{{policy}}

Customer question:
{{question}}
```

Save it with:

- commit message: `baseline support prompt`
- label: `production`
- optional tag: `workshop`

The double braces declare variables. They must match dataset input keys exactly in later UI experiments.

## Test version 1 in the Playground

Open the prompt in the Playground and select:

- connection: `Workshop LiteLLM`
- model: `auto`
- temperature: `0` or the lowest available value for repeatability
- max tokens: about `200`

Use these variables:

```text
policy = Passwords are reset from Settings > Security > Reset password. A reset link expires after 15 minutes.
question = How do I reset my password?
```

Run the prompt and inspect the response. Then test an unsupported question:

```text
policy = No policy is available for this request.
question = Can you book a flight for me?
```

Record whether the baseline invents an answer, refuses, or asks for clarification. Do not improve it yet; module 06 works best when the baseline has a visible weakness.

## Inspect the prompt version

Open the version detail and identify:

- prompt type: chat
- version number
- `production` label
- variables: `policy`, `question`
- commit message
- creation time and author
- Playground generation or linked observation, if shown

Labels are mutable pointers; versions are immutable history. Moving `production` changes what label-based clients fetch without deleting the previous version.

## Create a draft, but do not deploy it

Create a second version with the same two-message structure. Add one line to the system message:

```text
If the policy context does not support an answer, say that the information is unavailable instead of guessing.
```

Save this version without the `production` label and use commit message:

```text
draft grounding guardrail
```

Do not promote it yet. The workshop now has a deployed baseline and a candidate change.

## Compare versions

Use the version history or diff view to answer:

1. Which version is currently `production`?
2. What behavior is the draft intended to change?
3. Could the new rule regress useful answers when policy context is incomplete?
4. What dataset cases would prove the change is safe?

The last question is the bridge from prompt editing to evaluation engineering.

## Checkpoint

- [ ] `workshop/acme-support-agent` exists as a chat prompt.
- [ ] Version 1 has the `production` label.
- [ ] Version 1 runs through `Workshop LiteLLM / auto` in the Playground.
- [ ] Version 2 is an undeployed grounding draft.
- [ ] You wrote down one expected improvement and one possible regression.

Continue to [03 — Monitoring and Scores](03-monitoring-and-scores.md).
