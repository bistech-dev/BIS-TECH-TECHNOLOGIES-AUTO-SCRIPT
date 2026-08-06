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
