#!/bin/bash
#
# menu.sh
# Main interactive menu for BIS-TECH AUTO SCRIPT.
# This is the entry point launched by the 'bis-tech' command.
#

# Resolve the directory this script lives in, so it works regardless of
# where it's invoked from (e.g. via the /usr/local/bin/bis-tech symlink).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# ---------- Load configuration and shared helpers ----------
source "$SCRIPT_DIR/colors.sh"
source "$SCRIPT_DIR/config.conf"

# ---------- Load all modules ----------
for module in "$SCRIPT_DIR"/modules/*.sh; do
    # shellcheck source=/dev/null
    source "$module"
done

# ---------- Root check ----------
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR]${RESET} This script must be run as root. Try: sudo bis-tech"
    exit 1
fi

# =========================================================
# Generic systemd service manager (used for SSH / SSH UDP /
# ZIVPN / Xray sub-menus). Each of these tools is expected to
# run as its own systemd service; this gives a consistent way
# to install-check, start, stop, restart, and view status/logs
# for whichever service name is passed in.
# =========================================================
generic_service_manager() {
    local display_name="$1"
    local service_name="$2"

    while true; do
        banner
        echo -e "${WHITE} ${display_name}${RESET}"
        line

        if systemctl list-unit-files 2>/dev/null | grep -q "^${service_name}\.service"; then
            local state
            state=$(systemctl is-active "$service_name" 2>/dev/null)
            echo -e "${CYAN}Service status:${RESET} $state"
        else
            warning "Service '$service_name' is not installed on this system."
            echo "Install and configure it separately, then manage it here."
        fi
        line

        echo " [1] Start Service"
        echo " [2] Stop Service"
        echo " [3] Restart Service"
        echo " [4] Show Status"
        echo " [5] Show Recent Logs"
        echo " [0] Back to Main Menu"
        line
        read -rp "Select an option: " svc_choice

        case $svc_choice in
            1) systemctl start "$service_name" 2>/dev/null && success "Started $service_name" || error "Failed to start $service_name" ;;
            2) systemctl stop "$service_name" 2>/dev/null && success "Stopped $service_name" || error "Failed to stop $service_name" ;;
            3) systemctl restart "$service_name" 2>/dev/null && success "Restarted $service_name" || error "Failed to restart $service_name" ;;
            4) systemctl status "$service_name" --no-pager 2>/dev/null || warning "No status available." ;;
            5) journalctl -u "$service_name" -n 30 --no-pager 2>/dev/null || warning "No logs available." ;;
            0) return 0 ;;
            *) warning "Invalid option." ;;
        esac
        read -rp "Press Enter to continue..." _
    done
}

ssh_manager() {
    generic_service_manager "SSH MANAGER" "ssh"
}

ssh_udp_manager() {
    generic_service_manager "SSH UDP SERVICE MANAGER" "sshudp"
}

zivpn_manager() {
    generic_service_manager "ZIVPN SERVICE MANAGER" "zivpn"
}

xray_manager() {
    generic_service_manager "XRAY MANAGER" "xray"
}

# =========================================================
# Main Menu Loop
# =========================================================
main_menu() {
    while true; do
        banner
cat <<'EOF'
 SYSTEM
 ├─ [1] System Information
 ├─ [2] System Monitor
 ├─ [3] VPS Speed Test

 SERVICE MANAGERS
 ├─ [4] SSH Manager
 ├─ [5] SSH UDP Service Manager
 ├─ [6] ZIVPN Service Manager
 ├─ [7] Xray Manager
 ├─ [8] Firewall Manager

 USER MANAGEMENT
 ├─ [9] Create User
 ├─ [10] Create Trial Account
 ├─ [11] Delete User
 ├─ [12] List Users

 BACKUP & MAINTENANCE
 ├─ [13] Backup VPS
 ├─ [14] Restore VPS
 ├─ [15] Restart All Services
 ├─ [16] Enable BBR

 SCRIPT MANAGEMENT
 ├─ [17] Check for Updates
 ├─ [18] About
 ├─ [19] Uninstall Script

 [0] Exit

EOF
        line
        read -rp "Select an option: " choice

        case $choice in
            1) system_info ;;
            2) system_monitor ;;
            3) vps_speedtest ;;
            4) ssh_manager ;;
            5) ssh_udp_manager ;;
            6) zivpn_manager ;;
            7) xray_manager ;;
            8) firewall_manager ;;
            9) create_user ;;
            10) create_trial_user ;;
            11) delete_user ;;
            12) list_users ;;
            13) backup_vps ;;
            14) restore_vps ;;
            15) restart_all_services ;;
            16) enable_bbr ;;
            17) check_for_updates ;;
            18) show_about ;;
            19) uninstall_script ;;
            0)
                echo -e "${GREEN}Goodbye!${RESET}"
                exit 0
                ;;
            *)
                warning "Invalid option. Please try again."
                ;;
        esac

        if [ "$choice" != "0" ]; then
            echo
            read -rp "Press Enter to return to the main menu..." _
        fi
    done
}

main_menu
