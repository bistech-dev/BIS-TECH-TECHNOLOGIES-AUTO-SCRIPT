#!/bin/bash
#
# modules/uninstall.sh
# Removes BIS-TECH AUTO SCRIPT from the system.
# Sourced by menu.sh - do not execute directly.
#

uninstall_script() {
    banner
    echo -e "${WHITE} UNINSTALL SCRIPT${RESET}"
    line

    warning "This will remove BIS-TECH AUTO SCRIPT and the 'bis-tech' command."
    warning "Your backups in $BACKUP_DIR will NOT be touched unless you confirm below."
    read -rp "Are you sure you want to uninstall? (y/N): " confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        warning "Uninstall cancelled."
        return 0
    fi

    read -rp "Also delete backups in $BACKUP_DIR? (y/N): " del_backups

    info "Removing command shortcut..."
    rm -f /usr/local/bin/bis-tech

    if [[ "$del_backups" =~ ^[Yy]$ ]]; then
        info "Removing installation directory (including backups)..."
        rm -rf "$INSTALL_DIR"
    else
        info "Removing script files (keeping backups)..."
        find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 ! -name "backups" -exec rm -rf {} +
    fi

    success "BIS-TECH AUTO SCRIPT has been uninstalled."
    echo "Goodbye!"
    exit 0
}
