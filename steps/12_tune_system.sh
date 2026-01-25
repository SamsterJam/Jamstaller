#!/bin/bash
# CRITICAL=no
# DESCRIPTION=Tuning system performance
# ONFAIL=Some system tuning failed. System should still be bootable.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

log_info "Optimizing pacman configuration on new system..."
arch-chroot "$MOUNT_POINT" sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
arch-chroot "$MOUNT_POINT" sed -i 's/^#Color/Color/' /etc/pacman.conf
arch-chroot "$MOUNT_POINT" sed -i '/^#\[multilib\]/s/^#//' /etc/pacman.conf
arch-chroot "$MOUNT_POINT" sed -i '/^\[multilib\]/{n;s/^#Include = /Include = /}' /etc/pacman.conf
arch-chroot "$MOUNT_POINT" pacman -Sy

log_info "Optimizing makepkg.conf on new system..."
CPU_CORES=$(get_cpu_cores)
arch-chroot "$MOUNT_POINT" sed -i "s/^#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$CPU_CORES\"/" /etc/makepkg.conf
arch-chroot "$MOUNT_POINT" sed -i "s/^COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -z - --threads=$CPU_CORES)/" /etc/makepkg.conf

log_info "Optimizing disk I/O for SSD..."
echo "vm.swappiness=10" >> "$MOUNT_POINT/etc/sysctl.d/99-sysctl.conf"

log_success "System tuning completed successfully"

exit 0
