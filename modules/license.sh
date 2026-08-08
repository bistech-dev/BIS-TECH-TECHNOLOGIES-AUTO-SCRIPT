#!/bin/bash
#
# modules/license.sh
# Trial period tracking and license key activation.
# Sourced by menu.sh - do not execute directly.
#
# HOW IT WORKS
# ------------
# - On first run, a trial start timestamp is written to TRIAL_MARKER_FILE
#   (outside INSTALL_DIR, so uninstalling/reinstalling the script does
#   NOT reset the trial).
# - Each time the menu launches, we compare "now" against that start
#   time. Inside the configured trial duration, the tool runs normally
#   days left. After that, it requires a valid license key.
# - License keys are generated offline as:
#     sha256("<LICENSE_SECRET>:<customer email>") truncated/uppercased
#   The buyer enters their email + the key you gave them; the script
#   recomputes the same hash and compares. See generate_license.sh
#   (seller-only, not meant to ship to customers) to issue keys.
#
# LIMITATIONS (be upfront with yourself about this)
# ---------------------------------------------------
# This is an offline, client-side check - there is no server validating
# keys in real time. A technically determined user could bypass it by
# editing files on their own machine. It's a reasonable speed bump for
# casual/trial enforcement, not DRM. If you need real revocation or
# per-machine locking later, that requires a small validation server -
# ask and it can be added.
#

# Compute the expected license key for a given email
_bistech_expected_key() {
    local email="$1"
    echo -n "${LICENSE_SECRET}:${email}" | sha256sum | cut -c1-16 | tr '[:lower:]' '[:upper:]'
}

# Convert TRIAL_DURATION_VALUE + TRIAL_DURATION_UNIT into total seconds
_bistech_trial_seconds() {
    local value="${TRIAL_DURATION_VALUE:-3}"
    local unit="${TRIAL_DURATION_UNIT:-days}"
    case "$unit" in
        minute|minutes) echo $(( value * 60 )) ;;
        hour|hours)     echo $(( value * 3600 )) ;;
        day|days|*)     echo $(( value * 86400 )) ;;
    esac
}

# Format a count of seconds as a human-readable duration, picking
# whichever of days/hours/minutes fits best.
_bistech_human_duration() {
    local seconds="$1"
    [ "$seconds" -lt 0 ] && seconds=0

    if [ "$seconds" -ge 86400 ]; then
        echo "$(( seconds / 86400 )) day(s)"
    elif [ "$seconds" -ge 3600 ]; then
        echo "$(( seconds / 3600 )) hour(s)"
    elif [ "$seconds" -ge 60 ]; then
        echo "$(( seconds / 60 )) minute(s)"
    else
        echo "less than a minute"
    fi
}

# Read a password from stdin without echoing it, but show '*' per
# keystroke so it's clear input is being registered (not frozen).
# Feedback goes to stderr so this can still be used as
# var=$(_bistech_read_masked "prompt") without asterisks leaking into
# the captured value.
_bistech_read_masked() {
    local prompt="$1"
    local input=""
    local char

    echo -n "$prompt" 1>&2
    while IFS= read -r -s -n 1 char; do
        if [ -z "$char" ]; then
            break
        fi
        if [[ "$char" == $'\x7f' || "$char" == $'\b' ]]; then
            if [ -n "$input" ]; then
                input="${input%?}"
                echo -ne '\b \b' 1>&2
            fi
        else
            input+="$char"
            echo -n '*' 1>&2
        fi
    done
    echo 1>&2
    printf '%s' "$input"
}

# Ensure a trial start timestamp exists; create it on first-ever run
_bistech_init_trial() {
    if [ ! -f "$TRIAL_MARKER_FILE" ]; then
        date +%s > "$TRIAL_MARKER_FILE" 2>/dev/null
        chmod 444 "$TRIAL_MARKER_FILE" 2>/dev/null
    fi
}

# Returns 0 (true) if a valid, activated license is present
_bistech_has_valid_license() {
    [ -f "$LICENSE_FILE" ] || return 1

    local saved_email saved_key expected_key
    saved_email=$(grep -m1 "^EMAIL=" "$LICENSE_FILE" 2>/dev/null | cut -d= -f2-)
    saved_key=$(grep -m1 "^KEY=" "$LICENSE_FILE" 2>/dev/null | cut -d= -f2-)

    [ -z "$saved_email" ] && return 1
    [ -z "$saved_key" ] && return 1

    expected_key=$(_bistech_expected_key "$saved_email")
    [ "$saved_key" = "$expected_key" ]
}

# Prompt the user to enter their email + license key, validate, and save
activate_license() {
    banner
    echo -e "${WHITE} ACTIVATE LICENSE${RESET}"
    line

    read -rp "Enter the email you purchased with: " input_email
    read -rp "Enter your license key: " input_key

    if [ -z "$input_email" ] || [ -z "$input_key" ]; then
        error "Email and license key are both required."
        line
        return 1
    fi

    local expected
    expected=$(_bistech_expected_key "$input_email")

    if [ "$(echo "$input_key" | tr '[:lower:]' '[:upper:]')" = "$expected" ]; then
        {
            echo "EMAIL=${input_email}"
            echo "KEY=${expected}"
            echo "ACTIVATED_ON=$(date +%Y-%m-%d)"
        } > "$LICENSE_FILE"
        chmod 444 "$LICENSE_FILE" 2>/dev/null
        success "License activated successfully. Thank you!"
        line
        return 0
    else
        error "Invalid email/key combination. Please check and try again."
        line
        return 1
    fi
}

