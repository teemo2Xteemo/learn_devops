#!/usr/bin/env bash

set -euo pipefail

# --- CLEANUP SCRIPT FOR DEVOPS LAB ---
# Purpose: Clean up logs, temporary files, Docker resources, and Terraform state
# Usage: ./cleanup.sh [OPTIONS]
# Options:
#   --dry-run        Show what would be deleted without actually deleting
#   --no-confirm     Skip confirmation prompts
#   --backup         Backup logs before deletion
#   --full           Full cleanup including Docker and Terraform state
#   --help           Show this help message

# --- CONFIGURATION ---
CLEANUP_LOG="/opt/devops-monitor/logs/cleanup.log"
BACKUP_DIR="/opt/devops-monitor/backups"
DRY_RUN=false
CONFIRM_PROMPT=true
BACKUP_LOGS=false
FULL_CLEANUP=false
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# Create necessary directories
mkdir -p "$(dirname "$CLEANUP_LOG")" 2>/dev/null || true
mkdir -p "$BACKUP_DIR" 2>/dev/null || true

# --- HELPER FUNCTIONS ---
log() {
    local level="$1"
    shift
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] $*"
    echo "$msg" | tee -a "$CLEANUP_LOG"
}

info() { log "INFO" "$@"; }
warn() { log "WARN" "$@"; }
error() { log "ERROR" "$@"; }

print_help() {
    cat << EOF
Cleanup Script for DevOps Lab
==============================

Usage: ./cleanup.sh [OPTIONS]

Options:
  --dry-run        Show what would be deleted without actually deleting
  --no-confirm     Skip confirmation prompts (use with caution!)
  --backup         Backup logs before deletion
  --full           Full cleanup including Docker and Terraform state
  --help           Show this help message

Examples:
  # Preview cleanup without making changes
  ./cleanup.sh --dry-run

  # Clean logs only with confirmation
  ./cleanup.sh --backup

  # Full cleanup without prompts (careful!)
  ./cleanup.sh --full --no-confirm --dry-run

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                info "DRY RUN MODE: No files will be deleted"
                shift
                ;;
            --no-confirm)
                CONFIRM_PROMPT=false
                info "Confirmation prompts disabled"
                shift
                ;;
            --backup)
                BACKUP_LOGS=true
                info "Log backup enabled"
                shift
                ;;
            --full)
                FULL_CLEANUP=true
                info "Full cleanup mode enabled"
                shift
                ;;
            --help)
                print_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                print_help
                exit 1
                ;;
        esac
    done
}

# Confirm before potentially destructive operations
confirm() {
    local prompt="$1"
    
    if [[ "$CONFIRM_PROMPT" == false ]]; then
        return 0
    fi
    
    read -p "$prompt (yes/no): " -r response
    case "$response" in
        yes|YES|y|Y) return 0 ;;
        *) return 1 ;;
    esac
}

# Execute cleanup command (respecting dry-run mode)
execute() {
    local cmd="$1"
    local description="$2"
    
    if [[ "$DRY_RUN" == true ]]; then
        info "[DRY-RUN] Would execute: $cmd"
    else
        info "Executing: $description"
        if eval "$cmd"; then
            info "✓ Completed: $description"
        else
            error "✗ Failed: $description"
            return 1
        fi
    fi
}

# --- CLEANUP FUNCTIONS ---

cleanup_logs() {
    info "=== Starting Log Cleanup ==="
    
    local log_dir="/opt/devops-monitor/logs"
    
    if [[ ! -d "$log_dir" ]]; then
        warn "Log directory not found: $log_dir"
        return 0
    fi
    
    # Count logs to be deleted
    local old_logs_count=$(find "$log_dir" -type f -name "*.gz" -mtime +7 2>/dev/null | wc -l)
    
    if [[ $old_logs_count -eq 0 ]]; then
        info "No old log files to clean up"
        return 0
    fi
    
    info "Found $old_logs_count log files older than 7 days"
    
    # Backup logs if requested
    if [[ "$BACKUP_LOGS" == true ]]; then
        if confirm "Backup logs before deletion?"; then
            local backup_file="${BACKUP_DIR}/logs_backup_${TIMESTAMP}.tar.gz"
            execute "tar -czf '$backup_file' -C '$(dirname "$log_dir")' '$(basename "$log_dir")' 2>/dev/null || true" \
                "Backup logs to $backup_file"
        fi
    fi
    
    # Delete old logs
    if confirm "Delete $old_logs_count old log files?"; then
        execute "find '$log_dir' -type f -name '*.gz' -mtime +7 -delete" \
            "Delete log files older than 7 days"
    fi
    
    info "=== Log Cleanup Complete ==="
}

