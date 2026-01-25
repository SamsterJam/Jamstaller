#!/bin/bash
# CRITICAL=yes
# DESCRIPTION=Installing AUR packages
# ONFAIL=Some AUR packages failed. Check logs for details.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Use packagelist downloaded during bootstrap
PACKAGELIST="$SCRIPT_DIR/packagelist"

if [ ! -f "$PACKAGELIST" ]; then
    log_error "Package list not found at: $PACKAGELIST"
    log_error "This should have been downloaded during bootstrap"
    exit 1
fi

# Source packagelist to load arrays
log_info "Loading AUR package list..."
source "$PACKAGELIST"

TOTAL_AUR=${#AUR_PACKAGES[@]}
log_info "Found $TOTAL_AUR AUR packages to install"

declare -a FAILED_AUR=()

# AUR packages ALWAYS install one-by-one (they're fragile)
current=0
for pkg in "${AUR_PACKAGES[@]}"; do
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
