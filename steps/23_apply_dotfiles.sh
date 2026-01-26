#!/bin/bash
# CRITICAL=no
# DESCRIPTION=Applying dotfiles configuration
# ONFAIL=Some dotfile configurations failed to apply. Desktop may not be fully configured.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

DOTFILES_DIR="/home/$USERNAME/.dotfiles"
USER_HOME="/home/$USERNAME"

# Helper function for safe copying
copy_config() {
    local src="$1"
    local dest="$2"
    local as_user="$3"  # "yes" or "no"

    # Check source exists
    if ! arch-chroot "$MOUNT_POINT" [ -e "$src" ]; then
        log_warning "Source not found: $src"
        return 1
    fi

    # Create destination directory
    local dest_dir="$(dirname "$dest")"
    if [ "$as_user" = "yes" ]; then
        arch-chroot "$MOUNT_POINT" su - "$USERNAME" -c "mkdir -p '$dest_dir'"
    else
        arch-chroot "$MOUNT_POINT" mkdir -p "$dest_dir"
    fi

    # Copy files
    if [ "$as_user" = "yes" ]; then
        arch-chroot "$MOUNT_POINT" su - "$USERNAME" -c "cp -r '$src' '$dest'"
    else
        arch-chroot "$MOUNT_POINT" cp -r "$src" "$dest"
    fi
}

# Apply Hyprland configs
log_info "Applying Hyprland configuration..."
copy_config "$DOTFILES_DIR/hypr" "$USER_HOME/.config/hypr" "yes" || log_warning "Failed to copy hypr config"
copy_config "$DOTFILES_DIR/waybar" "$USER_HOME/.config/waybar" "yes" || log_warning "Failed to copy waybar config"

# Apply other configs
log_info "Applying desktop configurations..."
copy_config "$DOTFILES_DIR/alacritty" "$USER_HOME/.config/alacritty" "yes" || log_warning "Failed to copy alacritty config"
copy_config "$DOTFILES_DIR/dunst" "$USER_HOME/.config/dunst" "yes" || log_warning "Failed to copy dunst config"
copy_config "$DOTFILES_DIR/fastfetch" "$USER_HOME/.config/fastfetch" "yes" || log_warning "Failed to copy fastfetch config"
copy_config "$DOTFILES_DIR/Thunar" "$USER_HOME/.config/Thunar" "yes" || log_warning "Failed to copy Thunar config"
copy_config "$DOTFILES_DIR/rofi" "$USER_HOME/.config/rofi" "yes" || log_warning "Failed to copy rofi config"
copy_config "$DOTFILES_DIR/wlogout" "$USER_HOME/.config/wlogout" "yes" || log_warning "Failed to copy wlogout config"

# Individual files
log_info "Copying individual config files..."
copy_config "$DOTFILES_DIR/.nanorc" "$USER_HOME/.nanorc" "yes" || log_warning "Failed to copy .nanorc"
copy_config "$DOTFILES_DIR/.gtkrc-2.0" "$USER_HOME/.gtkrc-2.0" "yes" || log_warning "Failed to copy .gtkrc-2.0"
copy_config "$DOTFILES_DIR/.wallpaper" "$USER_HOME/.wallpaper" "yes" || log_warning "Failed to copy .wallpaper"

# Make .wallpaper executable
arch-chroot "$MOUNT_POINT" su - "$USERNAME" -c "chmod +x '$USER_HOME/.wallpaper'" || log_warning "Failed to make .wallpaper executable"

# Discord fix
arch-chroot "$MOUNT_POINT" su - "$USERNAME" -c "mkdir -p '$USER_HOME/.config/discord'"
copy_config "$DOTFILES_DIR/discord-update-fix.json" "$USER_HOME/.config/discord/settings.json" "yes" || log_warning "Failed to copy discord fix"

# Custom zsh theme
copy_config "$DOTFILES_DIR/archcraft.zsh-theme" "$USER_HOME/.oh-my-zsh/custom/themes/archcraft.zsh-theme" "yes" || log_warning "Failed to copy zsh theme"

