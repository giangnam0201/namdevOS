#!/bin/bash
#
# namdevOS Developer Environment Setup
# Installs all tools needed to build namdevOS on the development host
#

set -euo pipefail

echo "================================================"
echo "  namdevOS Developer Setup"
echo "================================================"
echo ""

# Check for root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (or with sudo)"
    echo "Usage: sudo $0"
    exit 1
fi

echo "Installing build dependencies..."

apt-get update -qq

# Core build tools
apt-get install -y \
    live-build \
    debootstrap \
    squashfs-tools \
    xorriso \
    isolinux \
    syslinux-common \
    syslinux-utils \
    mtools \
    grub-efi-amd64-bin

# Development tools
apt-get install -y \
    git \
    make \
    shellcheck \
    python3 \
    python3-yaml \
    docker.io

# Enable Docker for the current user
if [[ -n "${SUDO_USER:-}" ]]; then
    usermod -aG docker "$SUDO_USER"
    echo "Added $SUDO_USER to docker group"
fi

echo ""
echo "Developer environment setup complete!"
echo ""
echo "You can now build namdevOS:"
echo "  make validate   - Run validation checks"
echo "  sudo make build - Build the ISO"
echo "  make clean      - Clean build artifacts"
