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
if ! arch-chroot "$MOUNT_POINT" su - "$USERNAME" -c "cd '$BUILD_DIR/yay' && makepkg --noconfirm"; then
    log_error "Yay build failed"
    arch-chroot "$MOUNT_POINT" rm -rf "$BUILD_DIR"
    exit 1
fi

# Find and install the built package
log_info "Installing Yay package..."
YAY_PKG=$(arch-chroot "$MOUNT_POINT" find "$BUILD_DIR/yay" -name 'yay-*.pkg.tar.zst' | head -1)
if [ -z "$YAY_PKG" ]; then
    log_error "Could not find built Yay package"
    arch-chroot "$MOUNT_POINT" rm -rf "$BUILD_DIR"
    exit 1
fi

if ! arch-chroot "$MOUNT_POINT" pacman -U --noconfirm "$YAY_PKG"; then
    log_error "Failed to install Yay package"
    arch-chroot "$MOUNT_POINT" rm -rf "$BUILD_DIR"
    exit 1
fi

log_success "Yay built and installed successfully"

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