cleanup_temp_files() {
    info "=== Starting Temporary Files Cleanup ==="
    
    # Common temporary directories
    local temp_locations=(
        "/tmp/devops-*"
        "/var/tmp/devops-*"
        "$HOME/.cache/devops-*"
    )
    
    local total_removed=0
    
    for pattern in "${temp_locations[@]}"; do
        local count=$(find /tmp /var/tmp "$HOME/.cache" -maxdepth 1 -name "$(basename "$pattern")" 2>/dev/null | wc -l)
        if [[ $count -gt 0 ]]; then
            info "Found $count temporary files matching: $pattern"
            if confirm "Remove $count files matching $pattern?"; then
                execute "find /tmp /var/tmp '$HOME/.cache' -maxdepth 1 -name '$(basename \"$pattern\")' -delete 2>/dev/null || true" \
                    "Remove temporary files: $pattern"
                ((total_removed += count))
            fi
        fi
    done
    
    info "Removed $total_removed temporary files"
    info "=== Temporary Files Cleanup Complete ==="
}

cleanup_docker() {
    info "=== Starting Docker Cleanup ==="
    
    if ! command -v docker &> /dev/null; then
        warn "Docker is not installed or not in PATH"
        return 0
    fi
    
    # Remove stopped containers
    local stopped_containers=$(docker ps -aq --filter "status=exited" 2>/dev/null | wc -l)
    if [[ $stopped_containers -gt 0 ]]; then
        info "Found $stopped_containers stopped Docker containers"
        if confirm "Remove $stopped_containers stopped containers?"; then
            execute "docker container prune -f --filter 'until=72h'" \
                "Remove stopped containers older than 72 hours"
        fi
    fi
    
    # Remove dangling images
    local dangling_images=$(docker images -q -f "dangling=true" 2>/dev/null | wc -l)
    if [[ $dangling_images -gt 0 ]]; then
        info "Found $dangling_images dangling Docker images"
        if confirm "Remove $dangling_images dangling images?"; then
            execute "docker image prune -f" \
                "Remove dangling Docker images"
        fi
    fi
    
    # Remove unused networks
    local unused_networks=$(docker network ls -q --filter "type=custom" 2>/dev/null | wc -l)
    if [[ $unused_networks -gt 0 ]]; then
        info "Found $unused_networks unused Docker networks"
        if confirm "Remove $unused_networks unused networks?"; then
            execute "docker network prune -f" \
                "Remove unused Docker networks"
        fi
    fi
    
    info "=== Docker Cleanup Complete ==="
}

cleanup_terraform() {
    info "=== Starting Terraform State Cleanup ==="
    
    local tf_state_files=$(find . -name "terraform.tfstate*" -type f 2>/dev/null | wc -l)
    
    if [[ $tf_state_files -eq 0 ]]; then
        info "No Terraform state files found"
        return 0
    fi
    
    info "Found $tf_state_files Terraform state files"
    info "Terraform state files should generally not be deleted!"
    warn "Consider backing up state files instead of deleting them"
    
    if confirm "Do you want to backup Terraform state files?"; then
        local backup_file="${BACKUP_DIR}/terraform_state_${TIMESTAMP}.tar.gz"
        execute "find . -name 'terraform.tfstate*' -type f -print0 | tar -czf '$backup_file' --null -T -" \
            "Backup Terraform state files"
    fi
    
    info "=== Terraform State Cleanup Complete ==="
}

cleanup_disk_space() {
    info "=== Disk Space Summary ==="
    
    # Show disk usage before cleanup
    df -h / | tail -1 | awk '{print "Root filesystem: " $5 " used, " $4 " available"}'
    
    # Show log directory size
    if [[ -d "/opt/devops-monitor/logs" ]]; then
        local log_size=$(du -sh "/opt/devops-monitor/logs" 2>/dev/null | cut -f1)
        info "Log directory size: $log_size"
    fi
    
    # Show cleanup log size
    if [[ -f "$CLEANUP_LOG" ]]; then
        local cleanup_log_size=$(du -sh "$CLEANUP_LOG" 2>/dev/null | cut -f1)
        info "Cleanup log size: $cleanup_log_size"
    fi
}

# --- MAIN EXECUTION ---
main() {
    parse_args "$@"
    
    info "==================================="
    info "DevOps Cleanup Script Started"
    info "==================================="
    info "Timestamp: $TIMESTAMP"
    [[ "$DRY_RUN" == true ]] && info "MODE: DRY RUN (no changes will be made)"
    [[ "$FULL_CLEANUP" == true ]] && info "MODE: FULL CLEANUP"
    
    # Run cleanup functions
    cleanup_logs
    cleanup_temp_files
    
    if [[ "$FULL_CLEANUP" == true ]]; then
        cleanup_docker
        cleanup_terraform
    fi
    
    cleanup_disk_space
    
    info "==================================="
    info "DevOps Cleanup Script Completed"
    info "==================================="
    info "Cleanup log saved to: $CLEANUP_LOG"
}

# Run main function
main "$@"
