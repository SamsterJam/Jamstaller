#!/bin/bash
# CRITICAL=yes
# DESCRIPTION=Creating user account
# ONFAIL=Failed to create user account. Check username validity.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_info "Creating user $USERNAME..."
arch-chroot "$MOUNT_POINT" useradd -m -G wheel -s /bin/zsh "$USERNAME"

log_info "Setting password for $USERNAME..."
arch-chroot "$MOUNT_POINT" bash -c "echo '$USERNAME:$USER_PASSWORD' | chpasswd"

log_info "Setting root password..."
arch-chroot "$MOUNT_POINT" bash -c "echo 'root:$USER_PASSWORD' | chpasswd"

log_info "Changing root shell to zsh..."
arch-chroot "$MOUNT_POINT" chsh -s /bin/zsh root

log_info "Installing sudo..."
arch-chroot "$MOUNT_POINT" pacman -S --noconfirm sudo

log_info "Configuring sudo access for wheel group..."
arch-chroot "$MOUNT_POINT" sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

log_success "User account created successfully"

exit 0
