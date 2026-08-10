# Docker Validation Report

**[Workshop home](README.md) · [Setup lab](00-setup.md) · [Instructor guide](instructor-guide.md) · [Repository overview](../README.md)**

## Purpose

This document records how the complete workshop was validated in Docker. It is both a validation snapshot and a repeatable pre-delivery runbook for instructors, maintainers, and customer platform teams.

The latest recorded validation completed successfully on **2026-08-10** in the following final live state:

- ClickHouse: local open-source container
- Model path: Anthropic Sonnet through LiteLLM model alias `auto`
- Langfuse: self-hosted v4 web and worker containers
- Workshop applications: LibreChat, LiteLLM, and Langfuse

No secret values are included in this report. Run commands only from a private terminal with the generated `.env` file.

## Result

**Overall status: PASS**

| Validation area | Result | Evidence |
| --- | --- | --- |
| Four-way setup generation | PASS | Each choice produced the expected modes, profiles, and local-model selection behavior |
| Compose topology | PASS | All four profile combinations rendered with the expected services |
| Current Docker health | PASS | Nine required services were healthy or running; Ollama was absent in Anthropic mode |
| Model gateway | PASS | Langfuse container → LiteLLM `auto` → Anthropic returned the requested validation marker |
| Observability | PASS | Sonnet and local historical generations were present in Langfuse ClickHouse data |
| Prompt and dataset experiment | PASS | Prompt version 2, three dataset items, three completed experiment items, and three scores |
| Code evaluator | PASS | Active TypeScript rule produced a score and a `langfuse-code-eval` execution trace |
| Human-evaluation backend | PASS | Annotation Queue and Score Config public APIs returned successfully |
| ClickHouse analytics | PASS | The complete eight-section SQL workbook executed successfully |
| Workshop content | PASS | English-only Markdown, local links, TypeScript parsing, and 10-row CSV validation passed |

## Supported deployment matrix

Setup has two independent choices, producing four supported combinations. Anthropic and Ollama are mutually exclusive; ClickHouse Cloud and local ClickHouse are also mutually exclusive.

| Combination | `CLICKHOUSE_MODE` | `MODEL_MODE` | Required profiles | ClickHouse container | Ollama container |
| --- | --- | --- | --- | --- | --- |
| ClickHouse Cloud + Anthropic | `cloud` | `sonnet` | none | absent | absent |
| ClickHouse Cloud + local model | `cloud` | `local` | `local-model` | absent | present |
| ClickHouse OSS + Anthropic | `local` | `sonnet` | `local-clickhouse` | present | absent |
| ClickHouse OSS + local model | `local` | `local` | `local-clickhouse,local-model` | present | present |

The interactive setup was exercised in isolated temporary directories for all four paths. Each generated `.env` had owner-only permissions (`0600`). Local-model paths detected Docker memory, filtered the menu, displayed download sizes, and still required an explicit participant selection.

### Matrix rendering check

Run these checks without printing the rendered Compose configuration, which can contain secrets:

```bash
CLICKHOUSE_MODE=cloud MODEL_MODE=sonnet COMPOSE_PROFILES='' \
  docker compose config --quiet

CLICKHOUSE_MODE=cloud MODEL_MODE=local COMPOSE_PROFILES=local-model \
  docker compose config --quiet

CLICKHOUSE_MODE=local MODEL_MODE=sonnet COMPOSE_PROFILES=local-clickhouse \
  docker compose config --quiet

CLICKHOUSE_MODE=local MODEL_MODE=local \
  COMPOSE_PROFILES=local-clickhouse,local-model \
  docker compose config --quiet
```

`config --quiet` validates the model without exposing resolved credentials.

## Live service validation

### Expected services

Every deployment includes:

- `langfuse-web`
- `langfuse-worker`
- `litellm`
- `librechat`
- `mongodb`
- `postgres`
- `redis`
- `minio`

Local ClickHouse adds `clickhouse`. Local inference adds `ollama`.

Check current state:

```bash
docker compose ps
```

For the recorded final run, Langfuse Web, LiteLLM, ClickHouse, PostgreSQL, Redis, MinIO, and MongoDB reported `healthy`. Langfuse Worker and LibreChat reported `running`. Ollama had no container because Anthropic mode was selected.

### HTTP endpoints

```bash
curl -fsS http://localhost:3000/api/public/health >/dev/null
curl -fsS http://localhost:4000/health/liveliness >/dev/null
curl -fsS http://localhost:3080 >/dev/null
```

All three checks must exit with status `0`.

## Model-routing validation

LibreChat and Langfuse use one stable public model alias, `auto`. The LiteLLM callback rewrites that alias to exactly one configured route:

- Anthropic mode: `auto → sonnet`
- Local mode: `auto → local → selected Ollama model`

There is no automatic fallback between providers.

### Direct gateway request

