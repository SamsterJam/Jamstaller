#!/bin/bash
# CRITICAL=yes
# DESCRIPTION=Mounting partitions
# ONFAIL=Failed to mount partitions. Check filesystem integrity.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_info "Mounting root partition to $MOUNT_POINT..."
mount "$ROOT_PARTITION" "$MOUNT_POINT"

log_info "Creating EFI mount point..."
mkdir -p "$MOUNT_POINT/boot/efi"

log_info "Mounting EFI partition..."
mount "$EFI_PARTITION" "$MOUNT_POINT/boot/efi"

# Set up swap file if requested
if [ -n "$SWAP_SIZE" ] && [ "$SWAP_SIZE" -gt 0 ]; then
    log_info "Creating ${SWAP_SIZE}GB swap file..."
    fallocate -l "${SWAP_SIZE}G" "$MOUNT_POINT/swapfile"
    chmod 600 "$MOUNT_POINT/swapfile"
    mkswap "$MOUNT_POINT/swapfile"
    swapon "$MOUNT_POINT/swapfile"
    log_success "Swap file created and activated"
fi

log_success "Partitions mounted successfully"

exit 0
