#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

MODEL="${1:-${OLLAMA_MODEL:-qwen3:1.7b}}"

command -v docker >/dev/null 2>&1 || { echo "Docker is required."; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "Docker Compose v2 is required."; exit 1; }

echo "Preparing Ollama and pulling $MODEL..."
docker compose --profile local-model up -d ollama
docker compose exec -T ollama ollama pull "$MODEL"

echo
echo "Model '$MODEL' is ready."
if [[ "$MODEL" != "${OLLAMA_MODEL:-qwen3:1.7b}" ]]; then
  echo "To make it the gateway default, set OLLAMA_MODEL='$MODEL' in .env"
  echo "and run: docker compose up -d --force-recreate litellm"
fi
