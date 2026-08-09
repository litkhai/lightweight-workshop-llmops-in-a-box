# LLMOps in a Box — Lightweight Workshop Edition

A self-contained, laptop-friendly LLMOps stack for hands-on workshops and self-study.
Everything runs locally: no cloud account required, no per-token cost, no data leaving your machine.

---

## What this is

This repository is a stripped-down, beginner-accessible version of [llmops-in-a-box](https://github.com/litkhai/llmops-in-a-box) — a production-oriented LLMOps stack built around LiteLLM, Langfuse, and ClickHouse.

The full stack is designed for teams running LLMs in production on AWS, with Terraform, domain names, and a multi-phase build-up of capability. This workshop edition removes the infrastructure ceremony and focuses on the core concepts that matter most:

1. **A gateway layer** sits between every client and every model — routing, policy, and observability happen in one place without touching application code.
2. **Language-aware routing** rewrites the model field based on Unicode script detection in the user's message, sending different languages to different models — with zero changes at the client.
3. **Traces appear in Langfuse** for every completion: prompt, response, latency, token counts, the routing decision that was made, and which model actually answered.

The model is a small, CPU-capable open-weight model served by Ollama. You do not need a GPU, an API key, or an internet connection after the initial image and model pull.

---

## Architecture

```
Your client (Python / curl / any OpenAI SDK)
        │
        │  POST /v1/chat/completions
        │  model: "auto"          ← single alias for everything
        ▼
┌─────────────────────────────────────────────────────────────────┐
│  LiteLLM  (port 4000)                                           │
│                                                                 │
│  UnifiedRouter (callbacks.py)                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  async_pre_call_hook                                     │   │
│  │  · detect dominant Unicode script of last user message  │   │
│  │  · rewrite data["model"]:                               │   │
│  │      Korean (Hangul)  →  claude-sonnet  (if key set)    │   │
│  │      English / CJK   →  local  (Ollama)                 │   │
│  │  · write routing span to Langfuse trace                 │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  async_log_success_event                                        │
│  · send trace + generation span to Langfuse (SDK, direct)      │
│  · completion calls only — management API calls are filtered    │
└──────────────────┬─────────────────────────┬───────────────────┘
                   │                         │
         model: local                model: claude-sonnet
                   │                         │
                   ▼                         ▼
          Ollama (in Docker)          Anthropic API
          qwen2.5:1.5b                (optional)
          CPU, ~1 GB RAM


LiteLLM ──────── traces ──────────▶ Langfuse (port 3000)
                                    └── Postgres (metadata)
```

### Why this architecture?

**Single entrypoint.** Every client sends requests to `http://localhost:4000/v1` with `model="auto"`. The gateway decides which model receives the request. Clients never need to know about Ollama, Anthropic, or any other backend — changing the model is a gateway config change, not a code change.

**Routing at the pre-call hook.** LiteLLM's `CustomLogger.async_pre_call_hook` runs before the actual LLM call. This is where the `UnifiedRouter` callback rewrites the `model` field based on language detection. The router inspects the last user message, counts Unicode code points by script family (Hangul, CJK/kana, Latin), and picks a model. The entire detection is a pure Python function — no additional network call, under 1 ms.

**Observability at the gateway, not in the app.** Langfuse traces are created by the gateway callback, not by application code. This means:
- Every client — Python scripts, curl, LibreChat, LangChain agents — gets traced automatically, with no instrumentation in the application.
- Failures are traced, not just successes.
- The routing *decision* is a child span of the LLM generation span, so you can see exactly which language was detected and why a particular model was chosen.

**Manual SDK logging, not the built-in callback.** LiteLLM has a `success_callback: [langfuse]` feature that logs every proxy request to Langfuse automatically. We do not use it here. The built-in callback logs management API calls (like `/v2/user/info`) with a placeholder `"default-message-value"` as input, filling Langfuse with noise. Instead, the `UnifiedRouter.async_log_success_event` uses the Langfuse Python SDK directly and filters to `call_type in ("completion", "acompletion")` only.

---

## Stack components

| Component | Image | Port | Purpose |
|-----------|-------|------|---------|
| **Ollama** | `ollama/ollama` | internal | Serves local CPU models via OpenAI-compatible API |
| **LiteLLM** | `ghcr.io/berriai/litellm:main-stable` | 4000 | Gateway, routing, Langfuse logging |
| **Langfuse** | `langfuse/langfuse` | 3000 | Trace visualization and analytics |
| **Postgres** | `postgres:16-alpine` | internal | Langfuse metadata storage |

Langfuse uses only Postgres here — not ClickHouse, Redis, or MinIO. This keeps the stack to four containers and makes it comfortable on a laptop with 8 GB RAM.

---

## Prerequisites

- **Docker Desktop** (Mac / Windows) or **Docker Engine + Compose** (Linux)
- ~3 GB free disk space for images + the default model
- ~2 GB RAM free while running (4 GB recommended for the 3B model)
- No GPU required

---

## Quick start

### 1. Clone and configure

```bash
git clone https://github.com/litkhai/lightweight-workshop-llmops-in-a-box.git
cd lightweight-workshop-llmops-in-a-box
cp .env.example .env
```

The default `.env` works out of the box. No edits required for a purely local setup.

### 2. Start the stack

```bash
docker compose up -d
```

Wait about 30–60 seconds for Langfuse to finish its database migration. You can watch progress with:

```bash
docker compose logs -f langfuse
# ready when you see: "✓ Ready on http://0.0.0.0:3000"
```

### 3. Pull the model

```bash
./scripts/pull-model.sh
# pulls qwen2.5:1.5b (~1 GB) into the Ollama container
```

This only needs to run once. The model is stored in a Docker volume and persists across restarts.

### 4. Send your first request

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:4000/v1",
    api_key="sk-workshop-key",
)

