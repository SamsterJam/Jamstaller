#!/bin/bash
# CRITICAL=no
# DESCRIPTION=Installing Oh My Zsh
# ONFAIL=Oh My Zsh installation failed. Shell will work but without fancy themes.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Install for root
log_info "Installing Oh My Zsh for root..."
arch-chroot "$MOUNT_POINT" sh -c 'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' || log_warning "Root Oh My Zsh failed"

# Create custom themes directory for root
arch-chroot "$MOUNT_POINT" mkdir -p /root/.oh-my-zsh/custom/themes

# Install for user
log_info "Installing Oh My Zsh for $USERNAME..."
arch-chroot "$MOUNT_POINT" su - "$USERNAME" -c 'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' || log_warning "User Oh My Zsh failed"

# Create custom themes directory for user
arch-chroot "$MOUNT_POINT" su - "$USERNAME" -c "mkdir -p /home/$USERNAME/.oh-my-zsh/custom/themes"

# Ensure proper ownership
log_info "Setting proper ownership..."
arch-chroot "$MOUNT_POINT" chown -R "$USERNAME":"$USERNAME" "/home/$USERNAME/.oh-my-zsh"

log_success "Oh My Zsh installed"

exit 0