```bash
set -a
source .env
set +a

curl -fsS http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "auto",
    "messages": [
      {"role": "user", "content": "Reply with exactly: DOCKERVALIDATION"}
    ],
    "temperature": 0,
    "max_tokens": 40
  }' | jq -r '.choices[0].message.content'
```

Expected result: a non-empty response containing `DOCKERVALIDATION`.

Then verify the active boundary:

```bash
set -a
source .env
set +a

printf 'model mode: %s\n' "$MODEL_MODE"
docker compose ps --services --status running
```

In Anthropic mode, `ollama` must not be listed. In local mode, `ollama` must be running and the selected model must be visible through:

```bash
docker compose exec -T ollama ollama list
```

## Langfuse LLM Connection validation

The Playground, prompt experiments, and LLM-as-a-Judge call LiteLLM from inside the Langfuse containers. Their Base URL must therefore be:

```text
http://litellm:4000/v1
```

Langfuse v4 blocks private-network LLM Base URLs by default as SSRF protection. The Compose file uses a narrow exact-host exception:

```yaml
LANGFUSE_LLM_CONNECTION_WHITELISTED_HOST: litellm
```

Confirm both Langfuse containers received it:

```bash
docker compose exec -T langfuse-web sh -lc \
  'test "$LANGFUSE_LLM_CONNECTION_WHITELISTED_HOST" = litellm'

docker compose exec -T langfuse-worker sh -lc \
  'test "$LANGFUSE_LLM_CONNECTION_WHITELISTED_HOST" = litellm'
```

Validation created a temporary OpenAI-compatible LLM Connection using this Base URL, listed it through the public API, and deleted it. A request originating inside `langfuse-web` successfully reached LiteLLM and Anthropic through `auto`.

The learner-facing connection is intentionally not pre-created. Participants create `Workshop LiteLLM` in [module 00](00-setup.md) and add the custom model name `auto` themselves.

## Prompt, dataset, experiment, and score validation

An ephemeral Python 3.12 container joined the Compose network and used the current Langfuse Python SDK and OpenAI-compatible client. It performed this quality loop:

1. authenticated with the self-hosted Langfuse project
2. created two versions of a temporary prompt
3. labeled version 2 as `production`
4. created a hosted dataset with three representative support cases
5. fetched and compiled the production prompt
6. ran all three items through LiteLLM model `auto`
7. called Anthropic for every item
8. emitted one deterministic keyword-recall score per item
9. flushed the OpenTelemetry pipeline

Recorded evidence:

| Field | Result |
| --- | ---: |
| Langfuse Python SDK | `4.14.3` |
| Prompt version | `2` |
| Dataset items | `3` |
| Completed experiment items | `3` |
| Numeric scores | `3` |
| Average keyword recall | `0.667` |
| Item errors | `0` |

The score values were `0.4`, `1.0`, and `0.6`. Current Langfuse v4 experiment context was verified in `events_core.experiment_*`, and prompt attribution was verified through `prompt_name` and `prompt_version` on generation events.

## Self-hosted code evaluator validation

The Compose stack enables the trusted local TypeScript runner on both Langfuse application containers:

```text
LANGFUSE_CODE_EVAL_DISPATCHER=insecure-local
QUEUE_CONSUMER_CODE_EVAL_EXECUTION_QUEUE_IS_ENABLED=true
```

Confirm the worker started the queue consumer:

```bash
docker compose logs langfuse-worker | \
  grep 'code-eval-execution-queue executor started: true'
```

The live validation flow was:

1. create a temporary TypeScript evaluator from [`assets/all-caps-signal.ts`](assets/all-caps-signal.ts)
2. create and enable an observation evaluation rule
3. verify the rule reached `active` status, including preflight execution
4. send a new uppercase Anthropic request through LiteLLM
5. wait for asynchronous execution
6. verify one `workshop_all_caps_signal` score
7. verify one event in the `langfuse-code-eval` environment
8. delete the temporary rule and evaluator definition

`insecure-local` executes trusted TypeScript inside the worker process. It is not a sandbox and must not run untrusted participant code.

## Annotation and score-configuration backend

The validation used the current Langfuse CLI to discover and call the public API:

```bash
set -a
source .env
set +a
export LANGFUSE_HOST=http://localhost:3000

npx --yes langfuse-cli api annotation-queues list --json
npx --yes langfuse-cli api score-configs get-public --json
```

Both endpoints returned HTTP `200`. Creating human labels was not automated because applying a real judgment is a learner action, not an infrastructure health check. Module 07 validates the complete UI workflow during delivery.

## ClickHouse Analytics validation

Langfuse v4 writes current observations and experiment context to `events_core`; scores are stored in `scores`. The workbook uses `FINAL` and `is_deleted = 0` for versioned replacing-table semantics.

Run the complete workbook against local ClickHouse:

