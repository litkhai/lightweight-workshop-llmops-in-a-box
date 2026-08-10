# 08 — Analyze the Quality Loop in ClickHouse

**[Previous: Human and LLM Evaluation](07-human-and-llm-evaluation.md) · [Workshop home](README.md) · [Next: Wrap-up](09-wrap-up.md)**

## Goal

Query Langfuse's analytical model directly and show how observations, prompt versions, experiment runs, automated scores, and human annotations can be analyzed together.

## Storage model

Langfuse uses two primary databases in this stack:

| Store | Examples |
| --- | --- |
| PostgreSQL | organizations, projects, users, prompts, datasets, annotation queue definitions |
| ClickHouse | `events_core` traces/observations, scores, experiment context, analytical projections |

The final quality signals converge in ClickHouse even when their creation workflows differ.

## Read the SQL workbook

Open [`sql/quality-loop.sql`](sql/quality-loop.sql). It covers:

1. observation volume by route and model
2. latency, token, and cost summaries
3. score inventory by source and data type
4. numeric score distributions
5. experiment run comparison
6. prompt-version score comparison
7. human versus automated score agreement
8. daily quality trends

The SQL reads Langfuse v4's versioned `events_core` and `scores` tables with `FINAL` and filters `is_deleted = 0`. These tables use replacing semantics; omitting those clauses can count old row versions or deleted records. Legacy projections such as `observations` or `dataset_run_items_rmt` may still exist after an upgrade, but current SDK experiments carry their run context in `events_core.experiment_*` columns.

## Run against local ClickHouse

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

This command is available only when `CLICKHOUSE_MODE=local`.

## Run against ClickHouse Cloud

Option A: open the ClickHouse Cloud SQL Console, select the database entered during setup, and run sections from `quality-loop.sql`.

Option B: if `clickhouse-client` is installed locally:

```bash
set -a
source .env
set +a

cloud_host="${CLICKHOUSE_URL#https://}"
cloud_host="${cloud_host%%:*}"

clickhouse-client \
  --host "$cloud_host" \
  --secure \
  --port 9440 \
  --user "$CLICKHOUSE_USER" \
  --password "$CLICKHOUSE_PASSWORD" \
  --database "$CLICKHOUSE_DB" \
  --multiquery < workshop/sql/quality-loop.sql
```

Avoid copying credentials into shell history. The generated `.env` remains sensitive.

## Investigation exercises

### A. Route and performance

Compare `sonnet/response` or `local/response` latency and token usage. Explain which part is caused by model execution and which part could be gateway or queue overhead.

### B. Experiment evidence

Find `baseline-v1` and `candidate-v2` in the experiment query. Compare averages, count, and error coverage. Reconcile the SQL result with the Langfuse UI.

### C. Prompt attribution

Group scores by `prompt_name` and `prompt_version`. If values are missing, inspect whether the experiment observation was linked to the managed prompt version.

### D. Evaluator agreement

Find observations with both `workshop_keyword_recall` and a human or judge score. Identify one agreement and one disagreement.

### E. Operational question

Write one new query that answers a production question, for example:

- Which model route has the highest p95 latency?
- Are high-risk cases scoring worse than low-risk cases?
- Is all-caps frustration increasing by day?
- Which prompt version has the best quality per token?
- Which evaluator frequently disagrees with humans?

## Why query ClickHouse directly

The Langfuse UI is the right surface for trace debugging and day-to-day evaluation workflows. Direct ClickHouse access becomes useful when you need:

- organization-specific segmentation
- cross-signal joins not present in a standard view
- large-scale distribution or trend analysis
- integration with an existing BI or anomaly-detection stack
- schema-level verification during incident response

Treat internal tables as versioned product storage. Inspect `DESCRIBE TABLE` after upgrades and avoid building irreversible production dependencies on undocumented columns without a compatibility plan.

## Checkpoint

- [ ] The SQL workbook runs against the selected ClickHouse backend.
- [ ] You reconciled one experiment metric between SQL and the UI.
- [ ] You found at least one score source and data type.
- [ ] You explained why `FINAL` and `is_deleted = 0` matter.
- [ ] You wrote one additional business-oriented query.

Continue to [09 — Wrap-up](09-wrap-up.md).
