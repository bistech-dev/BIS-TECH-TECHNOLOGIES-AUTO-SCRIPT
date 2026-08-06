#!/bin/bash
#
# modules/restore.sh
# Restore configuration files from a previously created backup.
# Sourced by menu.sh - do not execute directly.
#

# Restore a selected backup archive to the filesystem root
restore_vps() {
    banner
    echo -e "${WHITE} RESTORE VPS${RESET}"
    line

    mkdir -p "$BACKUP_DIR"

    if [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        warning "No backups found in $BACKUP_DIR"
        line
        return 0
    fi

    local backups=()
    local i=1
    for f in "$BACKUP_DIR"/*.tar.gz; do
        [ -e "$f" ] || continue
        echo -e "${CYAN}[$i]${RESET} $(basename "$f")"
        backups+=("$f")
        i=$((i+1))
    done
    line

    read -rp "Enter the number of the backup to restore (0 to cancel): " choice
    if [ "$choice" = "0" ] || [ -z "$choice" ]; then
        warning "Cancelled."
        return 0
    fi

    local index=$((choice-1))
    if [ "$index" -lt 0 ] || [ "$index" -ge "${#backups[@]}" ]; then
        error "Invalid selection."
        return 1
    fi

    local selected_backup="${backups[$index]}"

    warning "This will overwrite existing configuration files with the backup contents."
    read -rp "Continue? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        warning "Cancelled."
        return 0
    fi

    info "Restoring from $(basename "$selected_backup")..."
    tar -xzf "$selected_backup" -C / 2>/dev/null

    if [ $? -eq 0 ]; then
        success "Restore completed successfully."
        warning "You may need to restart affected services (e.g. ssh, ufw) for changes to take effect."
    else
        error "Restore failed."
        return 1
    fi
    line
}
