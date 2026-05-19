#!/bin/bash
#
# namdevOS Welcome Script
# Displays a welcome dialog on first login with setup options
#

WELCOME_MARKER="$HOME/.config/namdevos/.welcome-done"

# Only show once per user
if [[ -f "$WELCOME_MARKER" ]]; then
    exit 0
fi

# Check if zenity is available for GUI dialogs
if ! command -v zenity &>/dev/null; then
    exit 0
fi

# Show welcome dialog
zenity --info \
    --title="Welcome to namdevOS" \
    --text="<b>Welcome to namdevOS!</b>\n\nA developer-focused Linux distribution built for productivity.\n\n<b>Quick Tips:</b>\n• Press <b>Super</b> to open the application menu\n• <b>Ctrl+Alt+T</b> opens a terminal\n• Docker is pre-installed and ready to use\n• VS Code is available in the applications menu\n• Run <b>sudo ufw status</b> to check firewall\n\n<b>Useful Commands:</b>\n• <b>btop</b> - System monitor\n• <b>fzf</b> - Fuzzy file finder\n• <b>rg</b> - Fast text search (ripgrep)\n• <b>bat</b> - Better cat with syntax highlighting\n\nEnjoy coding!" \
    --width=450 \
    --ok-label="Get Started" 2>/dev/null || true

# Ask if user wants to set up development environment
SETUP=$(zenity --list \
    --title="Quick Setup" \
    --text="Would you like to configure any of these?" \
    --checklist \
    --column="Select" --column="Option" --column="Description" \
    TRUE "shell" "Set Zsh as default shell" \
    TRUE "docker" "Verify Docker is working" \
    FALSE "ssh-key" "Generate SSH key pair" \
    --width=500 --height=350 2>/dev/null) || true

if [[ "$SETUP" == *"shell"* ]]; then
    if command -v zsh &>/dev/null; then
        chsh -s /usr/bin/zsh 2>/dev/null || true
    fi
fi

if [[ "$SETUP" == *"docker"* ]]; then
    if docker run --rm hello-world &>/dev/null; then
        zenity --info --text="Docker is working correctly!" --width=300 2>/dev/null || true
    else
        zenity --warning --text="Docker test failed. You may need to log out and back in for group permissions to take effect." --width=350 2>/dev/null || true
    fi
fi

if [[ "$SETUP" == *"ssh-key"* ]]; then
    if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
        EMAIL=$(zenity --entry --title="SSH Key" --text="Enter your email for the SSH key:" --width=350 2>/dev/null) || true
        if [[ -n "$EMAIL" ]]; then
            mkdir -p "$HOME/.ssh"
            ssh-keygen -t ed25519 -C "$EMAIL" -f "$HOME/.ssh/id_ed25519" -N "" 2>/dev/null
            zenity --info --text="SSH key generated!\n\nPublic key:\n$(cat "$HOME/.ssh/id_ed25519.pub")" --width=500 2>/dev/null || true
        fi
    fi
fi

# Mark welcome as done
mkdir -p "$(dirname "$WELCOME_MARKER")"
touch "$WELCOME_MARKER"
