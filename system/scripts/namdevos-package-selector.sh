#!/bin/bash
#
# namdevOS Package Selector
# Interactive tool to install optional software packages after first boot.
# Requires network connection.
#

set -euo pipefail

MARKER="$HOME/.config/namdevos/.packages-selected"

# Only show once
if [[ -f "$MARKER" ]]; then
    exit 0
fi

# Check for zenity
if ! command -v zenity &>/dev/null; then
    exit 0
fi

# ============================================================
# Check network connectivity
# ============================================================
check_network() {
    if ping -c 1 -W 3 archive.ubuntu.com &>/dev/null; then
        return 0
    fi
    return 1
}

if ! check_network; then
    zenity --warning \
        --title="Network Required" \
        --text="<b>No internet connection detected.</b>\n\nThe package selector requires an active internet connection to download and install software.\n\nPlease connect to WiFi or Ethernet and run this tool again from:\n<b>Applications → System → namdevOS Package Selector</b>" \
        --width=400 2>/dev/null || true
    exit 0
fi

# ============================================================
# Package categories
# ============================================================

SELECTIONS=$(zenity --list \
    --title="namdevOS Package Selector" \
    --text="<b>Choose software bundles to install</b>\n\nSelect the categories you need. Packages will be downloaded from the internet.\nYou can run this again later from the Applications menu." \
    --checklist \
    --column="Install" --column="Category" --column="Description" --column="Size" \
    TRUE  "developer-essentials" "Git, Docker, Node.js, VS Code, Neovim" "~800MB" \
    FALSE "developer-full"       "GCC, CMake, GDB, Valgrind, Go, Rust" "~1.5GB" \
    FALSE "python-dev"           "Python dev tools, pip, venv, jupyter" "~400MB" \
    TRUE  "modern-cli"           "ripgrep, fzf, bat, eza, fd, btop, tldr" "~50MB" \
    FALSE "containers"           "Docker, Docker Compose, Podman" "~500MB" \
    FALSE "office"               "LibreOffice, Thunderbird" "~700MB" \
    FALSE "multimedia"           "GIMP, Inkscape, OBS, Audacity, Kdenlive" "~900MB" \
    FALSE "gaming"               "Steam, Lutris, Wine, GameMode" "~600MB" \
    FALSE "networking"           "WireGuard, OpenVPN, Remmina, Samba, Nmap" "~200MB" \
    FALSE "virtualization"       "VirtualBox, QEMU/KVM, Virt-Manager" "~800MB" \
    --width=650 --height=500 2>/dev/null) || true

if [[ -z "$SELECTIONS" ]]; then
    # User cancelled - mark as done so we don't nag
    mkdir -p "$(dirname "$MARKER")"
    touch "$MARKER"
    exit 0
fi

# ============================================================
# Define package lists for each category
# ============================================================

declare -A PACKAGES
PACKAGES[developer-essentials]="git-lfs neovim nodejs npm docker.io docker-compose code tmux zsh openssh-server net-tools jq"
PACKAGES[developer-full]="gcc g++ make cmake gdb valgrind strace ltrace golang-go rustc cargo clang lldb"
PACKAGES[python-dev]="python3-dev python3-pip python3-venv python3-setuptools ipython3 jupyter-notebook python3-numpy python3-pandas"
PACKAGES[modern-cli]="ripgrep fd-find fzf bat eza btop httpie tldr tree yq"
PACKAGES[containers]="docker.io docker-compose podman buildah skopeo"
PACKAGES[office]="libreoffice thunderbird"
PACKAGES[multimedia]="gimp inkscape obs-studio audacity kdenlive cheese shotwell simple-scan"
PACKAGES[gaming]="steam-installer lutris wine gamemode"
PACKAGES[networking]="openvpn wireguard network-manager-openvpn network-manager-openvpn-gnome remmina remmina-plugin-rdp remmina-plugin-vnc samba smbclient nmap dnsutils aria2 transmission-gtk"
PACKAGES[virtualization]="virtualbox qemu-system-x86 qemu-utils libvirt-daemon-system virt-manager ovmf"

# ============================================================
# Install selected packages
# ============================================================

INSTALL_LIST=""
IFS='|' read -ra SELECTED_ARRAY <<< "$SELECTIONS"
for category in "${SELECTED_ARRAY[@]}"; do
    if [[ -n "${PACKAGES[$category]:-}" ]]; then
        INSTALL_LIST="$INSTALL_LIST ${PACKAGES[$category]}"
    fi
done

if [[ -z "$INSTALL_LIST" ]]; then
    mkdir -p "$(dirname "$MARKER")"
    touch "$MARKER"
    exit 0
fi

# Run installation with progress
(
    echo "10"
    echo "# Updating package lists..."
    sudo apt-get update -qq 2>&1

    echo "20"
    echo "# Installing selected packages..."
    sudo apt-get install -y --no-install-recommends $INSTALL_LIST 2>&1

    echo "90"
    echo "# Cleaning up..."
    sudo apt-get autoremove -y 2>&1
    sudo apt-get clean 2>&1

    echo "100"
    echo "# Installation complete!"
) | zenity --progress \
    --title="Installing Packages" \
    --text="Preparing..." \
    --percentage=0 \
    --auto-close \
    --width=400 2>/dev/null || {
        zenity --error \
            --title="Installation Error" \
            --text="Some packages may have failed to install.\nYou can retry by running:\n\n<b>namdevos-package-selector</b>\n\nfrom a terminal." \
            --width=350 2>/dev/null || true
    }

# Post-install configuration for Docker
if echo "$SELECTIONS" | grep -qE 'developer-essentials|containers'; then
    if command -v docker &>/dev/null; then
        sudo systemctl enable docker 2>/dev/null || true
        sudo usermod -aG docker "$USER" 2>/dev/null || true
        zenity --info \
            --text="Docker installed. Please <b>log out and back in</b> for group permissions to take effect." \
            --width=350 2>/dev/null || true
    fi
fi

# Mark as done
mkdir -p "$(dirname "$MARKER")"
touch "$MARKER"

zenity --info \
    --title="All Done!" \
    --text="<b>Packages installed successfully!</b>\n\nYou can install more packages anytime from:\n<b>Applications → System → namdevOS Package Selector</b>\n\nOr use: <b>sudo apt install package-name</b>" \
    --width=380 2>/dev/null || true
