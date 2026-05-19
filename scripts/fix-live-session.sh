#!/bin/bash
# ============================================================
# namdevOS Live Session Fixer
# Run this ONCE inside the booted live session to apply branding.
# Usage: curl -sL <raw-github-url> | sudo bash
#    OR: sudo bash fix-live-session.sh
# ============================================================

set -e

echo "================================================"
echo "  namdevOS Live Session Fixer"
echo "================================================"
echo ""

# Must be root
if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo bash $0"
    exit 1
fi

LIVE_USER="$(getent passwd 1000 | cut -d: -f1 || echo ubuntu)"
LIVE_HOME="/home/${LIVE_USER}"

echo "[1/7] Creating show.qml for Calamares..."
mkdir -p /etc/calamares/branding/namdevos
cat > /etc/calamares/branding/namdevos/show.qml << 'QML'
import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation {
    id: presentation

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0d1117"
            
            Column {
                anchors.centerIn: parent
                spacing: 20

                Text {
                    text: "Welcome to namdevOS"
                    color: "#ffffff"
                    font.pixelSize: 32
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "A developer-focused Linux distribution"
                    color: "#00d2d3"
                    font.pixelSize: 18
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Installing... This may take a few minutes."
                    color: "#a0a0b0"
                    font.pixelSize: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0d1117"

            Column {
                anchors.centerIn: parent
                spacing: 15

                Text {
                    text: "Developer Ready"
                    color: "#e94560"
                    font.pixelSize: 28
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "• Git, Python, build-essential pre-installed\n• Docker available via Package Selector\n• VS Code, Node.js one click away\n• Custom terminal with JetBrains Mono font"
                    color: "#e0e0e0"
                    font.pixelSize: 14
                    lineHeight: 1.5
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0d1117"

            Column {
                anchors.centerIn: parent
                spacing: 15

                Text {
                    text: "Almost Done!"
                    color: "#00d2d3"
                    font.pixelSize: 28
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "After installation:\n• Run 'namdevos-package-selector' to install more software\n• Press Super+Space for app launcher\n• Ctrl+Alt+T opens terminal"
                    color: "#e0e0e0"
                    font.pixelSize: 14
                    lineHeight: 1.5
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
QML

echo "[2/7] Fixing Calamares branding.desc..."
cat > /etc/calamares/branding/namdevos/branding.desc << 'BRAND'
---
componentName: namdevos

strings:
    productName:         "namdevOS"
    shortProductName:    "namdevOS"
    version:             "1.1"
    shortVersion:        "1.1"
    versionedName:       "namdevOS 1.1 Nova"
    shortVersionedName:  "namdevOS 1.1"
    bootloaderEntryName: "namdevOS"
    productUrl:          "https://github.com/giangnam0201/namdevOS"
    supportUrl:          "https://github.com/giangnam0201/namdevOS/issues"
    knownIssuesUrl:      "https://github.com/giangnam0201/namdevOS/issues"
    releaseNotesUrl:     "https://github.com/giangnam0201/namdevOS/releases"

images:
    productLogo:         "/usr/share/icons/namdevos/namdevos-logo.svg"
    productIcon:         "/usr/share/icons/namdevos/namdevos-logo.svg"

slideshow:               "show.qml"
slideshowAPI: 2

style:
    sidebarBackground:   "#0d1117"
    sidebarText:         "#e0e0e0"
    sidebarTextSelect:   "#e94560"
    sidebarTextHighlight: "#00d2d3"
BRAND

echo "[3/7] Creating Install namdevOS desktop shortcut..."
cat > /usr/share/applications/namdevos-installer.desktop << 'DESK'
[Desktop Entry]
Type=Application
Name=Install namdevOS
Comment=Install namdevOS to your hard drive
Exec=sudo calamares
Icon=calamares
Terminal=false
Categories=System;
DESK

# Remove old Debian installer shortcuts
rm -f /usr/share/applications/calamares-install-debian.desktop 2>/dev/null
rm -f /usr/share/applications/install-debian.desktop 2>/dev/null
rm -f "${LIVE_HOME}/Desktop/calamares-install-debian.desktop" 2>/dev/null
rm -f "${LIVE_HOME}/Desktop/install-debian.desktop" 2>/dev/null

# Put on desktop
mkdir -p "${LIVE_HOME}/Desktop"
cp /usr/share/applications/namdevos-installer.desktop "${LIVE_HOME}/Desktop/"
chmod +x "${LIVE_HOME}/Desktop/namdevos-installer.desktop"
chown "${LIVE_USER}:${LIVE_USER}" "${LIVE_HOME}/Desktop/namdevos-installer.desktop"

echo "[4/7] Setting wallpaper..."
if [[ -f /usr/share/backgrounds/namdevos/namdevos-default.svg ]]; then
    sudo -u "$LIVE_USER" xfconf-query -c xfce4-desktop \
        -p /backdrop/screen0/monitorVirtual-1/workspace0/last-image \
        -s /usr/share/backgrounds/namdevos/namdevos-default.svg --create -t string 2>/dev/null || true
    sudo -u "$LIVE_USER" xfconf-query -c xfce4-desktop \
        -p /backdrop/screen0/monitor0/workspace0/last-image \
        -s /usr/share/backgrounds/namdevos/namdevos-default.svg --create -t string 2>/dev/null || true
    # Also try without monitor name
    sudo -u "$LIVE_USER" xfconf-query -c xfce4-desktop \
        -p /backdrop/screen0/monitoreDP-1/workspace0/last-image \
        -s /usr/share/backgrounds/namdevos/namdevos-default.svg --create -t string 2>/dev/null || true
fi

echo "[5/7] Applying GTK dark theme..."
mkdir -p "${LIVE_HOME}/.config/gtk-3.0"
cat > "${LIVE_HOME}/.config/gtk-3.0/settings.ini" << 'GTK'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Inter 10
gtk-application-prefer-dark-theme=true
GTK
chown -R "${LIVE_USER}:${LIVE_USER}" "${LIVE_HOME}/.config/gtk-3.0"

echo "[6/7] Setting hostname..."
echo "namdevOS" > /etc/hostname
sed -i 's/127\.0\.1\.1.*/127.0.1.1\tnamdevOS/' /etc/hosts 2>/dev/null || true

echo "[7/7] Fixing os-release..."
cat > /etc/os-release << 'OSREL'
PRETTY_NAME="namdevOS 1.1 Nova"
NAME="namdevOS"
VERSION_ID="1.1"
VERSION="1.1 (Nova)"
ID=namdevos
ID_LIKE=ubuntu debian
HOME_URL="https://github.com/giangnam0201/namdevOS"
SUPPORT_URL="https://github.com/giangnam0201/namdevOS/issues"
BUG_REPORT_URL="https://github.com/giangnam0201/namdevOS/issues"
UBUNTU_CODENAME=noble
OSREL

echo ""
echo "================================================"
echo "  ALL FIXED!"  
echo "================================================"
echo ""
echo "Now you can:"
echo "  - Double-click 'Install namdevOS' on the desktop"
echo "  - The installer will show namdevOS branding"
echo "  - Wallpaper will update after you restart the desktop"
echo ""
echo "To restart the desktop panel: xfce4-panel -r"
echo ""
