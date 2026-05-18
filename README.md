# namdevOS

A professional Ubuntu-based Linux distribution built for developers. namdevOS provides a curated, preconfigured environment with all the tools you need to start coding immediately.

## Features

- **Developer-First**: Git, Docker, VS Code, Neovim, and 30+ development tools pre-installed
- **XFCE Desktop**: Lightweight, fast, and fully customizable desktop environment
- **Custom Branding**: Professional dark theme with custom wallpaper, boot splash, and login screen
- **Performance Tuned**: Optimized sysctl settings for developer workloads (increased inotify watches, reduced swap usage, TCP Fast Open)
- **Calamares Installer**: Smooth graphical installation experience
- **Flatpak Ready**: Flathub pre-configured for additional application installs
- **Secure Defaults**: UFW firewall enabled, SSH ready, sensible security settings
- **Reproducible Builds**: Docker-based build environment for consistent ISO generation

## System Requirements

### Running namdevOS

- 64-bit (amd64) processor
- 4 GB RAM minimum (8 GB recommended)
- 25 GB disk space minimum (50 GB recommended)
- UEFI or Legacy BIOS boot

### Building namdevOS

- Ubuntu 22.04+ or Debian 12+ build host
- 8 GB RAM minimum
- 50 GB free disk space
- Root access (for live-build)
- Internet connection (for package downloads)

## Quick Start

```bash
# Clone the repository
git clone https://github.com/namdevOS/namdevOS.git
cd namdevOS

# Run validation (no root required)
make validate

# Build the ISO (requires root)
sudo make build

# Or build in Docker (recommended)
make docker-build
```

## Detailed Build Guide

### Prerequisites

Install all build dependencies:

```bash
sudo bash scripts/setup-dev.sh
```

This installs live-build, debootstrap, squashfs-tools, xorriso, and other required packages.

### Building the ISO

1. **Validate the project structure:**
   ```bash
   bash scripts/validate.sh
   ```

2. **Build the ISO image:**
   ```bash
   sudo bash build.sh
   ```
   The ISO will be placed in `output/namdevOS-1.0-amd64.iso`.

3. **Clean build artifacts:**
   ```bash
   sudo bash build.sh --clean
   ```

4. **Dry run (validate without building):**
   ```bash
   bash build.sh --dry-run
   ```

### Docker Build (Recommended)

For reproducible builds without modifying your host system:

```bash
make docker-build
```

This builds the ISO inside a Docker container with all dependencies pre-installed.

## Customization Guide

### Adding Packages

Package lists are in the `packages/` directory:

- `base.list.chroot` - Core system packages
- `desktop.list.chroot` - Desktop environment
- `developer.list.chroot` - Development tools
- `multimedia.list.chroot` - Media applications
- `utilities.list.chroot` - System utilities

Add one package name per line. Lines starting with `#` are comments.

### Modifying Branding

- **Wallpaper**: Edit or replace `branding/wallpapers/namdevos-default.svg`
- **Logo**: Edit `branding/logo/namdevos-logo.svg`
- **Boot splash**: Modify `branding/plymouth/namdevos-theme/`
- **Login screen**: Edit `branding/lightdm/lightdm-gtk-greeter.conf`
- **Desktop layout**: Modify files in `branding/xfce/`

### Build Hooks

Hooks in `config/hooks/live/` run during the build process in alphabetical order:

| Hook | Purpose |
|------|---------|
| 0100-add-repos | Adds external repositories (VS Code, Docker) |
| 0200-install-extras | Installs packages from added repos |
| 0300-configure-desktop | Applies XFCE configuration to /etc/skel |
| 0400-apply-branding | Copies branding to system locations |
| 0500-system-tuning | Applies sysctl and system configs |
| 0600-cleanup | Removes apt cache and temp files |

## Directory Structure

```
namdevOS/
├── build.sh                    # Main build script
├── Makefile                    # Build targets
├── Dockerfile.build            # Docker build environment
├── config/
│   ├── live-build/auto/        # live-build configuration
│   └── hooks/live/             # Build hooks (chroot)
├── packages/                   # Package lists by category
├── branding/
│   ├── wallpapers/             # Desktop wallpapers
│   ├── logo/                   # Distribution logo
│   ├── plymouth/               # Boot splash theme
│   ├── lightdm/                # Login screen config
│   └── xfce/                   # Desktop environment config
├── installer/calamares/        # Calamares installer config
├── system/
│   ├── sysctl/                 # Kernel parameter tuning
│   ├── scripts/                # System scripts
│   └── grub/                   # Bootloader config
├── scripts/
│   ├── validate.sh             # Project validation
│   └── setup-dev.sh            # Dev environment setup
└── .github/workflows/          # CI/CD pipeline
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute to namdevOS.

## License

namdevOS is licensed under the [GNU General Public License v3.0](LICENSE).
