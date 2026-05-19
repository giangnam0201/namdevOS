#!/bin/bash
#
# namdevOS Build Script
# Orchestrates the ISO build using live-build
#

set -euo pipefail

# Configuration
DISTRO_NAME="namdevOS"
DISTRO_VERSION="1.1"
BUILD_DIR="build"
CONFIG_DIR="config/live-build"
PACKAGES_DIR="packages"
HOOKS_DIR="config/hooks"
OUTPUT_DIR="output"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flags
CLEAN=false
DRY_RUN=false

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Build the ${DISTRO_NAME} ISO image"
    echo ""
    echo "Options:"
    echo "  --clean     Clean build artifacts and exit"
    echo "  --dry-run   Validate configuration without building"
    echo "  -h, --help  Show this help message"
    echo ""
    echo "This script must be run as root (or with sudo)."
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        echo "Try: sudo $0"
        exit 1
    fi
}

patch_syslinux() {
    log_info "Replacing lb_binary_syslinux with namdevOS version..."

    # Strategy: completely replace lb_binary_syslinux with our own minimal
    # version that sets up isolinux booting WITHOUT any theme handling.
    # This is the only 100% reliable approach - sed pattern matching keeps
    # failing because the Ubuntu live-build script uses dynamic variables.

    local script=""
    # Try to find the script
    script="$(dpkg -L live-build 2>/dev/null | grep 'lb_binary_syslinux$' | head -1)" || true
    if [ -z "$script" ] || [ ! -f "$script" ]; then
        script="$(find /usr/lib/live /usr/share/live /usr/lib/live-build -name lb_binary_syslinux -type f 2>/dev/null | head -1)" || true
    fi

    if [ -n "$script" ] && [ -f "$script" ]; then
        # Back up original
        cp "$script" "${script}.orig.bak"

        # Write our replacement script
        cat > "$script" << 'SYSLINUX_REPLACEMENT'
#!/bin/sh
# namdevOS replacement for lb_binary_syslinux
# Sets up basic isolinux boot WITHOUT theme handling

set -e

echo "P: Begin installing syslinux..."

# Create isolinux directory in binary/
mkdir -p binary/isolinux

# Copy isolinux.bin
if [ -f /usr/lib/ISOLINUX/isolinux.bin ]; then
    cp /usr/lib/ISOLINUX/isolinux.bin binary/isolinux/
elif [ -f /usr/lib/syslinux/modules/bios/isolinux.bin ]; then
    cp /usr/lib/syslinux/modules/bios/isolinux.bin binary/isolinux/
elif [ -f /usr/share/syslinux/isolinux.bin ]; then
    cp /usr/share/syslinux/isolinux.bin binary/isolinux/
fi

# Copy ldlinux.c32 (required by syslinux 6.x)
for ldlinux in /usr/lib/syslinux/modules/bios/ldlinux.c32 /usr/share/syslinux/ldlinux.c32; do
    if [ -f "$ldlinux" ]; then
        cp "$ldlinux" binary/isolinux/
        break
    fi
done

# Copy other useful syslinux modules
for mod in libutil.c32 libcom32.c32 menu.c32 vesamenu.c32 hdt.c32 chain.c32; do
    for path in /usr/lib/syslinux/modules/bios /usr/share/syslinux; do
        if [ -f "${path}/${mod}" ]; then
            cp "${path}/${mod}" binary/isolinux/
            break
        fi
    done
done

# Create a basic isolinux.cfg if one doesn't exist
if [ ! -f binary/isolinux/isolinux.cfg ]; then
    cat > binary/isolinux/isolinux.cfg << 'ISOCFG'
DEFAULT live
TIMEOUT 50
PROMPT 0

UI menu.c32

MENU TITLE namdevOS Boot Menu
MENU BACKGROUND #0d1117
MENU COLOR title  1;36;40 #ff00d2d3 #00000000 none
MENU COLOR sel    7;37;40 #ffe94560 #00000000 none
MENU COLOR unsel  37;40   #ffe0e0e0 #00000000 none
MENU COLOR border 37;40   #00000000 #00000000 none

LABEL live
    MENU LABEL ^Start namdevOS
    MENU DEFAULT
    KERNEL /casper/vmlinuz
    APPEND initrd=/casper/initrd boot=casper quiet splash ---

LABEL live-safe
    MENU LABEL Start namdevOS (Safe Mode)
    KERNEL /casper/vmlinuz
    APPEND initrd=/casper/initrd boot=casper xforcevesa nomodeset quiet splash ---
ISOCFG
fi

# Create boot.cat marker
touch binary/isolinux/boot.cat 2>/dev/null || true

echo "P: Syslinux installed (namdevOS minimal config)"
SYSLINUX_REPLACEMENT

        chmod +x "$script"
        log_success "lb_binary_syslinux replaced with namdevOS version"
    else
        log_warn "lb_binary_syslinux not found — creating isolinux structure manually"
    fi

    # Also ensure the theme variable is empty everywhere
    find /usr/lib/live /usr/share/live /usr/lib/live-build -name "defaults.sh" -type f 2>/dev/null | while read -r f; do
        sed -i 's|LB_SYSLINUX_THEME=.*|LB_SYSLINUX_THEME=""|g' "$f" 2>/dev/null || true
    done || true

    # Create fake theme directories (belt and suspenders)
    mkdir -p /usr/share/syslinux/themes/isolinux-live
    mkdir -p /usr/share/syslinux/themes/ubuntu-oneiric/isolinux-live
    touch /usr/share/syslinux/themes/isolinux-live/.keep
    touch /usr/share/syslinux/themes/ubuntu-oneiric/isolinux-live/.keep
}

