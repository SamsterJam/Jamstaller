#!/bin/bash
#
# Network connectivity functions for Jamstaller
#

# Check if internet is available
check_internet() {
    local attempts=3
    local count=0

    while [ $count -lt $attempts ]; do
        if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
            return 0
        fi
        count=$((count + 1))
        [ $count -lt $attempts ] && sleep 2
    done

    return 1
}

# Copy NetworkManager connections from ISO to installed system
copy_network_config() {
    local src="/etc/NetworkManager/system-connections"
    local dest="${MOUNT_POINT}/etc/NetworkManager/system-connections"

    if [ -d "$src" ] && [ "$(ls -A $src 2>/dev/null)" ]; then
        log_info "Copying NetworkManager connections..."

        mkdir -p "$dest"
        cp -r "$src"/* "$dest/" 2>/dev/null || true
        arch-chroot "$MOUNT_POINT" chmod 600 /etc/NetworkManager/system-connections/* 2>/dev/null || true

        log_success "Network configuration copied"
        return 0
    else
        log_warning "No NetworkManager connections to copy"
        return 1
    fi
}

# Wait for internet connectivity
wait_for_internet() {
    local timeout=${1:-60}
    local elapsed=0

    log_info "Checking for internet connectivity..."

    while [ $elapsed -lt $timeout ]; do
        if check_internet; then
            log_success "Internet connection established"
            return 0
        fi

        echo -n "."
        sleep 5
        elapsed=$((elapsed + 5))
    done

    echo ""
    log_error "No internet connection after ${timeout}s"
    return 1
}

# Prompt user to connect to network
prompt_network_connection() {
    log_warning "No internet connection detected"
    echo ""
    echo "Please connect to the internet to continue installation."
    echo "You can use one of the following:"
    echo "  - Ethernet (plug in cable)"
    echo "  - WiFi: nmtui or nmcli"
    echo ""
    read -p "Press Enter once connected..."

    if wait_for_internet 30; then
        return 0
    else
        log_error "Still no internet connection. Installation cannot continue."
        return 1
    fi
}
