#!/bin/bash
# CRITICAL=no
# DESCRIPTION=Configuring timezone
# ONFAIL=Failed to set timezone. You can set it manually later with timedatectl.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_info "Setting timezone to $TIMEZONE..."
arch-chroot "$MOUNT_POINT" ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime

log_info "Syncing hardware clock..."
arch-chroot "$MOUNT_POINT" hwclock --systohc

log_success "Timezone configured successfully"

exit 0
