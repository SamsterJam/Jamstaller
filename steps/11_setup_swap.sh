#!/bin/bash
# CRITICAL=no
# DESCRIPTION=Setting up swap file
# ONFAIL=Swap file creation failed. System will work but may have memory issues.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Only create swap if SWAP_SIZE > 0
if [ "$SWAP_SIZE" -gt 0 ]; then
    log_info "Creating ${SWAP_SIZE}G swap file..."

    # Create swap file
    arch-chroot "$MOUNT_POINT" dd if=/dev/zero of=/swapfile bs=1M count=$((SWAP_SIZE * 1024)) status=progress

    # Set proper permissions (critical for security)
    log_info "Setting swap file permissions..."
    arch-chroot "$MOUNT_POINT" chmod 600 /swapfile

    # Format as swap
    log_info "Formatting swap file..."
    arch-chroot "$MOUNT_POINT" mkswap /swapfile

    # Enable swap
    log_info "Enabling swap file..."
    arch-chroot "$MOUNT_POINT" swapon /swapfile

    # Add to fstab if not already present
    if ! grep -q '/swapfile' "$MOUNT_POINT/etc/fstab"; then
        echo '/swapfile none swap defaults 0 0' >> "$MOUNT_POINT/etc/fstab"
        log_info "Added swap to fstab"
    fi

    log_success "Swap file created and enabled: ${SWAP_SIZE}G"
else
    log_info "SWAP_SIZE is 0, skipping swap creation"
fi

exit 0
