#!/bin/bash
#
# install.sh
# Installer for BIS-TECH AUTO SCRIPT.
# Detects the distro, installs dependencies, copies files to
# /opt/bis-tech, and creates the 'bis-tech' command shortcut.
#

set -e

GITHUB_USER_REPO="bistech-dev/BIS-TECH-TECHNOLOGIES-AUTO-SCRIPT"
GITHUB_BRANCH="main"
INSTALL_DIR="/opt/bis-tech"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# ---------- Standalone (curl | bash) support ----------
# If this file is running on its own (e.g. via
# bash <(curl -Ls https://raw.githubusercontent.com/.../install.sh))
# the rest of the project (colors.sh, menu.sh, modules/) won't exist
# locally yet. Detect that case and clone the full repo to a temp
# directory first, then continue the install from there.
if [ ! -f "$SCRIPT_DIR/colors.sh" ]; then
    if ! command -v git >/dev/null 2>&1; then
        echo "Installing git (required to download the project)..."
        apt-get update -y >/dev/null 2>&1 || true
        apt-get install -y git >/dev/null 2>&1
    fi
    echo "Downloading BIS-TECH AUTO SCRIPT from GitHub..."
    TMP_CLONE_DIR="$(mktemp -d)"
    if ! git clone --depth 1 --branch "$GITHUB_BRANCH" \
        "https://github.com/${GITHUB_USER_REPO}.git" "$TMP_CLONE_DIR" 2>/dev/null; then
        echo "ERROR: Failed to download the project from GitHub."
        echo "Check your internet connection and that the repo/branch exist:"
        echo "https://github.com/${GITHUB_USER_REPO}/tree/${GITHUB_BRANCH}"
        exit 1
    fi
    SCRIPT_DIR="$TMP_CLONE_DIR"
fi

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

# ---------- Start the trial clock (only on first-ever install) ----------
# Stored outside INSTALL_DIR so uninstalling/reinstalling the tool does
# not reset the trial period. TRIAL_MARKER_FILE comes from config.conf.
if [ -f "$INSTALL_DIR/config.conf" ]; then
    # shellcheck source=/dev/null
    source "$INSTALL_DIR/config.conf"
fi
TRIAL_MARKER_FILE="${TRIAL_MARKER_FILE:-/etc/.bistech_trial_start}"
if [ ! -f "$TRIAL_MARKER_FILE" ]; then
    date +%s > "$TRIAL_MARKER_FILE" 2>/dev/null
    chmod 444 "$TRIAL_MARKER_FILE" 2>/dev/null
    info "Trial period started (${TRIAL_DURATION_VALUE:-3} ${TRIAL_DURATION_UNIT:-days})."
else
    info "Existing trial/license record found - not resetting."
fi

# ---------- Create command shortcuts ----------
info "Creating 'bis-tech' command shortcut..."
cat > /usr/local/bin/bis-tech <<EOF
#!/bin/bash
exec "$INSTALL_DIR/menu.sh" "\$@"
EOF
chmod +x /usr/local/bin/bis-tech

info "Creating 'menu' command shortcut..."
cat > /usr/local/bin/menu <<EOF
#!/bin/bash
if [ "\$EUID" -ne 0 ]; then
    exec sudo "$INSTALL_DIR/menu.sh" "\$@"
else
    exec "$INSTALL_DIR/menu.sh" "\$@"
fi
EOF
chmod +x /usr/local/bin/menu

# ---------- Allow 'menu' to run without a password prompt ----------
# Grants the user who invoked this installer (via sudo) passwordless
# root access specifically to menu.sh, so 'menu' opens instantly with
# no sudo/password step. Skipped when installing directly as the root
# account (no separate sudo user to grant this to) or on shared systems
# where this may not be desired.
TARGET_USER="${SUDO_USER:-}"
if [ -n "$TARGET_USER" ] && [ "$TARGET_USER" != "root" ]; then
    info "Configuring passwordless access to 'menu' for user: $TARGET_USER"
    SUDOERS_FILE="/etc/sudoers.d/bis-tech-menu"
    echo "${TARGET_USER} ALL=(ALL) NOPASSWD: ${INSTALL_DIR}/menu.sh" > "$SUDOERS_FILE"
    chmod 440 "$SUDOERS_FILE"
    if visudo -cf "$SUDOERS_FILE" >/dev/null 2>&1; then
        success "You can now just type 'menu' - no sudo or password needed."
    else
        rm -f "$SUDOERS_FILE"
        warning "Could not safely configure passwordless access. Use 'sudo menu' instead."
    fi
else
    info "Installed as root directly - run 'menu' or 'bis-tech' to launch."
fi

success "Installation complete!"
line
echo -e "${WHITE}Run the tool anytime with:${RESET} ${GREEN}menu${RESET}"
line
