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

ssh_manager() {
    generic_service_manager "SSH MANAGER" "ssh" "install_ssh_service"
}

ssh_udp_manager() {
    generic_service_manager "SSH UDP SERVICE MANAGER" "sshudp" "install_sshudp_service"
}

zivpn_manager() {
    generic_service_manager "ZIVPN SERVICE MANAGER" "zivpn" "install_zivpn_service"
}

xray_manager() {
    generic_service_manager "XRAY MANAGER" "xray" "install_xray_service"
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
        box_two_col "[1]  System Information"   "[6]  ZIVPN Manager"
        box_two_col "[2]  System Monitor"        "[7]  Xray Manager"
        box_two_col "[3]  VPS Speed Test"         "[8]  Firewall Manager"
        box_two_col "[4]  SSH Manager"             "[9]  Create User"
        box_two_col "[5]  SSH UDP Manager"          "[10] Create Trial Account"
        box_bottom
        echo

        box_top
        box_line "${WHITE}TOOLS${RESET}" center
        box_divider
        box_two_col "[11] Delete User"            "[16] Enable BBR"
        box_two_col "[12] List Users"               "[17] Check for Updates"
        box_two_col "[13] Backup VPS"                 "[18] About"
        box_two_col "[14] Restore VPS"                 "[19] Uninstall Script"
        box_two_col "[15] Restart All Services"          "[20] Activate License"
        box_bottom
        echo

        echo -e "${WHITE} [0] EXIT${RESET}"
        echo
        read -rp "Select menu : " choice

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
            20) activate_license ;;
            21) generate_license_key ;;
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
