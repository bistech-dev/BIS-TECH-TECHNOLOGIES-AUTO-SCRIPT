#!/bin/bash
#
# modules/backup.sh
# Backup important configuration files.
# Sourced by menu.sh - do not execute directly.
#

# Files/directories considered important enough to back up.
# Only existing paths are included in the archive.
BACKUP_TARGETS=(
    "/etc/ssh/sshd_config"
    "/etc/hosts"
    "/etc/hostname"
    "/etc/passwd"
    "/etc/group"
    "/etc/ufw"
    "/etc/crontab"
    "/opt/bis-tech/config.conf"
)

# Create a timestamped backup archive
backup_vps() {
    banner
    echo -e "${WHITE} BACKUP VPS${RESET}"
    line

    mkdir -p "$BACKUP_DIR"

    local timestamp
    timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    local archive_name="backup_${timestamp}.tar.gz"
    local archive_path="${BACKUP_DIR}/${archive_name}"

    local existing_targets=()
    for target in "${BACKUP_TARGETS[@]}"; do
        [ -e "$target" ] && existing_targets+=("$target")
    done

    if [ ${#existing_targets[@]} -eq 0 ]; then
        error "No backup targets found on this system."
        return 1
    fi

    info "Creating backup archive..."
    tar -czf "$archive_path" "${existing_targets[@]}" 2>/dev/null

    if [ -f "$archive_path" ]; then
        success "Backup created: $archive_path"
        echo -e "${CYAN}Size:${RESET} $(du -h "$archive_path" | cut -f1)"
    else
        error "Backup failed."
        return 1
    fi
    line
}

# List all available backup archives
list_backups() {
    banner
    echo -e "${WHITE} AVAILABLE BACKUPS${RESET}"
    line

    mkdir -p "$BACKUP_DIR"

    if [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        warning "No backups found in $BACKUP_DIR"
        line
        return 0
    fi

    local i=1
    for f in "$BACKUP_DIR"/*.tar.gz; do
        [ -e "$f" ] || continue
        echo -e "${CYAN}[$i]${RESET} $(basename "$f")  ($(du -h "$f" | cut -f1))"
        i=$((i+1))
    done
    line
}
