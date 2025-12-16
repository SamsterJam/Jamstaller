#!/bin/bash
# CRITICAL=no
# DESCRIPTION=Installing hardware drivers
# ONFAIL=Failed to install some drivers. Graphics or hardware may not work optimally.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Install pciutils if not already available (needed for lspci)
if ! arch-chroot "$MOUNT_POINT" command -v lspci &> /dev/null; then
    log_info "Installing pciutils for hardware detection..."
    arch-chroot "$MOUNT_POINT" pacman -S --noconfirm pciutils
fi

# Detect and install graphics drivers
log_info "Detecting graphics hardware..."

nvidia_detected=$(detect_nvidia)
intel_detected=$(detect_intel)
amd_detected=$(detect_amd)

# Install NVIDIA drivers if detected
if [ "$nvidia_detected" = "yes" ]; then
    log_info "NVIDIA graphics detected, installing drivers..."
    arch-chroot "$MOUNT_POINT" pacman -S --noconfirm nvidia nvidia-utils nvidia-settings

    # Configure GRUB for NVIDIA
    log_info "Configuring GRUB for NVIDIA..."
    if grep -q 'GRUB_CMDLINE_LINUX_DEFAULT' "$MOUNT_POINT/etc/default/grub"; then
        arch-chroot "$MOUNT_POINT" sed -i 's/\(GRUB_CMDLINE_LINUX_DEFAULT=".*\)"$/\1 nvidia_drm.modeset=1"/' /etc/default/grub
    else
        echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet nvidia_drm.modeset=1"' >> "$MOUNT_POINT/etc/default/grub"
    fi
    arch-chroot "$MOUNT_POINT" grub-mkconfig -o /boot/grub/grub.cfg

    # Add NVIDIA modules to initramfs
    log_info "Adding NVIDIA modules to initramfs..."
    arch-chroot "$MOUNT_POINT" sed -i 's/^MODULES=(/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm /' /etc/mkinitcpio.conf
    arch-chroot "$MOUNT_POINT" mkinitcpio -P

elif [ "$intel_detected" = "yes" ]; then
    log_info "Intel graphics detected, installing drivers..."
    arch-chroot "$MOUNT_POINT" pacman -S --noconfirm xf86-video-intel

elif [ "$amd_detected" = "yes" ]; then
    log_info "AMD graphics detected, installing drivers..."
    arch-chroot "$MOUNT_POINT" pacman -S --noconfirm xf86-video-amdgpu
fi

# Detect and install CPU microcode
log_info "Detecting CPU..."

intel_cpu=$(detect_intel_cpu)
amd_cpu=$(detect_amd_cpu)

if [ "$intel_cpu" = "yes" ]; then
    log_info "Intel CPU detected, installing microcode..."
    arch-chroot "$MOUNT_POINT" pacman -S --noconfirm intel-ucode
fi

if [ "$amd_cpu" = "yes" ]; then
    log_info "AMD CPU detected, installing microcode..."
    arch-chroot "$MOUNT_POINT" pacman -S --noconfirm amd-ucode
fi

log_success "Hardware drivers installed successfully"

exit 0
