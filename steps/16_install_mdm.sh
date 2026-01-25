#!/bin/bash
# CRITICAL=yes
# DESCRIPTION=Installing MDM display manager
# ONFAIL=MDM installation failed. System won't have graphical login.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

MDM_REPO="https://github.com/SamsterJam/MDM.git"
BUILD_DIR="/tmp/mdm_build"

log_info "Cloning MDM repository..."
if ! arch-chroot "$MOUNT_POINT" bash -c "git clone '$MDM_REPO' '$BUILD_DIR'"; then
    log_error "Failed to clone MDM repository"
    exit 1
fi

log_info "Building MDM..."
if ! arch-chroot "$MOUNT_POINT" bash -c "cd '$BUILD_DIR' && make"; then
    log_error "MDM build failed"
    arch-chroot "$MOUNT_POINT" rm -rf "$BUILD_DIR"
    exit 1
fi

log_info "Installing MDM..."
if ! arch-chroot "$MOUNT_POINT" bash -c "cd '$BUILD_DIR' && make install"; then
    log_error "MDM installation failed"
    arch-chroot "$MOUNT_POINT" rm -rf "$BUILD_DIR"
    exit 1
fi

log_info "Enabling MDM service..."
arch-chroot "$MOUNT_POINT" systemctl enable mdm || log_warning "Failed to enable MDM service"

log_info "Cleaning up build directory..."
arch-chroot "$MOUNT_POINT" rm -rf "$BUILD_DIR"

log_success "MDM display manager installed"

exit 0
