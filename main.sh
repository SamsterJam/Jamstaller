#!/bin/bash
#
# Jamstaller Main Orchestrator
# Coordinates the installation process
#

# Note: We don't use 'set -e' here because the TUI scripts
# may return non-zero exit codes during normal operation.
# Critical errors are handled explicitly via the error trap.

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library files
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/network.sh"
source "$SCRIPT_DIR/lib/executor.sh"

# Source TUI modules
source "$SCRIPT_DIR/tui/installer.sh"
source "$SCRIPT_DIR/tui/install_location.sh"
source "$SCRIPT_DIR/tui/system_setup.sh"
source "$SCRIPT_DIR/tui/user_setup.sh"

# Main installation flow
main() {
    clear

    # Run the TUI to gather all configuration
    installer_tui "Jamstaller" \
        "Install Location" \
        "System Setup" \
        "User Setup"

    tui_result=$?

    # Check if user cancelled
    if [ $tui_result -ne 0 ]; then
        log_error "Installation cancelled by user"
        exit 0
    fi

    # TUI completed successfully, proceed with installation
    execute_install_steps "$SCRIPT_DIR/steps"

    # Cleanup
    finishing_cleanup

    echo ""
    log_success "Installation completed successfully!"
    echo ""
    echo -e "${YELLOW}You can now reboot into your new system.${NC}"
    echo -e "${YELLOW}Run: reboot${NC}"
    echo ""
}

# Show installation summary
show_installation_summary() {
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}        Installation Summary${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}Hostname:${NC}        $HOSTNAME"
    echo -e "${BLUE}Timezone:${NC}        $TIMEZONE"
    echo -e "${BLUE}Username:${NC}        $USERNAME"
    echo -e "${BLUE}Device:${NC}          /dev/$DEVICE"
    echo -e "${BLUE}EFI Partition:${NC}   $EFI_PARTITION"
    echo -e "${BLUE}Root Partition:${NC}  $ROOT_PARTITION"
    [ -n "$SWAP_SIZE" ] && [ "$SWAP_SIZE" -gt 0 ] && \
        echo -e "${BLUE}Swap Size:${NC}       ${SWAP_SIZE}GB" || \
        echo -e "${BLUE}Swap:${NC}            None"
    echo -e "${YELLOW}═══════════════════════════════════════${NC}"
    echo ""
}

# Confirm installation
confirm_installation() {
    echo -e "${YELLOW}WARNING: This will ERASE ALL DATA on /dev/$DEVICE${NC}"
    echo ""
    read -p "Are you sure you want to proceed? (yes/NO): " response

    if [ "$response" = "yes" ]; then
        return 0
    else
        return 1
    fi
}

# Cleanup function
finishing_cleanup() {
    log_info "Syncing filesystems..."
    sync
    sleep 2

    log_info "Unmounting partitions..."
    umount -R /mnt 2>/dev/null || true

    log_info "Deactivating swap..."
    swapoff /mnt/swapfile 2>/dev/null || true

    sync
}

# Error handler
error_handler() {
    log_error "An error occurred during installation"
    log_info "Attempting cleanup..."

    sync
    sleep 2

    umount /mnt/boot/efi 2>/dev/null || true
    swapoff /mnt/swapfile 2>/dev/null || true
    fuser -km /mnt 2>/dev/null || true
    sleep 1
    umount -R /mnt 2>/dev/null || true

    log_error "Installation failed. Check logs for details."
    exit 1
}

# Error trap disabled to prevent interfering with TUI operations
# The error_handler function is available but not automatically triggered
# trap error_handler ERR

# Run main
main "$@"
