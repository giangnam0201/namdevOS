#!/bin/bash
#
# namdevOS Post-Installation Script
# Runs after system installation to configure services and defaults
#

set -euo pipefail

echo "Running namdevOS post-installation configuration..."

# Enable Docker service
if command -v docker &>/dev/null; then
    systemctl enable docker
    echo "Docker service enabled"
fi

# Add the primary user to the docker group
if getent group docker &>/dev/null; then
    PRIMARY_USER="$(getent passwd 1000 | cut -d: -f1)"
    if [[ -n "$PRIMARY_USER" ]]; then
        usermod -aG docker "$PRIMARY_USER"
        echo "User $PRIMARY_USER added to docker group"
    fi
fi

# Set zsh as available default shell option and install oh-my-zsh skeleton
if command -v zsh &>/dev/null; then
    if ! grep -q "/usr/bin/zsh" /etc/shells; then
        echo "/usr/bin/zsh" >> /etc/shells
    fi
    echo "Zsh registered as available shell"
fi

# Configure Git defaults
if command -v git &>/dev/null; then
    git config --system init.defaultBranch main
    git config --system pull.rebase false
    git config --system core.autocrlf input
    git config --system core.editor "vim"
    git config --system color.ui auto
    echo "Git system defaults configured"
fi

# Enable and configure UFW firewall with sensible defaults
if command -v ufw &>/dev/null; then
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw --force enable
    echo "Firewall enabled with default rules"
fi

# Enable SSH server
if systemctl list-unit-files | grep -q "ssh.service"; then
    systemctl enable ssh
    echo "SSH service enabled"
fi

# Enable CUPS printing service
if systemctl list-unit-files | grep -q "cups.service"; then
    systemctl enable cups
    echo "CUPS printing service enabled"
fi

# Enable Bluetooth service
if systemctl list-unit-files | grep -q "bluetooth.service"; then
    systemctl enable bluetooth
    echo "Bluetooth service enabled"
fi

# Configure Flatpak with Flathub
if command -v flatpak &>/dev/null; then
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
    echo "Flathub repository configured"
fi

# Set up automatic security updates
if command -v unattended-upgrades &>/dev/null; then
    systemctl enable unattended-upgrades 2>/dev/null || true
    echo "Automatic security updates enabled"
fi

# Configure timezone to UTC by default (user can change during install)
timedatectl set-ntp true 2>/dev/null || true

# Optimize SSD if detected
if [[ -f /sys/block/sda/queue/rotational ]]; then
    if [[ "$(cat /sys/block/sda/queue/rotational)" == "0" ]]; then
        # Enable TRIM for SSDs
        systemctl enable fstrim.timer 2>/dev/null || true
        echo "SSD TRIM timer enabled"
    fi
fi

# Mark first-boot configuration as complete
mkdir -p /var/lib/namdevos
touch /var/lib/namdevos/.configured
echo "First-boot marker created"

echo "Post-installation configuration complete!"
