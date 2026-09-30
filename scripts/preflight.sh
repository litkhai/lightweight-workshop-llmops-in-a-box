#!/usr/bin/env bash
# Check what the workshop needs before ./setup.sh pulls several GB of images.
# Safe to run repeatedly. Works with macOS Bash 3.2.

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; FAIL=1; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }
FAIL=0

echo
echo "Local tooling"
docker info >/dev/null 2>&1 && ok "Docker is running" || bad "Docker is not running"
docker compose version >/dev/null 2>&1 \
    && ok "Compose v2 ($(docker compose version --short 2>/dev/null))" \
    || bad "docker compose (v2) not found"
command -v openssl >/dev/null && ok "openssl" || bad "openssl not found (setup.sh generates secrets with it)"

echo
echo "Resources (README → Requirements)"
mem=$(docker info --format '{{.MemTotal}}' 2>/dev/null)
if [ -n "$mem" ] && [ "$mem" -gt 0 ] 2>/dev/null; then
    gb=$(( (mem + 536870911) / 1073741824 ))
    if [ "$gb" -lt 4 ]; then bad "Docker has ${gb} GB of memory — setup.sh needs at least 4"
    elif [ "$gb" -lt 8 ]; then warn "Docker has ${gb} GB of memory — enough for Anthropic mode; fully local mode needs 8"
    else ok "Docker has ${gb} GB of memory"; fi
else
    warn "could not read Docker's memory (docker info)"
fi
free_kb=$(df -Pk . | awk 'NR==2 {print $4}')
if [ -n "$free_kb" ]; then
    free_gb=$(( free_kb / 1048576 ))
    if [ "$free_gb" -lt 5 ]; then bad "${free_gb} GB free disk — about 5 GB is needed (7–10 GB for fully local mode)"
    elif [ "$free_gb" -lt 10 ]; then warn "${free_gb} GB free disk — fine for Anthropic mode; fully local mode wants 7–10 GB"
    else ok "${free_gb} GB free disk"; fi
fi

echo
echo "Ports on 127.0.0.1 (docker-compose.yml; override in .env)"
[ -f .env ] && . ./.env 2>/dev/null
for pair in "LANGFUSE_PORT ${LANGFUSE_PORT:-3000}" "LIBRECHAT_PORT ${LIBRECHAT_PORT:-3080}" \
            "LITELLM_PORT ${LITELLM_PORT:-4000}" "MINIO_PORT ${MINIO_PORT:-9090}" \
            "CLICKHOUSE_HTTP_PORT ${CLICKHOUSE_HTTP_PORT:-8123}" "CLICKHOUSE_NATIVE_PORT ${CLICKHOUSE_NATIVE_PORT:-9000}"; do
    set -- $pair
    # a connection that succeeds means something already listens there
    if (exec 3<>"/dev/tcp/127.0.0.1/$2") 2>/dev/null; then
        if docker compose ps --status running -q 2>/dev/null | grep -q .; then warn "$2 in use ($1) — by this stack, or change $1 in .env"
        else bad "$2 in use ($1) — stop that process or set $1 in .env"; fi
    else
        ok "$2 free ($1)"
    fi
done

echo
echo "Configuration"
[ -f .env ] && ok ".env present (setup.sh already ran)" || warn ".env not found — run ./setup.sh next"

echo
if [ "$FAIL" -eq 0 ]; then echo "Ready."; else echo "Fix the ✗ items above, then run this again."; fi
exit "$FAIL"
