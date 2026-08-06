#!/bin/bash
#
# modules/about.sh
# Displays information about the script.
# Sourced by menu.sh - do not execute directly.
#

show_about() {
    banner
    echo -e "${WHITE} ABOUT${RESET}"
    line
    echo -e "${CYAN}Name    :${RESET} $SCRIPT_NAME"
    echo -e "${CYAN}Version :${RESET} $SCRIPT_VERSION"
    echo -e "${CYAN}Author  :${RESET} $AUTHOR"
    echo -e "${CYAN}Repo    :${RESET} https://github.com/${GITHUB_REPO}"
    echo
    echo "BIS-TECH AUTO SCRIPT is a modular VPS management and"
    echo "administration tool for Ubuntu/Debian servers, covering"
    echo "system monitoring, user management, firewall control,"
    echo "backups, and self-updating from GitHub."
    line
}
