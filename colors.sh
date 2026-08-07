#!/bin/bash
#
# colors.sh
# Color codes and shared output helper functions for BIS-TECH AUTO SCRIPT.
# This file is meant to be sourced by other scripts, not executed directly.
#

# ---------- Color Codes ----------
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
CYAN="\033[0;36m"
MAGENTA="\033[0;35m"
WHITE="\033[1;37m"
RESET="\033[0m"

# ---------- Helper Functions ----------

# Draw a horizontal divider line
line() {
    echo -e "${CYAN}══════════════════════════════════════════════${RESET}"
}

# Print the project banner
banner() {
    clear
    line
    echo -e "${WHITE}        BIS-TECH AUTO SCRIPT${RESET}"
    echo -e "${WHITE}        VPS Management & Automation Tool${RESET}"
    line
}

# Informational message (blue)
info() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

# Success message (green)
success() {
    echo -e "${GREEN}[OK]${RESET} $1"
}

# Warning message (yellow)
warning() {
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

# Error message (red)
error() {
    echo -e "${RED}[ERROR]${RESET} $1"
}

# ---------- Box-drawing helpers (dashboard-style UI) ----------
# All boxes use this fixed inner width so borders line up consistently.
BOX_WIDTH=76

# Strip ANSI color codes to measure a string's real visible length
_visible_len() {
    local stripped
    stripped=$(echo -ne "$1" | sed -E 's/\x1b\[[0-9;]*m//g')
    echo -n "${#stripped}"
}

box_top() {
    printf "${CYAN}╔"
    printf '═%.0s' $(seq 1 "$BOX_WIDTH")
    printf "╗${RESET}\n"
}

box_bottom() {
    printf "${CYAN}╚"
    printf '═%.0s' $(seq 1 "$BOX_WIDTH")
    printf "╝${RESET}\n"
}

box_divider() {
    printf "${CYAN}╠"
    printf '═%.0s' $(seq 1 "$BOX_WIDTH")
    printf "╣${RESET}\n"
}

# One line of plain text inside a box, left-padded, optionally centered
box_line() {
    local text="$1"
    local center="${2:-}"
    local visible_len pad_total pad_left pad_right

    visible_len=$(_visible_len "$text")

    # Defensive: if content is somehow wider than the box (e.g. an
    # unexpectedly long external value slipped through), just print it
    # without padding rather than corrupting the border alignment.
    if [ "$visible_len" -ge "$BOX_WIDTH" ]; then
        printf "${CYAN}║${RESET} %b${CYAN}║${RESET}\n" "$text"
        return
    fi

    if [ "$center" = "center" ]; then
        pad_total=$(( BOX_WIDTH - visible_len ))
        [ "$pad_total" -lt 0 ] && pad_total=0
        pad_left=$(( pad_total / 2 ))
        pad_right=$(( pad_total - pad_left ))
        printf "${CYAN}║${RESET}%*s%b%*s${CYAN}║${RESET}\n" "$pad_left" "" "$text" "$pad_right" ""
    else
        pad_right=$(( BOX_WIDTH - visible_len - 1 ))
        [ "$pad_right" -lt 0 ] && pad_right=0
        printf "${CYAN}║${RESET} %b%*s${CYAN}║${RESET}\n" "$text" "$pad_right" ""
    fi
}

# Two side-by-side columns in one box line, split at the midpoint,
# with a thin divider between them (matches the "MENU"/"TOOLS" layout).
box_two_col() {
    local left="$1"
    local right="$2"
    local col_width=$(( (BOX_WIDTH - 1) / 2 ))
    local left_len right_len left_pad right_pad

    left_len=$(_visible_len "$left")
    right_len=$(_visible_len "$right")
    left_pad=$(( col_width - left_len - 1 ))
    right_pad=$(( BOX_WIDTH - col_width - right_len - 2 ))
    [ "$left_pad" -lt 0 ] && left_pad=0
    [ "$right_pad" -lt 0 ] && right_pad=0

    printf "${CYAN}║${RESET} %b%*s${CYAN}│${RESET} %b%*s${CYAN}║${RESET}\n" \
        "$left" "$left_pad" "" "$right" "$right_pad" ""
}