install_dependencies() {
    local deps=(live-build debootstrap squashfs-tools xorriso genisoimage isolinux syslinux syslinux-common syslinux-utils mtools grub-efi-amd64 grub-efi-amd64-signed shim-signed grub-efi-amd64-bin)
    local missing=()

    for dep in "${deps[@]}"; do
        if ! dpkg -l "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_info "Installing missing dependencies: ${missing[*]}"
        apt-get update -qq
        apt-get install -y "${missing[@]}"
        log_success "Dependencies installed"
    else
        log_success "All dependencies are already installed"
    fi
}

setup_build_directory() {
    log_info "Setting up build directory..."

    mkdir -p "${BUILD_DIR}"

    # Copy live-build auto scripts
    mkdir -p "${BUILD_DIR}/auto"
    cp "${CONFIG_DIR}/auto/config" "${BUILD_DIR}/auto/config"
    cp "${CONFIG_DIR}/auto/build" "${BUILD_DIR}/auto/build"
    cp "${CONFIG_DIR}/auto/clean" "${BUILD_DIR}/auto/clean"
    chmod +x "${BUILD_DIR}/auto/"*

    log_success "Build directory prepared"
}

setup_package_lists() {
    log_info "Setting up package lists..."

    mkdir -p "${BUILD_DIR}/config/package-lists"

    for list_file in "${PACKAGES_DIR}"/*.list.chroot; do
        if [[ -f "$list_file" ]]; then
            local basename
            basename=$(basename "$list_file")
            cp "$list_file" "${BUILD_DIR}/config/package-lists/${basename}"
        fi
    done

    log_success "Package lists configured"
}

setup_hooks() {
    log_info "Setting up build hooks..."

    mkdir -p "${BUILD_DIR}/config/hooks/live"

    if [[ -d "${HOOKS_DIR}/live" ]]; then
        for hook in "${HOOKS_DIR}/live/"*.hook.chroot; do
            if [[ -f "$hook" ]]; then
                cp "$hook" "${BUILD_DIR}/config/hooks/live/"
                chmod +x "${BUILD_DIR}/config/hooks/live/$(basename "$hook")"
            fi
        done
    fi

    log_success "Build hooks configured"
}

setup_includes() {
    log_info "Staging branding, system, and installer files into chroot..."

    local includes="${BUILD_DIR}/config/includes.chroot"

    # Stage branding files where hooks expect them (/tmp/branding/)
    mkdir -p "${includes}/tmp/branding"
    cp -r branding/* "${includes}/tmp/branding/"

    # Stage system files where hooks expect them (/tmp/system/)
    mkdir -p "${includes}/tmp/system"
    cp -r system/* "${includes}/tmp/system/"

    # Stage Calamares configs directly to /etc/calamares/
    mkdir -p "${includes}/etc/calamares"
    cp -r installer/calamares/* "${includes}/etc/calamares/"

    log_success "Includes staged into chroot"
}

run_build() {
    log_info "Starting ISO build..."
    log_info "This may take a long time depending on your internet connection and hardware."

    pushd "${BUILD_DIR}" > /dev/null

    # Configure live-build
    lb config

    # Run the build
    lb build

    popd > /dev/null

    # Move the output ISO
    mkdir -p "${OUTPUT_DIR}"
    local iso_file
    iso_file=$(find "${BUILD_DIR}" -maxdepth 1 -name "*.iso" | head -1)

    if [[ -n "$iso_file" ]]; then
        local output_name="${DISTRO_NAME}-${DISTRO_VERSION}-amd64.iso"
        mv "$iso_file" "${OUTPUT_DIR}/${output_name}"
        log_success "ISO built successfully: ${OUTPUT_DIR}/${output_name}"

        local iso_size
        iso_size=$(du -h "${OUTPUT_DIR}/${output_name}" | cut -f1)
        log_info "ISO size: ${iso_size}"
    else
        log_error "Build completed but no ISO file found"
        exit 1
    fi
}

do_clean() {
    log_info "Cleaning build artifacts..."

    if [[ -d "${BUILD_DIR}" ]]; then
        pushd "${BUILD_DIR}" > /dev/null
        lb clean --purge 2>/dev/null || true
        popd > /dev/null
        rm -rf "${BUILD_DIR}"
    fi

    rm -rf "${OUTPUT_DIR}"

    log_success "Build artifacts cleaned"
}

do_dry_run() {
    log_info "Running dry-run validation..."

    local errors=0

    # Check config directory
    if [[ ! -d "${CONFIG_DIR}" ]]; then
        log_error "Config directory not found: ${CONFIG_DIR}"
        errors=$((errors + 1))
    else
        log_success "Config directory exists"
    fi

    # Check auto scripts
    for script in config build clean; do
        if [[ ! -f "${CONFIG_DIR}/auto/${script}" ]]; then
            log_error "Missing auto script: ${CONFIG_DIR}/auto/${script}"
            errors=$((errors + 1))
        else
            log_success "Auto script exists: ${script}"
        fi
    done

    # Check package lists
    if [[ ! -d "${PACKAGES_DIR}" ]]; then
        log_error "Packages directory not found: ${PACKAGES_DIR}"
        errors=$((errors + 1))
    else
        local list_count
        list_count=$(find "${PACKAGES_DIR}" -name "*.list.chroot" | wc -l)
        log_success "Found ${list_count} package list(s)"
    fi

    # Check hooks
    if [[ -d "${HOOKS_DIR}/live" ]]; then
        local hook_count
        hook_count=$(find "${HOOKS_DIR}/live" -name "*.hook.chroot" | wc -l)
        log_success "Found ${hook_count} build hook(s)"
    else
        log_warn "No hooks directory found (optional)"
    fi

    if [[ $errors -gt 0 ]]; then
        log_error "Dry run failed with ${errors} error(s)"
        exit 1
    fi

    log_success "Dry run passed - configuration is valid"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean)
            CLEAN=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main execution
echo "================================================"
echo "  ${DISTRO_NAME} Build System v${DISTRO_VERSION}"
echo "================================================"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    do_dry_run
    exit 0
fi

check_root

if [[ "$CLEAN" == "true" ]]; then
    do_clean
    exit 0
fi

install_dependencies
patch_syslinux
setup_build_directory
setup_package_lists
setup_hooks
setup_includes

# Force-install a working isohybrid EVERYWHERE it might be needed.
# live-build's binary.sh calls 'isohybrid' but on Ubuntu 24.04 it doesn't exist
# or the Perl version is broken. We install it at multiple locations.
log_info "Installing isohybrid wrapper..."
cat > /tmp/isohybrid_wrapper << 'HYBRIDWRAPPER'
#!/bin/sh
# isohybrid wrapper for namdevOS build
ISO=""
for arg in "$@"; do
    case "$arg" in
        -*) ;;
        *) ISO="$arg" ;;
    esac
done
[ -z "$ISO" ] && exit 0
[ ! -f "$ISO" ] && exit 0
if command -v xorriso >/dev/null 2>&1; then
    xorriso -indev "$ISO" -boot_image any partition_table=on -outdev "$ISO" 2>/dev/null
fi
exit 0
HYBRIDWRAPPER
chmod +x /tmp/isohybrid_wrapper
# Install to every possible location
cp /tmp/isohybrid_wrapper /usr/bin/isohybrid
cp /tmp/isohybrid_wrapper /usr/sbin/isohybrid
cp /tmp/isohybrid_wrapper /usr/local/bin/isohybrid
cp /tmp/isohybrid_wrapper /bin/isohybrid 2>/dev/null || true
chmod +x /usr/bin/isohybrid /usr/sbin/isohybrid /usr/local/bin/isohybrid
# Also make sure PATH includes everything
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
rm -f /tmp/isohybrid_wrapper
log_success "isohybrid installed to /usr/bin, /usr/sbin, /usr/local/bin"

run_build

echo ""
log_success "Build complete!"
