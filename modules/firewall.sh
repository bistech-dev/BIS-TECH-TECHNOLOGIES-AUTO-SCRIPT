#!/bin/bash
#
# modules/firewall.sh
# UFW firewall management functions.
# Sourced by menu.sh - do not execute directly.
#

_check_ufw_installed() {
    if ! command -v ufw >/dev/null 2>&1; then
        error "ufw is not installed. Re-run install.sh to install dependencies."
        return 1
    fi
    return 0
}

# Show current firewall status
firewall_status() {
    banner
    echo -e "${WHITE} FIREWALL STATUS${RESET}"
    line
    _check_ufw_installed || return 1
    ufw status verbose
    line
}

# Enable the firewall (opens SSH first to avoid lockout)
firewall_enable() {
    banner
    echo -e "${WHITE} ENABLE FIREWALL${RESET}"
    line
    _check_ufw_installed || return 1

    info "Ensuring SSH port is allowed before enabling firewall (avoid lockout)..."
    ufw allow OpenSSH >/dev/null 2>&1
    ufw allow 22/tcp >/dev/null 2>&1

    ufw --force enable
    success "Firewall enabled."
    line
}

# Disable the firewall
firewall_disable() {
    banner
    echo -e "${WHITE} DISABLE FIREWALL${RESET}"
    line
    _check_ufw_installed || return 1

    read -rp "Are you sure you want to disable the firewall? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        warning "Cancelled."
        return 0
    fi

    ufw disable
    success "Firewall disabled."
    line
}

# Allow common administration / server ports
firewall_allow_admin_ports() {
    banner
    echo -e "${WHITE} ALLOW ADMINISTRATION PORTS${RESET}"
    line
    _check_ufw_installed || return 1

    local ports=("22/tcp" "80/tcp" "443/tcp")
    for p in "${ports[@]}"; do
        ufw allow "$p" >/dev/null 2>&1
        success "Allowed port: $p"
    done

    read -rp "Enter any additional port to allow (leave blank to skip): " extra_port
    if [ -n "$extra_port" ]; then
        ufw allow "$extra_port" >/dev/null 2>&1
        success "Allowed port: $extra_port"
    fi
    line
}

# Show all current firewall rules
firewall_show_rules() {
    banner
    echo -e "${WHITE} FIREWALL RULES${RESET}"
    line
    _check_ufw_installed || return 1
    ufw status numbered
    line
}

# Simple aggregate menu used by the "Firewall Manager" main menu entry
firewall_manager() {
    while true; do
        banner
        echo -e "${WHITE} FIREWALL MANAGER${RESET}"
        line
        echo " [1] Show Status"
        echo " [2] Enable Firewall"
        echo " [3] Disable Firewall"
        echo " [4] Allow Admin Ports"
        echo " [5] Show Rules"
        echo " [0] Back to Main Menu"
        line
        read -rp "Select an option: " fw_choice
        case $fw_choice in
            1) firewall_status ;;
            2) firewall_enable ;;
            3) firewall_disable ;;
            4) firewall_allow_admin_ports ;;
            5) firewall_show_rules ;;
            0) return 0 ;;
            *) warning "Invalid option." ;;
        esac
        read -rp "Press Enter to continue..." _
    done
}
