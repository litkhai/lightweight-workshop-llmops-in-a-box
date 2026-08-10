# 09 — Close the Loop

**[Previous: ClickHouse Analytics](08-clickhouse-analytics.md) · [Workshop home](workshop-overview.md) · [Instructor guide](instructor-guide.md)**

## Goal

Summarize the evidence produced in the workshop, translate the laptop design into a production plan, and shut down or remove the environment safely.

## Tell the system story

You should now be able to narrate this sequence:

1. LibreChat sent a request using stable alias `auto`.
2. LiteLLM routed it to the one provider selected during setup—without fallback.
3. OpenTelemetry sent generation details to self-hosted Langfuse.
4. A production-like failure became a dataset item.
5. Prompt versions ran against the same golden dataset.
6. Code, human, and optional LLM-judge scores measured different quality dimensions.
7. A comparison produced a ship/no-ship decision.
8. ClickHouse exposed the complete analytical record.

## Evidence review

Complete the workshop evidence list:

- [ ] Trace/generation URL or ID
- [ ] Selected model route and proof
- [ ] Baseline prompt version
- [ ] Candidate prompt version
- [ ] Dataset name, size, and version time
- [ ] Baseline experiment run
- [ ] Candidate experiment run
- [ ] Deterministic evaluator result
- [ ] Human-review result
- [ ] Optional judge calibration result
- [ ] ClickHouse query result
- [ ] Ship/no-ship decision and rollback plan

## Production design discussion

The laptop stack demonstrates product behavior, not a production architecture. For a real deployment, decide:

| Area | Workshop | Production question |
| --- | --- | --- |
| Availability | single Docker host | How will web, worker, queues, and stores survive host/AZ loss? |
| Secrets | owner-only `.env` | Which secret manager and rotation process will be used? |
| ClickHouse | local volume or Cloud service | What retention, backup, sizing, region, and network controls are required? |
| PostgreSQL | local volume | What managed HA, backups, and recovery objectives are required? |
| Redis/MinIO | local containers | Which durable managed or HA services replace them? |
| Evaluator execution | trusted `insecure-local` | How will evaluator code be reviewed and sandboxed? |
| Model routing | one explicit backend | What retry policy is safe, and must fallback remain prohibited? |
| Access | one admin identity | What SSO, RBAC, tenant separation, and audit requirements apply? |
| Data | synthetic workshop content | What masking, residency, retention, and deletion policy applies? |
| Operations | manual health/log checks | Which SLOs, alerts, runbooks, and ownership model are required? |

## Minimum quality-loop operating model

For your own application, define:

1. **Owner** — who owns each prompt, dataset, evaluator, and ship decision?
2. **Signals** — which failures should be detected online?
3. **Golden set** — how do reviewed production failures enter the dataset?
4. **Release gate** — which score thresholds and high-risk cases block a change?
5. **Calibration** — how often are judges checked against human reviewers?
6. **Monitoring** — which quality, cost, and latency metrics are trended?
7. **Rollback** — how are prompt labels or model configuration reverted?
8. **Retention** — how long are raw prompts, outputs, and scores retained?

## Stop and preserve data

```bash
docker compose down
```

Restart later with:

```bash
./scripts/start.sh
```

Local Docker volumes and ClickHouse Cloud data remain intact.

## Delete local workshop data

> This is irreversible for local volumes.

```bash
docker compose down -v
```

This deletes project-local PostgreSQL, MongoDB, Redis, MinIO, local ClickHouse, LibreChat, and Ollama volume data. It does not delete Docker images or any Langfuse tables stored in ClickHouse Cloud.

## Clean ClickHouse Cloud separately

If Cloud was selected, follow your organization's approval and retention process to remove the workshop database or Langfuse tables. Never drop objects from a shared database without confirming ownership and scope.

## Protect credentials

- Delete unneeded `.env` backups securely.
- Rotate Anthropic keys or ClickHouse passwords exposed during screen sharing or troubleshooting.
- Do not commit `.env` or evaluator secrets.
- Remove workshop IP allow-list entries that are no longer needed.

## Next step

Repeat the loop on one narrow workflow from your own application using sanitized data. Start with ten reviewed cases, one deterministic metric, and one human rubric. Add semantic judges only after the human definition of quality is stable.

Workshop complete.
