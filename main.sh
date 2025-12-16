#!/bin/bash
#
# Jamstaller Main Orchestrator
# Coordinates the installation process
#

set -e
set -o pipefail

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
    log_header "Welcome to Jamstaller"

    # Step 1: Gather installation location
    log_info "Step 1: Select installation location"
    # TODO: Call your install_location TUI function here
    # For now, we'll skip to system setup

    # Step 2: Gather system configuration
    log_info "Step 2: Configure system settings"
    # TODO: Call your system_setup TUI function here

    # Step 3: Gather user configuration
    log_info "Step 3: Configure user account"
    # TODO: Call your user_setup TUI function here

    # Step 4: Show summary and confirm
    show_installation_summary

    if ! confirm_installation; then
        log_error "Installation cancelled by user"
        exit 0
    fi

    # Step 5: Execute installation steps
    log_header "Beginning Installation"
    execute_install_steps "$SCRIPT_DIR/steps"

    # Step 7: Cleanup
    log_header "Installation Complete"
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

# Set up error trap
trap error_handler ERR

# Run main
main "$@"
