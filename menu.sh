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

# ---------- Trial / License gate ----------
check_trial_or_license

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
    local install_function="$3"  # optional: name of a function that installs this service

    while true; do
        banner
        echo -e "${WHITE} ${display_name}${RESET}"
        line

        local is_installed=0
        if systemctl list-unit-files 2>/dev/null | grep -q "^${service_name}\.service"; then
            is_installed=1
            local state
            state=$(systemctl is-active "$service_name" 2>/dev/null)
            echo -e "${CYAN}Service status:${RESET} $state"
        else
            warning "Service '$service_name' is not installed on this system."
        fi
        line

        if [ "$is_installed" -eq 0 ] && [ -n "$install_function" ]; then
            echo " [1] Install Service"
        else
            echo " [1] Start Service"
        fi
        echo " [2] Stop Service"
        echo " [3] Restart Service"
        echo " [4] Show Status"
        echo " [5] Show Recent Logs"
        echo " [0] Back to Main Menu"
        line
        read -rp "Select an option: " svc_choice

        case $svc_choice in
            1)
                if [ "$is_installed" -eq 0 ] && [ -n "$install_function" ]; then
                    "$install_function"
                elif [ "$is_installed" -eq 0 ]; then
                    error "No installer configured for '$service_name'. Install it manually, then manage it here."
                else
                    systemctl start "$service_name" 2>/dev/null && success "Started $service_name" || error "Failed to start $service_name"
                fi
                ;;
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

# ---------- Real installer: SSH ----------
# SSH is present on almost every VPS already (it's how you're connected),
# but this ensures openssh-server is installed and enabled in case it
# was ever removed or this is an unusual minimal image.
install_ssh_service() {
    info "Installing/ensuring openssh-server..."
    apt-get update -y >/dev/null 2>&1
    if apt-get install -y openssh-server >/dev/null 2>&1; then
        systemctl enable ssh >/dev/null 2>&1
        systemctl start ssh >/dev/null 2>&1
        success "openssh-server installed and running."
    else
        error "Failed to install openssh-server."
    fi
}

# ---------- Real installer: Xray ----------
# Uses the official Xray-core installer maintained by the XTLS project
# (the upstream Xray developers) - this is the standard, widely
# documented way to install Xray on Linux.
install_xray_service() {
    info "Installing Xray via the official XTLS installer..."
    warning "This downloads and runs an installer script from github.com/XTLS - review it yourself if you want to verify first: https://github.com/XTLS/Xray-install"
    if bash -c "$(curl -Ls https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install; then
        success "Xray installed. Configure /usr/local/etc/xray/config.json before starting."
    else
        error "Xray installation failed. Check your internet connection."
    fi
}

# ---------- SSH UDP / ZIVPN: install from a URL you configure ----------
# No source is hardcoded here - see SSHUDP_INSTALL_URL / ZIVPN_INSTALL_URL
# in config.conf. Nothing runs until you (or a customer) explicitly
# supply and trust a source. This shows the URL before running it so
# it's never a silent surprise.
_install_from_configured_url() {
    local label="$1"
    local url="$2"

    if [ -z "$url" ]; then
        error "No install source configured for $label."
        echo "Set SSHUDP_INSTALL_URL or ZIVPN_INSTALL_URL in config.conf to a script you trust, then try again."
        return 1
    fi

    warning "About to download and run:"
    echo "  $url"
    echo "This will execute as root. Review it yourself first if you haven't already."
    read -rp "Continue? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        warning "Cancelled."
        return 0
    fi

    if bash -c "$(curl -Ls "$url")"; then
        success "$label install script finished."
    else
        error "$label installation failed or the script errored."
    fi
}

install_sshudp_service() {
    _install_from_configured_url "SSH UDP" "$SSHUDP_INSTALL_URL"
}

install_zivpn_service() {
    _install_from_configured_url "ZIVPN" "$ZIVPN_INSTALL_URL"
}

