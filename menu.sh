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

# ---------- One-click service toggle (no sub-menu) ----------
# Not installed -> installs it. Installed + stopped -> starts it.
# Installed + running -> stops it. This collapses install/start/stop
# into a single direct action so service control fits on the main
# menu screen instead of needing its own menu layer.
service_toggle() {
    local service_name="$1"
    local install_function="$2"

    if ! systemctl list-unit-files 2>/dev/null | grep -q "^${service_name}\.service"; then
        if [ -n "$install_function" ]; then
            "$install_function"
        else
            error "No installer configured for '$service_name'."
        fi
        return
    fi

    if systemctl is-active --quiet "$service_name" 2>/dev/null; then
        systemctl stop "$service_name" 2>/dev/null && success "Stopped $service_name" || error "Failed to stop $service_name"
    else
        systemctl start "$service_name" 2>/dev/null && success "Started $service_name" || error "Failed to start $service_name"
    fi
}

# =========================================================
# Main Menu Loop - everything on one screen, organized into
# boxes (MENU, SERVICES, TOOLS, footer). No sub-menu screens.
# =========================================================
main_menu() {
    while true; do
        dashboard_header

        box_top
        box_line "${WHITE}MENU${RESET}" center
        box_divider
        box_two_col "[1]  SSH/WS - Create Account"    "[6]  VLESS - Create Account"
        box_two_col "[2]  SSH/WS - Create Trial"        "[7]  TROJAN - Create Account"
        box_two_col "[3]  SSH UDP - Create Account"      "[8]  SOCKS - Create Account"
        box_two_col "[4]  SSH UDP - Create Trial"         "[9]  ZIVPN - Create Account"
        box_two_col "[5]  VMESS - Create Account"          "[10] ZIVPN - Create Trial"
        box_bottom
        echo

        box_top
        box_line "${WHITE}SERVICES${RESET}  (tap to install / start / stop)" center
        box_divider
        box_two_col "[11] Toggle SSH"        "[13] Toggle ZIVPN"
        box_two_col "[12] Toggle SSH UDP"     "[14] Toggle Xray"
        box_bottom
        echo

        box_top
        box_line "${WHITE}TOOLS${RESET}" center
        box_divider
        box_two_col "[15] System Information" "[21] Enable BBR"
        box_two_col "[16] System Monitor"       "[22] Check for Updates"
        box_two_col "[17] VPS Speed Test"         "[23] About"
        box_two_col "[18] Firewall Manager"         "[24] Uninstall Script"
        box_two_col "[19] Delete User"                "[25] Activate License"
        box_two_col "[20] List Users"                   ""
        box_bottom
        echo

        box_top
        box_line "${WHITE}MAINTENANCE${RESET}" center
        box_divider
        box_two_col "[26] Backup VPS"          "[29] Restart All Services"
        box_two_col "[27] Restore VPS"           "[88] Reboot VPS"
        box_two_col "[28] Clean Logs"              ""
        box_bottom
        echo

        box_top
        box_line "VERSION   : ${SCRIPT_VERSION}"
        box_line "SCRIPT BY : ${AUTHOR}"
        box_line "REPO      : $(echo "https://github.com/${GITHUB_REPO}" | cut -c1-58)"
        box_line "STATUS    : $(bistech_status_line)"
        box_bottom
        echo

        echo -e "${WHITE} [0] EXIT${RESET}"
        echo
        read -rp "Select menu : " choice

        case $choice in
            1) create_account_ssh_standard ;;
            2) create_account_ssh_trial ;;
            3) create_account_sshudp_standard ;;
            4) create_account_sshudp_trial ;;
            5) create_account_vmess ;;
            6) create_account_vless ;;
            7) create_account_trojan ;;
            8) create_account_socks ;;
            9) create_account_zivpn_standard ;;
            10) create_account_zivpn_trial ;;
            11) service_toggle "ssh" "install_ssh_service" ;;
            12) service_toggle "sshudp" "install_sshudp_service" ;;
            13) service_toggle "zivpn" "install_zivpn_service" ;;
            14) service_toggle "xray" "install_xray_service" ;;
            15) system_info ;;
            16) system_monitor ;;
            17) vps_speedtest ;;
            18) firewall_manager ;;
            19) delete_user ;;
            20) list_users ;;
            21) enable_bbr ;;
            22) check_for_updates ;;
            23) show_about ;;
            24) uninstall_script ;;
            25) activate_license ;;
            26) backup_vps ;;
            27) restore_vps ;;
            28) clean_vps_logs ;;
            29) restart_all_services ;;
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
