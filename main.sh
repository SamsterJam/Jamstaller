#!/bin/bash
#
# Jamstaller Main Orchestrator
# Coordinates the installation process
#

VERSION="0.7.0"
export VERSION

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

    echo "Jamstaller v${VERSION}" > /tmp/jamstaller_version.log
    echo "[INFO] Starting Jamstaller v${VERSION}" >> /tmp/jamstaller_debug.log

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

    # Load configuration from TUI modules
    log_info "Loading configuration..."

    # Debug: List all files in /tmp matching pattern
    echo "[DEBUG] Files in /tmp matching pattern:" >> /tmp/jamstaller_debug.log
    ls -la /tmp/jamstaller_*_config.conf >> /tmp/jamstaller_debug.log 2>&1

    # Source all config files created by TUI modules
    config_count=0
    for config_file in /tmp/jamstaller_*_config.conf; do
        if [ -f "$config_file" ]; then
            log_info "Loading config from: $config_file"
            echo "[DEBUG] Sourcing: $config_file" >> /tmp/jamstaller_debug.log
            echo "[DEBUG] Contents before source:" >> /tmp/jamstaller_debug.log
            cat "$config_file" >> /tmp/jamstaller_debug.log 2>&1
            source "$config_file"
            config_count=$((config_count + 1))
            echo "[DEBUG] After sourcing - DEVICE=$DEVICE, HOSTNAME=$HOSTNAME, USERNAME=$USERNAME" >> /tmp/jamstaller_debug.log
            rm -f "$config_file"  # Clean up temp files
        fi
    done

    if [ "$config_count" -eq 0 ]; then
        log_warning "No configuration files found in /tmp"
        log_info "Looking for files matching: /tmp/jamstaller_*_config.conf"
        echo "[DEBUG] No config files found!" >> /tmp/jamstaller_debug.log
    else
        log_info "Loaded $config_count configuration file(s)"
    fi

    # Validate critical configuration
    echo "[DEBUG] Final variables: DEVICE='$DEVICE', HOSTNAME='$HOSTNAME', USERNAME='$USERNAME'" >> /tmp/jamstaller_debug.log

    if [ -z "$DEVICE" ]; then
        log_error "DEVICE variable is not set. Installation cannot proceed."
        log_error "This indicates a configuration error. Please restart the installer."
        log_error "Check /tmp/jamstaller_debug.log for debugging information"
        cat /tmp/jamstaller_debug.log
        exit 1
    fi

    if [ -z "$HOSTNAME" ]; then
        log_error "HOSTNAME variable is not set. Installation cannot proceed."
        exit 1
    fi

    if [ -z "$USERNAME" ]; then
        log_error "USERNAME variable is not set. Installation cannot proceed."
        exit 1
    fi

    # Calculate partition names based on device type
    if [[ $DEVICE == nvme* ]]; then
        EFI_PARTITION="/dev/${DEVICE}p1"
        ROOT_PARTITION="/dev/${DEVICE}p2"
    else
        EFI_PARTITION="/dev/${DEVICE}1"
        ROOT_PARTITION="/dev/${DEVICE}2"
    fi

    # Set default locale if not set
    : "${LOCALE:=en_US.UTF-8}"

    # Export variables for child processes (steps)
    export HOSTNAME
    export TIMEZONE
    export USERNAME
    export USER_PASSWORD
    export DEVICE
    export EFI_PARTITION
    export ROOT_PARTITION
    export SWAP_SIZE
    export LOCALE
    export MOUNT_POINT

    # Debug: Verify exports before running steps
    echo "[DEBUG] Before execute_install_steps - exported vars:" >> /tmp/jamstaller_debug.log
    export | grep -E "DEVICE|HOSTNAME|USERNAME" >> /tmp/jamstaller_debug.log

    # User has already confirmed in TUI, proceed directly to installation
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
