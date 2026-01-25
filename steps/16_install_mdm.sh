#!/bin/bash
# CRITICAL=yes
# DESCRIPTION=Installing MDM display manager
# ONFAIL=MDM installation failed. System won't have graphical login.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

MDM_REPO="https://github.com/SamsterJam/MDM.git"

log_info "Cloning, building, and installing MDM..."

# Run all build steps in a single chroot session using /tmp as working directory
if ! arch-chroot "$MOUNT_POINT" /bin/bash <<'EOFMDM'
set -e
cd /tmp
git clone https://github.com/SamsterJam/MDM.git mdm_build
cd mdm_build
make
make install
EOFMDM
then
    log_error "MDM build/installation failed"
    arch-chroot "$MOUNT_POINT" rm -rf /tmp/mdm_build
    exit 1
fi

log_info "Enabling MDM service..."
arch-chroot "$MOUNT_POINT" systemctl enable mdm || log_warning "Failed to enable MDM service"

log_info "Cleaning up build directory..."
arch-chroot "$MOUNT_POINT" rm -rf "$BUILD_DIR"

log_success "MDM display manager installed"

exit 0
