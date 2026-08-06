#!/bin/bash
#
# modules/update.sh
# Checks for and applies updates from the configured GitHub repository.
# Sourced by menu.sh - do not execute directly.
#

# Compare the installed version with the latest version file on GitHub
check_for_updates() {
    banner
    echo -e "${WHITE} CHECK FOR UPDATES${RESET}"
    line

    if [ -z "$GITHUB_REPO" ] || [ "$GITHUB_REPO" = "YOUR_USERNAME/BIS-TECH-AUTO-SCRIPT" ]; then
        warning "GITHUB_REPO is not configured in config.conf. Set it to your repo, e.g. 'user/BIS-TECH-AUTO-SCRIPT'."
        line
        return 1
    fi

    local remote_version_url="https://raw.githubusercontent.com/${GITHUB_REPO}/main/version"
    info "Checking latest version from GitHub..."

    local remote_version
    remote_version=$(curl -s --max-time 10 "$remote_version_url" | tr -d '[:space:]')

    if [ -z "$remote_version" ]; then
        error "Could not reach GitHub or repository/version file not found."
        line
        return 1
    fi

    echo -e "${CYAN}Installed version:${RESET} $SCRIPT_VERSION"
    echo -e "${CYAN}Latest version   :${RESET} $remote_version"

    if [ "$remote_version" = "$SCRIPT_VERSION" ]; then
        success "You are running the latest version."
    else
        warning "A new version is available: $remote_version"
        read -rp "Do you want to update now? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            apply_update "$remote_version"
        fi
    fi
    line
}

# Download and apply the update by cloning the repository fresh,
# then replacing the installed files (config.conf and backups are preserved).
apply_update() {
    local new_version="$1"
    info "Downloading update..."

    local tmp_dir
    tmp_dir=$(mktemp -d)

    if ! git clone --depth 1 "https://github.com/${GITHUB_REPO}.git" "$tmp_dir" >/dev/null 2>&1; then
        error "Failed to download update from GitHub."
        rm -rf "$tmp_dir"
        return 1
    fi

    info "Applying update..."

    # Preserve the existing config.conf so custom settings survive the update
    cp "$INSTALL_DIR/config.conf" "$tmp_dir/config.conf.bak" 2>/dev/null

    rsync -a --exclude 'backups' --exclude '.git' "$tmp_dir"/ "$INSTALL_DIR"/ 2>/dev/null \
        || cp -r "$tmp_dir"/* "$INSTALL_DIR"/

    [ -f "$tmp_dir/config.conf.bak" ] && cp "$tmp_dir/config.conf.bak" "$INSTALL_DIR/config.conf"

    chmod +x "$INSTALL_DIR"/*.sh "$INSTALL_DIR"/modules/*.sh 2>/dev/null

    rm -rf "$tmp_dir"

    success "Updated to version $new_version. Please restart the script."
}
