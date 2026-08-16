#!/usr/bin/env bash
set -u

MAX_SIZE="${MAX_SIZE:-1048576}"
MAX_KEEP="${MAX_KEEP:-5}"
LOG_DIR="${LOG_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/logs}"
LOG_FILES=("backup-postgres.log" "healthcheck.log" "alert.log")

rotate_log() {
  local logfile="$1"
  local path="${LOG_DIR}/${logfile}"

  if [ ! -f "$path" ]; then
    return 0
  fi

  local size
  size=$(wc -c < "$path" 2>/dev/null || echo 0)

  if [ "$size" -lt "$MAX_SIZE" ]; then
    return 0
  fi

  # Rotate archived copies: .1 -> .2 -> .3 ... .N
  for ((i = MAX_KEEP - 1; i >= 1; i--)); do
    if [ -f "${path}.${i}" ]; then
      mv -f "${path}.${i}" "${path}.$((i + 1))"
    fi
  done

  # Remove oldest archive beyond the limit
  if [ -f "${path}.${MAX_KEEP}" ]; then
    rm -f "${path}.${MAX_KEEP}"
  fi

  # Important: copy the current file to the new archive name, then truncate the
  # original file in place. This keeps the current file descriptor valid for the
  # running service and prevents writes from being lost or redirected to a stale inode.
  cp --preserve=mode,timestamps "$path" "${path}.1"
  : > "$path"

  echo "Rotated ${path} -> ${path}.1"
}

main() {
  for logfile in "${LOG_FILES[@]}"; do
    rotate_log "$logfile"
  done
}

main "$@"
