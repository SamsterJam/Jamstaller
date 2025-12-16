#!/bin/bash
# CRITICAL=yes
# DESCRIPTION=Configuring locale
# ONFAIL=Failed to configure locale settings.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_info "Setting locale to $LOCALE..."

# Uncomment the locale in locale.gen
arch-chroot "$MOUNT_POINT" sed -i "s/^#${LOCALE} UTF-8/${LOCALE} UTF-8/" /etc/locale.gen

# Set LANG in locale.conf
echo "LANG=${LOCALE}" > "$MOUNT_POINT/etc/locale.conf"

# Set console keymap
echo "KEYMAP=us" > "$MOUNT_POINT/etc/vconsole.conf"

log_info "Generating locale files..."
arch-chroot "$MOUNT_POINT" locale-gen

log_success "Locale configured successfully"

exit 0
