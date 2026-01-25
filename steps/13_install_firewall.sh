#!/bin/bash
# CRITICAL=no
# DESCRIPTION=Installing firewall
# ONFAIL=Firewall installation failed. System will be less secure but functional.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_info "Installing UFW..."
arch-chroot "$MOUNT_POINT" pacman -S --noconfirm --needed ufw

# CRITICAL: Bind mount /lib/modules for UFW to access kernel modules
log_info "Preparing kernel modules for UFW..."
mkdir -p "$MOUNT_POINT/lib/modules"
mount --bind /lib/modules "$MOUNT_POINT/lib/modules"

# Configure UFW
log_info "Configuring UFW rules..."
arch-chroot "$MOUNT_POINT" ufw default deny incoming || log_warning "Failed to set default deny incoming"
arch-chroot "$MOUNT_POINT" ufw default allow outgoing || log_warning "Failed to set default allow outgoing"
arch-chroot "$MOUNT_POINT" ufw --force enable || log_warning "Failed to enable UFW"

# Enable UFW service
log_info "Enabling UFW service..."
arch-chroot "$MOUNT_POINT" systemctl enable ufw || log_warning "Failed to enable UFW service"

# CRITICAL: Unmount /lib/modules
log_info "Cleaning up kernel modules mount..."
umount "$MOUNT_POINT/lib/modules" || log_warning "Failed to unmount /lib/modules"

log_success "UFW firewall configured"

exit 0
