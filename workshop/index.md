# LLMOps in a Box

Use the top navigation to move between the learner workshop and operational references. Inside the **Workshop** tab, the left navigation keeps the complete module sequence visible from setup through ClickHouse analytics and wrap-up.

## Start here

New participants should begin with [00 — Setup and LLM Connection](00-setup.md). Instructors can open the [Instructor Guide](instructor-guide.md), while maintainers can use the [Docker Validation Report](docker-validation.md) before a customer delivery.

## What you will build

```text
model request → observable trace → managed prompt → golden dataset
              → repeatable experiment → automated and human scores
              → ClickHouse quality analysis → ship/no-ship decision
```

The workshop supports four explicit deployment paths without provider fallback: ClickHouse Cloud or local ClickHouse, each paired with Anthropic Sonnet or a participant-selected local Ollama model.
