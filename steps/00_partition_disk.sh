#!/bin/bash
# CRITICAL=yes
# DESCRIPTION=Partitioning disk
# ONFAIL=Failed to partition disk. Check that the device exists and is not in use.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Validate DEVICE variable
if [ -z "$DEVICE" ]; then
    log_error "DEVICE variable is empty or not set"
    log_error "Expected format: DEVICE=sda (without /dev/ prefix)"
    exit 1
fi

# Validate device exists
if [ ! -b "/dev/$DEVICE" ]; then
    log_error "Device /dev/$DEVICE does not exist or is not a block device"
    log_error "Available devices:"
    lsblk -ndo NAME,SIZE,TYPE | grep disk || echo "  No disks found"
    exit 1
fi

log_info "Partitioning /dev/$DEVICE..."

# Create GPT partition table
parted /dev/"$DEVICE" --script mklabel gpt

# Create EFI partition (512MB)
parted /dev/"$DEVICE" --script mkpart ESP fat32 1MiB 513MiB
parted /dev/"$DEVICE" --script set 1 boot on

# Create root partition (remaining space)
parted /dev/"$DEVICE" --script mkpart primary ext4 513MiB 100%

log_success "Disk partitioned successfully"

exit 0
