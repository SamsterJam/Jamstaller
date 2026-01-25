#!/bin/bash
# CRITICAL=yes
# DESCRIPTION=Cloning dotfiles repository
# ONFAIL=Failed to clone dotfiles. Check internet connection.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

DOTFILES_REPO="https://github.com/SamsterJam/DotFiles.git"
DOTFILES_DIR="/home/$USERNAME/.dotfiles"

log_info "Cloning DotFiles repository..."
if arch-chroot "$MOUNT_POINT" su - "$USERNAME" -c "git clone '$DOTFILES_REPO' '$DOTFILES_DIR'"; then
    log_success "DotFiles cloned successfully"
else
    log_error "Failed to clone DotFiles repository"
    log_error "Check internet connection and repository URL"
    exit 1
fi

# Verify clone succeeded
if ! arch-chroot "$MOUNT_POINT" [ -d "$DOTFILES_DIR/.git" ]; then
    log_error "DotFiles directory exists but is not a git repository"
    exit 1
fi

log_success "DotFiles repository ready"

exit 0
