#!/usr/bin/env bash
#
# Portainer Stack Deployment Script
# This script is executed on the LXC container by GitHub Actions
#
# Usage: ./deploy.sh [options]
# Options:
#   --validate-only     Validate configuration without deploying
#   --rollback         Rollback to previous version
#   --force            Skip health checks (dangerous!)
#
# Environment Variables:
#   COMPOSE_FILE       Path to compose file (default: containers/compose.yaml)
#   BACKUP_DIR         Backup directory (default: /mnt/local/backups)
#   REPO_DIR           Repository directory (default: /root/homelab)

set -euo pipefail  # Exit on error, undefined variables, pipe failures

# ============================================
# Configuration
# ============================================
readonly COMPOSE_FILE="${COMPOSE_FILE:-containers/compose.yaml}"
readonly BACKUP_DIR="${BACKUP_DIR:-/mnt/local/backups}"
readonly REPO_DIR="${REPO_DIR:-/root/homelab}"
readonly LOG_FILE="/var/log/portainer-deploy.log"
readonly MAX_HEALTH_CHECK_RETRIES=30
readonly HEALTH_CHECK_INTERVAL=5

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# ============================================
# Logging Functions
# ============================================
log() {
    echo -e "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"
}

# ============================================
# Pre-flight Checks
# ============================================
preflight_checks() {
    log_info "Running pre-flight checks..."

    # Check Docker daemon
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker daemon is not running"
        return 1
    fi
    log_info "✅ Docker daemon is running"

    # Check disk space
    local disk_usage
    disk_usage=$(df /mnt/local | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$disk_usage" -gt 90 ]; then
        log_error "Disk usage is ${disk_usage}% - critically high!"
        return 1
    elif [ "$disk_usage" -gt 85 ]; then
        log_warn "Disk usage is ${disk_usage}% - approaching limit"
    else
        log_info "✅ Disk usage: ${disk_usage}%"
    fi

    # Check repository exists
    if [ ! -d "$REPO_DIR" ]; then
        log_error "Repository directory not found: $REPO_DIR"
        return 1
    fi
    log_info "✅ Repository directory exists"

    # Check compose file exists
    if [ ! -f "$REPO_DIR/$COMPOSE_FILE" ]; then
        log_error "Compose file not found: $REPO_DIR/$COMPOSE_FILE"
        return 1
    fi
    log_info "✅ Compose file exists"

    # Validate compose file syntax
    if ! docker compose -f "$REPO_DIR/$COMPOSE_FILE" config --quiet; then
        log_error "Compose file validation failed"
        return 1
    fi
    log_info "✅ Compose file syntax is valid"

    # Check for :latest tags (anti-pattern)
    if grep -q ':latest' "$REPO_DIR/$COMPOSE_FILE"; then
        log_warn "Found :latest tags in compose file (not recommended for production)"
    fi

    log_info "✅ Pre-flight checks passed"
    return 0
}

# ============================================
# Backup Functions
# ============================================
create_backup() {
    log_info "Creating backup..."

    mkdir -p "$BACKUP_DIR"

    local backup_name="portainer-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    local backup_path="$BACKUP_DIR/$backup_name"

    # Stop Portainer gracefully to ensure consistent backup
    log_info "Stopping Portainer container..."
    docker compose -f "$REPO_DIR/$COMPOSE_FILE" stop portainer || true

    # Backup Portainer data volume
    log_info "Backing up data volume to $backup_path..."
    docker run --rm \
        -v portainer_data:/data:ro \
        -v "$BACKUP_DIR":/backup \
        alpine:3.21.0 \
        tar czf "/backup/$backup_name" -C /data .

    # Restart Portainer
    log_info "Restarting Portainer container..."
    docker compose -f "$REPO_DIR/$COMPOSE_FILE" start portainer || true

    # Verify backup
    if [ -f "$backup_path" ]; then
        local size
        size=$(du -h "$backup_path" | cut -f1)
        log_info "✅ Backup created: $backup_path ($size)"

        # Cleanup old backups (keep last 7 days)
        log_info "Cleaning up old backups..."
        find "$BACKUP_DIR" -name "portainer-backup-*.tar.gz" -mtime +7 -delete
    else
        log_error "Backup creation failed"
        return 1
    fi

    return 0
}

restore_backup() {
    local backup_file="${1:-}"

    if [ -z "$backup_file" ]; then
        # Use latest backup
        backup_file=$(ls -t "$BACKUP_DIR"/portainer-backup-*.tar.gz 2>/dev/null | head -1)
    fi

    if [ -z "$backup_file" ] || [ ! -f "$backup_file" ]; then
        log_error "No backup file found"
        return 1
    fi

    log_info "Restoring backup: $backup_file"

    # Stop Portainer
    docker compose -f "$REPO_DIR/$COMPOSE_FILE" stop portainer || true

    # Restore backup
    docker run --rm \
        -v portainer_data:/data \
        -v "$BACKUP_DIR":/backup:ro \
        alpine:3.21.0 \
        sh -c "cd /data && tar xzf /backup/$(basename "$backup_file")"

    # Start Portainer
    docker compose -f "$REPO_DIR/$COMPOSE_FILE" start portainer

    log_info "✅ Backup restored successfully"
    return 0
}

# ============================================
# Deployment Functions
# ============================================
sync_repository() {
    log_info "Syncing repository..."

    cd "$REPO_DIR"

    # Store current commit for rollback
    local current_commit
    current_commit=$(git rev-parse HEAD)
    echo "$current_commit" > /tmp/pre-deployment-commit
    log_info "Current commit: $current_commit"

    # Fetch latest changes
    git fetch origin

    # Reset to origin/main
    git reset --hard origin/main

    local new_commit
    new_commit=$(git rev-parse HEAD)
    log_info "New commit: $new_commit"

    # Show changes
    if [ "$current_commit" != "$new_commit" ]; then
        log_info "Changes:"
        git log --oneline "$current_commit..$new_commit" || true
        git diff --stat "$current_commit" "$new_commit" || true
    else
        log_info "No changes (already at latest commit)"
    fi

    return 0
}

pull_images() {
    log_info "Pulling container images..."

    cd "$REPO_DIR"

    if ! docker compose -f "$COMPOSE_FILE" pull; then
        log_error "Failed to pull container images"
        return 1
    fi

    log_info "✅ Images pulled successfully"
    return 0
}

deploy_services() {
    log_info "Deploying services..."

    cd "$REPO_DIR"

    # Deploy with minimal downtime (rolling update)
    if ! docker compose -f "$COMPOSE_FILE" up -d --remove-orphans; then
        log_error "Deployment failed"
        return 1
    fi

    log_info "✅ Services deployed"
    return 0
}

# ============================================
# Health Check Functions
# ============================================
health_check() {
    local force_skip="${1:-false}"

    if [ "$force_skip" = "true" ]; then
        log_warn "Skipping health checks (--force flag)"
        return 0
    fi

    log_info "Running health checks..."

    cd "$REPO_DIR"

    # Wait for containers to start
    sleep 10

    # Check for failed containers
    local failed_containers
    failed_containers=$(docker compose -f "$COMPOSE_FILE" ps --services --filter "status=exited" 2>/dev/null || true)

    if [ -n "$failed_containers" ]; then
        log_error "Failed containers detected:"
        echo "$failed_containers"
        docker compose -f "$COMPOSE_FILE" ps
        docker compose -f "$COMPOSE_FILE" logs --tail=100
        return 1
    fi

    # Check Portainer API health
    log_info "Checking Portainer API health..."
    local retry_count=0

    while [ $retry_count -lt $MAX_HEALTH_CHECK_RETRIES ]; do
        if curl -k -f -s https://localhost:9443/api/system/status > /dev/null 2>&1; then
            log_info "✅ Portainer API is healthy"
            break
        fi

        retry_count=$((retry_count + 1))
        log_info "⏳ Waiting for Portainer API... ($retry_count/$MAX_HEALTH_CHECK_RETRIES)"
        sleep $HEALTH_CHECK_INTERVAL
    done

    if [ $retry_count -eq $MAX_HEALTH_CHECK_RETRIES ]; then
        log_error "Portainer API health check failed after $MAX_HEALTH_CHECK_RETRIES retries"
        return 1
    fi

    # Check Homepage (non-critical)
    if curl -f -s http://localhost:3000 > /dev/null 2>&1; then
        log_info "✅ Homepage is healthy"
    else
        log_warn "Homepage health check failed (non-critical)"
    fi

    log_info "✅ All health checks passed"
    return 0
}

show_status() {
    log_info "Container status:"
    cd "$REPO_DIR"
    docker compose -f "$COMPOSE_FILE" ps
}

# ============================================
# Rollback Functions
# ============================================
rollback() {
    log_warn "Rolling back deployment..."

    if [ ! -f /tmp/pre-deployment-commit ]; then
        log_error "No previous commit found for rollback"
        return 1
    fi

    local rollback_commit
    rollback_commit=$(cat /tmp/pre-deployment-commit)
    log_info "Rolling back to commit: $rollback_commit"

    cd "$REPO_DIR"
    git reset --hard "$rollback_commit"

    # Redeploy
    if ! docker compose -f "$COMPOSE_FILE" up -d --remove-orphans; then
        log_error "Rollback deployment failed"
        return 1
    fi

    log_info "✅ Rollback complete"

    # Run health checks
    health_check false

    return 0
}

# ============================================
# Main Execution
# ============================================
main() {
    local validate_only=false
    local do_rollback=false
    local force_deploy=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --validate-only)
                validate_only=true
                shift
                ;;
            --rollback)
                do_rollback=true
                shift
                ;;
            --force)
                force_deploy=true
                shift
                ;;
            *)
                log_error "Unknown argument: $1"
                echo "Usage: $0 [--validate-only] [--rollback] [--force]"
                exit 1
                ;;
        esac
    done

    log_info "===== Portainer Deployment Script ====="
    log_info "Compose file: $COMPOSE_FILE"
    log_info "Repository: $REPO_DIR"
    log_info "Backup directory: $BACKUP_DIR"
    log_info ""

    # Handle rollback
    if [ "$do_rollback" = true ]; then
        rollback
        exit $?
    fi

    # Pre-flight checks
    if ! preflight_checks; then
        log_error "Pre-flight checks failed"
        exit 1
    fi

    # Validate-only mode
    if [ "$validate_only" = true ]; then
        log_info "Validation complete (--validate-only)"
        exit 0
    fi

    # Deployment flow
    if ! sync_repository; then
        log_error "Repository sync failed"
        exit 1
    fi

    if ! create_backup; then
        log_error "Backup failed - aborting deployment"
        exit 1
    fi

    if ! pull_images; then
        log_error "Image pull failed - consider rollback"
        exit 1
    fi

    if ! deploy_services; then
        log_error "Deployment failed - rolling back..."
        rollback
        exit 1
    fi

    if ! health_check "$force_deploy"; then
        log_error "Health checks failed - rolling back..."
        rollback
        exit 1
    fi

    show_status

    log_info ""
    log_info "===== Deployment Successful ====="
    log_info "Timestamp: $(date)"
    log_info "Commit: $(cd "$REPO_DIR" && git rev-parse HEAD)"
    log_info ""

    exit 0
}

# Execute main function
main "$@"