# ---------------------------------------------------------------
# ADMIN ONLY: generate a license key for a customer, from inside
# the running tool. Gated by ADMIN_PASSWORD_HASH (set in config.conf,
# sha256 hash of your chosen admin password - never store it as
# plain text). Anyone without that password sees only an error, even
# though this function exists in every customer's copy of the code.
# ---------------------------------------------------------------
generate_license_key() {
    banner
    echo -e "${WHITE} GENERATE LICENSE KEY (ADMIN ONLY)${RESET}"
    line

    if [ -z "$ADMIN_PASSWORD_HASH" ] || [ "$ADMIN_PASSWORD_HASH" = "CHANGE_ME_BEFORE_SELLING" ]; then
        error "ADMIN_PASSWORD_HASH is not configured in config.conf."
        warning "Set it to sha256(your admin password) before using this feature."
        line
        return 1
    fi

    local admin_pass_input
    admin_pass_input=$(_bistech_read_masked "Enter admin password: ")
    local admin_hash_input
    admin_hash_input=$(echo -n "$admin_pass_input" | sha256sum | cut -d' ' -f1)

    if [ "$admin_hash_input" != "$ADMIN_PASSWORD_HASH" ]; then
        error "Access denied."
        line
        return 1
    fi

    success "Admin verified."
    read -rp "Enter customer email to issue a key for: " customer_email
    if [ -z "$customer_email" ]; then
        error "Email cannot be empty."
        line
        return 1
    fi

    local issued_key
    issued_key=$(_bistech_expected_key "$customer_email")

    echo
    echo -e "${CYAN}Customer email :${RESET} $customer_email"
    echo -e "${CYAN}License key    :${RESET} $issued_key"
    echo
    info "Send both values to the customer. They activate via [Activate License]."

    # Keep a local record of issued keys for your own reference
    local log_file="${INSTALL_DIR}/issued_licenses.log"
    echo "$(date +%Y-%m-%d\ %H:%M:%S) | ${customer_email} | ${issued_key}" >> "$log_file" 2>/dev/null
    line
}

# Short one-line trial/license status, meant to be displayed inside
# the dashboard footer rather than printed separately before it.
bistech_status_line() {
    if _bistech_has_valid_license; then
        echo "Licensed"
        return
    fi

    local start_ts now_ts seconds_used trial_total_seconds seconds_left
    start_ts=$(cat "$TRIAL_MARKER_FILE" 2>/dev/null)
    now_ts=$(date +%s)
    [ -z "$start_ts" ] && start_ts=$now_ts

    trial_total_seconds=$(_bistech_trial_seconds)
    seconds_used=$(( now_ts - start_ts ))
    seconds_left=$(( trial_total_seconds - seconds_used ))

    if [ "$seconds_left" -gt 0 ]; then
        echo "Trial: $(_bistech_human_duration "$seconds_left") remaining"
    else
        echo "Trial expired"
    fi
}

# Gate function called once at menu startup.
# Returns 0 to allow the menu to continue, 1 to block it.
check_trial_or_license() {
    _bistech_init_trial

    if _bistech_has_valid_license; then
        return 0
    fi

    local start_ts now_ts seconds_used trial_total_seconds seconds_left
    start_ts=$(cat "$TRIAL_MARKER_FILE" 2>/dev/null)
    now_ts=$(date +%s)

    if [ -z "$start_ts" ]; then
        # Marker unreadable/missing for some reason - fail open to trial start
        start_ts=$now_ts
    fi

    trial_total_seconds=$(_bistech_trial_seconds)
    seconds_used=$(( now_ts - start_ts ))
    seconds_left=$(( trial_total_seconds - seconds_used ))

    if [ "$seconds_left" -gt 0 ]; then
        # Still within trial - say nothing here. The remaining time is
        # shown inside the dashboard footer instead of as loose text
        # that would just flash before the dashboard clears the screen.
        return 0
    fi

    # Trial expired - block until a valid license is entered
    banner
    echo -e "${WHITE} TRIAL EXPIRED${RESET}"
    line
    warning "Your ${TRIAL_DURATION_VALUE}-${TRIAL_DURATION_UNIT} free trial has ended."
    echo "Please activate a license to continue using BIS-TECH AUTO SCRIPT."
    line

    while true; do
        echo " [1] Activate License"
        echo " [0] Exit"
        read -rp "Select an option: " trial_choice
        case $trial_choice in
            1)
                if activate_license; then
                    return 0
                fi
                ;;
            0)
                echo "Goodbye!"
                exit 0
                ;;
            *)
                warning "Invalid option."
                ;;
        esac
    done
}
