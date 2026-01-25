#!/bin/sh

# Install Location Module for Jamstaller
# Returns: 1 if location selected, 0 if cancelled

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

# Get list of block devices
get_block_devices() {
    # Get major block devices (not partitions, not loops)
    lsblk -ndo NAME,SIZE,TYPE,MODEL 2>/dev/null | \
        awk '$3 == "disk" {
            name = $1
            size = $2
            model = ""
            for(i=4; i<=NF; i++) model = model $i " "
            sub(/ $/, "", model)
            if (model == "") model = "Unknown"
            print name "|" size "|" model
        }'
}

# Get partitions for a device
get_partitions() {
    device="$1"

    # Get partition info: name, size, filesystem, label
    lsblk -nlo NAME,SIZE,FSTYPE,LABEL "/dev/$device" 2>/dev/null | \
        awk -v dev="$device" '
        $1 != dev {
            name = $1
            size = $2
            fstype = $3
            label = ""
            for(i=4; i<=NF; i++) label = label $i " "
            sub(/ $/, "", label)
            if (fstype == "") fstype = "unknown"
            if (label == "") label = "-"
            print name "|" size "|" fstype "|" label
        }'
}

# Get partition info in bytes for visualization
get_partition_bytes() {
    device="$1"

    # Get size in bytes
    lsblk -nblo NAME,SIZE "/dev/$device" 2>/dev/null | \
        awk -v dev="$device" '
        $1 != dev {
            print $1 "|" $2
        }'
}

# Cleanup on exit
cleanup() {
    printf '\033[?25h\033[?1049l'
    stty echo icanon
}

# Ctrl+C handler
handle_sigint() {
    cleanup 0
}

