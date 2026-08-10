-- LLMOps in a Box: Langfuse v4 quality-loop workbook
-- Run in the Langfuse ClickHouse database selected during setup.
-- Langfuse v4 writes current trace and observation data to events_core.
-- Versioned replacing tables require FINAL plus is_deleted = 0 to avoid
-- counting obsolete row versions and logical deletions.

SELECT '1) Observation volume by route and model' AS section;
SELECT
    name,
    type,
    coalesce(nullIf(provided_model_name, ''), '(unknown)') AS model,
    count() AS observations
FROM events_core FINAL
WHERE is_deleted = 0
  AND start_time >= now() - INTERVAL 7 DAY
GROUP BY name, type, model
ORDER BY observations DESC;

SELECT '2) Latency, usage, and cost by generation name' AS section;
SELECT
    name,
    count() AS n,
    round(quantile(0.50)(dateDiff('millisecond', start_time, end_time)), 1) AS p50_ms,
    round(quantile(0.95)(dateDiff('millisecond', start_time, end_time)), 1) AS p95_ms,
    sum(usage_details['input']) AS input_tokens,
    sum(usage_details['output']) AS output_tokens,
    round(sum(total_cost), 6) AS total_cost
FROM events_core FINAL
WHERE is_deleted = 0
  AND type = 'GENERATION'
  AND end_time IS NOT NULL
  AND start_time >= now() - INTERVAL 7 DAY
GROUP BY name
ORDER BY n DESC;

SELECT '3) Unified score inventory' AS section;
SELECT
    source,
    name,
    data_type,
    count() AS n,
    countIf(observation_id IS NOT NULL) AS observation_scores,
    countIf(trace_id IS NOT NULL) AS trace_scores,
    countIf(dataset_run_id IS NOT NULL) AS experiment_scores
FROM scores FINAL
WHERE is_deleted = 0
GROUP BY source, name, data_type
ORDER BY source, name;

SELECT '4) Numeric score distributions' AS section;
SELECT
    name,
    count() AS n,
    round(avg(value), 3) AS mean,
    round(quantile(0.50)(value), 3) AS p50,
    round(quantile(0.90)(value), 3) AS p90,
    round(min(value), 3) AS min,
    round(max(value), 3) AS max
FROM scores FINAL
WHERE is_deleted = 0
  AND data_type IN ('NUMERIC', 'BOOLEAN')
GROUP BY name
ORDER BY name;

SELECT '5) Experiment run comparison' AS section;
SELECT
    e.experiment_name AS run,
    s.name AS metric,
    count() AS n,
    round(avg(s.value), 3) AS avg_value,
    countIf(e.level = 'ERROR') AS item_errors
FROM scores AS s FINAL
INNER JOIN events_core AS e FINAL
    ON s.observation_id = e.span_id
WHERE s.is_deleted = 0
  AND e.is_deleted = 0
  AND e.experiment_name != ''
  AND s.data_type IN ('NUMERIC', 'BOOLEAN')
GROUP BY run, metric
ORDER BY metric, run;

SELECT '6) Prompt-version performance' AS section;
SELECT
    g.prompt_name AS prompt,
    toString(g.prompt_version) AS version,
    s.name AS metric,
    countDistinct(s.id) AS n,
    round(avg(s.value), 3) AS avg_value
FROM scores AS s FINAL
INNER JOIN events_core AS g FINAL
    ON s.trace_id = g.trace_id
WHERE s.is_deleted = 0
  AND g.is_deleted = 0
  AND g.type = 'GENERATION'
  AND g.prompt_name != ''
  AND s.data_type IN ('NUMERIC', 'BOOLEAN')
GROUP BY prompt, version, metric
ORDER BY prompt, metric, version;

SELECT '7) Per-trace agreement across workshop signals' AS section;
SELECT
    trace_id,
    anyIf(value, name = 'workshop_keyword_recall') AS keyword_recall,
    anyIf(value, name = 'workshop_answer_quality') AS human_quality,
    anyIf(string_value, name = 'workshop_groundedness') AS human_groundedness,
    anyIf(string_value, name = 'workshop_llm_groundedness') AS judge_groundedness
FROM scores FINAL
WHERE is_deleted = 0
  AND trace_id IS NOT NULL
  AND name IN (
      'workshop_keyword_recall',
      'workshop_answer_quality',
      'workshop_groundedness',
      'workshop_llm_groundedness'
  )
GROUP BY trace_id
HAVING count() >= 2
ORDER BY trace_id
LIMIT 100;

SELECT '8) Daily quality trend' AS section;
SELECT
    toDate(timestamp) AS day,
    name,
    count() AS n,
    round(avg(value), 3) AS avg_value
FROM scores FINAL
WHERE is_deleted = 0
  AND data_type IN ('NUMERIC', 'BOOLEAN')
GROUP BY day, name
ORDER BY day, name;
