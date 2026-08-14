#!/usr/bin/env bash
#
# System Monitor and Log Rotation Script
# Purpose: Monitor system health, check service endpoints, and manage log files
# Usage: ./monitor_and_rotate.sh
#

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

readonly LOG_DIR="/opt/devops-monitor/logs"
readonly LOG_FILE="${LOG_DIR}/system_monitor.log"
readonly LOCK_FILE="/var/run/devops_monitor.lock"

# Monitoring thresholds
readonly DISK_THRESHOLD=85
readonly LOG_SIZE_THRESHOLD="10M"
readonly LOG_RETENTION_DAYS=7

# External dependencies
readonly WEBHOOK_URL="${ALERT_WEBHOOK_URL:-https://httpbin.org/post}"
readonly HEALTH_ENDPOINT="https://localhost/healthz"

# ============================================================================
# INITIALIZATION
# ============================================================================

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR" 2>/dev/null || {
    echo "[ERROR] Cannot create log directory: $LOG_DIR" >&2
    exit 1
}

# Acquire process lock to prevent concurrent execution
exec 200>"$LOCK_FILE" 2>/dev/null || {
    echo "[ERROR] Cannot acquire lock. Insufficient permissions or lock file path issue." >&2
    exit 1
}

if ! flock -n 200; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] Another instance is already running. Exiting." >> "$LOG_FILE"
    exit 0
fi

# ============================================================================
# CLEANUP & TRAP HANDLERS
# ============================================================================

cleanup() {
    local exit_code=$?
    flock -u 200 2>/dev/null || true
    rm -f "$LOCK_FILE"
    exit "$exit_code"
}

trap cleanup EXIT INT TERM

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log() {
    local level="$1"
    shift
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf "[%s] [%-5s] %s\n" "$timestamp" "$level" "$*" | tee -a "$LOG_FILE"
}

send_alert() {
    local message="$1"
    log "ALERT" "$message"
    
    local hostname timestamp
    hostname=$(hostname)
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    
    # Build JSON payload with proper escaping
    local payload
    payload=$(cat <<EOF
{
  "event": "DevOps Alert",
  "message": $(printf '%s\n' "$message" | sed 's/"/\\"/g'),
  "hostname": "$hostname",
  "timestamp": "$timestamp"
}
EOF
    )
    
    curl -s -X POST -H "Content-Type: application/json" \
        -d "$payload" "$WEBHOOK_URL" > /dev/null 2>&1 \
        || log "ERROR" "Failed to send alert via webhook"
}

# ============================================================================
# HEALTH CHECKS
# ============================================================================

check_disk_usage() {
    log "INFO" "Checking disk usage..."
    
    local disk_usage
    disk_usage=$(df / 2>/dev/null | awk 'NR==2 {print $5}' | tr -d '%' || echo "")
    
    # Validate disk usage value
    if [[ -z "$disk_usage" ]] || ! [[ "$disk_usage" =~ ^[0-9]+$ ]]; then
        log "ERROR" "Failed to read disk usage"
        return 1
    fi
    
    if ((disk_usage >= DISK_THRESHOLD)); then
        send_alert "CRITICAL: Root filesystem usage is at ${disk_usage}% (Threshold: ${DISK_THRESHOLD}%)"
    else
        log "INFO" "Disk usage normal: ${disk_usage}%"
    fi
}

check_service_health() {
    log "INFO" "Checking service health endpoint: $HEALTH_ENDPOINT"
    
    local http_status
    http_status=$(curl -k -s -o /dev/null -w "%{http_code}" \
        --connect-timeout 5 "$HEALTH_ENDPOINT" 2>/dev/null || echo "000")
    
    if [[ "$http_status" != "200" ]]; then
        send_alert "WARNING: Service health check failed on ${HEALTH_ENDPOINT} with HTTP Status: ${http_status}"
    else
        log "INFO" "Service endpoint healthy (HTTP 200)"
    fi
}

# ============================================================================
# LOG ROTATION & MAINTENANCE
# ============================================================================

rotate_logs() {
    log "INFO" "Rotating log files..."
    
    # Compress log files larger than threshold (excluding active log)
    local rotated_count
    rotated_count=$(find "$LOG_DIR" -maxdepth 1 -type f -name "*.log" \
        -size "+${LOG_SIZE_THRESHOLD}" ! -name "*.gz" ! -path "$LOG_FILE" \
        -print | wc -l)
    
    if ((rotated_count > 0)); then
        find "$LOG_DIR" -maxdepth 1 -type f -name "*.log" \
            -size "+${LOG_SIZE_THRESHOLD}" ! -name "*.gz" ! -path "$LOG_FILE" \
            -exec gzip {} \; 2>/dev/null || true
        log "INFO" "Rotated $rotated_count log files"
    fi
}

cleanup_old_logs() {
    log "INFO" "Cleaning up old log files..."
    
    local deleted_count
    deleted_count=$(find "$LOG_DIR" -type f -name "*.gz" \
        -mtime "+${LOG_RETENTION_DAYS}" -delete -print 2>/dev/null | wc -l)
    
    log "INFO" "Deleted $deleted_count log files older than ${LOG_RETENTION_DAYS} days"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    log "INFO" "========================================="
    log "INFO" "System monitoring routine started"
    log "INFO" "========================================="
    
    # Run health checks
    check_disk_usage || true
    check_service_health || true
    
    # Run log maintenance
    log "INFO" "Running log maintenance..."
    rotate_logs
    cleanup_old_logs
    
    log "INFO" "Routine completed successfully"
    log "INFO" "========================================="
}

main "$@"