```bash
set -a
source .env
set +a

docker compose exec -T clickhouse clickhouse-client \
  --user "$CLICKHOUSE_USER" \
  --password "$CLICKHOUSE_PASSWORD" \
  --database "$CLICKHOUSE_DB" \
  --multiquery < workshop/sql/quality-loop.sql
```

The validated workbook covers:

1. observation volume by route and model
2. latency, token usage, and cost
3. score inventory
4. numeric score distributions
5. experiment-run comparison
6. prompt-version performance
7. per-trace evaluator agreement
8. daily quality trends

The recorded experiment returned three `validation_keyword_recall` scores with average `0.667`, linked to prompt version 2. The later code-evaluator test added a `workshop_all_caps_signal` score.

For ClickHouse Cloud, run the same workbook in the Cloud SQL Console or with the secure native endpoint described in [module 08](08-clickhouse-analytics.md). Never print the Cloud password in logs or screenshots.

## Content integrity checks

The recorded validation also checked:

- Bash syntax for `setup.sh` and all scripts
- Compose rendering
- Git whitespace errors
- all workshop Markdown is English-only
- all relative Markdown links resolve
- the CSV contains exactly 10 data rows and the expected columns
- both TypeScript evaluator assets parse successfully
- the SQL workbook completes without query errors

Recommended pre-delivery commands:

```bash
bash -n setup.sh scripts/*.sh
docker compose config --quiet
git diff --check
```

## Issues found and corrected

### Internal LiteLLM Base URL was blocked

**Symptom:** Creating an LLM Connection with `http://litellm:4000/v1` returned `Blocked IP address detected`.

**Cause:** Langfuse v4 correctly rejected a private-network destination under its default SSRF policy.

**Correction:** Add only `litellm` to `LANGFUSE_LLM_CONNECTION_WHITELISTED_HOST` for both Langfuse containers. Do not use `*` or broadly allow private networks.

### Analytics used legacy experiment projections

**Symptom:** The SQL workbook executed, but experiment and prompt-version sections returned no current SDK experiment data.

**Cause:** The workbook joined legacy `observations` and `dataset_run_items_rmt` projections. The current v4 SDK stored the experiment context in `events_core.experiment_*` and linked scores to observation span IDs.

**Correction:** Update [`sql/quality-loop.sql`](sql/quality-loop.sql) to use `events_core`, join experiment scores through `observation_id = span_id`, and join prompt-linked generations by `trace_id`.

## Validation boundaries

A PASS means the provided software paths and backend capabilities worked in the recorded environment. It does not eliminate delivery-specific checks:

- ClickHouse Cloud network allow lists and credentials must be tested for each customer environment.
- Anthropic credentials, quotas, model availability, and spend limits must be checked before delivery.
- Local-model latency depends on Docker memory, CPU, and the selected Ollama model.
- Human annotation quality requires a consistent rubric and cannot be proven by an API health check.
- LLM-as-a-Judge should be calibrated against human judgments. Small local models may not satisfy the required structured tool-calling contract.
- `insecure-local` is suitable only for trusted workshop code.
- Langfuse internal ClickHouse tables can change across versions; re-run `DESCRIBE TABLE` after upgrades.

## Temporary resources and cleanup

Temporary LLM Connections, evaluation rules, and evaluator definitions were deleted after validation. SDK validation prompts, datasets, traces, and scores may be retained as inspectable evidence in the workshop project.

Before a customer session, either keep this evidence in a clearly labeled facilitator project or start with a clean project. Never delete customer or learner data without explicit approval.

Stop local services while preserving data:

```bash
docker compose down
```

The destructive clean reset is documented in the instructor guide and must be performed only with explicit confirmation.

## Delivery sign-off checklist

- [ ] All four setup paths still render successfully.
- [ ] The selected customer path starts from a clean environment.
- [ ] Required containers are healthy or running.
- [ ] Mutually exclusive containers are absent.
- [ ] `auto` returns a non-empty response through the selected provider.
- [ ] A new Langfuse generation appears after the request.
- [ ] `Workshop LiteLLM / auto` succeeds in the Playground.
- [ ] A three-item smoke experiment completes with scores.
- [ ] The TypeScript evaluator creates a score.
- [ ] Annotation Queue and Score Config screens load.
- [ ] The ClickHouse workbook completes against the selected backend.
- [ ] No credentials appear in terminal capture, screenshots, or shared notes.

## Official references

- [Langfuse LLM Connections](https://langfuse.com/docs/administration/llm-connection)
- [Langfuse experiments via SDK](https://langfuse.com/docs/evaluation/experiments/experiments-via-sdk)
- [Langfuse code evaluators](https://langfuse.com/docs/evaluation/evaluation-methods/code-evaluators)
- [Self-hosted code evaluator configuration](https://langfuse.com/self-hosting/configuration/code-evaluators)
- [Langfuse self-hosted environment example](https://github.com/langfuse/langfuse/blob/main/.env.prod.example)
