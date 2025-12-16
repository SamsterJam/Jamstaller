#!/bin/bash
# CRITICAL=yes
# DESCRIPTION=Generating fstab
# ONFAIL=Failed to generate fstab. Mounted partitions may not be accessible.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_info "Generating fstab with UUIDs..."
genfstab -U "$MOUNT_POINT" >> "$MOUNT_POINT/etc/fstab"

log_success "fstab generated successfully"

exit 0