# =========================================================
# Unified Service Manager hub - one screen for all four
# protocol services (SSH, SSH UDP, ZIVPN, Xray) instead of
# four separate top-level menu entries. Pick a service, act on
# it, and land back on this same hub - no more jumping between
# differently-labeled menus for each protocol.
# =========================================================
service_manager_hub() {
    while true; do
        banner
        echo -e "${WHITE} SERVICE MANAGER${RESET}"
        line

        local ssh_state sshudp_state zivpn_state xray_state
        ssh_state=$(systemctl is-active ssh 2>/dev/null || echo "not installed")
        sshudp_state=$(systemctl is-active sshudp 2>/dev/null || echo "not installed")
        zivpn_state=$(systemctl is-active zivpn 2>/dev/null || echo "not installed")
        xray_state=$(systemctl is-active xray 2>/dev/null || echo "not installed")

        echo -e " ${CYAN}[1]${RESET} SSH        - $ssh_state"
        echo -e " ${CYAN}[2]${RESET} SSH UDP    - $sshudp_state"
        echo -e " ${CYAN}[3]${RESET} ZIVPN      - $zivpn_state"
        echo -e " ${CYAN}[4]${RESET} Xray       - $xray_state"
        echo " [0] Back to Main Menu"
        line
        read -rp "Select a service to manage: " svc_pick

        case $svc_pick in
            1) generic_service_manager "SSH MANAGER" "ssh" "install_ssh_service" ;;
            2) generic_service_manager "SSH UDP SERVICE MANAGER" "sshudp" "install_sshudp_service" ;;
            3) generic_service_manager "ZIVPN SERVICE MANAGER" "zivpn" "install_zivpn_service" ;;
            4) generic_service_manager "XRAY MANAGER" "xray" "install_xray_service" ;;
            0) return 0 ;;
            *) warning "Invalid option." ; read -rp "Press Enter to continue..." _ ;;
        esac
    done
}

# =========================================================
# Main Menu Loop
# =========================================================
main_menu() {
    while true; do
        dashboard_header

        box_top
        box_line "${WHITE}MENU${RESET}" center
        box_divider
        box_two_col "[1] SSH/WS Menu"        "[7]  ZIVPN Menu"
        box_two_col "[2] SSH UDP Menu"        "[8]  Service Manager"
        box_two_col "[3] VMESS Menu"           "[9]  Firewall Manager"
        box_two_col "[4] VLESS Menu"            "[10] Delete User"
        box_two_col "[5] TROJAN Menu"            "[11] List Users"
        box_two_col "[6] SOCKS Menu"              ""
        box_bottom
        echo

        box_top
        box_line "${WHITE}TOOLS${RESET}" center
        box_divider
        box_two_col "[12] System Information" "[18] Enable BBR"
        box_two_col "[13] System Monitor"       "[19] Check for Updates"
        box_two_col "[14] VPS Speed Test"         "[20] About"
        box_two_col "[15] Backup VPS"               "[21] Uninstall Script"
        box_two_col "[16] Restore VPS"                "[22] Activate License"
        box_two_col "[17] Restart All Services"         "[88] Reboot VPS"
        box_bottom
        echo

        box_top
        box_line "VERSION   : ${SCRIPT_VERSION}"
        box_line "SCRIPT BY : ${AUTHOR}"
        box_line "REPO      : $(echo "https://github.com/${GITHUB_REPO}" | cut -c1-58)"
        box_bottom
        echo

        echo -e "${WHITE} [0] EXIT${RESET}"
        echo
        read -rp "Select menu : " choice

        case $choice in
            1) ssh_ws_menu ;;
            2) sshudp_menu ;;
            3) create_account_vmess ;;
            4) create_account_vless ;;
            5) create_account_trojan ;;
            6) create_account_socks ;;
            7) zivpn_menu ;;
            8) service_manager_hub ;;
            9) firewall_manager ;;
            10) delete_user ;;
            11) list_users ;;
            12) system_info ;;
            13) system_monitor ;;
            14) vps_speedtest ;;
            15) backup_vps ;;
            16) restore_vps ;;
            17) restart_all_services ;;
            18) enable_bbr ;;
            19) check_for_updates ;;
            20) show_about ;;
            21) uninstall_script ;;
            22) activate_license ;;
            88) reboot_vps ;;
            99) generate_license_key ;;
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
