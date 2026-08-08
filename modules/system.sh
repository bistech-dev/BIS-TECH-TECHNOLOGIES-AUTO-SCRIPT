#!/bin/bash
#
# modules/system.sh
# System information and monitoring functions.
# Sourced by menu.sh - do not execute directly.
#

# Display general system information
system_info() {
    banner
    echo -e "${WHITE} SYSTEM INFORMATION${RESET}"
    line

    local hostname_val os_val kernel_val cpu_val ram_val disk_val uptime_val ip_val

    hostname_val=$(hostname 2>/dev/null)

    if [ -f /etc/os-release ]; then
        os_val=$(. /etc/os-release && echo "$PRETTY_NAME")
    else
        os_val="Unknown"
    fi

    kernel_val=$(uname -r)

    cpu_val=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ //')
    [ -z "$cpu_val" ] && cpu_val=$(uname -p)
    local cpu_cores
    cpu_cores=$(nproc 2>/dev/null)

    ram_val=$(free -h | awk '/^Mem:/ {print $3 " used / " $2 " total"}')

    disk_val=$(df -h / | awk 'NR==2 {print $3 " used / " $2 " total (" $5 " used)"}')

    uptime_val=$(uptime -p 2>/dev/null)

    ip_val=$(hostname -I 2>/dev/null | awk '{print $1}')
    local public_ip
    public_ip=$(curl -s --max-time 3 https://ifconfig.me 2>/dev/null)

    echo -e "${CYAN}Hostname     :${RESET} ${hostname_val}"
    echo -e "${CYAN}OS           :${RESET} ${os_val}"
    echo -e "${CYAN}Kernel       :${RESET} ${kernel_val}"
    echo -e "${CYAN}CPU          :${RESET} ${cpu_val} (${cpu_cores} cores)"
    echo -e "${CYAN}RAM          :${RESET} ${ram_val}"
    echo -e "${CYAN}Disk         :${RESET} ${disk_val}"
    echo -e "${CYAN}Uptime       :${RESET} ${uptime_val}"
    echo -e "${CYAN}Local IP     :${RESET} ${ip_val:-N/A}"
    echo -e "${CYAN}Public IP    :${RESET} ${public_ip:-N/A (no internet access)}"
    line
}

# Live-ish system monitor snapshot (CPU / RAM / Disk / load)
system_monitor() {
    banner
    echo -e "${WHITE} SYSTEM MONITOR${RESET}"
    line

    local load_val cpu_usage mem_line disk_line

    load_val=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ //')

    if command -v mpstat >/dev/null 2>&1; then
        cpu_usage=$(mpstat 1 1 | awk '/Average/ {print 100 - $NF"%"}')
    else
        cpu_usage=$(top -bn1 | grep -i "Cpu(s)" | awk '{print $2 + $4"%"}')
    fi

    mem_line=$(free -h | awk '/^Mem:/ {print "Used: "$3" / Total: "$2" | Free: "$4}')
    disk_line=$(df -h / | awk 'NR==2 {print "Used: "$3" / Total: "$2" ("$5" used)"}')

    echo -e "${CYAN}Load Average :${RESET} ${load_val}"
    echo -e "${CYAN}CPU Usage    :${RESET} ${cpu_usage}"
    echo -e "${CYAN}Memory       :${RESET} ${mem_line}"
    echo -e "${CYAN}Disk (/)     :${RESET} ${disk_line}"
    line
    info "Tip: run 'htop' for a full live monitor."
}

# Basic network speed test using curl download of a known test file
vps_speedtest() {
    banner
    echo -e "${WHITE} VPS SPEED TEST${RESET}"
    line

    if ! command -v curl >/dev/null 2>&1; then
        error "curl is required for the speed test but is not installed."
        return 1
    fi

    info "Testing download speed (this may take a few seconds)..."
    local result
    result=$(curl -o /dev/null -s -w 'Download Speed: %{speed_download} bytes/sec\nTime Taken: %{time_total} sec\n' \
        https://speed.hetzner.de/100MB.bin --max-time 20 2>/dev/null)

    if [ -z "$result" ]; then
        warning "Speed test failed. Check your internet connection or firewall rules."
    else
        echo -e "${CYAN}${result}${RESET}"
    fi
    line
}

# Enable TCP BBR congestion control
enable_bbr() {
    banner
    echo -e "${WHITE} ENABLE BBR${RESET}"
    line

    if lsmod | grep -q bbr; then
        success "BBR is already enabled on this system."
        line
        return 0
    fi

    info "Enabling BBR congestion control..."

    if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf 2>/dev/null; then
        echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    fi
    if ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf 2>/dev/null; then
        echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    fi

    sysctl -p >/dev/null 2>&1

    if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr; then
        success "BBR has been enabled successfully."
    else
        error "Failed to enable BBR. Your kernel may not support it (needs Linux 4.9+)."
    fi
    line
}

# Restart common VPS services
restart_all_services() {
    banner
    echo -e "${WHITE} RESTART ALL SERVICES${RESET}"
    line

    local services=("ssh" "cron" "ufw" "networking")

    for svc in "${services[@]}"; do
        if systemctl list-unit-files 2>/dev/null | grep -q "^${svc}\.service"; then
            systemctl restart "$svc" >/dev/null 2>&1 && success "Restarted: $svc" || warning "Could not restart: $svc"
        fi
    done
    line
    success "Service restart routine complete."
}

# Reboot the entire VPS - always confirm first, this drops the SSH session
reboot_vps() {
    banner
    echo -e "${WHITE} REBOOT VPS${RESET}"
    line
    warning "This will reboot the entire server. Your SSH session will drop."
    read -rp "Are you sure you want to reboot now? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        warning "Cancelled."
        return 0
    fi
    info "Rebooting..."
    reboot
}
