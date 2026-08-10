# 00 — Workshop Setup

**[Workshop home](workshop-overview.md) · [Next: Observability](01-observability.md)**

## Goal

Start one of the four supported deployment combinations, verify its service boundary, and configure Langfuse to call the workshop's stable `auto` model through LiteLLM.

## Choose a deployment

| ClickHouse | Model | External credentials | Local optional services | Data boundary |
| --- | --- | --- | --- | --- |
| Cloud | Anthropic | ClickHouse Cloud + Anthropic | none | Prompts go to Anthropic; observations go to ClickHouse Cloud |
| Cloud | local | ClickHouse Cloud | Ollama | Inference is local; observations still go to ClickHouse Cloud |
| local OSS | Anthropic | Anthropic | ClickHouse | Prompts go to Anthropic; observations stay local |
| local OSS | local | none | ClickHouse + Ollama | Inference and workshop data stay local |

Local inference is not the same as fully local data. If prompt content must not leave the laptop, choose local ClickHouse and a local model and use only approved sample data.

## Prerequisites

- macOS, Linux, or WSL2
- Docker Desktop or Docker Engine with Compose v2
- `bash`, `openssl`, and `curl`
- Internet access for the first image pull
- About 5 GB of free disk for an Anthropic path
- About 7–10 GB of free disk for a local-model path

The setup filters local models using memory available to Docker, not advertised laptop memory. Docker Desktop users can check **Settings → Resources → Memory**.

## Preflight

From the repository root:

```bash
docker version
docker compose version
docker info --format 'Docker memory: {{.MemTotal}} bytes'
docker compose config --quiet
```

Resolve any Docker daemon or Compose error before continuing.

The workshop publishes only loopback ports:

| Application | URL |
| --- | --- |
| LibreChat | `http://localhost:3080` |
| Langfuse | `http://localhost:3000` |
| LiteLLM | `http://localhost:4000` |

## Run interactive setup

```bash
./setup.sh
```

The prompts are ordered intentionally:

1. Workshop login identity
2. ClickHouse Cloud or local ClickHouse
3. Anthropic or a local model
4. Docker memory and explicit model selection, only when Anthropic is not used
5. Start now or later

### Selection matrix

| Target | `Use ClickHouse Cloud?` | `Do you have an Anthropic API key?` |
| --- | --- | --- |
| Cloud + Anthropic | `y` | `y` |
| Cloud + local model | `y` | `n` |
| local ClickHouse + Anthropic | `n` | `y` |
| local ClickHouse + local model | `n` | `n` |

For ClickHouse Cloud, enter the hostname without protocol or port, database, user, and password. The Docker host must be allowed by the Cloud IP access list, and outbound ports `8443` and `9440` must be open. Use a workshop-specific database when possible because Langfuse creates schema objects and writes trace data.

For a local model, setup shows only choices that fit the detected or entered Docker memory. Every menu row includes download size. Setup never selects a runtime fallback.

| Model | Download | Cloud ClickHouse threshold | Local ClickHouse threshold |
| --- | ---: | ---: | ---: |
| `gemma3:1b` | 0.8 GB | 4 GB | 4 GB |
| `qwen3:1.7b` | 1.4 GB | 7 GB | 7 GB |
| `llama3.2:3b` | 2.0 GB | 9 GB | 13 GB |
| `phi4-mini` | 2.5 GB | 12 GB | 20 GB |
| `qwen3.5:4b` | 3.4 GB | 16 GB | 24 GB |

The generated `.env` has owner-only permissions and is excluded from Git. Do not share it: it contains the workshop login, internal secrets, and any external credentials you entered.

## Start the stack

If setup did not start it automatically:

```bash
./scripts/start.sh
```

Wait for `Workshop is ready`. A first local-model pull may take several minutes.

Verify services:

```bash
docker compose ps
docker compose ps --services --status running | sort
```

| Combination | Expected running services |
| --- | --- |
| Cloud + Anthropic | 8 base services; no `clickhouse`, no `ollama` |
| Cloud + local | 8 base services + `ollama`; no `clickhouse` |
| local + Anthropic | 8 base services + `clickhouse`; no `ollama` |
| local + local | 8 base services + `clickhouse` + `ollama` |

The base services are `postgres`, `redis`, `minio`, `mongodb`, `langfuse-web`, `langfuse-worker`, `litellm`, and `librechat`.

Verify endpoints:

```bash
curl --fail --silent http://localhost:3000/api/public/health
curl --fail --silent http://localhost:4000/health/readiness
curl --fail --silent --output /dev/null http://localhost:3080/
echo "Workshop endpoints are ready"
```

## Sign in

Open both applications and use the email/password entered in setup:

- LibreChat: `http://localhost:3080`
- Langfuse: `http://localhost:3000`

Langfuse initializes the organization and project as **LLMOps Workshop**. LibreChat registration is disabled; `start.sh` creates the initial account.

## Create the Langfuse → LiteLLM connection

This connection lets the Langfuse Playground, prompt experiments, and optional evaluators use the exact provider path selected during setup.

1. In Langfuse, open **Project Settings → LLM Connections**.
2. Choose **Add new LLM API key**.
3. Select **OpenAI** as the compatible provider.
4. Name the connection `Workshop LiteLLM`.
5. Enter the generated `LITELLM_MASTER_KEY` as the API key.
6. Under advanced settings, set Base URL to `http://litellm:4000/v1`.
7. Add the custom model name `auto`.
8. Leave **Use Responses API** disabled; this gateway path uses Chat Completions.
9. Save and test a simple request in the Playground.

`http://localhost:4000/v1` is wrong in this form because Langfuse calls the gateway from inside its container. The Compose service name `litellm` is reachable on the internal network.

The Compose stack explicitly allowlists only the internal `litellm` hostname for this connection. Langfuse otherwise blocks private-network Base URLs as SSRF protection. Keep this allowlist narrow; do not use a wildcard.

To reveal the generated gateway key only in your private terminal:

```bash
set -a
source .env
set +a
printf '%s\n' "$LITELLM_MASTER_KEY"
```

Do not paste the value into notes or screenshots.

## Checkpoint

- [ ] The expected services are running.
- [ ] Langfuse, LiteLLM, and LibreChat health checks pass.
- [ ] You can sign in to LibreChat and Langfuse.
- [ ] `Workshop LiteLLM` uses `http://litellm:4000/v1` and model `auto`.
- [ ] A Playground test returns a non-empty response.

Continue to [01 — Observability](01-observability.md).
