#!/bin/bash
#
# modules/status.sh
# Displays running/failed services and resource usage.
# Sourced by menu.sh - do not execute directly.
#

show_status() {
    banner
    echo -e "${WHITE} SERVICE & RESOURCE STATUS${RESET}"
    line

    echo -e "${CYAN}-- Running Services (top 10) --${RESET}"
    systemctl list-units --type=service --state=running --no-legend 2>/dev/null | awk '{print " - "$1}' | head -10

    echo
    echo -e "${CYAN}-- Failed Services --${RESET}"
    local failed
    failed=$(systemctl list-units --type=service --state=failed --no-legend 2>/dev/null)
    if [ -z "$failed" ]; then
        success "No failed services."
    else
        echo "$failed" | awk '{print " - "$1}'
    fi

    echo
    echo -e "${CYAN}-- Memory Usage --${RESET}"
    free -h

    echo
    echo -e "${CYAN}-- Disk Usage --${RESET}"
    df -h --output=source,size,used,avail,pcent,target 2>/dev/null | grep -E '^/dev|Filesystem'

    line
}