# Main TUI
install_location_tui() {
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

    # Setup
    padding=2
    border_width=2
    box_inner_width=70
    box_width=$((box_inner_width + border_width))

    start_col=$(((term_cols - box_width) / 2))
    [ "$start_col" -lt 1 ] && start_col=1

    # Save cursor and enter alt screen
    printf '\033[?1049h\033[H\033[2J\033[?25l'
    stty -echo -icanon

    trap 'handle_sigint' INT
    trap 'cleanup 1' TERM

    # === SCREEN 1: Device Selection ===
    device_selection_screen() {
        # Scan for devices
        device_count=0
        while IFS='|' read -r name size model; do
            device_count=$((device_count + 1))
            eval "device_${device_count}_name=\"\$name\""
            eval "device_${device_count}_size=\"\$size\""
            eval "device_${device_count}_model=\"\$model\""
        done <<EOF
$(get_block_devices)
EOF

        if [ "$device_count" -eq 0 ]; then
            # No devices found
            box_inner_height=10
            box_height=$((box_inner_height + border_width))
            start_row=$(((term_rows - box_height) / 2))

            printf '\033[H\033[2J'
            draw_box_at "$start_row" "$start_col" "$box_inner_width" "$box_inner_height" 0

            title="Install Location"
            title_row=$((start_row + padding + 1))
            title_col=$((start_col + (box_inner_width - ${#title}) / 2 + 1))
            printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

            error_row=$((title_row + 2))
            error_msg="\033[31m[X]\033[0m No storage devices found"
            error_len=30
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

        # Calculate box height
        max_devices=6
        display_count=$device_count
        [ "$display_count" -gt "$max_devices" ] && display_count=$max_devices

        box_inner_height=$((padding * 2 + 1 + 1 + 1 + display_count + 2 + 1))
        box_height=$((box_inner_height + border_width))
        start_row=$(((term_rows - box_height) / 2))
        [ "$start_row" -lt 1 ] && start_row=1

        printf '\033[H\033[2J'
        draw_box_at "$start_row" "$start_col" "$box_inner_width" "$box_inner_height" 0

        title="Install Location"
        title_row=$((start_row + padding + 1))
        title_col=$((start_col + (box_inner_width - ${#title}) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

        subtitle_row=$((title_row + 1))
        subtitle="Select installation device:"
        subtitle_col=$((start_col + padding + 2))
        printf '\033[%d;%dH%s' "$subtitle_row" "$subtitle_col" "$subtitle"

        # Draw device list
        draw_devices() {
            selected_idx="$1"
            scroll_offset="$2"

            list_start_row=$((subtitle_row + 2))
            i=1
            display_idx=0

            while [ "$i" -le "$device_count" ] && [ "$display_idx" -lt "$display_count" ]; do
                if [ "$i" -gt "$scroll_offset" ]; then
                    eval "name=\$device_${i}_name"
                    eval "size=\$device_${i}_size"
                    eval "model=\$device_${i}_model"

                    row=$((list_start_row + display_idx))
                    col=$((start_col + padding + 2))

                    # Format: /dev/sda (500GB) - Model Name
                    device_text="/dev/$name ($size) - $model"

                    # Truncate if too long
                    max_len=$((box_inner_width - 8))
                    if [ "${#device_text}" -gt "$max_len" ]; then
                        device_text=$(echo "$device_text" | cut -c1-$((max_len - 3)))
                        device_text="${device_text}..."
                    fi

                    printf '\033[%d;%dH' "$row" "$col"

                    if [ "$i" -eq "$selected_idx" ]; then
                        printf '\033[7m> %-64s\033[0m' "$device_text"
                    else
                        printf '  %-64s' "$device_text"
                    fi

                    display_idx=$((display_idx + 1))
                fi
                i=$((i + 1))
            done
        }

        # Draw buttons
        draw_device_buttons() {
            cancel_selected="$1"

            button_row=$((start_row + box_inner_height - padding))

            cancel_text="Cancel"
            button_col=$((start_col + (box_inner_width - ${#cancel_text}) / 2 + 1))

            printf '\033[%d;%dH' "$button_row" "$button_col"

            if [ "$cancel_selected" -eq 1 ]; then
                printf '\033[7m%s\033[0m' "$cancel_text"
            else
                printf '%s' "$cancel_text"
            fi
        }

        # Device selection loop
        selected_device=1
        scroll_offset=0
        selected_item=0  # 0 = device, 1 = cancel

        draw_devices "$selected_device" "$scroll_offset"
        draw_device_buttons 0

        while true; do
            char=$(dd bs=1 count=1 2>/dev/null)

            if [ "$char" = "$(printf '\033')" ]; then
                dd bs=1 count=1 2>/dev/null | read -r _ 2>/dev/null
                char=$(dd bs=1 count=1 2>/dev/null)

                case "$char" in
                    A) # Up
                        if [ "$selected_item" -eq 0 ]; then
                            if [ "$selected_device" -gt 1 ]; then
                                selected_device=$((selected_device - 1))
                                if [ "$selected_device" -le "$scroll_offset" ]; then
                                    scroll_offset=$((selected_device - 1))
                                    [ "$scroll_offset" -lt 0 ] && scroll_offset=0
                                fi
                                draw_devices "$selected_device" "$scroll_offset"
                            fi
                        elif [ "$selected_item" -eq 1 ]; then
                            selected_item=0
                            draw_devices "$selected_device" "$scroll_offset"
                            draw_device_buttons 0
                        fi
                        ;;
                    B) # Down
                        if [ "$selected_item" -eq 0 ]; then
                            if [ "$selected_device" -lt "$device_count" ]; then
                                selected_device=$((selected_device + 1))
                                max_visible=$((scroll_offset + display_count))
                                if [ "$selected_device" -gt "$max_visible" ]; then
                                    scroll_offset=$((scroll_offset + 1))
                                fi
                                draw_devices "$selected_device" "$scroll_offset"
                            else
                                selected_item=1
                                draw_devices "$selected_device" "$scroll_offset"
                                draw_device_buttons 1
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
                    # Enter on device - go to mode selection
                    eval "chosen_device=\$device_${selected_device}_name"
                    mode_selection_screen "$chosen_device"
                    return $?
                fi
            fi
        done
    }

    # === SCREEN 2: Installation Mode Selection ===
    mode_selection_screen() {
        device="$1"

        box_inner_height=14
        box_height=$((box_inner_height + border_width))
        start_row=$(((term_rows - box_height) / 2))
        [ "$start_row" -lt 1 ] && start_row=1

        printf '\033[H\033[2J'
        draw_box_at "$start_row" "$start_col" "$box_inner_width" "$box_inner_height" 0

        title="Install Location"
        title_row=$((start_row + padding + 1))
        title_col=$((start_col + (box_inner_width - ${#title}) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

        device_row=$((title_row + 1))
        device_text="Device: /dev/$device"
        device_col=$((start_col + padding + 2))
        printf '\033[%d;%dH\033[2m%s\033[0m' "$device_row" "$device_col" "$device_text"

        subtitle_row=$((device_row + 2))
        subtitle="Select installation mode:"
        subtitle_col=$((start_col + padding + 2))
        printf '\033[%d;%dH%s' "$subtitle_row" "$subtitle_col" "$subtitle"

        # Mode options
        mode1_row=$((subtitle_row + 2))
        mode1_text="Erase disk and install"
        mode1_desc="(Entire disk will be wiped)"

        mode2_row=$((mode1_row + 2))
        mode2_text="Install alongside existing OS"
        mode2_desc="(Select partition to install on)"

        # Draw mode options
        draw_modes() {
            selected="$1"

            col=$((start_col + padding + 2))

            # Mode 1
            printf '\033[%d;%dH' "$mode1_row" "$col"
            if [ "$selected" -eq 1 ]; then
                printf '\033[7m> %s\033[0m' "$mode1_text"
                printf '\033[%d;%dH\033[7m  %s\033[0m' $((mode1_row + 1)) "$col" "$mode1_desc"
            else
                printf '  %s' "$mode1_text"
                printf '\033[%d;%dH  \033[2m%s\033[0m' $((mode1_row + 1)) "$col" "$mode1_desc"
            fi

            # Mode 2
            printf '\033[%d;%dH' "$mode2_row" "$col"
            if [ "$selected" -eq 2 ]; then
                printf '\033[7m> %s\033[0m' "$mode2_text"
                printf '\033[%d;%dH\033[7m  %s\033[0m' $((mode2_row + 1)) "$col" "$mode2_desc"
            else
                printf '  %s' "$mode2_text"
                printf '\033[%d;%dH  \033[2m%s\033[0m' $((mode2_row + 1)) "$col" "$mode2_desc"
            fi
        }

        # Draw buttons
        draw_mode_buttons() {
            back_selected="$1"

            button_row=$((start_row + box_inner_height - padding))

            back_text="Back"
            button_col=$((start_col + (box_inner_width - ${#back_text}) / 2 + 1))

            printf '\033[%d;%dH' "$button_row" "$button_col"

            if [ "$back_selected" -eq 1 ]; then
                printf '\033[7m%s\033[0m' "$back_text"
            else
                printf '%s' "$back_text"
            fi
        }

        # Mode selection loop
        selected_mode=1
        selected_item=0  # 0 = mode, 1 = back

        draw_modes "$selected_mode"
        draw_mode_buttons 0

        while true; do
            char=$(dd bs=1 count=1 2>/dev/null)

            if [ "$char" = "$(printf '\033')" ]; then
                dd bs=1 count=1 2>/dev/null | read -r _ 2>/dev/null
                char=$(dd bs=1 count=1 2>/dev/null)

                case "$char" in
                    A) # Up
                        if [ "$selected_item" -eq 0 ]; then
                            if [ "$selected_mode" -gt 1 ]; then
                                selected_mode=$((selected_mode - 1))
                                draw_modes "$selected_mode"
                            fi
                        elif [ "$selected_item" -eq 1 ]; then
                            selected_item=0
                            draw_modes "$selected_mode"
                            draw_mode_buttons 0
                        fi
                        ;;
                    B) # Down
                        if [ "$selected_item" -eq 0 ]; then
                            if [ "$selected_mode" -lt 2 ]; then
                                selected_mode=$((selected_mode + 1))
                                draw_modes "$selected_mode"
                            else
                                selected_item=1
                                draw_modes "$selected_mode"
                                draw_mode_buttons 1
                            fi
                        fi
                        ;;
                esac
            elif [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                if [ "$selected_item" -eq 1 ]; then
                    # Back
                    device_selection_screen
                    return $?
                else
                    # Enter on mode
                    if [ "$selected_mode" -eq 1 ]; then
                        # Full disk - go to confirmation
                        confirmation_screen "$device" "full" ""
                        return $?
                    else
                        # Partition mode - go to partition selection
                        partition_selection_screen "$device"
                        return $?
                    fi
                fi
            fi
        done
    }

    # === SCREEN 3: Partition Selection ===
    partition_selection_screen() {
        device="$1"

        # Get partitions
        partition_count=0
        total_device_bytes=0

        # Get device size
        total_device_bytes=$(lsblk -nbdo SIZE "/dev/$device" 2>/dev/null)

        # Get partitions with sizes
        while IFS='|' read -r name size fstype label; do
            partition_count=$((partition_count + 1))
            eval "partition_${partition_count}_name=\"\$name\""
            eval "partition_${partition_count}_size=\"\$size\""
            eval "partition_${partition_count}_fstype=\"\$fstype\""
            eval "partition_${partition_count}_label=\"\$label\""
        done <<EOF
$(get_partitions "$device")
EOF

        # Get byte sizes for visualization
        part_idx=1
        while IFS='|' read -r name bytes; do
            eval "partition_${part_idx}_bytes=\"\$bytes\""
            part_idx=$((part_idx + 1))
        done <<EOF
$(get_partition_bytes "$device")
EOF

        if [ "$partition_count" -eq 0 ]; then
            # No partitions - can't install alongside
            box_inner_height=12
            box_height=$((box_inner_height + border_width))
            start_row=$(((term_rows - box_height) / 2))

            printf '\033[H\033[2J'
            draw_box_at "$start_row" "$start_col" "$box_inner_width" "$box_inner_height" 0

            title="Install Location"
            title_row=$((start_row + padding + 1))
            title_col=$((start_col + (box_inner_width - ${#title}) / 2 + 1))
            printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

            error_row=$((title_row + 2))
            error_msg="\033[31m[X]\033[0m No partitions found"
            error_len=24
            error_col=$((start_col + (box_inner_width - error_len) / 2 + 1))
            printf '\033[%d;%dH%b' "$error_row" "$error_col" "$error_msg"

            info_row=$((error_row + 2))
            info_msg="Cannot install alongside on unpartitioned disk."
            info_col=$((start_col + (box_inner_width - ${#info_msg}) / 2 + 1))
            printf '\033[%d;%dH%s' "$info_row" "$info_col" "$info_msg"

            button_row=$((info_row + 3))
            button_text="Back"
            button_col=$((start_col + (box_inner_width - ${#button_text}) / 2 + 1))
            printf '\033[%d;%dH\033[7m%s\033[0m' "$button_row" "$button_col" "$button_text"

            while true; do
                char=$(dd bs=1 count=1 2>/dev/null)
                if [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                    mode_selection_screen "$device"
                    return $?
                fi
            done
        fi

        # Calculate box height for partition view
        max_partitions=5
        display_count=$partition_count
        [ "$display_count" -gt "$max_partitions" ] && display_count=$max_partitions

        # Height: title + device + visual bar + partition list + buttons
        box_inner_height=$((padding * 2 + 1 + 1 + 2 + 1 + 1 + display_count + 2 + 1))
        box_height=$((box_inner_height + border_width))
        start_row=$(((term_rows - box_height) / 2))
        [ "$start_row" -lt 1 ] && start_row=1

        printf '\033[H\033[2J'
        draw_box_at "$start_row" "$start_col" "$box_inner_width" "$box_inner_height" 0

        title="Install Location"
        title_row=$((start_row + padding + 1))
        title_col=$((start_col + (box_inner_width - ${#title}) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

        device_row=$((title_row + 1))
        device_text="Device: /dev/$device"
        device_col=$((start_col + padding + 2))
        printf '\033[%d;%dH\033[2m%s\033[0m' "$device_row" "$device_col" "$device_text"

        # Visual partition bar
        bar_row=$((device_row + 2))
        bar_col=$((start_col + padding + 2))
        bar_width=$((box_inner_width - padding * 2 - 2))

        # Draw visual partition bar
        draw_partition_bar() {
            selected_part="$1"

            printf '\033[%d;%dH│' "$bar_row" "$bar_col"

            # Calculate widths
            rendered=0
            i=1
            while [ "$i" -le "$partition_count" ]; do
                eval "bytes=\$partition_${i}_bytes"

                # Calculate width proportionally
                if [ "$total_device_bytes" -gt 0 ]; then
                    # Use awk for floating point math
                    width=$(awk "BEGIN {printf \"%.0f\", ($bytes / $total_device_bytes) * ($bar_width - $partition_count - 1)}")
                    [ "$width" -lt 1 ] && width=1
                else
                    width=1
                fi

                # Color and pattern based on selection - green with different pattern
                if [ "$i" -eq "$selected_part" ]; then
                    printf '\033[32m'
                    repeat_char '▓' "$width"
                    printf '\033[0m'
                else
                    repeat_char '█' "$width"
                fi

                # Separator
                if [ "$i" -lt "$partition_count" ]; then
                    printf '│'
                fi

                i=$((i + 1))
            done

            printf '│'
        }

        subtitle_row=$((bar_row + 2))
        subtitle="Select partition to install on:"
        subtitle_col=$((start_col + padding + 2))
        printf '\033[%d;%dH%s' "$subtitle_row" "$subtitle_col" "$subtitle"

        # Draw partition list
        draw_partitions() {
            selected_idx="$1"
            scroll_offset="$2"

            list_start_row=$((subtitle_row + 1))
            i=1
            display_idx=0

            while [ "$i" -le "$partition_count" ] && [ "$display_idx" -lt "$display_count" ]; do
                if [ "$i" -gt "$scroll_offset" ]; then
                    eval "name=\$partition_${i}_name"
                    eval "size=\$partition_${i}_size"
                    eval "fstype=\$partition_${i}_fstype"
                    eval "label=\$partition_${i}_label"

                    row=$((list_start_row + display_idx))
                    col=$((start_col + padding + 2))

                    # Format: /dev/sda1 (50GB) ext4 [Ubuntu]
                    part_text="/dev/$name ($size) $fstype"
                    if [ "$label" != "-" ]; then
                        part_text="$part_text [$label]"
                    fi

                    # Truncate if too long
                    max_len=$((box_inner_width - 8))
                    if [ "${#part_text}" -gt "$max_len" ]; then
                        part_text=$(echo "$part_text" | cut -c1-$((max_len - 3)))
                        part_text="${part_text}..."
                    fi

                    printf '\033[%d;%dH' "$row" "$col"

                    if [ "$i" -eq "$selected_idx" ]; then
                        printf '\033[7m> %-64s\033[0m' "$part_text"
                    else
                        printf '  %-64s' "$part_text"
                    fi

                    display_idx=$((display_idx + 1))
                fi
                i=$((i + 1))
            done
        }

        # Draw buttons
        draw_partition_buttons() {
            back_selected="$1"

            button_row=$((start_row + box_inner_height - padding))

            back_text="Back"
            button_col=$((start_col + (box_inner_width - ${#back_text}) / 2 + 1))

            printf '\033[%d;%dH' "$button_row" "$button_col"

            if [ "$back_selected" -eq 1 ]; then
                printf '\033[7m%s\033[0m' "$back_text"
            else
                printf '%s' "$back_text"
            fi
        }

        # Partition selection loop
        selected_partition=1
        scroll_offset=0
        selected_item=0  # 0 = partition, 1 = back

        draw_partition_bar "$selected_partition"
        draw_partitions "$selected_partition" "$scroll_offset"
        draw_partition_buttons 0

        while true; do
            char=$(dd bs=1 count=1 2>/dev/null)

            if [ "$char" = "$(printf '\033')" ]; then
                dd bs=1 count=1 2>/dev/null | read -r _ 2>/dev/null
                char=$(dd bs=1 count=1 2>/dev/null)

                case "$char" in
                    A) # Up
                        if [ "$selected_item" -eq 0 ]; then
                            if [ "$selected_partition" -gt 1 ]; then
                                selected_partition=$((selected_partition - 1))
                                if [ "$selected_partition" -le "$scroll_offset" ]; then
                                    scroll_offset=$((selected_partition - 1))
                                    [ "$scroll_offset" -lt 0 ] && scroll_offset=0
                                fi
                                draw_partition_bar "$selected_partition"
                                draw_partitions "$selected_partition" "$scroll_offset"
                            fi
                        elif [ "$selected_item" -eq 1 ]; then
                            selected_item=0
                            draw_partitions "$selected_partition" "$scroll_offset"
                            draw_partition_buttons 0
                        fi
                        ;;
                    B) # Down
                        if [ "$selected_item" -eq 0 ]; then
                            if [ "$selected_partition" -lt "$partition_count" ]; then
                                selected_partition=$((selected_partition + 1))
                                max_visible=$((scroll_offset + display_count))
                                if [ "$selected_partition" -gt "$max_visible" ]; then
                                    scroll_offset=$((scroll_offset + 1))
                                fi
                                draw_partition_bar "$selected_partition"
                                draw_partitions "$selected_partition" "$scroll_offset"
                            else
                                selected_item=1
                                draw_partitions "$selected_partition" "$scroll_offset"
                                draw_partition_buttons 1
                            fi
                        fi
                        ;;
                esac
            elif [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                if [ "$selected_item" -eq 1 ]; then
                    # Back
                    mode_selection_screen "$device"
                    return $?
                else
                    # Enter on partition - go to confirmation
                    eval "chosen_partition=\$partition_${selected_partition}_name"
                    confirmation_screen "$device" "partition" "$chosen_partition"
                    return $?
                fi
            fi
        done
    }

    # === SCREEN 4: Confirmation ===
    confirmation_screen() {
        device="$1"
        mode="$2"
        partition="$3"

        box_inner_height=16
        box_height=$((box_inner_height + border_width))
        start_row=$(((term_rows - box_height) / 2))
        [ "$start_row" -lt 1 ] && start_row=1

        printf '\033[H\033[2J'
        draw_box_at "$start_row" "$start_col" "$box_inner_width" "$box_inner_height" 0

        title="Installation Summary"
        title_row=$((start_row + padding + 1))
        title_col=$((start_col + (box_inner_width - ${#title}) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

        summary_row=$((title_row + 2))
        col=$((start_col + padding + 2))

        printf '\033[%d;%dH%s' "$summary_row" "$col" "Device: /dev/$device"

        if [ "$mode" = "full" ]; then
            printf '\033[%d;%dH%s' $((summary_row + 1)) "$col" "Mode: Full disk installation"

            warn_row=$((summary_row + 3))
            printf '\033[%d;%dH\033[1;31m%s\033[0m' "$warn_row" "$col" "WARNING: All data on /dev/$device will be erased!"
        else
            printf '\033[%d;%dH%s' $((summary_row + 1)) "$col" "Mode: Install alongside"
            printf '\033[%d;%dH%s' $((summary_row + 2)) "$col" "Partition: /dev/$partition"

            warn_row=$((summary_row + 4))
            printf '\033[%d;%dH\033[1;31m%s\033[0m' "$warn_row" "$col" "WARNING: Data on /dev/$partition will be erased!"
        fi

        confirm_row=$((warn_row + 3))
        confirm_msg="Proceed with this configuration?"
        confirm_col=$((start_col + (box_inner_width - ${#confirm_msg}) / 2 + 1))
        printf '\033[%d;%dH%s' "$confirm_row" "$confirm_col" "$confirm_msg"

        # Draw buttons
        draw_confirm_buttons() {
            back_selected="$1"
            confirm_selected="$2"

            button_row=$((start_row + box_inner_height - padding))

            back_text="Back"
            confirm_text="Confirm"
            gap=3
            total_width=$((${#back_text} + gap + ${#confirm_text}))
            button_col=$((start_col + (box_inner_width - total_width) / 2 + 1))

            printf '\033[%d;%dH' "$button_row" "$button_col"

            if [ "$back_selected" -eq 1 ]; then
                printf '\033[7m%s\033[0m' "$back_text"
            else
                printf '%s' "$back_text"
            fi

            printf '   '

            if [ "$confirm_selected" -eq 1 ]; then
                printf '\033[7m%s\033[0m' "$confirm_text"
            else
                printf '%s' "$confirm_text"
            fi
        }

        # Confirmation loop
        selected_button=1  # 1 = back, 2 = confirm

        draw_confirm_buttons 1 0

        while true; do
            char=$(dd bs=1 count=1 2>/dev/null)

            if [ "$char" = "$(printf '\033')" ]; then
                dd bs=1 count=1 2>/dev/null | read -r _ 2>/dev/null
                char=$(dd bs=1 count=1 2>/dev/null)

                case "$char" in
                    A|B) # Up/Down - toggle between buttons
                        if [ "$selected_button" -eq 1 ]; then
                            selected_button=2
                            draw_confirm_buttons 0 1
                        else
                            selected_button=1
                            draw_confirm_buttons 1 0
                        fi
                        ;;
                    C) # Right
                        if [ "$selected_button" -eq 1 ]; then
                            selected_button=2
                            draw_confirm_buttons 0 1
                        fi
                        ;;
                    D) # Left
                        if [ "$selected_button" -eq 2 ]; then
                            selected_button=1
                            draw_confirm_buttons 1 0
                        fi
                        ;;
                esac
            elif [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                if [ "$selected_button" -eq 1 ]; then
                    # Back
                    if [ "$mode" = "full" ]; then
                        mode_selection_screen "$device"
                    else
                        partition_selection_screen "$device"
                    fi
                    return $?
                else
                    # Confirm - save configuration and exit
                    # Save to temp file for main installer to read
                    # Use fixed filename instead of $$ to ensure main.sh can find it
                    config_file="/tmp/jamstaller_install_config.conf"
                    cat > "$config_file" <<EOF
DEVICE=$device
INSTALL_MODE=$mode
INSTALL_PARTITION=/dev/$partition
EOF
                    # Debug: Log what was written
                    echo "[DEBUG] Created config file: $config_file" >> /tmp/jamstaller_debug.log
                    echo "[DEBUG] Contents:" >> /tmp/jamstaller_debug.log
                    cat "$config_file" >> /tmp/jamstaller_debug.log
                    echo "[DEBUG] device=$device, mode=$mode, partition=$partition" >> /tmp/jamstaller_debug.log
                    cleanup 1
                    return 1
                fi
            fi
        done
    }

    # Start with device selection
    device_selection_screen
}
