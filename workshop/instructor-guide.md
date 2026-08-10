# Instructor Guide — LLMOps in a Box

**[Workshop home](README.md) · [Learner start](00-setup.md) · [Docker validation](docker-validation.md) · [Repository overview](https://github.com/litkhai/lightweight-workshop-llmops-in-a-box)**

This guide supports a live English-language delivery of the self-guided workshop. Learner instructions remain the source of truth; these notes add timing, teaching points, checkpoints, and recovery options.

## Audience and outcomes

Recommended audience:

- application and platform engineers
- data/ML engineers
- solution architects
- technical product owners responsible for LLM quality

Learners should leave able to distinguish observability from evaluation, build a small quality loop, and explain the operational role of ClickHouse behind Langfuse.

## Recommended formats

| Format | Duration | Scope |
| --- | ---: | --- |
| Executive technical demo | 60 min | 00, 01, 02, experiment comparison demo, 08 |
| Standard hands-on | 2.5 hours | 00–06, abbreviated 07–09 |
| Full workshop | 3.5 hours | all modules plus breaks and discussion |
| Advanced architecture session | 4 hours | all modules, judge calibration, custom SQL, production design |

## Preparation checklist

Complete this at least one day before delivery:

- [ ] Run the [Docker Validation Report](docker-validation.md) sign-off checks.
- [ ] Validate Docker image pulls on the participant network.
- [ ] Confirm ports 3000, 3080, 4000, 8123, and 9000 are not blocked or occupied.
- [ ] Decide which of the four ClickHouse/model combinations the audience will use.
- [ ] Validate ClickHouse Cloud IP allow lists and ports 8443/9440 when applicable.
- [ ] Confirm external credentials have workshop-safe quotas and rotation plans.
- [ ] Run the exact selected combination from a clean environment.
- [ ] Test `Workshop LiteLLM` from the Langfuse Playground.
- [ ] Import the supplied CSV and complete one prompt experiment.
- [ ] Confirm the TypeScript evaluator dispatcher is visible and executes.
- [ ] Decide whether LLM-as-a-Judge is included or skipped.
- [ ] Prepare a clean fallback laptop or prebuilt environment for demo continuity.
- [ ] Do not distribute a shared `.env` containing real credentials.

## Data and credential briefing

State this before setup:

- Only synthetic Acme data belongs in the workshop.
- Anthropic receives prompts when Anthropic mode is selected.
- ClickHouse Cloud receives Langfuse observation data when Cloud mode is selected, even if inference is local.
- A local-model path is not automatically a fully local data path.
- The local code evaluator runner executes trusted TypeScript inside the worker and is not sandboxed.
- Screenshots and support logs must not expose `.env`, API keys, or passwords.

## Suggested full agenda

| Time | Activity |
| ---: | --- |
| 00:00–00:10 | Architecture, data boundary, learning goals |
| 00:10–00:30 | Module 00 setup and LLM connection |
| 00:30–00:45 | Module 01 tracing |
| 00:45–01:00 | Module 02 prompt management |
| 01:00–01:15 | Module 03 monitoring |
| 01:15–01:25 | Break / catch-up |
| 01:25–01:40 | Module 04 dataset |
| 01:40–02:05 | Module 05 baseline experiment |
| 02:05–02:20 | Module 06 candidate comparison |
| 02:20–02:45 | Module 07 human review and optional judge |
| 02:45–03:05 | Module 08 ClickHouse analytics |
| 03:05–03:20 | Module 09 production design and close |

CPU-local experiments may require more time. Start local model pulls before the architecture introduction when bandwidth is constrained.

## Teaching narrative by module

### 00 — Setup

Core point: resource detection limits the menu, but the user still chooses the model. Anthropic and local model paths are mutually exclusive; Cloud and local ClickHouse paths are mutually exclusive.

Ask learners to predict the expected running services before `docker compose ps`.

Common failure: Langfuse LLM Connection uses `localhost`. Remind learners that the call originates inside the Langfuse container; the correct Base URL is `http://litellm:4000/v1`.

If Langfuse reports `Blocked IP address detected`, confirm both application containers received `LANGFUSE_LLM_CONNECTION_WHITELISTED_HOST=litellm`. This exact-host allowlist is required for the private Compose address; do not broaden it to arbitrary internal destinations.

### 01 — Observability

Core point: a trace helps explain one request; it does not say whether the behavior is good across a population.

Demo rhythm:

1. Send a normal request.
2. Find the generation.
3. Walk left to right: input → model → output → latency/usage → metadata/tags.
4. Prove the route using observation name and service list.

Avoid spending time on every field. Keep asking, “What operational question does this field answer?”

### 02 — Prompt Management

Core point: versions are history; labels are deployment pointers.

Do not promote the draft early. The undeployed candidate is essential for the experiment story.

Ask: “What evidence would justify moving `production`?” The desired answer is a dataset run plus review, not a nicer-looking diff.

### 03 — Monitoring

Core point: start with signals that identify traces worth reading. Do not create an impressive dashboard before agreeing on what the metric means.

The all-caps rule should intentionally produce false positives. Use that limitation to motivate human review and semantic evaluation.

If code evaluator options are absent, verify both `langfuse-web` and `langfuse-worker` received:

```text
LANGFUSE_CODE_EVAL_DISPATCHER=insecure-local
QUEUE_CONSUMER_CODE_EVAL_EXECUTION_QUEUE_IS_ENABLED=true
```

Then recreate both services.

### 04 — Datasets

Core point: a golden dataset is reviewed product knowledge, not a random trace dump.

Inspect the out-of-scope and security rows with the group. Discuss why risk metadata matters even when the first metric does not use it.

The best learner action in this module is adding one observed failure with a corrected expected output.

### 05 — Experiments

Core point: deterministic and semantic evaluators answer different questions. A metric can be reproducible and still incomplete.

Keep all model settings fixed. If local inference is slow, reduce the dataset temporarily to five items but include one normal, one high-risk, and one out-of-scope case.

Require learners to read low-scoring outputs before proposing a change.

### 06 — Evaluate a Change

Core point: change one variable, rerun the same cases, inspect regressions, and write the decision.

The candidate does not need to win. A `DO NOT SHIP` result is valid workshop completion if the evidence is sound.

Ask one group to argue for shipping and another to argue against it using the same run data.

### 07 — Human and LLM Evaluation

Core point: human review defines/calibrates quality; judge models scale a rubric but do not replace ownership.

Run the optional judge only when the selected backend reliably supports structured tool calling. For a small local model, explicitly skip and explain the architectural contract instead of changing providers behind the learner's back.

The most valuable discussion is evaluator disagreement. Ask which evaluator is wrong, whether the rubric is ambiguous, and what new dataset item would reduce uncertainty.

### 08 — ClickHouse Analytics

Core point: the UI serves operational workflows; SQL enables cross-cutting analysis and integration.

Show `DESCRIBE TABLE` before analytical queries. Explain replacing tables, `FINAL`, and logical deletion. Then reconcile one UI experiment average with SQL.

For Cloud delivery, use the SQL Console and never display the password. For local delivery, use the included `docker compose exec` command.

### 09 — Wrap-up

Core point: the workshop is a quality-loop pattern, not a production reference architecture.

Have each learner name one workflow, one failure signal, one dataset owner, and one release gate they would implement next.

## Checkpoint answer key

| Checkpoint | Expected evidence |
| --- | --- |
| Route | `sonnet/response` with no Ollama, or `local/response` with Ollama |
| Prompt | v1 deployed, v2 candidate, same `policy`/`question` variables |
| Live monitor | normal input false; `NOTHINGWORKS` true |
| Dataset | 10 imported cases plus optional observed failure |
| Baseline | completed outputs and keyword recall scores |
| Candidate | same settings, different prompt version |
| Human review | two configured dimensions and comments |
| Judge | optional; mapped variables and calibration sample |
| ClickHouse | route/score/run query returns learner artifacts |
| Decision | ship/no-ship plus rollback and next case |

Model outputs and score values are intentionally not fixed answers. The correct outcome is reproducible evidence and defensible interpretation.

## Recovery playbook

### A learner is behind during image/model pull

Pair them with a completed environment for UI modules. Do not share external API keys in chat. Resume their own environment during the break.

### Playground works from host curl but not Langfuse

Check the internal Base URL and gateway key. From `langfuse-web`, `litellm` must resolve on the Compose network.

### Evaluator scores are pending

Check target type, dataset/name filter, enable state, then worker logs. Evaluation is asynchronous.

### Local model cannot complete a judge call

Skip the optional judge branch. Continue with code evaluator, score configs, annotation queue, and ClickHouse analysis. Do not introduce fallback.

### Existing login password differs from `.env`

The existing MongoDB-backed LibreChat user is preserved on restart. Use the original password or reset the local workshop volumes in a controlled way. PostgreSQL credentials are synchronized automatically; LibreChat user passwords are not.

### A clean restart is required

With explicit learner confirmation that local data can be discarded:

```bash
docker compose down -v
mv .env ".env.backup.$(date +%Y%m%d-%H%M%S)"
./setup.sh
```

This does not remove ClickHouse Cloud data.

## Post-workshop cleanup

- Stop or delete local containers as agreed.
- Remove Cloud IP allow-list entries created only for the event.
- Rotate exposed or shared credentials.
- Apply the organization's retention process to Cloud traces.
- Collect feedback on model download time, UI wording, and evaluator completion time.
- Record the exact Langfuse image, model, and ClickHouse version used for the delivery.

## Official references

- [Langfuse official workshop](https://langfuse.com/workshop)
- [Evaluation core concepts](https://langfuse.com/docs/evaluation/core-concepts)
- [Prompt Management](https://langfuse.com/docs/prompt-management/overview)
- [Datasets](https://langfuse.com/docs/evaluation/experiments/datasets)
- [Experiments via UI](https://langfuse.com/docs/evaluation/experiments/experiments-via-ui)
- [Code evaluators](https://langfuse.com/docs/evaluation/evaluation-methods/code-evaluators)
- [Self-hosted code evaluator configuration](https://langfuse.com/self-hosting/configuration/code-evaluators)
- [LLM-as-a-Judge](https://langfuse.com/docs/evaluation/evaluation-methods/llm-as-a-judge)
- [Annotation queues](https://langfuse.com/docs/evaluation/evaluation-methods/annotation-queues)
- [LLM Connections](https://langfuse.com/docs/administration/llm-connection)
