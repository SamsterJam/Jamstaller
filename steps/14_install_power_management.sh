#!/bin/bash
# CRITICAL=no
# DESCRIPTION=Installing power management
# ONFAIL=TLP installation failed. Battery life may be suboptimal.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_info "Installing TLP..."
arch-chroot "$MOUNT_POINT" pacman -S --noconfirm --needed tlp tlp-rdw

log_info "Enabling TLP service..."
arch-chroot "$MOUNT_POINT" systemctl enable tlp.service || log_warning "Failed to enable TLP"

log_success "Power management installed"

exit 0
