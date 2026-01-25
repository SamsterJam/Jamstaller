#!/bin/bash
# CRITICAL=yes
# DESCRIPTION=Installing NetworkManager
# ONFAIL=Failed to install NetworkManager. You may not have network connectivity after reboot.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_info "Installing NetworkManager..."
arch-chroot "$MOUNT_POINT" pacman -S --noconfirm networkmanager

log_info "Enabling NetworkManager service..."
arch-chroot "$MOUNT_POINT" systemctl enable NetworkManager

log_info "Enabling systemd-timesyncd for time synchronization..."
arch-chroot "$MOUNT_POINT" systemctl enable systemd-timesyncd.service

log_success "NetworkManager installed and enabled"

exit 0
