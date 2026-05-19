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
    log_info "Neutralizing lb_binary_syslinux (using GRUB-EFI, syslinux themes not needed)..."

    # Find the lb_binary_syslinux script and replace it entirely with a no-op.
    # The script tries to cp theme files that don't exist in Ubuntu 24.04.
    # The path uses a variable ($LB_SYSLINUX_THEME) which can be empty,
    # resulting in paths like /usr/share/syslinux/themes//isolinux-live.
    local script
    script=$(dpkg -L live-build 2>/dev/null | grep -m1 'lb_binary_syslinux$' || true)
    [[ -z "$script" ]] && script=$(find /usr/lib/live /usr/share/live /usr/lib/live-build 2>/dev/null -name lb_binary_syslinux -type f | head -1)

    if [[ -n "$script" && -f "$script" ]]; then
        # Backup original
        cp "$script" "${script}.orig"
        # Replace with a script that just exits successfully
        cat > "$script" << 'NOOP'
#!/bin/sh
# PATCHED by namdevOS: syslinux theme handling disabled (GRUB-EFI only)
exit 0
NOOP
        chmod +x "$script"
        log_success "lb_binary_syslinux replaced with no-op"
    else
        log_warn "lb_binary_syslinux not found — skipping"
    fi

    # Also create fake directories as a belt-and-suspenders approach
    # in case any other script references these paths
    mkdir -p /usr/share/syslinux/themes/isolinux-live
    mkdir -p /usr/share/syslinux/themes/ubuntu-oneiric/isolinux-live
    # Create a minimal isolinux.cfg so nothing complains
    touch /usr/share/syslinux/themes/isolinux-live/isolinux.cfg
    touch /usr/share/syslinux/themes/ubuntu-oneiric/isolinux-live/isolinux.cfg

    # Ensure syslinux-common is installed
    if ! dpkg -l syslinux-common &>/dev/null 2>&1; then
        apt-get install -y syslinux-common 2>/dev/null || true
    fi
}

install_dependencies() {
    local deps=(live-build debootstrap squashfs-tools xorriso isolinux syslinux-common syslinux-utils mtools grub-efi-amd64 grub-efi-amd64-signed shim-signed grub-efi-amd64-bin)
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
run_build

echo ""
log_success "Build complete!"
