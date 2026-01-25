#!/bin/bash
# CRITICAL=no
# DESCRIPTION=Installing AUR packages
# ONFAIL=Some AUR packages failed. Check logs for details.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Use packagelist downloaded in step 15 (or download if missing)
PACKAGELIST="/tmp/jamstaller_packagelist"

if [ ! -f "$PACKAGELIST" ]; then
    log_info "Package list not found, downloading from GitHub..."
    PACKAGELIST_URL="https://raw.githubusercontent.com/SamsterJam/DotFiles/main/packagelist"

    if ! curl -fsSL "$PACKAGELIST_URL" -o "$PACKAGELIST"; then
        log_error "Failed to download package list from: $PACKAGELIST_URL"
        log_error "Check internet connection"
        exit 1
    fi
fi

# Parse AUR_PACKAGES from packagelist
log_info "Parsing AUR package list..."
# Extract package names from the AUR_PACKAGES array
AUR_PKGS=($(sed -n '/^AUR_PACKAGES=(/,/^)/p' "$PACKAGELIST" | grep -v '^AUR_PACKAGES=(' | grep -v '^)' | grep -v '^#' | awk '{print $1}' | grep -v '^$'))

TOTAL_AUR=${#AUR_PKGS[@]}
log_info "Found $TOTAL_AUR AUR packages to install"

declare -a FAILED_AUR=()

# AUR packages ALWAYS install one-by-one (they're fragile)
current=0
for pkg in "${AUR_PKGS[@]}"; do
    current=$((current + 1))
    log_info "[$current/$TOTAL_AUR] Building AUR package: $pkg..."

    if arch-chroot "$MOUNT_POINT" su - "$USERNAME" -c "yay -S --needed --noconfirm '$pkg'" >> "$VERBOSE_LOG" 2>&1; then
        log_success "Installed: $pkg"
    else
        FAILED_AUR+=("$pkg")
        log_warning "Failed to build: $pkg"
    fi
done

# Report results
if [ ${#FAILED_AUR[@]} -eq 0 ]; then
    log_success "All $TOTAL_AUR AUR packages installed"
else
    log_warning "Installed $((TOTAL_AUR - ${#FAILED_AUR[@]}))/$TOTAL_AUR AUR packages"
    log_warning "Failed AUR packages (${#FAILED_AUR[@]}):"
    for failed in "${FAILED_AUR[@]}"; do
        echo "  - $failed" | tee -a "$VERBOSE_LOG"
    done
    log_info "Failed AUR packages logged to: $VERBOSE_LOG"
fi

exit 0
