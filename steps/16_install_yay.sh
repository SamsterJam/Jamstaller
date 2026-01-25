#!/bin/bash
# CRITICAL=yes
# DESCRIPTION=Building Yay AUR helper
# ONFAIL=Yay installation failed. Cannot install AUR packages. Check build logs.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Install build dependencies
log_info "Installing Yay build dependencies..."
arch-chroot "$MOUNT_POINT" pacman -S --needed --noconfirm git base-devel go

# Build directory
BUILD_DIR="/home/$USERNAME/yay_build"

# Create build directory
log_info "Preparing build directory..."
arch-chroot "$MOUNT_POINT" su - "$USERNAME" -c "mkdir -p '$BUILD_DIR'"

# Clone Yay repository
log_info "Cloning Yay repository..."
if ! arch-chroot "$MOUNT_POINT" su - "$USERNAME" -c "git clone https://aur.archlinux.org/yay.git '$BUILD_DIR/yay'"; then
    log_error "Failed to clone Yay repository"
    arch-chroot "$MOUNT_POINT" rm -rf "$BUILD_DIR"
    exit 1
fi

# Build Yay (with error handling)
log_info "Building Yay (this may take a few minutes)..."
if arch-chroot "$MOUNT_POINT" su - "$USERNAME" -c "cd '$BUILD_DIR/yay' && makepkg -si --noconfirm"; then
    log_success "Yay built successfully"
else
    log_error "Yay build failed"
    arch-chroot "$MOUNT_POINT" rm -rf "$BUILD_DIR"
    exit 1
fi

# Verify Yay installation
log_info "Verifying Yay installation..."
if arch-chroot "$MOUNT_POINT" su - "$USERNAME" -c "yay --version" > /dev/null 2>&1; then
    log_success "Yay is working correctly"
else
    log_error "Yay installation verification failed"
    exit 1
fi

# Cleanup build directory
log_info "Cleaning up build directory..."
arch-chroot "$MOUNT_POINT" rm -rf "$BUILD_DIR"

log_success "Yay AUR helper installed"

exit 0
