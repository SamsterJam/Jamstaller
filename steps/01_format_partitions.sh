#!/bin/bash
# CRITICAL=yes
# DESCRIPTION=Formatting partitions
# ONFAIL=Failed to format partitions. The disk may be corrupted or write-protected.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_info "Formatting EFI partition $EFI_PARTITION..."
mkfs.fat -F32 "$EFI_PARTITION"

log_info "Formatting root partition $ROOT_PARTITION..."
mkfs.ext4 -F "$ROOT_PARTITION"

log_success "Partitions formatted successfully"

exit 0
