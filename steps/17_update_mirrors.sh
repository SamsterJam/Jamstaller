#!/bin/bash
# CRITICAL=no
# DESCRIPTION=Optimizing package mirrors
# ONFAIL=Mirror optimization failed. Package downloads may be slower.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_info "Updating mirror list with reflector..."
log_info "This may take a few minutes..."

if arch-chroot "$MOUNT_POINT" reflector --verbose --latest 10 --sort rate --save /etc/pacman.d/mirrorlist >> "$VERBOSE_LOG" 2>&1; then
    log_success "Mirror list optimized"
else
    log_warning "Reflector failed, using existing mirrors"
fi

exit 0
