#!/bin/sh

# Network Setup Module for Jamstaller
# Returns: 1 if connected, 0 if not connected

# Helper: repeat a character N times
repeat_char() {
    char="$1"
    count="$2"
    [ "$count" -lt 1 ] && return
    _repeat_i=1
    while [ "$_repeat_i" -le "$count" ]; do
        printf '%s' "$char"
        _repeat_i=$((_repeat_i + 1))
    done
}

# Helper: draw a box at given position
draw_box_at() {
    box_row="$1"
    box_col="$2"
    inner_width="$3"
    inner_height="$4"
    fill_inside="${5:-0}"

    # Top border
    printf '\033[%d;%dH┌' "$box_row" "$box_col"
    repeat_char '─' "$inner_width"
    printf '┐'

    # Sides
    _box_i=1
    while [ "$_box_i" -le "$inner_height" ]; do
        printf '\033[%d;%dH│' $((box_row + _box_i)) "$box_col"
        [ "$fill_inside" -eq 1 ] && repeat_char ' ' "$inner_width"
        printf '\033[%d;%dH│' $((box_row + _box_i)) $((box_col + inner_width + 1))
        _box_i=$((_box_i + 1))
    done

    # Bottom border
    printf '\033[%d;%dH└' $((box_row + inner_height + 1)) "$box_col"
    repeat_char '─' "$inner_width"
    printf '┘'
}

# Check network connectivity
check_connectivity() {
    # Try multiple times with longer timeout since DHCP might still be completing
    attempts=3
    i=0
    while [ "$i" -lt "$attempts" ]; do
        if ping -c 1 -W 3 1.1.1.1 >/dev/null 2>&1 || ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
            return 0  # Connected
        fi
        i=$((i + 1))
        [ "$i" -lt "$attempts" ] && sleep 1
    done
    return 1  # Not connected
}

# Get current connection info
get_connection_info() {
    # Try iwctl first (iwd)
    if command -v iwctl >/dev/null 2>&1; then
        # Get device name - strip ANSI codes
        device=$(iwctl device list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk 'NR>4 && NF>0 && $1 ~ /^[a-z]/ {print $1; exit}')
        if [ -n "$device" ]; then
            # Get connected network - strip ANSI codes
            network=$(iwctl station "$device" show 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep "Connected network" | awk '{print $3}')
            if [ -n "$network" ]; then
                echo "$network"
                return 0
            fi
        fi
    fi

    # Fallback to ip/iw
    if command -v iw >/dev/null 2>&1; then
        device=$(iw dev 2>/dev/null | awk '$1=="Interface"{print $2; exit}')
        if [ -n "$device" ]; then
            ssid=$(iw dev "$device" link 2>/dev/null | grep "SSID" | awk '{print $2}')
            if [ -n "$ssid" ]; then
                echo "$ssid"
                return 0
            fi
        fi
    fi

    echo "Unknown"
    return 1
}

# Get WiFi device name
get_wifi_device() {
    if command -v iwctl >/dev/null 2>&1; then
        # Strip ANSI codes and parse device list
        iwctl device list 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | awk 'NR>4 && NF>0 && $1 ~ /^[a-z]/ {print $1; exit}'
    elif command -v iw >/dev/null 2>&1; then
        iw dev 2>/dev/null | awk '$1=="Interface"{print $2; exit}'
    fi
}

