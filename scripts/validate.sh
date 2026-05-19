#!/bin/bash
#
# namdevOS Project Validation Script
# Performs static checks on the project structure and scripts
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    PASS=$((PASS + 1))
}

fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAIL=$((FAIL + 1))
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    WARN=$((WARN + 1))
}

# Determine project root (script location parent)
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "================================================"
echo "  namdevOS Project Validation"
echo "================================================"
echo ""
echo "Project root: ${PROJECT_ROOT}"
echo ""

# -------------------------------------------
# Check 1: Install shellcheck if not available
# -------------------------------------------
echo "--- Checking tools ---"
if ! command -v shellcheck &>/dev/null; then
    echo "shellcheck not found, attempting to install..."
    if command -v apt-get &>/dev/null; then
        if sudo apt-get update -qq 2>/dev/null; then
            sudo apt-get install -y shellcheck 2>/dev/null || true
        fi
    fi
fi

if command -v shellcheck &>/dev/null; then
    pass "shellcheck is available"
else
    warn "shellcheck not available - skipping shell script checks"
fi
echo ""

# -------------------------------------------
# Check 2: Run shellcheck on all .sh files
# -------------------------------------------
echo "--- Shellcheck validation ---"
if command -v shellcheck &>/dev/null; then
    shellcheck_errors=0
    while IFS= read -r -d '' script; do
        if shellcheck -S error "$script" 2>/dev/null; then
            pass "shellcheck: $(basename "$script")"
        else
            fail "shellcheck: $(basename "$script")"
            shellcheck_errors=$((shellcheck_errors + 1))
        fi
    done < <(find "$PROJECT_ROOT" -name "*.sh" -not -path "*/.git/*" -print0)

    if [[ $shellcheck_errors -eq 0 ]]; then
        pass "All shell scripts pass shellcheck"
    fi
fi
echo ""

# -------------------------------------------
# Check 3: Verify directory structure
# -------------------------------------------
echo "--- Directory structure ---"
required_dirs=(
    "config/live-build/auto"
    "config/hooks/live"
    "packages"
    "branding/wallpapers"
    "branding/logo"
    "branding/plymouth/namdevos-theme"
    "branding/lightdm"
    "branding/xfce"
    "installer/calamares/modules"
    "installer/calamares/branding/namdevos"
    "system/sysctl"
    "system/scripts"
    "system/grub"
    "scripts"
    ".github/workflows"
)

for dir in "${required_dirs[@]}"; do
    if [[ -d "${PROJECT_ROOT}/${dir}" ]]; then
        pass "Directory exists: ${dir}"
    else
        fail "Missing directory: ${dir}"
    fi
done
echo ""

# -------------------------------------------
# Check 4: Verify package list files
# -------------------------------------------
echo "--- Package lists ---"
required_lists=(
    "packages/base.list.chroot"
    "packages/desktop.list.chroot"
    "packages/developer.list.chroot"
    "packages/multimedia.list.chroot"
    "packages/networking.list.chroot"
    "packages/utilities.list.chroot"
)

for list in "${required_lists[@]}"; do
    if [[ -f "${PROJECT_ROOT}/${list}" ]]; then
        line_count=$(grep -cv '^\s*#\|^\s*$' "${PROJECT_ROOT}/${list}" || true)
        pass "Package list: ${list} (${line_count} packages)"
    else
        fail "Missing package list: ${list}"
    fi
done
echo ""

# -------------------------------------------
# Check 5: Verify key files exist
# -------------------------------------------
echo "--- Key files ---"
required_files=(
    "build.sh"
    "Makefile"
    "Dockerfile.build"
    "README.md"
    "LICENSE"
    "CONTRIBUTING.md"
    "config/live-build/auto/config"
    "config/live-build/auto/build"
    "config/live-build/auto/clean"
    "branding/wallpapers/namdevos-default.svg"
    "branding/logo/namdevos-logo.svg"
    "branding/plymouth/namdevos-theme/namdevos-theme.plymouth"
    "branding/plymouth/namdevos-theme/namdevos-theme.script"
    "branding/lightdm/lightdm-gtk-greeter.conf"
    "branding/xfce/xfce4-panel.xml"
    "branding/xfce/xfce4-desktop.xml"
    "branding/xfce/whiskermenu.rc"
    "installer/calamares/settings.conf"
    "installer/calamares/branding/namdevos/branding.desc"
    "system/sysctl/99-namdevos-performance.conf"
    "system/scripts/post-install.sh"
    "system/grub/namdevos-grub.cfg"
    ".github/workflows/build.yml"
)

for file in "${required_files[@]}"; do
    if [[ -f "${PROJECT_ROOT}/${file}" ]]; then
        pass "File exists: ${file}"
    else
        fail "Missing file: ${file}"
    fi
done
echo ""

# -------------------------------------------
# Check 6: Validate YAML files
# -------------------------------------------
echo "--- YAML validation ---"
while IFS= read -r -d '' yaml_file; do
    relative="${yaml_file#"${PROJECT_ROOT}/"}"
    if python3 -c "
import yaml, sys
try:
    with open('${yaml_file}', 'r') as f:
        yaml.safe_load(f)
    sys.exit(0)
except Exception as e:
    print(f'  Error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null; then
        pass "Valid YAML: ${relative}"
    else
        fail "Invalid YAML: ${relative}"
    fi
done < <(find "$PROJECT_ROOT" \( -name "*.yml" -o -name "*.yaml" \) -not -path "*/.git/*" -print0)
echo ""

# -------------------------------------------
# Check 7: Verify scripts are executable
# -------------------------------------------
echo "--- Script permissions ---"
executable_scripts=(
    "build.sh"
    "scripts/validate.sh"
    "scripts/setup-dev.sh"
    "config/hooks/live/0100-add-repos.hook.chroot"
    "config/hooks/live/0200-install-extras.hook.chroot"
    "config/hooks/live/0300-configure-desktop.hook.chroot"
    "config/hooks/live/0400-apply-branding.hook.chroot"
    "config/hooks/live/0500-system-tuning.hook.chroot"
    "config/hooks/live/0600-cleanup.hook.chroot"
    "system/scripts/post-install.sh"
)

for script in "${executable_scripts[@]}"; do
    filepath="${PROJECT_ROOT}/${script}"
    if [[ -f "$filepath" ]]; then
        if [[ -x "$filepath" ]]; then
            pass "Executable: ${script}"
        else
            fail "Not executable: ${script}"
        fi
    fi
done
echo ""

# -------------------------------------------
# Check 8: Verify XML files are well-formed
# -------------------------------------------
echo "--- XML validation ---"
while IFS= read -r -d '' xml_file; do
    relative="${xml_file#"${PROJECT_ROOT}/"}"
    if python3 -c "
import xml.etree.ElementTree as ET
import sys
try:
    ET.parse('${xml_file}')
    sys.exit(0)
except Exception as e:
    print(f'  Error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null; then
        pass "Valid XML: ${relative}"
    else
        fail "Invalid XML: ${relative}"
    fi
done < <(find "$PROJECT_ROOT" -name "*.xml" | grep -v ".git" | tr '\n' '\0')
echo ""

# -------------------------------------------
# Summary
# -------------------------------------------
echo "================================================"
echo "  Validation Summary"
echo "================================================"
echo -e "  ${GREEN}Passed: ${PASS}${NC}"
echo -e "  ${RED}Failed: ${FAIL}${NC}"
echo -e "  ${YELLOW}Warnings: ${WARN}${NC}"
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo -e "${RED}VALIDATION FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}ALL CHECKS PASSED${NC}"
    exit 0
fi
