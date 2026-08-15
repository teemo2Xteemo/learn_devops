#!/usr/bin/env bash
set -u

LOG_FILE="${LOG_FILE:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/healthcheck.log}"
ALERT_FILE="${ALERT_FILE:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/alert.log}"
POSTGRES_CONTAINER="${POSTGRES_CONTAINER:-lab_postgres}"
REDIS_CONTAINER="${REDIS_CONTAINER:-lab_redis}"

mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"
touch "$ALERT_FILE"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" "$1" >> "$LOG_FILE"
}

send_alert() {
  local message="$1"
  log "ALERT: $message"

  printf '%s\n' "$message" >> "$ALERT_FILE"

  if command -v curl >/dev/null 2>&1; then
    curl -fsS -X POST \
      -H 'Content-Type: application/json' \
      -d "{\"message\":\"$message\",\"service\":\"postgres-redis-healthcheck\"}" \
      https://httpbin.org/post >/dev/null 2>&1 || true
  fi
}

check_postgres() {
  if docker exec "$POSTGRES_CONTAINER" pg_isready -h 127.0.0.1 -U app_user -d app_db >/dev/null 2>&1; then
    log "OK: PostgreSQL is healthy"
    return 0
  fi

  send_alert "PostgreSQL container '$POSTGRES_CONTAINER' is down or not ready"
  return 1
}

check_redis() {
  if docker exec "$REDIS_CONTAINER" redis-cli ping >/dev/null 2>&1; then
    log "OK: Redis is healthy"
    return 0
  fi

  send_alert "Redis container '$REDIS_CONTAINER' is down or not responding"
  return 1
}

main() {
  log "INFO: Starting PostgreSQL and Redis health check"

  local postgres_ok=0
  local redis_ok=0

  if check_postgres; then
    postgres_ok=1
  fi

  if check_redis; then
    redis_ok=1
  fi

  if [ "$postgres_ok" -eq 0 ] || [ "$redis_ok" -eq 0 ]; then
    exit 1
  fi

  log "INFO: All dependencies are healthy"
  exit 0
}

main "$@"
