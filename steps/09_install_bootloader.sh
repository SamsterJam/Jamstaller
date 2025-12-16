#!/bin/bash
# CRITICAL=yes
# DESCRIPTION=Installing bootloader
# ONFAIL=Failed to install GRUB bootloader. System will not be bootable.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_info "Installing GRUB to EFI partition..."
arch-chroot "$MOUNT_POINT" grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi

log_info "Enabling os-prober in GRUB configuration..."
arch-chroot "$MOUNT_POINT" sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub

log_info "Generating GRUB configuration..."
arch-chroot "$MOUNT_POINT" grub-mkconfig -o /boot/grub/grub.cfg

log_info "Verifying UEFI boot entries..."
arch-chroot "$MOUNT_POINT" efibootmgr -v

# If GRUB entry is missing, create it manually
if ! arch-chroot "$MOUNT_POINT" efibootmgr -v | grep -q "GRUB"; then
    log_warning "GRUB entry not found in UEFI, creating manually..."
    arch-chroot "$MOUNT_POINT" efibootmgr --create --disk /dev/"$DEVICE" --part 1 --label "GRUB" --loader /EFI/GRUB/grubx64.efi
fi

log_success "Bootloader installed successfully"

exit 0
