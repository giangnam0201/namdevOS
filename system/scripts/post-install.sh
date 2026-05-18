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
    PRIMARY_USER="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
    if [[ -n "$PRIMARY_USER" ]]; then
        usermod -aG docker "$PRIMARY_USER"
        echo "User $PRIMARY_USER added to docker group"
    fi
fi

# Set zsh as available default shell option
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

echo "Post-installation configuration complete!"
