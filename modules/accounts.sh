#!/bin/bash
#
# modules/accounts.sh
# Protocol-specific account creation (SSH/WS, VMess, VLESS, Trojan,
# SOCKS) with a clean, copyable connection-details output. Xray
# protocols are provisioned for real against the live Xray config;
# SSH/WS uses the same Linux account system as create_user.
#
# Sourced by menu.sh - do not execute directly.
#

XRAY_CONFIG_PATH="${XRAY_CONFIG_PATH:-/usr/local/etc/xray/config.json}"

# Preferred server address to embed in connection links: DOMAIN if
# configured, otherwise the VPS's public IP.
_accounts_server_address() {
    if [ -n "$DOMAIN" ]; then
        echo "$DOMAIN"
        return
    fi
    local ip
    ip=$(curl -s --max-time 3 https://ifconfig.me 2>/dev/null)
    if [ -z "$ip" ] || echo "$ip" | grep -qi "error\|not in allowlist\|<html\|rate limit"; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    [ -z "$ip" ] && ip="N/A"
    echo "$ip"
}

# Print a copyable account-details box for a Linux/SSH-WS account
_accounts_show_ssh_details() {
    local username="$1"
    local password="$2"
    local address
    address=$(_accounts_server_address)

    box_top
    box_line "${WHITE}SSH / WS ACCOUNT DETAILS${RESET}" center
    box_divider
    box_line "Host      : $address"
    box_line "Port      : 22"
    box_line "Username  : $username"
    box_line "Password  : $password"
    box_bottom
}

# Print a copyable account-details box for an SSH UDP account. Same
# Linux login as SSH, but shows the UDP tunnel port as well - that's
# the extra piece client apps (HTTP Injector etc.) need to connect.
_accounts_show_sshudp_details() {
    local username="$1"
    local password="$2"
    local address
    address=$(_accounts_server_address)

    box_top
    box_line "${WHITE}SSH UDP ACCOUNT DETAILS${RESET}" center
    box_divider
    box_line "Host      : $address"
    box_line "SSH Port  : 22"
    box_line "UDP Port  : ${SSHUDP_PORT:-7300}"
    box_line "Username  : $username"
    box_line "Password  : $password"
    box_bottom
}

# Shared account-creation logic used by every menu that creates a
# plain Linux login (SSH/WS, SSH UDP). Returns 0 on success with
# username/password available via the global _PROV_USER/_PROV_PASS,
# 1 on failure (already reported via error()).
_accounts_create_linux_user() {
    local username="$1"
    local password="$2"
    local expire_days="$3"

    if [ -z "$username" ]; then
        error "Username cannot be empty."
        return 1
    fi
    if id "$username" >/dev/null 2>&1; then
        error "User '$username' already exists."
        return 1
    fi
    if [ -z "$password" ]; then
        error "Password cannot be empty."
        return 1
    fi

    useradd -m -s /bin/bash "$username"
    echo "${username}:${password}" | chpasswd

    if [ -n "$expire_days" ]; then
        local expire_date
        expire_date=$(date -d "+${expire_days} days" +%Y-%m-%d)
        chage -E "$expire_date" "$username"
    fi

    return 0
}

# Same as above but for an hours-based trial expiry, and generates
# the username/password itself. Prints the generated username via
# stdout for the caller to capture.
_accounts_create_linux_trial() {
    local trial_hours="$1"

    local trial_user="trial$(date +%s | tail -c 5)"
    local trial_pass
    trial_pass=$(openssl rand -base64 6 2>/dev/null | tr -dc 'a-zA-Z0-9' | head -c 8)
    [ -z "$trial_pass" ] && trial_pass="trial$(( RANDOM % 9000 + 1000 ))"

    useradd -m -s /bin/bash "$trial_user"
    echo "${trial_user}:${trial_pass}" | chpasswd

    local expire_date
    expire_date=$(date -d "+${trial_hours} hours" +%Y-%m-%d)
    chage -E "$expire_date" "$trial_user"

    echo "USER=$trial_user"
    echo "PASS=$trial_pass"
    echo "EXPIRES=$expire_date"
}

# Provision one Xray-based protocol account and print its connection
# details. Requires Xray to be installed and to already have an
# inbound configured for the requested protocol.
_accounts_create_xray_account() {
    local protocol="$1"
    local username="$2"

    if ! systemctl list-unit-files 2>/dev/null | grep -q "^xray\.service"; then
        error "Xray is not installed. Install it via the SERVICES box (Toggle Xray) first."
        return 1
    fi

    if [ ! -f "$XRAY_CONFIG_PATH" ]; then
        error "No Xray config found at $XRAY_CONFIG_PATH."
        return 1
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        error "python3 is required for this feature but isn't installed."
        return 1
    fi

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

    local address
    address=$(_accounts_server_address)

    local backup_path="${XRAY_CONFIG_PATH}.bak_$(date +%Y%m%d_%H%M%S)"
    cp "$XRAY_CONFIG_PATH" "$backup_path" 2>/dev/null

    local fields
    fields=$(python3 "$script_dir/scripts/xray_provision.py" "$XRAY_CONFIG_PATH" "$protocol" "$username" "$address" 2>&1)
    local exit_code=$?

    if [ "$exit_code" -ne 0 ]; then
        error "$fields"
        rm -f "$backup_path" 2>/dev/null
        return 1
    fi

    local link
    link=$(echo "$fields" | python3 "$script_dir/scripts/build_share_link.py" "$username" 2>&1)

    systemctl restart xray >/dev/null 2>&1

    local port network security
    port=$(echo "$fields" | grep '^PORT=' | cut -d= -f2-)
    network=$(echo "$fields" | grep '^NETWORK=' | cut -d= -f2-)
    security=$(echo "$fields" | grep '^SECURITY=' | cut -d= -f2-)

    box_top
    box_line "${WHITE}$(echo "$protocol" | tr '[:lower:]' '[:upper:]') ACCOUNT DETAILS${RESET}" center
    box_divider
    box_line "Address   : $address"
    box_line "Port      : $port"
    box_line "Network   : $network"
    box_line "Security  : $security"
    box_line "Username  : $username"
    box_bottom
    echo
    echo -e "${CYAN}Copy this into your client app:${RESET}"
    echo -e "${GREEN}${link}${RESET}"
    echo
    success "Account created."
    return 0
}

# ---------- Menu-facing entry points ----------

create_account_ssh_standard() {
    banner
    echo -e "${WHITE} CREATE SSH/WS ACCOUNT${RESET}"
    line

    read -rp "Enter username: " uname_input
    read -rsp "Enter password: " pass_input
    echo
    read -rp "Account expiry in days (leave blank for none): " expire_days

    if _accounts_create_linux_user "$uname_input" "$pass_input" "$expire_days"; then
        success "Account created."
        _accounts_show_ssh_details "$uname_input" "$pass_input"
    fi
    line
}

create_account_ssh_trial() {
    banner
    echo -e "${WHITE} CREATE SSH/WS TRIAL ACCOUNT${RESET}"
    line

    read -rp "Trial duration in hours [default: 24]: " trial_hours
    trial_hours=${trial_hours:-24}

    local result trial_user trial_pass expire_date
    result=$(_accounts_create_linux_trial "$trial_hours")
    trial_user=$(echo "$result" | grep '^USER=' | cut -d= -f2-)
    trial_pass=$(echo "$result" | grep '^PASS=' | cut -d= -f2-)
    expire_date=$(echo "$result" | grep '^EXPIRES=' | cut -d= -f2-)

    success "Trial account created."
    _accounts_show_ssh_details "$trial_user" "$trial_pass"
    echo -e "${CYAN}Expires  :${RESET} $expire_date (in ${trial_hours}h)"
    line
}

# SSH UDP: same Linux login mechanism as SSH/WS, but the account
# details shown highlight the UDP tunnel port too (SSHUDP_PORT in
# config.conf) since that's the extra piece client apps need.
create_account_sshudp_standard() {
    banner
    echo -e "${WHITE} CREATE SSH UDP ACCOUNT${RESET}"
    line

    if ! systemctl list-unit-files 2>/dev/null | grep -q "^sshudp\.service"; then
        warning "SSH UDP service isn't installed yet - install it via the SERVICES box (Toggle SSH UDP) first."
        echo "The Linux account below will still be created and works over plain SSH;"
        echo "it just won't tunnel over UDP until the service is installed."
        echo
    fi

    read -rp "Enter username: " uname_input
    read -rsp "Enter password: " pass_input
    echo
    read -rp "Account expiry in days (leave blank for none): " expire_days

    if _accounts_create_linux_user "$uname_input" "$pass_input" "$expire_days"; then
        success "Account created."
        _accounts_show_sshudp_details "$uname_input" "$pass_input"
    fi
    line
}

create_account_sshudp_trial() {
    banner
    echo -e "${WHITE} CREATE SSH UDP TRIAL ACCOUNT${RESET}"
    line

    if ! systemctl list-unit-files 2>/dev/null | grep -q "^sshudp\.service"; then
        warning "SSH UDP service isn't installed yet - install it via the SERVICES box (Toggle SSH UDP) first."
        echo "The Linux account below will still be created and works over plain SSH;"
        echo "it just won't tunnel over UDP until the service is installed."
        echo
    fi

    read -rp "Trial duration in hours [default: 24]: " trial_hours
    trial_hours=${trial_hours:-24}

    local result trial_user trial_pass expire_date
    result=$(_accounts_create_linux_trial "$trial_hours")
    trial_user=$(echo "$result" | grep '^USER=' | cut -d= -f2-)
    trial_pass=$(echo "$result" | grep '^PASS=' | cut -d= -f2-)
    expire_date=$(echo "$result" | grep '^EXPIRES=' | cut -d= -f2-)

    success "Trial account created."
    _accounts_show_sshudp_details "$trial_user" "$trial_pass"
    echo -e "${CYAN}Expires  :${RESET} $expire_date (in ${trial_hours}h)"
    line
}

create_account_vmess() {
    banner
    echo -e "${WHITE} CREATE VMESS ACCOUNT${RESET}"
    line
    read -rp "Enter username: " uname_input
    [ -z "$uname_input" ] && { error "Username cannot be empty."; return 1; }
    _accounts_create_xray_account "vmess" "$uname_input"
    line
}

create_account_vless() {
    banner
    echo -e "${WHITE} CREATE VLESS ACCOUNT${RESET}"
    line
    read -rp "Enter username: " uname_input
    [ -z "$uname_input" ] && { error "Username cannot be empty."; return 1; }
    _accounts_create_xray_account "vless" "$uname_input"
    line
}

create_account_trojan() {
    banner
    echo -e "${WHITE} CREATE TROJAN ACCOUNT${RESET}"
    line
    read -rp "Enter username: " uname_input
    [ -z "$uname_input" ] && { error "Username cannot be empty."; return 1; }
    _accounts_create_xray_account "trojan" "$uname_input"
    line
}

create_account_socks() {
    banner
    echo -e "${WHITE} CREATE SOCKS ACCOUNT${RESET}"
    line
    read -rp "Enter username: " uname_input
    [ -z "$uname_input" ] && { error "Username cannot be empty."; return 1; }
    _accounts_create_xray_account "socks" "$uname_input"
    line
}

# Print a copyable account-details box for a ZIVPN account
_accounts_show_zivpn_details() {
    local username="$1"
    local password="$2"
    local address
    address=$(_accounts_server_address)

    box_top
    box_line "${WHITE}ZIVPN ACCOUNT DETAILS${RESET}" center
    box_divider
    box_line "Host      : $address"
    box_line "UDP Port  : ${ZIVPN_PORT:-5667}"
    box_line "Username  : $username"
    box_line "Password  : $password"
    box_bottom
}

_accounts_zivpn_not_wired_notice() {
    warning "This creates a tracking account (Linux login + these details),"
    echo "but doesn't add the password to ZIVPN's own config yet - no install"
    echo "source is configured for ZIVPN (ZIVPN_INSTALL_URL in config.conf),"
    echo "so this tool doesn't know its config file format. Add the password"
    echo "to ZIVPN's config manually for now, or tell me which ZIVPN build"
    echo "you're using and I can wire this up for real."
    echo
}

create_account_zivpn_standard() {
    banner
    echo -e "${WHITE} CREATE ZIVPN ACCOUNT${RESET}"
    line
    _accounts_zivpn_not_wired_notice

    read -rp "Enter username: " uname_input
    read -rsp "Enter password: " pass_input
    echo
    read -rp "Account expiry in days (leave blank for none): " expire_days

    if _accounts_create_linux_user "$uname_input" "$pass_input" "$expire_days"; then
        success "Account created."
        _accounts_show_zivpn_details "$uname_input" "$pass_input"
    fi
    line
}

create_account_zivpn_trial() {
    banner
    echo -e "${WHITE} CREATE ZIVPN TRIAL ACCOUNT${RESET}"
    line
    _accounts_zivpn_not_wired_notice

    read -rp "Trial duration in hours [default: 24]: " trial_hours
    trial_hours=${trial_hours:-24}

    local result trial_user trial_pass expire_date
    result=$(_accounts_create_linux_trial "$trial_hours")
    trial_user=$(echo "$result" | grep '^USER=' | cut -d= -f2-)
    trial_pass=$(echo "$result" | grep '^PASS=' | cut -d= -f2-)
    expire_date=$(echo "$result" | grep '^EXPIRES=' | cut -d= -f2-)

    success "Trial account created."
    _accounts_show_zivpn_details "$trial_user" "$trial_pass"
    echo -e "${CYAN}Expires  :${RESET} $expire_date (in ${trial_hours}h)"
    line
}