# Scan for WiFi networks
scan_wifi() {
    device="$1"

    # Prefer nmcli if NetworkManager is running
    if command -v nmcli >/dev/null 2>&1 && systemctl is-active NetworkManager >/dev/null 2>&1; then
        # Rescan
        nmcli device wifi rescan 2>/dev/null
        sleep 2

        nmcli -t -f SSID,SIGNAL device wifi list 2>/dev/null | \
            awk -F: '{
                if ($1 != "" && $1 != "--") {
                    # Convert signal to bars
                    signal = int($2)
                    if (signal >= 75) bars = "****"
                    else if (signal >= 50) bars = "***"
                    else if (signal >= 25) bars = "**"
                    else bars = "*"
                    print $1 "|" bars
                }
            }'
    elif command -v iwctl >/dev/null 2>&1; then
        # Trigger scan
        iwctl station "$device" scan >/dev/null 2>&1
        sleep 2

        # Get networks - strip ANSI codes first
        iwctl station "$device" get-networks 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | \
            awk 'NR>4 && NF>0 {
                # Network name is first non-empty field
                ssid = $1
                # Skip empty lines and header separators
                if (ssid == "" || ssid ~ /^-+$/) next

                # Get signal strength (last field with asterisks)
                signal = ""
                for(i=1; i<=NF; i++) {
                    if ($i ~ /\*/) {
                        signal = $i
                    }
                }

                if (ssid != "" && signal != "") {
                    print ssid "|" signal
                } else if (ssid != "") {
                    print ssid "|**"
                }
            }'
    else
        return 1
    fi
}

# Connect to WiFi network
connect_wifi() {
    device="$1"
    ssid="$2"
    password="$3"

    # Prefer nmcli if NetworkManager is running - it handles everything
    if command -v nmcli >/dev/null 2>&1 && systemctl is-active NetworkManager >/dev/null 2>&1; then
        if [ -n "$password" ]; then
            nmcli device wifi connect "$ssid" password "$password" >/dev/null 2>&1
        else
            nmcli device wifi connect "$ssid" >/dev/null 2>&1
        fi

        if [ $? -eq 0 ]; then
            # NetworkManager connected, wait for IP with timeout
            max_wait=20
            waited=0
            while [ "$waited" -lt "$max_wait" ]; do
                if ip addr show "$device" 2>/dev/null | grep -q "inet "; then
                    return 0
                fi
                sleep 0.5
                waited=$((waited + 1))
            done
            # Still return success even if IP taking long
            return 0
        else
            return 1
        fi
    elif command -v iwctl >/dev/null 2>&1; then
        # Using iwd directly (typical in Arch ISO)
        if [ -n "$password" ]; then
            iwctl --passphrase="$password" station "$device" connect "$ssid" >/dev/null 2>&1
        else
            iwctl station "$device" connect "$ssid" >/dev/null 2>&1
        fi

        # Poll for connection state with timeout (max 15 seconds)
        max_attempts=30
        attempt=0
        while [ "$attempt" -lt "$max_attempts" ]; do
            state=$(iwctl station "$device" show 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep "State" | awk '{print $2}')

            if [ "$state" = "connected" ]; then
                # Connected! Now wait for IP address (iwd built-in DHCP or manual)
                dhcp_attempts=30
                dhcp_attempt=0
                while [ "$dhcp_attempt" -lt "$dhcp_attempts" ]; do
                    # Check if interface has an IP address
                    if ip addr show "$device" 2>/dev/null | grep -q "inet "; then
                        return 0
                    fi
                    sleep 0.5
                    dhcp_attempt=$((dhcp_attempt + 1))
                done

                # If no IP after waiting, try to trigger DHCP manually if dhcpcd available
                if command -v dhcpcd >/dev/null 2>&1; then
                    dhcpcd "$device" >/dev/null 2>&1 &
                    sleep 3
                    if ip addr show "$device" 2>/dev/null | grep -q "inet "; then
                        return 0
                    fi
                fi

                # Connected to WiFi but no IP - still return success
                # (network config might need to be setup separately)
                return 0
            elif [ "$state" = "disconnected" ]; then
                # Connection failed
                return 1
            fi

            sleep 0.5
            attempt=$((attempt + 1))
        done

        # Timeout
        return 1
    else
        return 1
    fi
}

# Show loading spinner
show_spinner() {
    row="$1"
    col="$2"
    msg="$3"
    pid="$4"

    chars="|/-\\"
    i=0

    while kill -0 "$pid" 2>/dev/null; do
        char=$(echo "$chars" | cut -c$((i+1)))
        printf '\033[%d;%dH\033[2K%s %s' "$row" "$col" "$char" "$msg"
        i=$(((i + 1) % 4))
        sleep 0.1
    done

    # Clear spinner line
    printf '\033[%d;%dH\033[2K' "$row" "$col"
}

