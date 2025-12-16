#!/bin/bash
# CRITICAL=no
# DESCRIPTION=Setting hostname
# ONFAIL=Failed to set hostname. You can set it manually later in /etc/hostname.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_info "Setting hostname to $HOSTNAME..."
echo "$HOSTNAME" > "$MOUNT_POINT/etc/hostname"

log_info "Configuring hosts file..."
cat >> "$MOUNT_POINT/etc/hosts" <<EOF
127.0.0.1 localhost
::1       localhost
127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

log_success "Hostname configured successfully"

exit 0
