# LLMOps in a Box — Self-Service Workshop

**[Overview](README.md) · [Documentation site](https://litkhai.github.io/llmops-workshop/) · [Workshop](workshop/workshop-overview.md) · [Workshop setup](workshop/00-setup.md) · [Instructor guide](workshop/instructor-guide.md) · [Docker validation](workshop/docker-validation.md)**

[English](#english) | [한국어](#한국어)

---

## English

A single, self-guided workshop stack for running an LLM application through a gateway and inspecting every model call. There are no phases and no cloud account is required unless you choose Anthropic or ClickHouse Cloud during setup.

Start the English-only, self-guided course from the dedicated [Workshop](workshop/workshop-overview.md) section. It covers setup, observability, prompt management, monitoring, datasets, experiments, automated and human evaluation, and direct ClickHouse analysis.

### Documentation site

The workshop is published as a searchable [GitHub Pages documentation site](https://litkhai.github.io/llmops-workshop/). The site uses the Markdown files in `workshop/` directly, so the repository and website never maintain separate copies of the course.

To preview the site locally:

```bash
python3 -m venv .venv-docs
source .venv-docs/bin/activate
pip install --requirement requirements-docs.txt
mkdocs serve
```

Open `http://127.0.0.1:8000`. A push to `main` that changes the workshop, theme, MkDocs configuration, or Pages workflow rebuilds and deploys the site automatically.

### What you get

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

### Requirements

- Docker Desktop or Docker Engine with Compose v2
- `bash` and `openssl`
- Internet access for the first image pull
- Anthropic mode: approximately 5 GB free disk space recommended
- Fully local mode: approximately 7-10 GB free disk and at least 8 GB of memory available to Docker

Local model downloads range from approximately 0.8 GB to 3.4 GB. All menu options can run on CPU; larger models respond more slowly.

Use the memory allocated to Docker, not the laptop's advertised physical memory. On Docker Desktop, check **Settings → Resources → Memory**. This Compose file does not configure GPU passthrough, so recommendations assume CPU inference.

### Start the workshop

Check the machine first — Docker, memory, disk and free ports; it changes nothing:

```bash
scripts/preflight.sh
```

Then run the interactive setup:

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

### Setup choices

#### ClickHouse Cloud

Enter the Cloud hostname, database, username, and password. Setup configures Langfuse with:

- HTTPS endpoint on port `8443`
- Native migration endpoint on port `9440`
- Migration TLS enabled

Allow connections from the Docker host in the ClickHouse Cloud IP access list. Langfuse v4 requires ClickHouse 25.12 or newer.

#### Local ClickHouse

Setup enables the `local-clickhouse` Compose profile and starts `clickhouse/clickhouse-server:25.12`. Data is persisted in a Docker volume. The HTTP and native ports bind only to `127.0.0.1`.

#### Anthropic Sonnet

When an Anthropic key is supplied, LiteLLM routes `auto` to `anthropic/claude-sonnet-4-5`. Ollama is not started.

#### Local model selection

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

### Test the gateway directly

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

### Changing the local model

The setup script is the preferred way to select a model. To change it manually without replacing other settings:

```bash
# Stop active requests, then edit OLLAMA_MODEL in .env.
./scripts/pull-model.sh llama3.2:3b

# Recreate LiteLLM so its model deployment reads the new value.
docker compose up -d --force-recreate litellm
```

`OLLAMA_MODEL` contains the Ollama tag without a provider prefix. Compose supplies the `ollama/` prefix to LiteLLM automatically.

### Troubleshooting

#### Setup reports that `.env` already exists

Setup never overwrites credentials. Stop the stack, move `.env` to a backup location, and run `./setup.sh` again. Moving `.env` does not delete Docker volumes.

#### A local response is slow

CPU inference can be slow on the first request while Ollama loads the model. Check the active model with `docker compose exec ollama ollama ps`. If memory pressure persists, rerun setup and choose a smaller model.

#### A model returns an empty answer

Confirm that both local deployments in `config/litellm_config.yaml` retain `reasoning_effort: none`. This is required for predictable short responses from thinking-capable Qwen models. Then recreate LiteLLM.

#### ClickHouse Cloud does not connect

Confirm that the Cloud service allows the Docker host's public IP and that outbound ports `8443` and `9440` are available. Inspect migrations with `docker compose logs langfuse-web langfuse-worker`.

#### A service does not become healthy

```bash
docker compose ps
docker compose logs --tail=200 <service-name>
```

The most useful service names are `litellm`, `librechat`, `langfuse-web`, `langfuse-worker`, `postgres`, `redis`, `minio`, `clickhouse`, `mongodb`, and `ollama`.

### Operations

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

### Verification status

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

### Repository layout

```text
.
├── setup.sh                       # Interactive configuration
├── docker-compose.yml             # Complete workshop stack
├── .env.example                   # Local-only field reference; setup generates real secrets
├── workshop/                      # English learner modules, instructor notes, assets, SQL
│   ├── workshop-overview.md       # Dedicated workshop landing page
│   ├── 00-setup.md ... 09-wrap-up.md
│   ├── instructor-guide.md
│   ├── assets/                    # Dataset and paste-ready evaluators
│   └── sql/                       # Langfuse v4 ClickHouse analytics
├── config/
│   ├── callbacks.py               # Selects Sonnet or the local model for `auto`
│   ├── librechat.yaml             # LibreChat → LiteLLM connection
│   └── litellm_config.yaml        # Models, gateway, Langfuse OTEL callback
└── scripts/
    ├── preflight.sh               # Check Docker, memory, disk and ports before setup
    ├── start.sh                   # Start, pull model, initialize LibreChat user
    └── pull-model.sh              # Manually pull an Ollama model
```

### Langfuse v4 notes

This stack follows the Langfuse v4 self-hosted architecture. PostgreSQL stores application metadata; ClickHouse stores observations and scores; Redis handles queues and caching; MinIO stores incoming events and media; and separate web and worker containers run the application. PostgreSQL always stays local as required by this workshop.

---

## 한국어

이 워크숍은 게이트웨이를 통해 LLM 애플리케이션을 실행하고 모든 모델 호출을 점검할 수 있는 단일한 자율 학습형 스택입니다. 별도의 단계 구분이 없으며, 설정 과정에서 Anthropic이나 ClickHouse Cloud를 선택하지 않는 한 클라우드 계정도 필요하지 않습니다.

영어로만 제공되는 자율 학습 과정은 전용 [Workshop](workshop/workshop-overview.md) 섹션에서 시작할 수 있습니다. 이 과정은 설정, 관측 가능성(observability), 프롬프트 관리, 모니터링, 데이터셋, 실험, 자동 및 수동 평가, ClickHouse 직접 분석을 다룹니다.

### 문서 사이트

이 워크숍은 검색 가능한 [GitHub Pages 문서 사이트](https://litkhai.github.io/llmops-workshop/)로도 제공됩니다. 이 사이트는 `workshop/` 디렉터리의 Markdown 파일을 그대로 사용하므로, 저장소와 웹사이트가 과정 내용을 별도로 유지 관리하지 않습니다.

사이트를 로컬에서 미리 보려면 다음을 실행합니다.

```bash
python3 -m venv .venv-docs
source .venv-docs/bin/activate
pip install --requirement requirements-docs.txt
mkdocs serve
```

`http://127.0.0.1:8000`을 엽니다. 워크숍, 테마, MkDocs 설정 또는 Pages 워크플로를 변경하는 커밋이 `main`에 푸시되면 사이트가 자동으로 다시 빌드되어 배포됩니다.

### 제공되는 것

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

LibreChat는 안정적인 LiteLLM 모델 별칭인 `auto`만 알고 있습니다. 이 별칭이 Sonnet을 사용할지 선택된 로컬 Ollama 모델을 사용할지는 설정 과정에서 결정됩니다. LiteLLM은 프롬프트, 응답, 토큰 사용량, 지연 시간, 오류, 모델 메타데이터에 대한 OpenTelemetry 관측 데이터를 Langfuse v4로 내보냅니다.

### 요구 사항

- Compose v2를 지원하는 Docker Desktop 또는 Docker Engine
- `bash` 및 `openssl`
- 최초 이미지 pull을 위한 인터넷 연결
- Anthropic 모드: 약 5 GB의 여유 디스크 공간 권장
- 완전 로컬 모드: 약 7-10 GB의 여유 디스크 공간과 Docker에서 사용 가능한 최소 8 GB의 메모리

로컬 모델 다운로드 용량은 약 0.8 GB에서 3.4 GB 사이입니다. 메뉴의 모든 옵션은 CPU에서 실행할 수 있으며, 모델이 클수록 응답 속도는 느려집니다.

노트북에 표기된 물리 메모리가 아니라 Docker에 할당된 메모리를 기준으로 판단합니다. Docker Desktop에서는 **Settings → Resources → Memory**에서 확인할 수 있습니다. 이 Compose 파일은 GPU passthrough를 구성하지 않으므로, 권장 사항은 CPU 추론을 전제로 합니다.

### 워크숍 시작하기

먼저 머신 상태를 확인합니다 — Docker, 메모리, 디스크, 사용 가능한 포트를 점검하며 아무것도 변경하지 않습니다.

```bash
scripts/preflight.sh
```

그런 다음 대화형 설정을 실행합니다.

```bash
./setup.sh
```

다음 항목을 입력하라는 메시지가 표시됩니다.

1. 워크숍 사용자 ID, 이메일, 비밀번호
2. ClickHouse Cloud 또는 로컬 ClickHouse
3. Anthropic API 키, 또는 키를 입력하지 않을 경우 Docker 메모리 감지 후 적합한 모델 중 명시적으로 선택
4. 스택을 즉시 시작할지 여부

생성된 `.env` 파일은 소유자만 읽을 수 있으며 Git에서 제외됩니다. 내부 PostgreSQL, ClickHouse, Redis, MinIO, JWT, Langfuse, LiteLLM의 비밀 값은 워크숍 비밀번호를 재사용하지 않고 각각 독립적으로 생성됩니다.

계정 입력 프롬프트에서 Enter만 누르면 워크숍 기본값인 `admin`, `admin@example.com`, `Clickhouse_4U`가 사용됩니다. 이 공개 기본값은 노트북 워크숍 환경에서만 사용하도록 의도된 것입니다.

즉시 시작하지 않기로 선택한 경우:

```bash
./scripts/start.sh
```

start 스크립트는 선택된 서비스를 실행하고, 필요한 경우 선택된 Ollama 모델을 pull하며, LibreChat 초기 관리자 계정을 생성합니다. Langfuse도 동일한 워크숍 계정을 자동으로 초기화합니다.

기존 PostgreSQL 볼륨을 재생성된 `.env`와 함께 재사용하는 경우, start 스크립트는 데이터를 삭제하지 않고 저장된 로컬 PostgreSQL 역할의 비밀번호를 새로 생성된 값으로 업데이트합니다.

다음 주소를 엽니다 (공개된 모든 포트는 `127.0.0.1`에만 바인딩됩니다).

- LibreChat: [http://localhost:3080](http://localhost:3080)
- Langfuse: [http://localhost:3000](http://localhost:3000)
- LiteLLM API: [http://localhost:4000](http://localhost:4000)

설정 과정에서 입력한 이메일과 비밀번호로 LibreChat과 Langfuse에 로그인합니다.

### 설정 옵션

#### ClickHouse Cloud

Cloud 호스트명, 데이터베이스, 사용자 이름, 비밀번호를 입력합니다. 설정 과정은 Langfuse를 다음과 같이 구성합니다.

- 포트 `8443`의 HTTPS 엔드포인트
- 포트 `9440`의 네이티브 마이그레이션 엔드포인트
- 마이그레이션 TLS 활성화

ClickHouse Cloud의 IP 접근 목록에 Docker 호스트의 연결을 허용해야 합니다. Langfuse v4는 ClickHouse 25.12 이상을 요구합니다.

#### 로컬 ClickHouse

설정 과정은 `local-clickhouse` Compose 프로파일을 활성화하고 `clickhouse/clickhouse-server:25.12`를 시작합니다. 데이터는 Docker 볼륨에 저장됩니다. HTTP 포트와 네이티브 포트는 `127.0.0.1`에만 바인딩됩니다.

#### Anthropic Sonnet

Anthropic 키가 제공되면 LiteLLM은 `auto`를 `anthropic/claude-sonnet-4-5`로 라우팅합니다. 이 경우 Ollama는 시작되지 않습니다.

#### 로컬 모델 선택

Anthropic 키가 없으면 설정 과정은 `local-model` 프로파일을 활성화하고, Docker에서 사용 가능한 메모리를 감지한 뒤, 참가자에게 적합한 모델 중에서 선택하도록 요청합니다. 각 옵션에는 다운로드 용량이 함께 표시됩니다. ClickHouse가 로컬에서 실행되는 경우 ClickHouse와 모델이 Docker 메모리를 함께 사용하므로 필터링 기준이 더 보수적으로 적용됩니다. 설정 과정은 모델을 자동으로 선택하지 않습니다.

| 모델 | 다운로드 용량 | 적합한 환경 |
| --- | ---: | --- |
| `gemma3:1b` | 0.8 GB | 매우 제한적인 사양의 노트북 |
| `qwen3:1.7b` | 1.4 GB | 가볍고 균형 잡힌 기본값 |
| `llama3.2:3b` | 2.0 GB | 영어 지시 수행, 요약, 재작성 |
| `phi4-mini` | 2.5 GB | 추론 및 정확한 지시 이행 |
| `qwen3.5:4b` | 3.4 GB | 설정에서 제공하는 가장 높은 일반 품질 |

Qwen3와 Qwen3.5는 Ollama에서 기본적으로 추론(reasoning) 기능이 활성화되어 있습니다. 게이트웨이는 모든 로컬 배포에 대해 `reasoning_effort: none`을 설정하여, 짧은 워크숍 요청이 숨겨진 추론에 출력 예산을 소모하는 대신 즉시 눈에 보이는 답변을 반환하도록 합니다. 참가자는 이후 LiteLLM 모델 설정을 변경하여 추론 동작을 직접 살펴볼 수 있습니다.

이 워크숍은 다음과 같이 보수적인 가용 메모리 기준을 사용합니다. 이는 모델 제공사의 최소 요구 사항이 아니라 전체 스택을 위한 선택 가드레일입니다.

| 모델 | ClickHouse Cloud | 로컬 ClickHouse |
| --- | ---: | ---: |
| `gemma3:1b` | 4 GB | 4 GB |
| `qwen3:1.7b` | 7 GB | 7 GB |
| `llama3.2:3b` | 9 GB | 13 GB |
| `phi4-mini` | 12 GB | 20 GB |
| `qwen3.5:4b` | 16 GB | 24 GB |

두 개 이상의 모델을 사용할 수 있는 경우 메뉴의 기본 선택값은 `qwen3:1.7b`이지만, 최종 선택은 참가자가 직접 합니다.

### 게이트웨이 직접 테스트하기

`.env`에서 생성된 키를 확인한 뒤, OpenAI 호환 엔드포인트를 호출합니다.

```bash
set -a
source .env
set +a

curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"Explain an LLM gateway in two sentences."}]}'
```

응답을 받은 후 Langfuse를 열어 생성된 관측(observation) 데이터를 확인합니다.

로컬 요청이 성공했는지 확인하려면 다음 세 가지 결과를 모두 검증합니다.

1. API가 비어 있지 않은 어시스턴트 메시지와 함께 HTTP `200`을 반환합니다.
2. LiteLLM이 성공한 `POST /v1/chat/completions` 요청을 로그로 기록합니다.
3. Langfuse에 소스가 `otel`인 새로운 `GENERATION` 관측이 표시됩니다.

### 로컬 모델 변경하기

모델을 선택하는 가장 권장되는 방법은 설정 스크립트를 사용하는 것입니다. 다른 설정을 유지한 채 수동으로 변경하려면 다음과 같이 합니다.

```bash
# Stop active requests, then edit OLLAMA_MODEL in .env.
./scripts/pull-model.sh llama3.2:3b

# Recreate LiteLLM so its model deployment reads the new value.
docker compose up -d --force-recreate litellm
```

`OLLAMA_MODEL`에는 provider 접두사가 없는 Ollama 태그가 들어 있습니다. Compose가 자동으로 `ollama/` 접두사를 붙여 LiteLLM에 전달합니다.

### 문제 해결

#### 설정 시 `.env`가 이미 존재한다는 메시지가 나오는 경우

설정 과정은 자격 증명을 덮어쓰지 않습니다. 스택을 중지하고 `.env`를 백업 위치로 옮긴 뒤 `./setup.sh`를 다시 실행합니다. `.env`를 옮기는 작업은 Docker 볼륨을 삭제하지 않습니다.

#### 로컬 응답이 느린 경우

Ollama가 모델을 로드하는 동안 첫 요청에서는 CPU 추론이 느릴 수 있습니다. `docker compose exec ollama ollama ps`로 현재 활성 모델을 확인합니다. 메모리 부족 현상이 계속되면 설정을 다시 실행하여 더 작은 모델을 선택합니다.

#### 모델이 빈 응답을 반환하는 경우

`config/litellm_config.yaml`의 두 로컬 배포 모두에 `reasoning_effort: none`이 유지되고 있는지 확인합니다. 이는 추론 기능이 있는 Qwen 모델에서 예측 가능한 짧은 응답을 얻기 위해 필요합니다. 확인 후 LiteLLM을 다시 생성합니다.

#### ClickHouse Cloud에 연결되지 않는 경우

Cloud 서비스가 Docker 호스트의 공인 IP를 허용하고 있는지, 아웃바운드 포트 `8443`과 `9440`을 사용할 수 있는지 확인합니다. `docker compose logs langfuse-web langfuse-worker`로 마이그레이션 상태를 점검합니다.

#### 서비스가 정상 상태(healthy)가 되지 않는 경우

```bash
docker compose ps
docker compose logs --tail=200 <service-name>
```

가장 유용하게 확인할 서비스 이름은 `litellm`, `librechat`, `langfuse-web`, `langfuse-worker`, `postgres`, `redis`, `minio`, `clickhouse`, `mongodb`, `ollama`입니다.

### 운영

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

다른 설정 옵션을 선택하려면 스택을 중지하고 기존 `.env`를 안전한 곳으로 옮긴 뒤 `./setup.sh`를 다시 실행합니다. 기존 Docker 볼륨은 서로 다른 ClickHouse 구성 간에 자동으로 마이그레이션되지 않습니다.

### 검증 상태

재현 가능한 테스트 절차, 관찰된 증거, 수정된 이슈, 인도 승인 체크리스트는 상세한 [Docker Validation Report](workshop/docker-validation.md)를 참고합니다.

이번 개정판은 다음 경로에 대해 검증되었습니다.

- 다섯 개 로컬 모델 전체에 대한 메모리 기반 가용성 필터링 및 명시적 선택
- 로컬 및 Cloud ClickHouse 프로파일 선택
- Ollama를 제외하는 Anthropic 모드
- Ollama를 포함하는 로컬 모델 모드
- ClickHouse/모델 배포 조합 네 가지 전체에 대한 Compose 구성 렌더링
- Anthropic Sonnet과 선택된 Ollama 모델 각각에 대한 `auto`를 통한 실제 요청
- `sonnet/response` 및 `local/response` `GENERATION` 관측에 대한 Langfuse v4 수집
- LibreChat 및 Langfuse 워크숍 계정 초기화
- ClickHouse Cloud 또는 로컬 ClickHouse를 Anthropic 또는 로컬 모델과 각각 조합한 네 가지 전체 조합의 엔드투엔드 실행

### 저장소 구조

```text
.
├── setup.sh                       # Interactive configuration
├── docker-compose.yml             # Complete workshop stack
├── .env.example                   # Local-only field reference; setup generates real secrets
├── workshop/                      # English learner modules, instructor notes, assets, SQL
│   ├── workshop-overview.md       # Dedicated workshop landing page
│   ├── 00-setup.md ... 09-wrap-up.md
│   ├── instructor-guide.md
│   ├── assets/                    # Dataset and paste-ready evaluators
│   └── sql/                       # Langfuse v4 ClickHouse analytics
├── config/
│   ├── callbacks.py               # Selects Sonnet or the local model for `auto`
│   ├── librechat.yaml             # LibreChat → LiteLLM connection
│   └── litellm_config.yaml        # Models, gateway, Langfuse OTEL callback
└── scripts/
    ├── preflight.sh               # Check Docker, memory, disk and ports before setup
    ├── start.sh                   # Start, pull model, initialize LibreChat user
    └── pull-model.sh              # Manually pull an Ollama model
```

### Langfuse v4 참고 사항

이 스택은 Langfuse v4의 셀프 호스팅 아키텍처를 따릅니다. PostgreSQL은 애플리케이션 메타데이터를 저장하고, ClickHouse는 관측 데이터와 점수를 저장하며, Redis는 큐와 캐싱을 처리하고, MinIO는 수신 이벤트와 미디어를 저장하며, 별도의 web 및 worker 컨테이너가 애플리케이션을 실행합니다. 이 워크숍의 요구 사항에 따라 PostgreSQL은 항상 로컬에 유지됩니다.
