#!/bin/bash
# CRITICAL=no
# DESCRIPTION=Installing desktop packages
# ONFAIL=Some packages failed to install. Check logs for details.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Download packagelist from DotFiles repository
PACKAGELIST_URL="https://raw.githubusercontent.com/SamsterJam/DotFiles/main/packagelist"
PACKAGELIST="/tmp/jamstaller_packagelist"

log_info "Downloading package list from GitHub..."
if ! curl -fsSL "$PACKAGELIST_URL" -o "$PACKAGELIST"; then
    log_error "Failed to download package list from: $PACKAGELIST_URL"
    log_error "Check internet connection"
    exit 1
fi

if [ ! -f "$PACKAGELIST" ]; then
    log_error "Package list download failed"
    exit 1
fi

# Parse PACMAN_PACKAGES from packagelist
log_info "Parsing package list..."
# Extract package names from the PACMAN_PACKAGES array
PACKAGES=($(sed -n '/^PACMAN_PACKAGES=(/,/^)/p' "$PACKAGELIST" | grep -v '^PACMAN_PACKAGES=(' | grep -v '^)' | grep -v '^#' | awk '{print $1}' | grep -v '^$'))

# Count total packages
TOTAL_PKGS=${#PACKAGES[@]}
log_info "Found $TOTAL_PKGS packages to install"

# Failed packages tracking
declare -a FAILED_PACKAGES=()

# STRATEGY 1: Try bulk installation first
log_info "Attempting bulk installation of all packages..."
if arch-chroot "$MOUNT_POINT" pacman -S --noconfirm --needed "${PACKAGES[@]}" >> "$VERBOSE_LOG" 2>&1; then
    log_success "All packages installed successfully via bulk install"
else
    log_warning "Bulk installation failed, falling back to individual installation..."

    # STRATEGY 2: Install one-by-one
    local current=0
    for pkg in "${PACKAGES[@]}"; do
        current=$((current + 1))
        log_info "[$current/$TOTAL_PKGS] Installing $pkg..."

        if arch-chroot "$MOUNT_POINT" pacman -S --noconfirm --needed "$pkg" >> "$VERBOSE_LOG" 2>&1; then
            echo -n "."  # Progress indicator
        else
            FAILED_PACKAGES+=("$pkg")
            log_warning "Failed to install: $pkg"
        fi
    done
    echo ""  # New line after progress dots
fi

# Report results
if [ ${#FAILED_PACKAGES[@]} -eq 0 ]; then
    log_success "All $TOTAL_PKGS packages installed successfully"
else
    log_warning "Installed $((TOTAL_PKGS - ${#FAILED_PACKAGES[@]}))/$TOTAL_PKGS packages"
    log_warning "Failed packages (${#FAILED_PACKAGES[@]}):"
    for failed_pkg in "${FAILED_PACKAGES[@]}"; do
        echo "  - $failed_pkg" | tee -a "$VERBOSE_LOG"
    done
    log_info "Failed packages logged to: $VERBOSE_LOG"
fi

# Enable services for installed packages
log_info "Enabling system services..."
arch-chroot "$MOUNT_POINT" systemctl enable systemd-timesyncd.service || log_warning "Failed to enable timesyncd"
arch-chroot "$MOUNT_POINT" systemctl enable bluetooth.service || log_warning "Failed to enable bluetooth"

# Still exit 0 (non-critical)
exit 0
