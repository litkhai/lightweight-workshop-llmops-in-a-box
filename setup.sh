#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$ROOT_DIR/.env"

if [[ -e "$ENV_FILE" ]]; then
  echo ".env already exists. Move or remove it before running setup again."
  exit 1
fi

command -v docker >/dev/null 2>&1 || { echo "Docker is required."; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "Docker Compose v2 is required."; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo "openssl is required."; exit 1; }

ask_yes_no() {
  local prompt="$1" default="${2:-n}" answer
  while true; do
    if [[ "$default" == "y" ]]; then
      read -r -p "$prompt [Y/n] " answer
      answer="${answer:-y}"
    else
      read -r -p "$prompt [y/N] " answer
      answer="${answer:-n}"
    fi
    case "$answer" in
      y|Y|yes|YES) return 0 ;;
      n|N|no|NO) return 1 ;;
    esac
  done
}

secret_hex() {
  openssl rand -hex "${1:-32}"
}

write_env() {
  local key="$1" value="$2"
  [[ "$value" != *"'"* ]] || { echo "Values cannot contain a single quote (')."; exit 1; }
  printf "%s='%s'\n" "$key" "$value" >> "$ENV_FILE"
}

detect_docker_memory_gb() {
  local memory_bytes
  memory_bytes="$(docker info --format '{{.MemTotal}}' 2>/dev/null || true)"
  if [[ "$memory_bytes" =~ ^[0-9]+$ && "$memory_bytes" -gt 0 ]]; then
    echo $(((memory_bytes + 536870911) / 1073741824))
  else
    echo 8
  fi
}

echo "LLMOps self-service workshop setup"
echo "Langfuse v4, LibreChat, LiteLLM, PostgreSQL, Redis and MinIO run locally."
echo

while true; do
  read -r -p "Workshop user ID [admin]: " workshop_id
  workshop_id="${workshop_id:-admin}"
  [[ "$workshop_id" =~ ^[A-Za-z][A-Za-z0-9_.-]{2,31}$ ]] && break
  echo "Use 3-32 letters, digits, dots, underscores or hyphens; start with a letter."
done