response = client.chat.completions.create(
    model="auto",
    messages=[{"role": "user", "content": "Explain what a LLM gateway does in two sentences."}],
)
print(response.choices[0].message.content)
```

Or with curl:

```bash
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-workshop-key" \
  -H "Content-Type: application/json" \
  -d '{"model": "auto", "messages": [{"role": "user", "content": "What is LLMOps?"}]}'
```

### 5. Open Langfuse

Go to [http://localhost:3000](http://localhost:3000) and log in with:

- Email: `workshop@example.com`
- Password: `workshop123`

Navigate to **Tracing**. The request you just sent should appear with:
- The full prompt and completion
- Latency and token counts
- A `routing` child span showing which script was detected and which model was chosen

---

## Language routing in action

The gateway routes requests based on the dominant Unicode script of the last user message. Try sending messages in different languages and observe the `routed` field in the Langfuse trace:

```python
messages = [
    "Explain ClickHouse in one sentence.",           # Latin → local (Ollama)
    "ClickHouse를 한 문장으로 설명해줘.",              # Hangul → local (no API key)
    "用一句话解释一下 ClickHouse。",                   # CJK → local (Ollama)
]

for msg in messages:
    response = client.chat.completions.create(
        model="auto",
        messages=[{"role": "user", "content": msg}],
    )
    print(f"[{msg[:30]}...] → {response.choices[0].message.content[:80]}")
```

In Langfuse, each trace will have a `routing` span. Open one and look at the span's `input` and `output` fields — you will see `detected_script` and `routed` logged there.

### Enabling cloud routing (optional)

If you add an Anthropic API key, Korean (Hangul-heavy) messages will be routed to `claude-sonnet` instead of the local model. This lets you compare quality and latency side by side in the same Langfuse project.

Add to your `.env`:

```
ANTHROPIC_API_KEY=sk-ant-...
```

Then restart LiteLLM:

```bash
docker compose restart litellm
```

Now re-run the Korean message and check the trace — `routed` should show `claude-sonnet`, and `actual` should confirm which model answered.

---

## Changing the local model

The default is `qwen2.5:1.5b`. To use a different model:

```bash
# Pull an alternative
./scripts/pull-model.sh qwen2.5:3b

# Update the model name in config
# Edit config/litellm_config.yaml:
#   model: ollama/qwen2.5:1.5b  →  model: ollama/qwen2.5:3b

# Restart LiteLLM to pick up the change
docker compose restart litellm
```

Suggested models by use case:

| Model | Size | Notes |
|-------|------|-------|
| `qwen2.5:0.5b` | ~400 MB | Fastest; basic quality; good for slow machines |
| `qwen2.5:1.5b` | ~1 GB | **Default** — good balance |
| `qwen2.5:3b` | ~2 GB | Better reasoning; needs ≥8 GB RAM |
| `phi4-mini` | ~2.5 GB | Strong instruction-following |
| `gemma2:2b` | ~1.6 GB | Good multilingual quality |

---

## Project structure

```
.
├── docker-compose.yml          # All four services
├── .env.example                # Environment variable template
├── config/
│   ├── litellm_config.yaml     # Model list, routing config, gateway settings
│   └── callbacks.py            # UnifiedRouter: language routing + Langfuse logging
└── scripts/
    └── pull-model.sh           # Pull model into Ollama container
```

### `config/callbacks.py`

This is the heart of the workshop. The `LanguageRouter` class extends `litellm.CustomLogger` and provides three hooks:

- **`async_pre_call_hook`** — runs before the LLM call. Detects the dominant script, rewrites `data["model"]`, sets Langfuse metadata, and creates a `routing` span.
- **`async_log_success_event`** — runs after a successful LLM call. Logs the trace and generation span to Langfuse via the SDK. Skips non-completion call types to avoid noise.
- **`async_post_call_failure_hook`** — runs after a failed call. Logs an error trace to Langfuse.

### `config/litellm_config.yaml`

Defines the model list, timeout settings, and callback registration. Key points:
- `success_callback: []` — built-in Langfuse callback is intentionally disabled (see "Manual SDK logging" above).
- `callbacks: [callbacks.language_router]` — registers our custom callback.
- `fallbacks` — if `local` (Ollama) is unavailable and `ANTHROPIC_API_KEY` is set, requests fall back to `claude-sonnet`.

---

## Stopping and resetting

```bash
# Stop all containers (data is preserved in volumes)
docker compose down

# Stop and delete all data (volumes included)
docker compose down -v
```

---

## Relationship to the full stack

This repository is intentionally minimal. The [full llmops-in-a-box stack](https://github.com/litkhai/llmops-in-a-box) adds:

- AWS infrastructure (Terraform, EC2, Route 53)
- Langfuse backed by ClickHouse for high-volume trace analytics
- MinIO for image storage
- LibreChat as a full chat UI
- Image generation via Cloudflare Workers AI (FLUX.1-schnell)
- MCP tool integration (mcp-clickhouse for ClickHouse Cloud)
- RunPod Serverless for GPU-backed model serving (Phase 4)
- A multi-phase `stack.yaml` build system

If you want to go beyond the workshop, the full stack documentation is at [llmops-in-a-box docs](https://github.com/litkhai/llmops-in-a-box/tree/main/docs).
