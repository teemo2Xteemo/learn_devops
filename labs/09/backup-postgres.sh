#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${LOG_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/logs}"
BACKUP_DIR="${BACKUP_DIR:-$SCRIPT_DIR/backups}"
LOG_FILE="${LOG_FILE:-$LOG_DIR/backup-postgres.log}"
CONTAINER_NAME="${CONTAINER_NAME:-lab_postgres}"
POSTGRES_USER="${POSTGRES_USER:-app_user}"
POSTGRES_DB="${POSTGRES_DB:-app_db}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-app_password_secure}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"

mkdir -p "$BACKUP_DIR"
touch "$LOG_FILE"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" "$1" >> "$LOG_FILE"
}

cleanup_old_backups() {
  if [ -d "$BACKUP_DIR" ]; then
    find "$BACKUP_DIR" -maxdepth 1 -type f -name 'backup_*.sql' -mtime +"$RETENTION_DAYS" -print -delete
  fi
}

create_backup() {
  local timestamp backup_file err_file
  timestamp="$(date '+%Y%m%d_%H%M%S')"
  backup_file="$BACKUP_DIR/backup_${timestamp}.sql"
  err_file="${backup_file}.err"

  if ! docker ps --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then
    log "ERROR: PostgreSQL container '$CONTAINER_NAME' is not running. Backup aborted."
    return 1
  fi

  if ! docker exec -i "$CONTAINER_NAME" env PGPASSWORD="$POSTGRES_PASSWORD" pg_dump -h 127.0.0.1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists > "$backup_file" 2> "$err_file"; then
    local err_output
    err_output="$(tr -d '\r' < "$err_file" 2>/dev/null | tail -n 20)"

    rm -f "$backup_file"
    if [ -n "$err_output" ]; then
      log "ERROR: pg_dump failed for database '$POSTGRES_DB' on container '$CONTAINER_NAME'. Details: $err_output"
    else
      log "ERROR: pg_dump failed for database '$POSTGRES_DB' on container '$CONTAINER_NAME'. No detailed error output was returned."
    fi

    rm -f "$err_file"
    return 1
  fi

  rm -f "$err_file"

  if [ ! -s "$backup_file" ]; then
    log "ERROR: Backup file '$backup_file' was created but is empty. The dump may have failed silently."
    rm -f "$backup_file"
    return 1
  fi

  log "SUCCESS: Backup created successfully at '$backup_file'"
  return 0
}

main() {
  log "INFO: Starting PostgreSQL backup job for database '$POSTGRES_DB' on container '$CONTAINER_NAME'"
  cleanup_old_backups

  if create_backup; then
    exit 0
  fi

  exit 1
}

main "$@"
