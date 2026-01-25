#!/bin/bash
# CRITICAL=no
# DESCRIPTION=Installing GRUB theme
# ONFAIL=GRUB theme installation failed. Default GRUB appearance will be used.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

DOTFILES_DIR="/home/$USERNAME/.dotfiles"
THEME_DIR="/usr/share/grub/themes"
THEME_NAME="Vimix"

# Create theme directory
log_info "Creating GRUB theme directory..."
arch-chroot "$MOUNT_POINT" mkdir -p "$THEME_DIR/$THEME_NAME"

# Remove old theme if exists
if arch-chroot "$MOUNT_POINT" [ -d "$THEME_DIR/$THEME_NAME" ]; then
    log_info "Removing existing theme..."
    arch-chroot "$MOUNT_POINT" rm -rf "$THEME_DIR/$THEME_NAME"
    arch-chroot "$MOUNT_POINT" mkdir -p "$THEME_DIR/$THEME_NAME"
fi

# Copy theme files
log_info "Installing $THEME_NAME theme..."
if ! arch-chroot "$MOUNT_POINT" [ -d "$DOTFILES_DIR/grubtheme/Vimix" ]; then
    log_error "Theme source directory not found: $DOTFILES_DIR/grubtheme/Vimix"
    exit 1
fi

arch-chroot "$MOUNT_POINT" cp -a "$DOTFILES_DIR/grubtheme/Vimix/"* "$THEME_DIR/$THEME_NAME/" || {
    log_error "Failed to copy theme files"
    exit 1
}

# Backup GRUB config
log_info "Backing up GRUB configuration..."
if arch-chroot "$MOUNT_POINT" [ -f /etc/default/grub ]; then
    arch-chroot "$MOUNT_POINT" cp -n /etc/default/grub /etc/default/grub.bak || true
fi

# Remove existing GRUB_THEME line if present
log_info "Configuring GRUB theme..."
arch-chroot "$MOUNT_POINT" sed -i '/GRUB_THEME=/d' /etc/default/grub

# Add new theme line
echo "GRUB_THEME=\"$THEME_DIR/$THEME_NAME/theme.txt\"" >> "$MOUNT_POINT/etc/default/grub"

# Update GRUB configuration
log_info "Updating GRUB configuration..."
arch-chroot "$MOUNT_POINT" grub-mkconfig -o /boot/grub/grub.cfg >> "$VERBOSE_LOG" 2>&1 || {
    log_error "Failed to update GRUB configuration"
    exit 1
}

log_success "GRUB theme installed successfully"

exit 0
