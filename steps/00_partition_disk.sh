#!/bin/bash
# CRITICAL=yes
# DESCRIPTION=Partitioning disk
# ONFAIL=Failed to partition disk. Check that the device exists and is not in use.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

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
