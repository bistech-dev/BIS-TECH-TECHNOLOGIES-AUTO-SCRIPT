#!/bin/bash
#
# install.sh
# Installer for BIS-TECH AUTO SCRIPT.
# Detects the distro, installs dependencies, copies files to
# /opt/bis-tech, and creates the 'bis-tech' command shortcut.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
INSTALL_DIR="/opt/bis-tech"

# shellcheck source=/dev/null
source "$SCRIPT_DIR/colors.sh"

banner

# ---------- Root check ----------
if [ "$EUID" -ne 0 ]; then
    error "This installer must be run as root. Try: sudo bash install.sh"
    exit 1
fi

# ---------- Detect distribution ----------
if [ -f /etc/os-release ]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    DISTRO_ID="$ID"
else
    error "Cannot detect Linux distribution (/etc/os-release not found)."
    exit 1
fi

info "Detected distribution: $PRETTY_NAME"

case "$DISTRO_ID" in
    ubuntu|debian)
        PKG_MANAGER="apt-get"
        ;;
    *)
        warning "This script targets Ubuntu/Debian. Detected: $DISTRO_ID"
        warning "Attempting to continue with apt-get; this may fail on other distros."
        PKG_MANAGER="apt-get"
        ;;
esac

# ---------- Install dependencies ----------
DEPENDENCIES=(curl wget git nano vim unzip zip jq htop net-tools lsof ufw cron openssl ca-certificates socat rsync)

info "Updating package lists..."
$PKG_MANAGER update -y >/dev/null 2>&1 || warning "Package list update reported issues; continuing."

info "Installing dependencies: ${DEPENDENCIES[*]}"
if $PKG_MANAGER install -y "${DEPENDENCIES[@]}" >/dev/null 2>&1; then
    success "All dependencies installed."
else
    warning "Some dependencies may have failed to install. Check manually if needed."
fi

# ---------- Backup existing installation, if any ----------
if [ -d "$INSTALL_DIR" ]; then
    warning "Existing installation found at $INSTALL_DIR"
    TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
    cp -r "$INSTALL_DIR" "${INSTALL_DIR}.bak_${TIMESTAMP}" 2>/dev/null || true
    info "Existing installation backed up to ${INSTALL_DIR}.bak_${TIMESTAMP}"
fi

# ---------- Create installation directory ----------
info "Creating installation directory: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/backups"

# ---------- Copy project files ----------
info "Copying script files..."
cp -r "$SCRIPT_DIR"/* "$INSTALL_DIR"/ 2>/dev/null

# ---------- Set executable permissions ----------
info "Setting executable permissions..."
chmod +x "$INSTALL_DIR"/*.sh
chmod +x "$INSTALL_DIR"/modules/*.sh

# ---------- Create command shortcut ----------
info "Creating 'bis-tech' command shortcut..."
cat > /usr/local/bin/bis-tech <<EOF
#!/bin/bash
exec "$INSTALL_DIR/menu.sh" "\$@"
EOF
chmod +x /usr/local/bin/bis-tech

success "Installation complete!"
line
echo -e "${WHITE}Run the tool anytime with:${RESET} ${GREEN}sudo bis-tech${RESET}"
line
