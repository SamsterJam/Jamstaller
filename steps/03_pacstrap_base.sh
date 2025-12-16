#!/bin/bash
# CRITICAL=yes
# DESCRIPTION=Installing base system
# ONFAIL=Failed to install base system. Check internet connection and mirror availability.

set -e

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Optimize pacman.conf on the ISO before installing
log_info "Optimizing pacman configuration on ISO..."
sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 5/' /etc/pacman.conf
sed -i 's/^#Color/Color/' /etc/pacman.conf

# Optimize makepkg.conf on the ISO
CPU_CORES=$(get_cpu_cores)
log_info "Optimizing makepkg to use $CPU_CORES cores..."
sed -i "s/^#MAKEFLAGS=\"-j2\"/MAKEFLAGS=\"-j$CPU_CORES\"/" /etc/makepkg.conf
sed -i "s/^#COMPRESSXZ=(xz -c -z -)/COMPRESSXZ=(xz -c -z - --threads=$CPU_CORES)/" /etc/makepkg.conf

# Install base system
log_info "Installing base system packages..."
pacstrap "$MOUNT_POINT" base linux linux-firmware linux-headers grub efibootmgr os-prober zsh curl wget git nano

log_success "Base system installed successfully"

exit 0