# GTK settings
log_info "Applying GTK settings..."
arch-chroot "$MOUNT_POINT" su - "$USERNAME" -c "mkdir -p '$USER_HOME/.config/gtk-3.0'"
copy_config "$DOTFILES_DIR/gtk-3.0" "$USER_HOME/.config/gtk-3.0" "yes" || log_warning "Failed to copy gtk-3.0"

# Root GTK settings
arch-chroot "$MOUNT_POINT" mkdir -p "/root/.config/gtk-3.0"
copy_config "$DOTFILES_DIR/gtk-3.0" "/root/.config/gtk-3.0" "no" || log_warning "Failed to copy root gtk-3.0"
copy_config "$DOTFILES_DIR/.gtkrc-2.0" "/root/.gtkrc-2.0" "no" || log_warning "Failed to copy root .gtkrc-2.0"

# Pictures/Wallpapers
log_info "Copying pictures and wallpapers..."
copy_config "$DOTFILES_DIR/Pictures" "$USER_HOME/Pictures" "yes" || log_warning "Failed to copy Pictures"

# System-wide: Icons, fonts
log_info "Installing system-wide themes and fonts..."
copy_config "$DOTFILES_DIR/Nordic-Cursors" "/usr/share/icons/Nordic-Cursors" "no" || log_warning "Failed to copy Nordic-Cursors"
copy_config "$DOTFILES_DIR/Nordic-Folders" "/usr/share/icons/Nordic-Folders" "no" || log_warning "Failed to copy Nordic-Folders"
arch-chroot "$MOUNT_POINT" cp "$DOTFILES_DIR"/fonts/* /usr/share/fonts/ 2>/dev/null || log_warning "Failed to copy fonts"
arch-chroot "$MOUNT_POINT" fc-cache -fv >> "$VERBOSE_LOG" 2>&1 || log_warning "Failed to refresh font cache"

# QT theming
log_info "Configuring QT theming..."
cat >> "$MOUNT_POINT/etc/environment" << 'EOF'
QT_QPA_PLATFORMTHEME=gtk2
QT_STYLE_OVERRIDE=gtk2
EOF

# Update .zshrc with theme
log_info "Configuring zsh theme..."
arch-chroot "$MOUNT_POINT" su - "$USERNAME" -c "sed -i 's/^ZSH_THEME=\".*\"/ZSH_THEME=\"archcraft\"/' '$USER_HOME/.zshrc'" || log_warning "Failed to set zsh theme"

# Add custom aliases
log_info "Adding custom aliases..."
arch-chroot "$MOUNT_POINT" su - "$USERNAME" -c "cat >> '$USER_HOME/.zshrc' << 'EOFZSH'

# Custom aliases
alias la=\"ls -a\"
alias neofetch=\"fastfetch\"
alias nf=\"clear && fastfetch\"
alias ff=\"fastfetch\"
alias nv=\"nvim\"
alias cls=\"clear\"
EOFZSH" || log_warning "Failed to add custom aliases"

# Create XDG user directories
log_info "Creating user directories..."
arch-chroot "$MOUNT_POINT" su - "$USERNAME" -c "xdg-user-dirs-update" || log_warning "Failed to create user directories"

# Generate Color Palette
arch-chroot "$MOUNT_POINT" su - "$USERNAME" -c "wal -n -s -t -e -i $USER_HOME/Pictures/Wallpapers/GlacierMountains-Kurt-Cotoaga.jpg" || log_warning "Failed to create color palette"

# Cleanup unwanted directories and files
log_info "Cleaning up unwanted files..."
arch-chroot "$MOUNT_POINT" rm -rf "$USER_HOME/Public" "$USER_HOME/Templates" 2>/dev/null || true
arch-chroot "$MOUNT_POINT" rm -f "$USER_HOME/.bash"* "$USER_HOME/.zcompdump-"* 2>/dev/null || true
arch-chroot "$MOUNT_POINT" rm -rf "$USER_HOME/.dotfiles" 2>/dev/null || true

# Final ownership fix
log_info "Fixing file ownership..."
arch-chroot "$MOUNT_POINT" chown -R "$USERNAME":"$USERNAME" "$USER_HOME"

log_success "Dotfiles applied successfully"

exit 0