while true; do
  read -r -p "Email [admin@example.com]: " workshop_email
  workshop_email="${workshop_email:-admin@example.com}"
  [[ "$workshop_email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] && break
  echo "Enter a valid email address."
done

while true; do
  read -r -s -p "Password [workshop default]: " workshop_password
  echo
  workshop_password="${workshop_password:-Clickhouse_4U}"
  read -r -s -p "Confirm password [same default]: " password_confirmation
  echo
  password_confirmation="${password_confirmation:-Clickhouse_4U}"
  if [[ ${#workshop_password} -ge 8 && "$workshop_password" == "$password_confirmation" && "$workshop_password" != *"'"* ]]; then
    break
  fi
  echo "Passwords must match, contain at least 8 characters, and not contain a single quote."
done

profiles=()
if ask_yes_no "Use ClickHouse Cloud?" "n"; then
  clickhouse_mode="cloud"
  read -r -p "ClickHouse Cloud host (without protocol): " clickhouse_host
  clickhouse_host="${clickhouse_host#https://}"
  clickhouse_host="${clickhouse_host#http://}"
  clickhouse_host="${clickhouse_host%%/*}"
  clickhouse_host="${clickhouse_host%%:*}"
  [[ -n "$clickhouse_host" ]] || { echo "ClickHouse host is required."; exit 1; }
  read -r -p "ClickHouse database [default]: " clickhouse_db
  clickhouse_db="${clickhouse_db:-default}"
  read -r -p "ClickHouse user [default]: " clickhouse_user
  clickhouse_user="${clickhouse_user:-default}"
  read -r -s -p "ClickHouse password: " clickhouse_password
  echo
  [[ -n "$clickhouse_password" ]] || { echo "ClickHouse password is required."; exit 1; }
  [[ "$clickhouse_password" != *"'"* ]] || { echo "The password cannot contain a single quote."; exit 1; }
  clickhouse_url="https://${clickhouse_host}:8443"
  clickhouse_migration_url="clickhouse://${clickhouse_host}:9440"
  clickhouse_migration_ssl="true"
  clickhouse_cluster_enabled="true"
else
  clickhouse_mode="local"
  profiles+=(local-clickhouse)
  clickhouse_db="langfuse"
  clickhouse_user="langfuse"
  clickhouse_password="$(secret_hex 24)"
  clickhouse_url="http://clickhouse:8123"
  clickhouse_migration_url="clickhouse://clickhouse:9000"
  clickhouse_migration_ssl="false"
  clickhouse_cluster_enabled="false"
fi

if ask_yes_no "Do you have an Anthropic API key?" "n"; then
  read -r -s -p "Anthropic API key: " anthropic_api_key
  echo
  [[ -n "$anthropic_api_key" ]] || { echo "Anthropic API key is required."; exit 1; }
  model_mode="sonnet"
  ollama_model=""
else
  anthropic_api_key=""
  model_mode="local"
  profiles+=(local-model)

  detected_memory_gb="$(detect_docker_memory_gb)"
  while true; do
    read -r -p "Memory available to Docker in GB [$detected_memory_gb]: " docker_memory_gb
    docker_memory_gb="${docker_memory_gb:-$detected_memory_gb}"
    [[ "$docker_memory_gb" =~ ^[0-9]+$ && "$docker_memory_gb" -ge 4 && "$docker_memory_gb" -le 512 ]] && break
    echo "Enter a whole number between 4 and 512. Use Docker Desktop's memory limit."
  done

  echo
  if [[ "$clickhouse_mode" == "local" ]]; then
    echo "Local ClickHouse shares Docker memory with the model; conservative limits are applied."
    model_minimums=(4 7 13 20 24)
  else
    echo "ClickHouse Cloud does not consume local Docker memory."
    model_minimums=(4 7 9 12 16)
  fi

  model_names=(gemma3:1b qwen3:1.7b llama3.2:3b phi4-mini qwen3.5:4b)
  model_downloads=(0.8 1.4 2.0 2.5 3.4)
  model_descriptions=(
    "smallest option"
    "balanced lightweight model"
    "English instructions and rewriting"
    "reasoning and precise instructions"
    "highest general quality in this menu"
  )
  available_models=()

  echo "Available local models for ${docker_memory_gb} GB of Docker memory:"
  for i in "${!model_names[@]}"; do
    if ((docker_memory_gb >= model_minimums[i])); then
      available_models+=("${model_names[i]}")
      printf "  %d) %-14s - %s GB download, %s\n" \
        "${#available_models[@]}" "${model_names[i]}" "${model_downloads[i]}" "${model_descriptions[i]}"
    fi
  done

  default_choice=1
  if ((${#available_models[@]} >= 2)); then
    default_choice=2
  fi
  while true; do
    read -r -p "Choose a local model [$default_choice]: " model_choice
    model_choice="${model_choice:-$default_choice}"
    if [[ "$model_choice" =~ ^[0-9]+$ ]] && \
       ((model_choice >= 1 && model_choice <= ${#available_models[@]})); then
      ollama_model="${available_models[model_choice - 1]}"
      break
    fi
    echo "Choose a number from 1 to ${#available_models[@]}."
  done
fi

if ((${#profiles[@]})); then
  compose_profiles="$(IFS=,; echo "${profiles[*]}")"
else
  compose_profiles=""
fi

umask 077
: > "$ENV_FILE"
write_env COMPOSE_PROFILES "$compose_profiles"
write_env WORKSHOP_USER_ID "$workshop_id"
write_env WORKSHOP_USER_EMAIL "$workshop_email"
write_env WORKSHOP_PASSWORD "$workshop_password"
write_env MODEL_MODE "$model_mode"
if [[ "$model_mode" == "local" ]]; then
  write_env DOCKER_MEMORY_GB "$docker_memory_gb"
fi
write_env ANTHROPIC_API_KEY "$anthropic_api_key"
write_env OLLAMA_MODEL "$ollama_model"
write_env LITELLM_MASTER_KEY "sk-$(secret_hex 24)"
write_env LITELLM_PORT "4000"
write_env LIBRECHAT_PORT "3080"
write_env LANGFUSE_PORT "3000"
write_env MINIO_PORT "9090"
write_env LANGFUSE_PUBLIC_KEY "pk-lf-$(secret_hex 16)"
write_env LANGFUSE_SECRET_KEY "sk-lf-$(secret_hex 24)"
write_env LANGFUSE_SALT "$(secret_hex 32)"
write_env LANGFUSE_ENCRYPTION_KEY "$(secret_hex 32)"
write_env LANGFUSE_NEXTAUTH_SECRET "$(secret_hex 32)"
write_env POSTGRES_USER "langfuse"
write_env POSTGRES_PASSWORD "$(secret_hex 24)"
write_env POSTGRES_DB "langfuse"
write_env REDIS_AUTH "$(secret_hex 24)"
write_env MINIO_ROOT_USER "minio"
write_env MINIO_ROOT_PASSWORD "$(secret_hex 24)"
write_env CLICKHOUSE_MODE "$clickhouse_mode"
write_env CLICKHOUSE_URL "$clickhouse_url"
write_env CLICKHOUSE_MIGRATION_URL "$clickhouse_migration_url"
write_env CLICKHOUSE_MIGRATION_SSL "$clickhouse_migration_ssl"
write_env CLICKHOUSE_USER "$clickhouse_user"
write_env CLICKHOUSE_PASSWORD "$clickhouse_password"
write_env CLICKHOUSE_DB "$clickhouse_db"
write_env CLICKHOUSE_CLUSTER_ENABLED "$clickhouse_cluster_enabled"
write_env LIBRECHAT_JWT_SECRET "$(secret_hex 32)"
write_env LIBRECHAT_JWT_REFRESH_SECRET "$(secret_hex 32)"
write_env LIBRECHAT_CREDS_KEY "$(secret_hex 32)"
write_env LIBRECHAT_CREDS_IV "$(secret_hex 16)"

echo
echo "Configuration written to .env (permissions: owner only)."
echo "ClickHouse: $clickhouse_mode"
if [[ "$model_mode" == "local" ]]; then
  echo "Model: local ($ollama_model)"
else
  echo "Model: Anthropic Sonnet"
fi

if ask_yes_no "Start the workshop now?" "y"; then
  exec "$ROOT_DIR/scripts/start.sh"
fi

echo "Run ./scripts/start.sh when you are ready."
