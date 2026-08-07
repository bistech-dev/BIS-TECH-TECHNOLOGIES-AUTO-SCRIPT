#!/bin/bash
#
# modules/dashboard.sh
# Boxed dashboard header shown at the top of the main menu:
# title box, live system stats box, and a service status line.
# Sourced by menu.sh - do not execute directly.
#

# Fetch ISP/org info from a public API, with a short timeout and a
# graceful fallback message if it's unreachable or rate-limited.
_dashboard_isp() {
    local isp
    isp=$(curl -s --max-time 3 https://ipinfo.io/org 2>/dev/null)
    if [ -z "$isp" ] || echo "$isp" | grep -qi "error\|rate limit\|not in allowlist\|<html"; then
        echo "N/A"
    else
        echo "$isp"
    fi
}

# Truncate a value so it can never overflow a box line, regardless of
# what an external API or system command happens to return.
_dashboard_truncate() {
    local text="$1"
    local max="${2:-55}"
    if [ "${#text}" -gt "$max" ]; then
        echo "${text:0:$((max-3))}..."
    else
        echo "$text"
    fi
}

# Print [RUN] or [DOWN] for a given systemd service name
_dashboard_service_tag() {
    local svc="$1"
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        echo -e "${GREEN}[RUN]${RESET}"
    else
        echo -e "${RED}[DOWN]${RESET}"
    fi
}

dashboard_header() {
    clear

    # ---------- Title ----------
    box_top
    box_line "${WHITE}${SCRIPT_NAME}${RESET}" center
    box_bottom
    echo

    # ---------- System stats ----------
    local os_val cpu_val cpu_cores cpu_use ram_used ram_total ram_pct load_val uptime_val ipv4_val ipv6_val isp_val domain_val

    if [ -f /etc/os-release ]; then
        os_val=$(. /etc/os-release && echo "$PRETTY_NAME")
    else
        os_val="Unknown"
    fi

    cpu_val=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ //')
    [ -z "$cpu_val" ] && cpu_val=$(uname -p)
    cpu_val=$(_dashboard_truncate "$cpu_val" 45)
    cpu_cores=$(nproc 2>/dev/null)

    cpu_use=$(top -bn1 2>/dev/null | grep -i "Cpu(s)" | awk '{print $2 + $4"%"}')
    [ -z "$cpu_use" ] && cpu_use="N/A"

    read -r ram_used ram_total <<< "$(free -m | awk '/^Mem:/ {print $3, $2}')"
    if [ -n "$ram_total" ] && [ "$ram_total" -gt 0 ]; then
        ram_pct=$(awk -v u="$ram_used" -v t="$ram_total" 'BEGIN{printf "%.1f", (u/t)*100}')
    else
        ram_pct="0.0"
    fi

    load_val=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ //')
    uptime_val=$(uptime -p 2>/dev/null)

    ipv4_val=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$ipv4_val" ] && ipv4_val=$(curl -s --max-time 3 https://ifconfig.me 2>/dev/null)
    [ -z "$ipv4_val" ] && ipv4_val="N/A"

    ipv6_val=$(ip -6 addr show scope global 2>/dev/null | grep -oP '(?<=inet6\s)[\da-f:]+' | head -1)
    [ -z "$ipv6_val" ] && ipv6_val="N/A"

    isp_val=$(_dashboard_truncate "$(_dashboard_isp)" 55)

    domain_val=$(_dashboard_truncate "${DOMAIN:-Not configured}" 55)

    box_top
    box_line "${CYAN}OS${RESET}       : $os_val"
    box_line "${CYAN}CPU${RESET}      : ${cpu_val} (${cpu_cores} core(s))"
    box_line "${CYAN}CPU USE${RESET}  : $cpu_use"
    box_line "${CYAN}RAM${RESET}      : ${ram_used}/${ram_total}MB (${ram_pct}%)"
    box_line "${CYAN}LOAD AVG${RESET} : $load_val"
    box_line "${CYAN}UPTIME${RESET}   : $uptime_val"
    box_line "${CYAN}IPv4${RESET}     : $ipv4_val"
    box_line "${CYAN}IPv6${RESET}     : $ipv6_val"
    box_line "${CYAN}ISP${RESET}      : $isp_val"
    box_line "${CYAN}DOMAIN${RESET}   : $domain_val"
    box_bottom
    echo

    # ---------- Service status line ----------
    local status_line
    status_line="SSH:$(_dashboard_service_tag ssh)  XRAY:$(_dashboard_service_tag xray)  SSHUDP:$(_dashboard_service_tag sshudp)  ZIVPN:$(_dashboard_service_tag zivpn)"
    box_top
    box_line "$status_line" center
    box_bottom
    echo
}
