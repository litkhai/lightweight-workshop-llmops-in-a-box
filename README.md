# LLMOps in a Box — Self-Service Workshop

**[Overview](README.md) · [Documentation site](https://litkhai.github.io/lightweight-workshop-llmops-in-a-box/) · [Workshop](workshop/README.md) · [Workshop setup](workshop/00-setup.md) · [Instructor guide](workshop/instructor-guide.md) · [Docker validation](workshop/docker-validation.md)**

A single, self-guided workshop stack for running an LLM application through a gateway and inspecting every model call. There are no phases and no cloud account is required unless you choose Anthropic or ClickHouse Cloud during setup.

Start the English-only, self-guided course from the dedicated [Workshop](workshop/README.md) section. It covers setup, observability, prompt management, monitoring, datasets, experiments, automated and human evaluation, and direct ClickHouse analysis.

## Documentation site

The workshop is published as a searchable [GitHub Pages documentation site](https://litkhai.github.io/lightweight-workshop-llmops-in-a-box/). The site uses the Markdown files in `workshop/` directly, so the repository and website never maintain separate copies of the course.

To preview the site locally:

```bash
python3 -m venv .venv-docs
source .venv-docs/bin/activate
pip install --requirement requirements-docs.txt
mkdocs serve
```

Open `http://127.0.0.1:8000`. A push to `main` that changes the workshop, theme, MkDocs configuration, or Pages workflow rebuilds and deploys the site automatically.

## What you get

```text
Browser
  └─ LibreChat :3080
       └─ LiteLLM :4000
            ├─ Anthropic Sonnet (when an API key is supplied)
            └─ Ollama + selected local model (otherwise)
                 └─ Langfuse v4 :3000
                      ├─ PostgreSQL (always local)
                      ├─ Redis (local)
                      ├─ MinIO / S3-compatible storage (local)
                      └─ ClickHouse Cloud or local ClickHouse
```

LibreChat only knows the stable LiteLLM model alias `auto`. Setup decides whether that alias uses Sonnet or the selected local Ollama model. LiteLLM exports OpenTelemetry observations to Langfuse v4 for prompts, responses, token usage, latency, errors, and model metadata.

## Requirements

- Docker Desktop or Docker Engine with Compose v2
- `bash` and `openssl`
- Internet access for the first image pull
- Anthropic mode: approximately 5 GB free disk space recommended
- Fully local mode: approximately 7-10 GB free disk and at least 8 GB of memory available to Docker

Local model downloads range from approximately 0.8 GB to 3.4 GB. All menu options can run on CPU; larger models respond more slowly.

Use the memory allocated to Docker, not the laptop's advertised physical memory. On Docker Desktop, check **Settings → Resources → Memory**. This Compose file does not configure GPU passthrough, so recommendations assume CPU inference.

## Start the workshop

Run the interactive setup:

```bash
./setup.sh
```

It asks for:

1. Workshop user ID, email, and password
2. ClickHouse Cloud or local ClickHouse
3. Anthropic API key or, when no key is supplied, Docker memory detection and an explicit choice from the models that fit
4. Whether to start the stack immediately

The generated `.env` is readable only by its owner and is excluded from Git. Internal PostgreSQL, ClickHouse, Redis, MinIO, JWT, Langfuse, and LiteLLM secrets are generated independently instead of reusing the workshop password.

Pressing Enter through the account prompts uses the workshop defaults: `admin`, `admin@example.com`, and `Clickhouse_4U`. These public defaults are intended only for a laptop workshop environment.

If you chose not to start immediately:

```bash
./scripts/start.sh
```

The start script launches the selected services, pulls the selected Ollama model when needed, and creates the initial LibreChat administrator. Langfuse initializes the same workshop identity automatically.

When an existing PostgreSQL volume is reused with a regenerated `.env`, the start script updates the persisted local PostgreSQL role to the new generated password without deleting data.

Open (all published ports bind to `127.0.0.1` only):

- LibreChat: [http://localhost:3080](http://localhost:3080)
- Langfuse: [http://localhost:3000](http://localhost:3000)
- LiteLLM API: [http://localhost:4000](http://localhost:4000)

Log into LibreChat and Langfuse with the email and password entered during setup.

## Setup choices

### ClickHouse Cloud

Enter the Cloud hostname, database, username, and password. Setup configures Langfuse with:

- HTTPS endpoint on port `8443`
- Native migration endpoint on port `9440`
- Migration TLS enabled

Allow connections from the Docker host in the ClickHouse Cloud IP access list. Langfuse v4 requires ClickHouse 25.12 or newer.

### Local ClickHouse

Setup enables the `local-clickhouse` Compose profile and starts `clickhouse/clickhouse-server:25.12`. Data is persisted in a Docker volume. The HTTP and native ports bind only to `127.0.0.1`.

### Anthropic Sonnet

When an Anthropic key is supplied, LiteLLM routes `auto` to `anthropic/claude-sonnet-4-5`. Ollama is not started.

### Local model selection

Without an Anthropic key, setup enables the `local-model` profile, detects the memory available to Docker, and asks the participant to choose from the models that fit. Each option includes its download size. The filter is more conservative when ClickHouse runs locally because ClickHouse and the model share Docker memory. Setup never selects a model automatically.

| Model | Download | Best fit |
| --- | ---: | --- |
| `gemma3:1b` | 0.8 GB | Very constrained laptops |
| `qwen3:1.7b` | 1.4 GB | Lightweight balanced default |
| `llama3.2:3b` | 2.0 GB | English instructions, summarization, and rewriting |
| `phi4-mini` | 2.5 GB | Reasoning and precise instruction adherence |
| `qwen3.5:4b` | 3.4 GB | Highest general quality offered by setup |

Qwen3 and Qwen3.5 enable reasoning by default in Ollama. The gateway sets `reasoning_effort: none` for every local deployment so short workshop requests return a visible answer promptly instead of spending their output budget on hidden reasoning. Participants can still study reasoning behavior later by changing the LiteLLM model configuration.

The workshop uses the following conservative availability thresholds. These are selection guardrails for the complete stack, not the model vendors' minimum requirements.

| Model | ClickHouse Cloud | Local ClickHouse |
| --- | ---: | ---: |
| `gemma3:1b` | 4 GB | 4 GB |
| `qwen3:1.7b` | 7 GB | 7 GB |
| `llama3.2:3b` | 9 GB | 13 GB |
| `phi4-mini` | 12 GB | 20 GB |
| `qwen3.5:4b` | 16 GB | 24 GB |

If two or more models are available, the default menu choice is `qwen3:1.7b`; the participant still makes the final selection.

## Test the gateway directly

Get the generated key from `.env`, then call the OpenAI-compatible endpoint:

```bash
set -a
source .env
set +a

curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"Explain an LLM gateway in two sentences."}]}'
```

Open Langfuse after the response and inspect the generated observation.

For a successful local request, verify all three outcomes:

1. The API returns HTTP `200` with a non-empty assistant message.
2. LiteLLM logs a successful `POST /v1/chat/completions` request.
3. Langfuse shows a new `GENERATION` observation with source `otel`.

## Changing the local model

The setup script is the preferred way to select a model. To change it manually without replacing other settings:

```bash
# Stop active requests, then edit OLLAMA_MODEL in .env.
./scripts/pull-model.sh llama3.2:3b

# Recreate LiteLLM so its model deployment reads the new value.
docker compose up -d --force-recreate litellm
```

`OLLAMA_MODEL` contains the Ollama tag without a provider prefix. Compose supplies the `ollama/` prefix to LiteLLM automatically.

## Troubleshooting

### Setup reports that `.env` already exists

Setup never overwrites credentials. Stop the stack, move `.env` to a backup location, and run `./setup.sh` again. Moving `.env` does not delete Docker volumes.

### A local response is slow

CPU inference can be slow on the first request while Ollama loads the model. Check the active model with `docker compose exec ollama ollama ps`. If memory pressure persists, rerun setup and choose a smaller model.

### A model returns an empty answer

Confirm that both local deployments in `config/litellm_config.yaml` retain `reasoning_effort: none`. This is required for predictable short responses from thinking-capable Qwen models. Then recreate LiteLLM.

### ClickHouse Cloud does not connect

Confirm that the Cloud service allows the Docker host's public IP and that outbound ports `8443` and `9440` are available. Inspect migrations with `docker compose logs langfuse-web langfuse-worker`.

### A service does not become healthy

```bash
docker compose ps
docker compose logs --tail=200 <service-name>
```

The most useful service names are `litellm`, `librechat`, `langfuse-web`, `langfuse-worker`, `postgres`, `redis`, `minio`, `clickhouse`, `mongodb`, and `ollama`.

## Operations

```bash
# Status
docker compose ps

# Follow logs
docker compose logs -f librechat litellm langfuse-web langfuse-worker

# Stop while preserving data
docker compose down

# Start again
./scripts/start.sh

# Delete all workshop data (irreversible)
docker compose down -v
```

To choose different setup options, stop the stack, move the existing `.env` somewhere safe, and run `./setup.sh` again. Existing Docker volumes are not automatically migrated between different ClickHouse configurations.

## Validation status

See the detailed [Docker Validation Report](workshop/docker-validation.md) for the reproducible test procedure, observed evidence, corrected issues, and delivery sign-off checklist.

This revision was validated against the following paths:

- Memory-based availability filtering and explicit selection across all five local models
- Local and Cloud ClickHouse profile selection
- Anthropic mode excluding Ollama
- Local model mode including Ollama
- Compose configuration rendering for all four ClickHouse/model deployment combinations
- Live requests through `auto` for both Anthropic Sonnet and a selected Ollama model
- Langfuse v4 ingestion of `sonnet/response` and `local/response` `GENERATION` observations
- LibreChat and Langfuse workshop account initialization
- End-to-end execution of all four combinations: ClickHouse Cloud or local ClickHouse, each paired with Anthropic or a local model

## Repository layout

```text
.
├── setup.sh                       # Interactive configuration
├── docker-compose.yml             # Complete workshop stack
├── .env.example                   # Local-only field reference; setup generates real secrets
├── workshop/                      # English learner modules, instructor notes, assets, SQL
│   ├── README.md                  # Dedicated workshop landing page
│   ├── 00-setup.md ... 09-wrap-up.md
│   ├── instructor-guide.md
│   ├── assets/                    # Dataset and paste-ready evaluators
│   └── sql/                       # Langfuse v4 ClickHouse analytics
├── config/
│   ├── callbacks.py               # Selects Sonnet or the local model for `auto`
│   ├── librechat.yaml             # LibreChat → LiteLLM connection
│   └── litellm_config.yaml        # Models, gateway, Langfuse OTEL callback
└── scripts/
    ├── start.sh                   # Start, pull model, initialize LibreChat user
    └── pull-model.sh              # Manually pull an Ollama model
```

## Langfuse v4 notes

This stack follows the Langfuse v4 self-hosted architecture. PostgreSQL stores application metadata; ClickHouse stores observations and scores; Redis handles queues and caching; MinIO stores incoming events and media; and separate web and worker containers run the application. PostgreSQL always stays local as required by this workshop.
