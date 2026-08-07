#!/bin/bash
#
# modules/provisioning.sh
# When a Linux account is created (create_user / create_trial_user),
# this provisions the SAME username across the other protocols this
# tool manages, so one account creation covers everything instead of
# needing separate steps per protocol.
#
# Coverage today:
#   - SSH:      covered automatically - it IS the Linux account.
#   - SSH UDP:  covered automatically - it tunnels over the same SSH
#               login, no separate account exists.
#   - Xray:     a real client entry (UUID or Trojan password) is added
#               to /usr/local/etc/xray/config.json if Xray is installed
#               and configured, then the service is reloaded.
#   - ZIVPN:    NOT provisioned. There's no install source configured
#               for ZIVPN yet (see ZIVPN_INSTALL_URL in config.conf),
#               so this tool doesn't know its config format and won't
#               guess at one. Once you wire in a real ZIVPN installer,
#               this is the function to extend.
#
# Sourced by menu.sh - do not execute directly.
#

XRAY_CONFIG_PATH="${XRAY_CONFIG_PATH:-/usr/local/etc/xray/config.json}"

# Add a client to the Xray config for the given username, if Xray is
# installed and configured. Silent no-op (with an info note) if not -
# this is meant to enhance account creation, never block it.
provision_xray_client() {
    local username="$1"

    if ! systemctl list-unit-files 2>/dev/null | grep -q "^xray\.service"; then
        return 0
    fi

    if [ ! -f "$XRAY_CONFIG_PATH" ]; then
        warning "Xray is installed but no config found at $XRAY_CONFIG_PATH - skipping Xray provisioning."
        return 0
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        warning "python3 is required to edit the Xray config - skipping Xray provisioning."
        return 0
    fi

    # Back up before modifying, consistent with this project's
    # "backup before modification" principle.
    local backup_path="${XRAY_CONFIG_PATH}.bak_$(date +%Y%m%d_%H%M%S)"
    cp "$XRAY_CONFIG_PATH" "$backup_path" 2>/dev/null

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

    local result
    result=$(python3 "$script_dir/scripts/add_xray_client.py" "$XRAY_CONFIG_PATH" "$username" 2>&1)
    local exit_code=$?

    if [ "$exit_code" -ne 0 ]; then
        warning "Xray provisioning skipped: $result"
        rm -f "$backup_path" 2>/dev/null
        return 1
    fi

    systemctl restart xray >/dev/null 2>&1

    echo -e "${CYAN}Xray credential:${RESET} $result"
    success "Xray client added for '$username'."
    return 0
}

# Called after a Linux user is created, to provision the same
# username across every other protocol this tool manages.
provision_all_protocols() {
    local username="$1"

    echo
    info "Provisioning '$username' across supported protocols..."
    echo -e "${CYAN}SSH${RESET}      : ready (same login)"
    echo -e "${CYAN}SSH UDP${RESET}  : ready (tunnels over the same login)"
    provision_xray_client "$username"
    echo -e "${CYAN}ZIVPN${RESET}    : not provisioned - no install source configured yet (see ZIVPN_INSTALL_URL in config.conf)"
}
