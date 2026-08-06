# BIS-TECH AUTO SCRIPT

**VPS Management & Automation Tool**

BIS-TECH AUTO SCRIPT is a modular Bash-based toolkit for managing and
administering a Linux VPS. It provides a single interactive menu for
common sysadmin tasks: system monitoring, user management, firewall
control, backups/restores, service management, and self-updating from
GitHub.

---

## Features

- **System tools** — hostname/OS/kernel/CPU/RAM/disk/uptime/IP info,
  a live-ish system monitor, a basic download speed test, and a
  one-command TCP BBR enabler.
- **Service managers** — start/stop/restart/status/logs for SSH,
  SSH-over-UDP, ZIVPN, and Xray services (assumes these are already
  installed as systemd services; BIS-TECH manages them, it doesn't
  install third-party VPN software).
- **Firewall manager** — UFW status, enable/disable, allow common
  admin ports, and view numbered rules.
- **User management** — create, delete, and list Linux users; create
  time-limited trial accounts; set passwords; view detailed user info.
- **Backup & restore** — timestamped tar.gz backups of key config
  files (`sshd_config`, `hosts`, `ufw` rules, etc.) with a simple
  restore flow.
- **Service status dashboard** — running/failed systemd services plus
  memory and disk usage.
- **Self-update system** — checks a `version` file in your GitHub repo
  and can pull and apply updates automatically, preserving your local
  `config.conf`.
- **Colorized terminal UI** with a consistent banner and menu.

---

## Supported Operating Systems

- Ubuntu 20.04+
- Ubuntu 22.04+
- Debian 11 / 12

(Other Debian-based distributions may work but are not officially
supported.)

---

## Installation

**One-line install (recommended):**

```bash
bash <(curl -Ls https://raw.githubusercontent.com/bistech-dev/BIS-TECH-AUTO-SCRIPT/main/install.sh)
```

**Or, clone and install manually:**

```bash
git clone https://github.com/bistech-dev/BIS-TECH-AUTO-SCRIPT.git
cd BIS-TECH-AUTO-SCRIPT
sudo bash install.sh
```

Both methods do the same thing — the one-liner just downloads the
project automatically first.

Once installed, launch the tool anytime with:

```bash
menu
```

If you installed as a regular user via `sudo`, the installer configures
passwordless access so `menu` opens instantly with no `sudo` or password
prompt. If that step is skipped (e.g. you installed directly as `root`,
or on a shared system), use `sudo bis-tech` instead.

The installer will:

1. Verify it's running as root.
2. Detect your Linux distribution.
3. Install required dependencies (`curl`, `wget`, `git`, `nano`,
   `vim`, `unzip`, `zip`, `jq`, `htop`, `net-tools`, `lsof`, `ufw`,
   `cron`, `openssl`, `ca-certificates`, `socat`, `rsync`).
4. Back up any existing installation at `/opt/bis-tech`.
5. Copy the project into `/opt/bis-tech`.
6. Set executable permissions on all scripts.
7. Create the `bis-tech` and `menu` commands in `/usr/local/bin`.
8. Grant the installing user passwordless access to `menu` (via a
   dedicated `/etc/sudoers.d/bis-tech-menu` rule), so `menu` alone is
   enough to launch the tool with full root privileges.

---

## Folder Structure

```
BIS-TECH-AUTO-SCRIPT/
├── install.sh          # Installer script
├── menu.sh             # Main interactive menu (entry point)
├── colors.sh           # Color codes + output helper functions
├── config.conf          # Script name/version/author/repo config
├── version              # Current version number
├── README.md
├── LICENSE
└── modules/
    ├── system.sh        # System info, monitor, speedtest, BBR, restarts
    ├── users.sh         # Create/delete/list users, passwords, info
    ├── firewall.sh       # UFW status/enable/disable/rules
    ├── backup.sh         # Backup config files
    ├── restore.sh        # Restore from backup
    ├── update.sh          # GitHub-based self-update system
    ├── status.sh          # Service & resource status dashboard
    ├── about.sh            # About screen
    └── uninstall.sh        # Clean removal of the tool
```

---

## Configuration

Edit `config.conf` (or `/opt/bis-tech/config.conf` after install) to
point the update system at your own fork:

```bash
SCRIPT_NAME="BIS-TECH AUTO SCRIPT"
SCRIPT_VERSION="1.0.0"
AUTHOR="BIS-TECH TECHNOLOGIES"
GITHUB_REPO="bistech-dev/BIS-TECH-AUTO-SCRIPT"
```

---

## Updating

From within the menu, choose **[17] Check for Updates**. The script
will:

1. Fetch the `version` file from your configured GitHub repo.
2. Compare it against the locally installed version.
3. If a newer version is found, offer to download and apply it.
4. Preserve your existing `config.conf` and `backups/` directory.

You can also update manually by re-running `install.sh` from a fresh
clone of the repository.

---

## Uninstalling

From the menu, choose **[19] Uninstall Script**, or run:

```bash
sudo rm -f /usr/local/bin/bis-tech
sudo rm -rf /opt/bis-tech
```

---

## Security Notes

- The installer and menu both require root privileges and will exit
  if not run as root.
- The firewall manager always allows SSH/OpenSSH before enabling UFW
  to reduce the risk of remote lockout.
- Destructive actions (user deletion, firewall disable, restore,
  uninstall) require explicit `y/N` confirmation.
- User deletion is not on the codebase used to protect the OS itself,
  so always double check target usernames.

---

## Author

**BIS-TECH TECHNOLOGIES**

Contributions and pull requests are welcome — fork the repo, make
your changes, and submit a PR.

## License

Released under the MIT License. See [LICENSE](LICENSE) for details.
