#!/bin/bash
#
# modules/users.sh
# Linux user account management functions.
# Sourced by menu.sh - do not execute directly.
#

# Create a new Linux user
create_user() {
    banner
    echo -e "${WHITE} CREATE USER${RESET}"
    line

    read -rp "Enter new username: " uname_input
    if [ -z "$uname_input" ]; then
        error "Username cannot be empty."
        return 1
    fi

    if id "$uname_input" >/dev/null 2>&1; then
        error "User '$uname_input' already exists."
        return 1
    fi

    read -rsp "Enter password: " pass_input
    echo
    if [ -z "$pass_input" ]; then
        error "Password cannot be empty."
        return 1
    fi

    read -rp "Account expiry in days (leave blank for none): " expire_days

    useradd -m -s /bin/bash "$uname_input"
    echo "${uname_input}:${pass_input}" | chpasswd

    if [ -n "$expire_days" ]; then
        local expire_date
        expire_date=$(date -d "+${expire_days} days" +%Y-%m-%d)
        chage -E "$expire_date" "$uname_input"
        info "Account will expire on: $expire_date"
    fi

    success "User '$uname_input' created successfully."
    provision_all_protocols "$uname_input"
    line
}

# Create a short-lived trial account (default 1 day expiry)
create_trial_user() {
    banner
    echo -e "${WHITE} CREATE TRIAL ACCOUNT${RESET}"
    line

    local trial_user="trial$(date +%s | tail -c 5)"
    local trial_pass
    trial_pass=$(openssl rand -base64 6 2>/dev/null | tr -dc 'a-zA-Z0-9' | head -c 8)
    [ -z "$trial_pass" ] && trial_pass="trial$(( RANDOM % 9000 + 1000 ))"

    read -rp "Trial duration in hours [default: 24]: " trial_hours
    trial_hours=${trial_hours:-24}

    useradd -m -s /bin/bash "$trial_user"
    echo "${trial_user}:${trial_pass}" | chpasswd

    local expire_date
    expire_date=$(date -d "+${trial_hours} hours" +%Y-%m-%d)
    chage -E "$expire_date" "$trial_user"

    success "Trial account created."
    echo -e "${CYAN}Username:${RESET} $trial_user"
    echo -e "${CYAN}Password:${RESET} $trial_pass"
    echo -e "${CYAN}Expires :${RESET} $expire_date"
    provision_all_protocols "$trial_user"
    line
}

# Delete an existing Linux user
delete_user() {
    banner
    echo -e "${WHITE} DELETE USER${RESET}"
    line

    read -rp "Enter username to delete: " uname_input
    if [ -z "$uname_input" ]; then
        error "Username cannot be empty."
        return 1
    fi

    if ! id "$uname_input" >/dev/null 2>&1; then
        error "User '$uname_input' does not exist."
        return 1
    fi

    read -rp "Are you sure you want to delete '$uname_input'? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        warning "Cancelled."
        return 0
    fi

    userdel -r "$uname_input" >/dev/null 2>&1
    success "User '$uname_input' deleted."
    line
}

# List all human (non-system) Linux users
list_users() {
    banner
    echo -e "${WHITE} SYSTEM USERS${RESET}"
    line
    printf "${CYAN}%-20s %-10s %-15s${RESET}\n" "USERNAME" "UID" "EXPIRES"
    while IFS=: read -r name _ uid _ _ _ _; do
        if [ "$uid" -ge 1000 ] && [ "$name" != "nobody" ]; then
            local exp
            exp=$(chage -l "$name" 2>/dev/null | grep "Account expires" | cut -d: -f2 | sed 's/^ //')
            printf "%-20s %-10s %-15s\n" "$name" "$uid" "${exp:-Never}"
        fi
    done < /etc/passwd
    line
}

# Change a user's password
set_user_password() {
    banner
    echo -e "${WHITE} SET USER PASSWORD${RESET}"
    line

    read -rp "Enter username: " uname_input
    if ! id "$uname_input" >/dev/null 2>&1; then
        error "User '$uname_input' does not exist."
        return 1
    fi

    read -rsp "Enter new password: " pass_input
    echo
    echo "${uname_input}:${pass_input}" | chpasswd
    success "Password updated for '$uname_input'."
    line
}

# Show detailed info about a specific user
show_user_info() {
    banner
    echo -e "${WHITE} USER INFORMATION${RESET}"
    line

    read -rp "Enter username: " uname_input
    if ! id "$uname_input" >/dev/null 2>&1; then
        error "User '$uname_input' does not exist."
        return 1
    fi

    id "$uname_input"
    echo
    chage -l "$uname_input"
    line
}