# Network Setup TUI
network_setup_tui() {
    # Get terminal dimensions
    if command -v tput >/dev/null 2>&1; then
        term_rows=$(tput lines)
        term_cols=$(tput cols)
    else
        size=$(stty size 2>/dev/null)
        term_rows=${size%% *}
        term_cols=${size##* }
    fi
    : "${term_rows:=24}"
    : "${term_cols:=80}"

    # Calculate box dimensions
    padding=2
    border_width=2
    box_inner_width=60
    box_width=$((box_inner_width + border_width))

    # Variable height based on state
    max_networks=8

    # Center position
    start_col=$(((term_cols - box_width) / 2))
    [ "$start_col" -lt 1 ] && start_col=1

    # Cleanup on exit
    cleanup() {
        printf '\033[?25h\033[?1049l'
        stty echo icanon
        clear
        exit "${1:-0}"
    }

    # Ctrl+C handler
    handle_sigint() {
        cleanup 0
    }

    # Save cursor and enter alt screen
    printf '\033[?1049h\033[H\033[2J\033[?25l'
    stty -echo -icanon

    trap 'handle_sigint' INT
    trap 'cleanup 1' TERM

    # Initial connectivity check
    box_inner_height=8
    box_height=$((box_inner_height + border_width))
    start_row=$(((term_rows - box_height) / 2))
    [ "$start_row" -lt 1 ] && start_row=1

    draw_box_at "$start_row" "$start_col" "$box_inner_width" "$box_inner_height" 0

    # Title
    title="Network Setup"
    title_row=$((start_row + padding + 1))
    title_col=$((start_col + (box_inner_width - ${#title}) / 2 + 1))
    printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

    # Checking message
    msg_row=$((title_row + 2))
    msg="Checking connectivity..."
    msg_col=$((start_col + (box_inner_width - ${#msg}) / 2 + 1))

    # Spinner characters
    spinner_chars="|/-\\"
    spinner_idx=0

    # Check connectivity with spinner
    check_done=0
    is_connected=0
    (sleep 1 && check_connectivity && touch /tmp/net_connected.$$ || rm -f /tmp/net_connected.$$ ; touch /tmp/net_check_done.$$) &
    check_pid=$!

    while [ "$check_done" -eq 0 ]; do
        if [ -f /tmp/net_check_done.$$ ]; then
            check_done=1
            if [ -f /tmp/net_connected.$$ ]; then
                is_connected=1
            fi
            rm -f /tmp/net_check_done.$$ /tmp/net_connected.$$
        else
            char=$(echo "$spinner_chars" | cut -c$((spinner_idx+1)))
            printf '\033[%d;%dH%s %s' "$msg_row" "$msg_col" "$char" "$msg"
            spinner_idx=$(((spinner_idx + 1) % 4))
            sleep 0.1
        fi
    done

    wait "$check_pid" 2>/dev/null

    # Clear screen for next phase
    printf '\033[H\033[2J'

    if [ "$is_connected" -eq 1 ]; then
        # Already connected - show status
        connection_info=$(get_connection_info)

        box_inner_height=10
        box_height=$((box_inner_height + border_width))
        start_row=$(((term_rows - box_height) / 2))
        [ "$start_row" -lt 1 ] && start_row=1

        draw_box_at "$start_row" "$start_col" "$box_inner_width" "$box_inner_height" 0

        # Title
        printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

        # Status
        status_row=$((title_row + 2))
        status_msg="\033[32m[OK]\033[0m Connected to Internet"
        status_len=$((26))  # Length without ANSI codes
        status_col=$((start_col + (box_inner_width - status_len) / 2 + 1))
        printf '\033[%d;%dH%b' "$status_row" "$status_col" "$status_msg"

        # Network info
        info_row=$((status_row + 2))
        info_msg="Network: $connection_info"
        info_col=$((start_col + (box_inner_width - ${#info_msg}) / 2 + 1))
        printf '\033[%d;%dH%s' "$info_row" "$info_col" "$info_msg"

        # Done button
        button_row=$((info_row + 3))
        button_text="Done"
        button_col=$((start_col + (box_inner_width - ${#button_text}) / 2 + 1))
        printf '\033[%d;%dH\033[7m%s\033[0m' "$button_row" "$button_col" "$button_text"

        # Wait for Enter
        while true; do
            char=$(dd bs=1 count=1 2>/dev/null)
            if [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                cleanup 1
                return 1
            fi
        done
    else
        # Need to setup WiFi
        wifi_device=$(get_wifi_device)

        if [ -z "$wifi_device" ]; then
            # No WiFi device found
            box_inner_height=10
            box_height=$((box_inner_height + border_width))
            start_row=$(((term_rows - box_height) / 2))

            draw_box_at "$start_row" "$start_col" "$box_inner_width" "$box_inner_height" 0
            printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

            error_row=$((title_row + 2))
            error_msg="\033[31m[X]\033[0m No WiFi device found"
            error_len=24
            error_col=$((start_col + (box_inner_width - error_len) / 2 + 1))
            printf '\033[%d;%dH%b' "$error_row" "$error_col" "$error_msg"

            button_row=$((error_row + 3))
            button_text="Exit"
            button_col=$((start_col + (box_inner_width - ${#button_text}) / 2 + 1))
            printf '\033[%d;%dH\033[7m%s\033[0m' "$button_row" "$button_col" "$button_text"

            while true; do
                char=$(dd bs=1 count=1 2>/dev/null)
                if [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                    cleanup 0
                    return 0
                fi
            done
        fi

        # Scan for networks
        box_inner_height=10
        box_height=$((box_inner_height + border_width))
        start_row=$(((term_rows - box_height) / 2))

        draw_box_at "$start_row" "$start_col" "$box_inner_width" "$box_inner_height" 0
        printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

        scan_row=$((title_row + 2))
        scan_msg="Scanning for networks..."
        scan_col=$((start_col + (box_inner_width - ${#scan_msg}) / 2 + 1))

        # Scan with spinner
        spinner_idx=0
        scan_done=0
        (scan_wifi "$wifi_device" > /tmp/wifi_scan.$$ ; touch /tmp/scan_done.$$) &
        scan_pid=$!

        while [ "$scan_done" -eq 0 ]; do
            if [ -f /tmp/scan_done.$$ ]; then
                scan_done=1
                rm -f /tmp/scan_done.$$
            else
                char=$(echo "$spinner_chars" | cut -c$((spinner_idx+1)))
                printf '\033[%d;%dH%s %s' "$scan_row" "$scan_col" "$char" "$scan_msg"
                spinner_idx=$(((spinner_idx + 1) % 4))
                sleep 0.1
            fi
        done

        wait "$scan_pid" 2>/dev/null

        # Read scan results
        if [ ! -f /tmp/wifi_scan.$$ ] || [ ! -s /tmp/wifi_scan.$$ ]; then
            # No networks found
            printf '\033[H\033[2J'

            box_inner_height=10
            box_height=$((box_inner_height + border_width))
            start_row=$(((term_rows - box_height) / 2))

            draw_box_at "$start_row" "$start_col" "$box_inner_width" "$box_inner_height" 0
            printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

            error_row=$((title_row + 2))
            error_msg="No networks found"
            error_col=$((start_col + (box_inner_width - ${#error_msg}) / 2 + 1))
            printf '\033[%d;%dH%s' "$error_row" "$error_col" "$error_msg"

            button_row=$((error_row + 3))
            button_text="Exit"
            button_col=$((start_col + (box_inner_width - ${#button_text}) / 2 + 1))
            printf '\033[%d;%dH\033[7m%s\033[0m' "$button_row" "$button_col" "$button_text"

            while true; do
                char=$(dd bs=1 count=1 2>/dev/null)
                if [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                    rm -f /tmp/wifi_scan.$$
                    cleanup 0
                    return 0
                fi
            done
        fi

        # Parse networks
        network_count=0
        while IFS='|' read -r ssid signal; do
            network_count=$((network_count + 1))
            eval "network_${network_count}_ssid=\"\$ssid\""
            eval "network_${network_count}_signal=\"\$signal\""
        done < /tmp/wifi_scan.$$
        rm -f /tmp/wifi_scan.$$

        [ "$network_count" -eq 0 ] && {
            cleanup 0
            return 0
        }

        # Display network list
        display_count=$network_count
        [ "$display_count" -gt "$max_networks" ] && display_count=$max_networks

        # Calculate box height: padding + title + subtitle + spacer + networks + spacer + button + padding
        box_inner_height=$((padding * 2 + 1 + 1 + 1 + display_count + 2 + 1))
        box_height=$((box_inner_height + border_width))
        start_row=$(((term_rows - box_height) / 2))
        [ "$start_row" -lt 1 ] && start_row=1

        printf '\033[H\033[2J'
        draw_box_at "$start_row" "$start_col" "$box_inner_width" "$box_inner_height" 0

        # Recalculate title row based on new start_row
        title_row=$((start_row + padding + 1))
        title_col=$((start_col + (box_inner_width - ${#title}) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

        subtitle_row=$((title_row + 1))
        subtitle="Select a network:"
        subtitle_col=$((start_col + padding + 2))
        printf '\033[%d;%dH%s' "$subtitle_row" "$subtitle_col" "$subtitle"

        # Draw networks function
        draw_networks() {
            selected_idx="$1"
            scroll_offset="$2"

            list_start_row=$((subtitle_row + 2))
            i=1
            display_idx=0

            while [ "$i" -le "$network_count" ] && [ "$display_idx" -lt "$display_count" ]; do
                if [ "$i" -gt "$scroll_offset" ]; then
                    eval "ssid=\$network_${i}_ssid"
                    eval "signal=\$network_${i}_signal"

                    row=$((list_start_row + display_idx))
                    col=$((start_col + padding + 2))

                    # Truncate SSID if too long
                    max_ssid_len=$((box_inner_width - 20))
                    if [ "${#ssid}" -gt "$max_ssid_len" ]; then
                        ssid=$(echo "$ssid" | cut -c1-$((max_ssid_len - 3)))
                        ssid="${ssid}..."
                    fi

                    printf '\033[%d;%dH' "$row" "$col"

                    if [ "$i" -eq "$selected_idx" ]; then
                        printf '\033[7m> %-40s %s\033[0m' "$ssid" "$signal"
                    else
                        printf '  %-40s %s' "$ssid" "$signal"
                    fi

                    display_idx=$((display_idx + 1))
                fi
                i=$((i + 1))
            done
        }

        # Draw buttons
        draw_network_buttons() {
            cancel_selected="$1"

            button_row=$((start_row + box_inner_height - padding))
            button_col=$((start_col + (box_inner_width - 6) / 2 + 1))

            printf '\033[%d;%dH' "$button_row" "$button_col"
            if [ "$cancel_selected" -eq 1 ]; then
                printf '\033[7mCancel\033[0m'
            else
                printf 'Cancel'
            fi
        }

        # Network selection loop
        selected_network=1
        scroll_offset=0
        selected_item=0  # 0 = network, 1 = cancel button

        draw_networks "$selected_network" "$scroll_offset"
        draw_network_buttons 0

        while true; do
            char=$(dd bs=1 count=1 2>/dev/null)

            if [ "$char" = "$(printf '\033')" ]; then
                dd bs=1 count=1 2>/dev/null | read -r _ 2>/dev/null
                char=$(dd bs=1 count=1 2>/dev/null)

                case "$char" in
                    A) # Up
                        if [ "$selected_item" -eq 0 ]; then
                            if [ "$selected_network" -gt 1 ]; then
                                selected_network=$((selected_network - 1))

                                # Adjust scroll if needed
                                if [ "$selected_network" -le "$scroll_offset" ]; then
                                    scroll_offset=$((selected_network - 1))
                                    [ "$scroll_offset" -lt 0 ] && scroll_offset=0
                                fi

                                draw_networks "$selected_network" "$scroll_offset"
                            fi
                        else
                            # Move from cancel to last visible network
                            selected_item=0
                            draw_networks "$selected_network" "$scroll_offset"
                            draw_network_buttons 0
                        fi
                        ;;
                    B) # Down
                        if [ "$selected_item" -eq 0 ]; then
                            if [ "$selected_network" -lt "$network_count" ]; then
                                selected_network=$((selected_network + 1))

                                # Adjust scroll if needed
                                max_visible=$((scroll_offset + display_count))
                                if [ "$selected_network" -gt "$max_visible" ]; then
                                    scroll_offset=$((scroll_offset + 1))
                                fi

                                draw_networks "$selected_network" "$scroll_offset"
                            else
                                # Move to cancel button
                                selected_item=1
                                draw_networks "$selected_network" "$scroll_offset"
                                draw_network_buttons 1
                            fi
                        fi
                        ;;
                esac
            elif [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                if [ "$selected_item" -eq 1 ]; then
                    # Cancel
                    cleanup 0
                    return 0
                else
                    # Connect to selected network
                    eval "selected_ssid=\$network_${selected_network}_ssid"

                    # Password dialog
                    dialog_width=50
                    dialog_height=10
                    dialog_row=$(((term_rows - dialog_height) / 2))
                    dialog_col=$(((term_cols - dialog_width) / 2))

                    printf '\033[H\033[2J'
                    draw_box_at "$dialog_row" "$dialog_col" "$dialog_width" "$dialog_height" 0

                    pass_title="Enter Password"
                    pass_title_row=$((dialog_row + 2))
                    pass_title_col=$((dialog_col + (dialog_width - ${#pass_title}) / 2 + 1))
                    printf '\033[%d;%dH\033[1m%s\033[0m' "$pass_title_row" "$pass_title_col" "$pass_title"

                    ssid_row=$((pass_title_row + 1))
                    ssid_display="Network: $selected_ssid"
                    # Truncate if needed
                    max_len=$((dialog_width - 4))
                    if [ "${#ssid_display}" -gt "$max_len" ]; then
                        ssid_display=$(echo "$ssid_display" | cut -c1-$((max_len - 3)))
                        ssid_display="${ssid_display}..."
                    fi
                    ssid_col=$((dialog_col + (dialog_width - ${#ssid_display}) / 2 + 1))
                    printf '\033[%d;%dH%s' "$ssid_row" "$ssid_col" "$ssid_display"

                    input_row=$((ssid_row + 2))
                    input_col=$((dialog_col + 5))
                    printf '\033[%d;%dHPassword: ' "$input_row" "$input_col"

                    # Read password with backspace support
                    password_col=$((input_col + 10))
                    printf '\033[%d;%dH' "$input_row" "$password_col"

                    # Show cursor and enable echo for password input
                    printf '\033[?25h'
                    stty echo icanon

                    # Read password
                    wifi_password=""
                    read -r wifi_password

                    # Hide cursor and disable echo
                    printf '\033[?25l'
                    stty -echo -icanon

                    # Connecting message
                    printf '\033[H\033[2J'
                    draw_box_at "$dialog_row" "$dialog_col" "$dialog_width" "$dialog_height" 0
                    printf '\033[%d;%dH\033[1m%s\033[0m' "$pass_title_row" "$pass_title_col" "$pass_title"

                    connect_row=$((pass_title_row + 2))
                    connect_msg="Connecting..."
                    connect_col=$((dialog_col + (dialog_width - ${#connect_msg}) / 2 + 1))

                    # Connect with spinner
                    spinner_idx=0
                    connect_done=0
                    (connect_wifi "$wifi_device" "$selected_ssid" "$wifi_password" && touch /tmp/wifi_success.$$ || rm -f /tmp/wifi_success.$$ ; touch /tmp/wifi_done.$$) &
                    connect_pid=$!

                    while [ "$connect_done" -eq 0 ]; do
                        if [ -f /tmp/wifi_done.$$ ]; then
                            connect_done=1
                        else
                            char=$(echo "$spinner_chars" | cut -c$((spinner_idx+1)))
                            printf '\033[%d;%dH%s %s' "$connect_row" "$connect_col" "$char" "$connect_msg"
                            spinner_idx=$(((spinner_idx + 1) % 4))
                            sleep 0.1
                        fi
                    done

                    wait "$connect_pid" 2>/dev/null

                    # Check result
                    if [ -f /tmp/wifi_success.$$ ]; then
                        rm -f /tmp/wifi_success.$$ /tmp/wifi_done.$$

                        # Verify connectivity (connect_wifi already waited for connection and DHCP)
                        if check_connectivity; then
                            # Success!
                            printf '\033[%d;%dH\033[2K' "$connect_row" "$connect_col"
                            success_msg="\033[32m[OK]\033[0m Connected successfully!"
                            success_len=29
                            success_col=$((dialog_col + (dialog_width - success_len) / 2 + 1))
                            printf '\033[%d;%dH%b' "$connect_row" "$success_col" "$success_msg"

                            button_row=$((connect_row + 2))
                            button_text="Continue"
                            button_col=$((dialog_col + (dialog_width - ${#button_text}) / 2 + 1))
                            printf '\033[%d;%dH\033[7m%s\033[0m' "$button_row" "$button_col" "$button_text"

                            while true; do
                                char=$(dd bs=1 count=1 2>/dev/null)
                                if [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                                    cleanup 1
                                    return 1
                                fi
                            done
                        else
                            # Connected but no internet
                            printf '\033[%d;%dH\033[2K' "$connect_row" "$connect_col"
                            warn_msg="\033[33m!\033[0m Connected but no internet"
                            warn_len=28
                            warn_col=$((dialog_col + (dialog_width - warn_len) / 2 + 1))
                            printf '\033[%d;%dH%b' "$connect_row" "$warn_col" "$warn_msg"

                            button_row=$((connect_row + 2))
                            button_text="Exit"
                            button_col=$((dialog_col + (dialog_width - ${#button_text}) / 2 + 1))
                            printf '\033[%d;%dH\033[7m%s\033[0m' "$button_row" "$button_col" "$button_text"

                            while true; do
                                char=$(dd bs=1 count=1 2>/dev/null)
                                if [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                                    cleanup 0
                                    return 0
                                fi
                            done
                        fi
                    else
                        rm -f /tmp/wifi_done.$$

                        # Connection failed
                        printf '\033[%d;%dH\033[2K' "$connect_row" "$connect_col"
                        error_msg="\033[31m[X]\033[0m Connection failed"
                        error_len=21
                        error_col=$((dialog_col + (dialog_width - error_len) / 2 + 1))
                        printf '\033[%d;%dH%b' "$connect_row" "$error_col" "$error_msg"

                        retry_row=$((connect_row + 1))
                        retry_msg="Check password and try again"
                        retry_col=$((dialog_col + (dialog_width - ${#retry_msg}) / 2 + 1))
                        printf '\033[%d;%dH%s' "$retry_row" "$retry_col" "$retry_msg"

                        button_row=$((retry_row + 2))
                        button_text="Back"
                        button_col=$((dialog_col + (dialog_width - ${#button_text}) / 2 + 1))
                        printf '\033[%d;%dH\033[7m%s\033[0m' "$button_row" "$button_col" "$button_text"

                        while true; do
                            char=$(dd bs=1 count=1 2>/dev/null)
                            if [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                                # Return to network list
                                printf '\033[H\033[2J'
                                draw_box_at "$start_row" "$start_col" "$box_inner_width" "$box_inner_height" 0
                                printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"
                                printf '\033[%d;%dH%s' "$subtitle_row" "$subtitle_col" "$subtitle"
                                draw_networks "$selected_network" "$scroll_offset"
                                draw_network_buttons 0
                                break
                            fi
                        done
                    fi
                fi
            fi
        done
    fi
}

# Run network setup
network_setup_tui
exit $?
