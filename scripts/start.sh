#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

[[ -f .env ]] || { echo "Run ./setup.sh first."; exit 1; }
set -a
# shellcheck disable=SC1091
source .env
set +a

wait_healthy() {
  local service="$1" container_id status
  echo "Waiting for $service..."
  for _ in $(seq 1 90); do
    container_id="$(docker compose ps -q "$service")"
    if [[ -n "$container_id" ]]; then
      status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "$container_id")"
      [[ "$status" == "healthy" || "$status" == "running" ]] && return 0
    fi
    sleep 2
  done
  echo "$service did not become healthy. Check: docker compose logs $service"
  return 1
}

sync_postgres_password() {
  [[ "${POSTGRES_USER:-}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || {
    echo "POSTGRES_USER must be a valid PostgreSQL identifier."
    return 1
  }
  [[ -n "${POSTGRES_PASSWORD:-}" && "$POSTGRES_PASSWORD" != *"'"* ]] || {
    echo "POSTGRES_PASSWORD must be non-empty and cannot contain a single quote."
    return 1
  }

  # A regenerated .env can coexist with an older data volume. Local socket
  # authentication lets the container align the persisted role with .env
  # without deleting workshop data.
  printf "ALTER ROLE \"%s\" WITH PASSWORD '%s';\n" \
    "$POSTGRES_USER" "$POSTGRES_PASSWORD" |
    docker compose exec -T postgres psql \
      --username "$POSTGRES_USER" \
      --dbname "${POSTGRES_DB:-langfuse}" \
      --set=ON_ERROR_STOP=1 >/dev/null
}

# Start storage first so Langfuse v4 migrations do not race local dependencies.
docker compose up -d postgres redis minio mongodb
wait_healthy postgres
echo "Synchronizing PostgreSQL credentials with .env..."
sync_postgres_password

if [[ "${CLICKHOUSE_MODE:-local}" == "local" ]]; then
  docker compose up -d clickhouse
  wait_healthy clickhouse
fi

if [[ "${MODEL_MODE:-local}" == "local" ]]; then
  docker compose up -d ollama
  wait_healthy ollama
  echo "Preparing local model ${OLLAMA_MODEL:-qwen3:1.7b}..."
  docker compose exec -T ollama ollama pull "${OLLAMA_MODEL:-qwen3:1.7b}"
fi

docker compose up -d

echo "Waiting for LibreChat..."
for _ in $(seq 1 60); do
  if docker compose ps --status running --services | grep -qx librechat; then
    break
  fi
  sleep 2
done

existing_user="$(docker compose exec -T mongodb mongosh --quiet --eval \
  "db.getSiblingDB('LibreChat').users.countDocuments({email: '${WORKSHOP_USER_EMAIL}'})" 2>/dev/null || echo 0)"

if [[ "$existing_user" == "0" ]]; then
  echo "Creating the LibreChat workshop account..."
  docker compose exec -T librechat npm run create-user -- \
    "$WORKSHOP_USER_EMAIL" "$WORKSHOP_USER_ID" "$WORKSHOP_USER_ID" "$WORKSHOP_PASSWORD" \
    --email-verified=true
else
  echo "LibreChat account already exists; leaving it unchanged."
fi

echo
echo "Workshop is ready:"
echo "  LibreChat: http://localhost:${LIBRECHAT_PORT:-3080}"
echo "  Langfuse:  http://localhost:${LANGFUSE_PORT:-3000}"
echo "  LiteLLM:   http://localhost:${LITELLM_PORT:-4000}"
echo "  Login:     ${WORKSHOP_USER_EMAIL}"
