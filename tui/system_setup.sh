#!/bin/sh

# System Setup Module for Jamstaller
# Returns: 1 if configuration complete, 0 if cancelled

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

# Get list of timezones by region
get_timezone_regions() {
    find /usr/share/zoneinfo -maxdepth 1 -type d -not -name "zoneinfo" -not -name "posix" -not -name "right" 2>/dev/null | \
        sed 's|/usr/share/zoneinfo/||' | \
        grep -v "^/usr/share/zoneinfo$" | \
        sort
}

# Get cities for a region
get_timezone_cities() {
    region="$1"
    find "/usr/share/zoneinfo/$region" -type f 2>/dev/null | \
        sed "s|/usr/share/zoneinfo/$region/||" | \
        sort
}

# Detect current timezone based on system
detect_timezone() {
    # Try to get from /etc/timezone
    if [ -f /etc/timezone ]; then
        cat /etc/timezone
        return 0
    fi

    # Try to get from timedatectl
    if command -v timedatectl >/dev/null 2>&1; then
        timedatectl 2>/dev/null | grep "Time zone" | awk '{print $3}'
        return 0
    fi

    # Default
    echo "UTC"
}

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

# Main TUI
system_setup_tui() {
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

    # Configuration variables
    config_hostname=""
    config_timezone=""
    config_swap=""

    # === SCREEN 1: Hostname Input ===
    hostname_screen() {
        box_inner_height=12
        box_height=$((box_inner_height + border_width))
        start_row=$(((term_rows - box_height) / 2))
        [ "$start_row" -lt 1 ] && start_row=1

        printf '\033[H\033[2J'
        draw_box_at "$start_row" "$start_col" "$box_inner_width" "$box_inner_height" 0

        title="System Setup"
        title_row=$((start_row + padding + 1))
        title_col=$((start_col + (box_inner_width - ${#title}) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

        subtitle_row=$((title_row + 2))
        subtitle="Enter hostname:"
        subtitle_col=$((start_col + padding + 2))
        printf '\033[%d;%dH%s' "$subtitle_row" "$subtitle_col" "$subtitle"

        info_row=$((subtitle_row + 1))
        info_text="\033[2m(This will be the name of your computer)\033[0m"
        info_col=$((start_col + padding + 2))
        printf '\033[%d;%dH%b' "$info_row" "$info_col" "$info_text"

        input_row=$((info_row + 2))
        input_col=$((start_col + padding + 2))

        # Input box
        input_box_width=$((box_inner_width - padding * 2 - 4))
        printf '\033[%d;%dH┌' "$input_row" "$input_col"
        repeat_char '─' "$input_box_width"
        printf '┐'
        printf '\033[%d;%dH│' $((input_row + 1)) "$input_col"
        printf '\033[%d;%dH│' $((input_row + 1)) $((input_col + input_box_width + 1))
        printf '\033[%d;%dH└' $((input_row + 2)) "$input_col"
        repeat_char '─' "$input_box_width"
        printf '┘'

        # Draw buttons
        draw_hostname_buttons() {
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

        # Input field position
        field_row=$((input_row + 1))
        field_col=$((input_col + 2))
        max_hostname_len=$((input_box_width - 2))

        # Start with empty input
        hostname_input=""
        cursor_pos=0

        # Draw current input
        draw_input() {
            printf '\033[%d;%dH%s' "$field_row" "$field_col" "$hostname_input"
            # Clear any remaining characters
            remaining=$((max_hostname_len - ${#hostname_input}))
            if [ "$remaining" -gt 0 ]; then
                repeat_char ' ' "$remaining"
            fi
        }

        selected_button=0  # 0 = input, 1 = cancel

        draw_input
        draw_hostname_buttons 0
        printf '\033[?25h'  # Show cursor
        printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))

        while true; do
            char=$(dd bs=1 count=1 2>/dev/null)

            if [ "$char" = "$(printf '\033')" ]; then
                dd bs=1 count=1 2>/dev/null | read -r _ 2>/dev/null
                char=$(dd bs=1 count=1 2>/dev/null)

                case "$char" in
                    A) # Up
                        if [ "$selected_button" -eq 1 ]; then
                            selected_button=0
                            printf '\033[?25h'
                            draw_hostname_buttons 0
                            printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                        fi
                        ;;
                    B) # Down
                        if [ "$selected_button" -eq 0 ]; then
                            selected_button=1
                            printf '\033[?25l'
                            draw_hostname_buttons 1
                        fi
                        ;;
                    C) # Right
                        if [ "$selected_button" -eq 0 ]; then
                            if [ "$cursor_pos" -lt "${#hostname_input}" ]; then
                                cursor_pos=$((cursor_pos + 1))
                                printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                            fi
                        fi
                        ;;
                    D) # Left
                        if [ "$selected_button" -eq 0 ]; then
                            if [ "$cursor_pos" -gt 0 ]; then
                                cursor_pos=$((cursor_pos - 1))
                                printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                            fi
                        fi
                        ;;
                    3) # Delete key
                        if [ "$selected_button" -eq 0 ] && [ "$cursor_pos" -lt "${#hostname_input}" ]; then
                            # Delete character at cursor
                            if [ "$cursor_pos" -eq 0 ]; then
                                hostname_input="${hostname_input#?}"
                            else
                                before="${hostname_input%"${hostname_input#????????????????????????????????????????????????????????????????}"}"
                                before=$(echo "$hostname_input" | awk -v pos="$cursor_pos" '{print substr($0, 1, pos)}')
                                after=$(echo "$hostname_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+2)}')
                                hostname_input="${before}${after}"
                            fi
                            # Just redraw from cursor position
                            after_cursor=$(echo "$hostname_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+1)}')
                            printf '\033[%d;%dH%s ' "$field_row" $((field_col + cursor_pos)) "$after_cursor"
                            printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                        fi
                        ;;
                esac
            elif [ "$char" = "$(printf '\177')" ]; then
                # Backspace
                if [ "$selected_button" -eq 0 ] && [ "$cursor_pos" -gt 0 ]; then
                    before=$(echo "$hostname_input" | awk -v pos="$cursor_pos" '{print substr($0, 1, pos-1)}')
                    after=$(echo "$hostname_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+1)}')
                    hostname_input="${before}${after}"
                    cursor_pos=$((cursor_pos - 1))
                    # Just redraw from cursor position
                    after_cursor=$(echo "$hostname_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+1)}')
                    printf '\033[%d;%dH%s ' "$field_row" $((field_col + cursor_pos)) "$after_cursor"
                    printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                fi
            elif [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                if [ "$selected_button" -eq 1 ]; then
                    # Cancel
                    cleanup 0
                    return 0
                else
                    # Enter - validate hostname
                    if [ -z "$hostname_input" ]; then
                        # Show error if empty
                        error_row=$((input_row + 4))
                        error_msg="\033[31mHostname cannot be empty\033[0m"
                        error_col=$((start_col + padding + 2))
                        printf '\033[%d;%dH%b' "$error_row" "$error_col" "$error_msg"
                        sleep 1
                        printf '\033[%d;%dH' "$error_row" "$error_col"
                        repeat_char ' ' 30
                        if [ "$selected_button" -eq 0 ]; then
                            printf '\033[?25h'
                            printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                        fi
                    # Validate hostname format
                    elif echo "$hostname_input" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$'; then
                        config_hostname="$hostname_input"
                        printf '\033[?25l'
                        timezone_region_screen
                        return $?
                    else
                        # Invalid hostname - show error
                        error_row=$((input_row + 4))
                        error_msg="\033[31mInvalid hostname format\033[0m"
                        error_col=$((start_col + padding + 2))
                        printf '\033[%d;%dH%b' "$error_row" "$error_col" "$error_msg"
                        sleep 1
                        printf '\033[%d;%dH' "$error_row" "$error_col"
                        repeat_char ' ' 30
                        if [ "$selected_button" -eq 0 ]; then
                            printf '\033[?25h'
                            printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                        fi
                    fi
                fi
            else
                # Regular character input
                if [ "$selected_button" -eq 0 ]; then
                    # Only accept valid hostname characters
                    if echo "$char" | grep -qE '^[a-zA-Z0-9-]$'; then
                        if [ "${#hostname_input}" -lt "$max_hostname_len" ]; then
                            if [ "$cursor_pos" -eq 0 ]; then
                                hostname_input="${char}${hostname_input}"
                            elif [ "$cursor_pos" -eq "${#hostname_input}" ]; then
                                hostname_input="${hostname_input}${char}"
                            else
                                before=$(echo "$hostname_input" | awk -v pos="$cursor_pos" '{print substr($0, 1, pos)}')
                                after=$(echo "$hostname_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+1)}')
                                hostname_input="${before}${char}${after}"
                            fi
                            cursor_pos=$((cursor_pos + 1))
                            # Just redraw from cursor position - 1
                            from_cursor=$(echo "$hostname_input" | awk -v pos="$cursor_pos" '{print substr($0, pos)}')
                            printf '\033[%d;%dH%s' "$field_row" $((field_col + cursor_pos - 1)) "$from_cursor"
                            printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                        fi
                    fi
                fi
            fi
        done
    }

    # === SCREEN 2: Timezone Region Selection ===
    timezone_region_screen() {
        # Get regions
        region_count=0
        while IFS= read -r region; do
            region_count=$((region_count + 1))
            eval "region_${region_count}=\"\$region\""
        done <<EOF
$(get_timezone_regions)
EOF

        if [ "$region_count" -eq 0 ]; then
            # Fallback to UTC
            config_timezone="UTC"
            swap_screen
            return $?
        fi

        # Calculate box height
        max_regions=10
        display_count=$region_count
        [ "$display_count" -gt "$max_regions" ] && display_count=$max_regions

        box_inner_height=$((padding * 2 + 1 + 1 + 1 + display_count + 2 + 1))
        box_height=$((box_inner_height + border_width))
        start_row=$(((term_rows - box_height) / 2))
        [ "$start_row" -lt 1 ] && start_row=1

        printf '\033[H\033[2J'
        draw_box_at "$start_row" "$start_col" "$box_inner_width" "$box_inner_height" 0

        title="System Setup"
        title_row=$((start_row + padding + 1))
        title_col=$((start_col + (box_inner_width - ${#title}) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

        subtitle_row=$((title_row + 1))
        subtitle="Select timezone region:"
        subtitle_col=$((start_col + padding + 2))
        printf '\033[%d;%dH%s' "$subtitle_row" "$subtitle_col" "$subtitle"

        # Draw regions
        draw_regions() {
            selected_idx="$1"
            scroll_offset="$2"

            list_start_row=$((subtitle_row + 2))
            i=1
            display_idx=0

            while [ "$i" -le "$region_count" ] && [ "$display_idx" -lt "$display_count" ]; do
                if [ "$i" -gt "$scroll_offset" ]; then
                    eval "region=\$region_$i"

                    row=$((list_start_row + display_idx))
                    col=$((start_col + padding + 2))

                    printf '\033[%d;%dH' "$row" "$col"

                    if [ "$i" -eq "$selected_idx" ]; then
                        printf '\033[7m> %-64s\033[0m' "$region"
                    else
                        printf '  %-64s' "$region"
                    fi

                    display_idx=$((display_idx + 1))
                fi
                i=$((i + 1))
            done
        }

        # Draw buttons
        draw_region_buttons() {
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

        # Region selection loop
        selected_region=1
        scroll_offset=0
        selected_item=0  # 0 = region, 1 = back

        draw_regions "$selected_region" "$scroll_offset"
        draw_region_buttons 0

        while true; do
            char=$(dd bs=1 count=1 2>/dev/null)

            if [ "$char" = "$(printf '\033')" ]; then
                dd bs=1 count=1 2>/dev/null | read -r _ 2>/dev/null
                char=$(dd bs=1 count=1 2>/dev/null)

                case "$char" in
                    A) # Up
                        if [ "$selected_item" -eq 0 ]; then
                            if [ "$selected_region" -gt 1 ]; then
                                selected_region=$((selected_region - 1))
                                if [ "$selected_region" -le "$scroll_offset" ]; then
                                    scroll_offset=$((selected_region - 1))
                                    [ "$scroll_offset" -lt 0 ] && scroll_offset=0
                                fi
                                draw_regions "$selected_region" "$scroll_offset"
                            fi
                        elif [ "$selected_item" -eq 1 ]; then
                            selected_item=0
                            draw_regions "$selected_region" "$scroll_offset"
                            draw_region_buttons 0
                        fi
                        ;;
                    B) # Down
                        if [ "$selected_item" -eq 0 ]; then
                            if [ "$selected_region" -lt "$region_count" ]; then
                                selected_region=$((selected_region + 1))
                                max_visible=$((scroll_offset + display_count))
                                if [ "$selected_region" -gt "$max_visible" ]; then
                                    scroll_offset=$((scroll_offset + 1))
                                fi
                                draw_regions "$selected_region" "$scroll_offset"
                            else
                                selected_item=1
                                # Clear the region highlight by redrawing without selection
                                list_start_row=$((subtitle_row + 2))
                                i=1
                                display_idx=0
                                while [ "$i" -le "$region_count" ] && [ "$display_idx" -lt "$display_count" ]; do
                                    if [ "$i" -gt "$scroll_offset" ]; then
                                        eval "region=\$region_$i"
                                        row=$((list_start_row + display_idx))
                                        col=$((start_col + padding + 2))
                                        printf '\033[%d;%dH  %-64s' "$row" "$col" "$region"
                                        display_idx=$((display_idx + 1))
                                    fi
                                    i=$((i + 1))
                                done
                                draw_region_buttons 1
                            fi
                        fi
                        ;;
                esac
            elif [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                if [ "$selected_item" -eq 1 ]; then
                    # Back
                    hostname_screen
                    return $?
                else
                    # Select region - go to city selection
                    eval "chosen_region=\$region_$selected_region"
                    timezone_city_screen "$chosen_region"
                    return $?
                fi
            fi
        done
    }

    # === SCREEN 3: Timezone City Selection ===
    timezone_city_screen() {
        region="$1"

        # Get cities
        city_count=0
        while IFS= read -r city; do
            city_count=$((city_count + 1))
            eval "city_${city_count}=\"\$city\""
        done <<EOF
$(get_timezone_cities "$region")
EOF

        if [ "$city_count" -eq 0 ]; then
            # No cities, use region as timezone
            config_timezone="$region"
            swap_screen
            return $?
        fi

        # Calculate box height
        max_cities=10
        display_count=$city_count
        [ "$display_count" -gt "$max_cities" ] && display_count=$max_cities

        box_inner_height=$((padding * 2 + 1 + 1 + 1 + 1 + display_count + 2 + 1))
        box_height=$((box_inner_height + border_width))
        start_row=$(((term_rows - box_height) / 2))
        [ "$start_row" -lt 1 ] && start_row=1

        printf '\033[H\033[2J'
        draw_box_at "$start_row" "$start_col" "$box_inner_width" "$box_inner_height" 0

        title="System Setup"
        title_row=$((start_row + padding + 1))
        title_col=$((start_col + (box_inner_width - ${#title}) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

        region_row=$((title_row + 1))
        region_text="Region: $region"
        region_col=$((start_col + padding + 2))
        printf '\033[%d;%dH\033[2m%s\033[0m' "$region_row" "$region_col" "$region_text"

        subtitle_row=$((region_row + 1))
        subtitle="Select city/timezone:"
        subtitle_col=$((start_col + padding + 2))
        printf '\033[%d;%dH%s' "$subtitle_row" "$subtitle_col" "$subtitle"

        # Draw cities
        draw_cities() {
            selected_idx="$1"
            scroll_offset="$2"

            list_start_row=$((subtitle_row + 2))
            i=1
            display_idx=0

            while [ "$i" -le "$city_count" ] && [ "$display_idx" -lt "$display_count" ]; do
                if [ "$i" -gt "$scroll_offset" ]; then
                    eval "city=\$city_$i"

                    row=$((list_start_row + display_idx))
                    col=$((start_col + padding + 2))

                    printf '\033[%d;%dH' "$row" "$col"

                    if [ "$i" -eq "$selected_idx" ]; then
                        printf '\033[7m> %-64s\033[0m' "$city"
                    else
                        printf '  %-64s' "$city"
                    fi

                    display_idx=$((display_idx + 1))
                fi
                i=$((i + 1))
            done
        }

        # Draw buttons
        draw_city_buttons() {
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

        # City selection loop
        selected_city=1
        scroll_offset=0
        selected_item=0  # 0 = city, 1 = back

        draw_cities "$selected_city" "$scroll_offset"
        draw_city_buttons 0

        while true; do
            char=$(dd bs=1 count=1 2>/dev/null)

            if [ "$char" = "$(printf '\033')" ]; then
                dd bs=1 count=1 2>/dev/null | read -r _ 2>/dev/null
                char=$(dd bs=1 count=1 2>/dev/null)

                case "$char" in
                    A) # Up
                        if [ "$selected_item" -eq 0 ]; then
                            if [ "$selected_city" -gt 1 ]; then
                                selected_city=$((selected_city - 1))
                                if [ "$selected_city" -le "$scroll_offset" ]; then
                                    scroll_offset=$((selected_city - 1))
                                    [ "$scroll_offset" -lt 0 ] && scroll_offset=0
                                fi
                                draw_cities "$selected_city" "$scroll_offset"
                            fi
                        elif [ "$selected_item" -eq 1 ]; then
                            selected_item=0
                            draw_cities "$selected_city" "$scroll_offset"
                            draw_city_buttons 0
                        fi
                        ;;
                    B) # Down
                        if [ "$selected_item" -eq 0 ]; then
                            if [ "$selected_city" -lt "$city_count" ]; then
                                selected_city=$((selected_city + 1))
                                max_visible=$((scroll_offset + display_count))
                                if [ "$selected_city" -gt "$max_visible" ]; then
                                    scroll_offset=$((scroll_offset + 1))
                                fi
                                draw_cities "$selected_city" "$scroll_offset"
                            else
                                selected_item=1
                                # Clear the city highlight by redrawing without selection
                                list_start_row=$((subtitle_row + 2))
                                i=1
                                display_idx=0
                                while [ "$i" -le "$city_count" ] && [ "$display_idx" -lt "$display_count" ]; do
                                    if [ "$i" -gt "$scroll_offset" ]; then
                                        eval "city=\$city_$i"
                                        row=$((list_start_row + display_idx))
                                        col=$((start_col + padding + 2))
                                        printf '\033[%d;%dH  %-64s' "$row" "$col" "$city"
                                        display_idx=$((display_idx + 1))
                                    fi
                                    i=$((i + 1))
                                done
                                draw_city_buttons 1
                            fi
                        fi
                        ;;
                esac
            elif [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                if [ "$selected_item" -eq 1 ]; then
                    # Back
                    timezone_region_screen
                    return $?
                else
                    # Select city
                    eval "chosen_city=\$city_$selected_city"
                    config_timezone="$region/$chosen_city"
                    swap_screen
                    return $?
                fi
            fi
        done
    }

    # === SCREEN 4: Swap Configuration ===
    swap_screen() {
        box_inner_height=12
        box_height=$((box_inner_height + border_width))
        start_row=$(((term_rows - box_height) / 2))
        [ "$start_row" -lt 1 ] && start_row=1

        printf '\033[H\033[2J'
        draw_box_at "$start_row" "$start_col" "$box_inner_width" "$box_inner_height" 0

        title="System Setup"
        title_row=$((start_row + padding + 1))
        title_col=$((start_col + (box_inner_width - ${#title}) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

        subtitle_row=$((title_row + 2))
        subtitle="Swap Configuration"
        subtitle_col=$((start_col + padding + 2))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$subtitle_row" "$subtitle_col" "$subtitle"

        info_row=$((subtitle_row + 1))
        info_text="\033[2m(Enter swap size in GB, or leave empty for no swap)\033[0m"
        info_col=$((start_col + padding + 2))
        printf '\033[%d;%dH%b' "$info_row" "$info_col" "$info_text"

        input_row=$((info_row + 2))
        input_col=$((start_col + padding + 2))

        # Input box
        input_box_width=20
        printf '\033[%d;%dH┌' "$input_row" "$input_col"
        repeat_char '─' "$input_box_width"
        printf '┐'
        printf '\033[%d;%dH│' $((input_row + 1)) "$input_col"
        repeat_char ' ' "$input_box_width"
        printf '│'
        printf '\033[%d;%dH└' $((input_row + 2)) "$input_col"
        repeat_char '─' "$input_box_width"
        printf '┘'

        # Label
        label_row=$((input_row + 1))
        label_col=$((input_col + input_box_width + 3))
        printf '\033[%d;%dHGB' "$label_row" "$label_col"

        # Draw buttons
        draw_swap_buttons() {
            back_selected="$1"
            next_selected="$2"

            button_row=$((start_row + box_inner_height - padding))

            back_text="Back"
            next_text="Next"
            gap=3
            total_width=$((${#back_text} + gap + ${#next_text}))
            button_col=$((start_col + (box_inner_width - total_width) / 2 + 1))

            printf '\033[%d;%dH' "$button_row" "$button_col"

            if [ "$back_selected" -eq 1 ]; then
                printf '\033[7m%s\033[0m' "$back_text"
            else
                printf '%s' "$back_text"
            fi

            printf '   '

            if [ "$next_selected" -eq 1 ]; then
                printf '\033[7m%s\033[0m' "$next_text"
            else
                printf '%s' "$next_text"
            fi
        }

        # Input field position
        field_row=$((input_row + 1))
        field_col=$((input_col + 2))
        max_swap_len=$((input_box_width - 2))

        swap_input=""
        cursor_pos=0

        # Draw current input
        draw_swap_input() {
            printf '\033[%d;%dH%s' "$field_row" "$field_col" "$swap_input"
            # Clear any remaining characters
            remaining=$((max_swap_len - ${#swap_input}))
            if [ "$remaining" -gt 0 ]; then
                repeat_char ' ' "$remaining"
            fi
        }

        selected_button=0  # 0 = input, 1 = back, 2 = next

        draw_swap_input
        draw_swap_buttons 0 0
        printf '\033[?25h'  # Show cursor
        printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))

        while true; do
            char=$(dd bs=1 count=1 2>/dev/null)

            if [ "$char" = "$(printf '\033')" ]; then
                dd bs=1 count=1 2>/dev/null | read -r _ 2>/dev/null
                char=$(dd bs=1 count=1 2>/dev/null)

                case "$char" in
                    A) # Up
                        if [ "$selected_button" -eq 1 ]; then
                            selected_button=0
                            printf '\033[?25h'
                            draw_swap_buttons 0 0
                            printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                        elif [ "$selected_button" -eq 2 ]; then
                            selected_button=0
                            printf '\033[?25h'
                            draw_swap_buttons 0 0
                            printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                        fi
                        ;;
                    B) # Down
                        if [ "$selected_button" -eq 0 ]; then
                            selected_button=1
                            printf '\033[?25l'
                            draw_swap_buttons 1 0
                        fi
                        ;;
                    C) # Right
                        if [ "$selected_button" -eq 0 ]; then
                            if [ "$cursor_pos" -lt "${#swap_input}" ]; then
                                cursor_pos=$((cursor_pos + 1))
                                printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                            fi
                        elif [ "$selected_button" -eq 1 ]; then
                            selected_button=2
                            draw_swap_buttons 0 1
                        fi
                        ;;
                    D) # Left
                        if [ "$selected_button" -eq 0 ]; then
                            if [ "$cursor_pos" -gt 0 ]; then
                                cursor_pos=$((cursor_pos - 1))
                                printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                            fi
                        elif [ "$selected_button" -eq 2 ]; then
                            selected_button=1
                            draw_swap_buttons 1 0
                        fi
                        ;;
                    3) # Delete key
                        if [ "$selected_button" -eq 0 ] && [ "$cursor_pos" -lt "${#swap_input}" ]; then
                            if [ "$cursor_pos" -eq 0 ]; then
                                swap_input="${swap_input#?}"
                            else
                                before=$(echo "$swap_input" | awk -v pos="$cursor_pos" '{print substr($0, 1, pos)}')
                                after=$(echo "$swap_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+2)}')
                                swap_input="${before}${after}"
                            fi
                            # Just redraw from cursor position
                            after_cursor=$(echo "$swap_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+1)}')
                            printf '\033[%d;%dH%s ' "$field_row" $((field_col + cursor_pos)) "$after_cursor"
                            printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                        fi
                        ;;
                esac
            elif [ "$char" = "$(printf '\177')" ]; then
                # Backspace
                if [ "$selected_button" -eq 0 ] && [ "$cursor_pos" -gt 0 ]; then
                    before=$(echo "$swap_input" | awk -v pos="$cursor_pos" '{print substr($0, 1, pos-1)}')
                    after=$(echo "$swap_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+1)}')
                    swap_input="${before}${after}"
                    cursor_pos=$((cursor_pos - 1))
                    # Just redraw from cursor position
                    after_cursor=$(echo "$swap_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+1)}')
                    printf '\033[%d;%dH%s ' "$field_row" $((field_col + cursor_pos)) "$after_cursor"
                    printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                fi
            elif [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                if [ "$selected_button" -eq 1 ]; then
                    # Back
                    printf '\033[?25l'
                    timezone_region_screen
                    return $?
                elif [ "$selected_button" -eq 2 ] || [ "$selected_button" -eq 0 ]; then
                    # Next - validate swap size
                    if [ -z "$swap_input" ]; then
                        # No swap
                        config_swap="0"
                        printf '\033[?25l'
                        summary_screen
                        return $?
                    elif echo "$swap_input" | grep -qE '^[0-9]+(\.[0-9]+)?$'; then
                        # Valid number
                        config_swap="$swap_input"
                        printf '\033[?25l'
                        summary_screen
                        return $?
                    else
                        # Invalid input
                        error_row=$((input_row + 4))
                        error_msg="\033[31mPlease enter a valid number\033[0m"
                        error_col=$((start_col + padding + 2))
                        printf '\033[%d;%dH%b' "$error_row" "$error_col" "$error_msg"
                        sleep 1
                        printf '\033[%d;%dH' "$error_row" "$error_col"
                        repeat_char ' ' 40
                        if [ "$selected_button" -eq 0 ]; then
                            printf '\033[?25h'
                            printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                        fi
                    fi
                fi
            else
                # Regular character input
                if [ "$selected_button" -eq 0 ]; then
                    # Only accept numbers and decimal point
                    if echo "$char" | grep -qE '^[0-9.]$'; then
                        if [ "${#swap_input}" -lt "$max_swap_len" ]; then
                            if [ "$cursor_pos" -eq 0 ]; then
                                swap_input="${char}${swap_input}"
                            elif [ "$cursor_pos" -eq "${#swap_input}" ]; then
                                swap_input="${swap_input}${char}"
                            else
                                before=$(echo "$swap_input" | awk -v pos="$cursor_pos" '{print substr($0, 1, pos)}')
                                after=$(echo "$swap_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+1)}')
                                swap_input="${before}${char}${after}"
                            fi
                            cursor_pos=$((cursor_pos + 1))
                            # Just redraw from cursor position - 1
                            from_cursor=$(echo "$swap_input" | awk -v pos="$cursor_pos" '{print substr($0, pos)}')
                            printf '\033[%d;%dH%s' "$field_row" $((field_col + cursor_pos - 1)) "$from_cursor"
                            printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                        fi
                    fi
                fi
            fi
        done
    }

    # === SCREEN 5: Summary and Confirmation ===
    summary_screen() {
        box_inner_height=16
        box_height=$((box_inner_height + border_width))
        start_row=$(((term_rows - box_height) / 2))
        [ "$start_row" -lt 1 ] && start_row=1

        printf '\033[H\033[2J'
        draw_box_at "$start_row" "$start_col" "$box_inner_width" "$box_inner_height" 0

        title="System Configuration Summary"
        title_row=$((start_row + padding + 1))
        title_col=$((start_col + (box_inner_width - ${#title}) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

        summary_row=$((title_row + 2))
        col=$((start_col + padding + 2))

        printf '\033[%d;%dH\033[1mHostname:\033[0m     %s' "$summary_row" "$col" "$config_hostname"
        printf '\033[%d;%dH\033[1mTimezone:\033[0m     %s' $((summary_row + 2)) "$col" "$config_timezone"

        if [ "$config_swap" = "0" ]; then
            printf '\033[%d;%dH\033[1mSwap:\033[0m         No swap' $((summary_row + 4)) "$col"
        else
            printf '\033[%d;%dH\033[1mSwap:\033[0m         %s GB' $((summary_row + 4)) "$col" "$config_swap"
        fi

        confirm_row=$((summary_row + 7))
        confirm_msg="Confirm system configuration?"
        confirm_col=$((start_col + (box_inner_width - ${#confirm_msg}) / 2 + 1))
        printf '\033[%d;%dH%s' "$confirm_row" "$confirm_col" "$confirm_msg"

        # Draw buttons
        draw_summary_buttons() {
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

        # Button selection loop
        selected_button=1  # 1 = back, 2 = confirm

        draw_summary_buttons 1 0

        while true; do
            char=$(dd bs=1 count=1 2>/dev/null)

            if [ "$char" = "$(printf '\033')" ]; then
                dd bs=1 count=1 2>/dev/null | read -r _ 2>/dev/null
                char=$(dd bs=1 count=1 2>/dev/null)

                case "$char" in
                    A|B) # Up/Down - toggle
                        if [ "$selected_button" -eq 1 ]; then
                            selected_button=2
                            draw_summary_buttons 0 1
                        else
                            selected_button=1
                            draw_summary_buttons 1 0
                        fi
                        ;;
                    C) # Right
                        if [ "$selected_button" -eq 1 ]; then
                            selected_button=2
                            draw_summary_buttons 0 1
                        fi
                        ;;
                    D) # Left
                        if [ "$selected_button" -eq 2 ]; then
                            selected_button=1
                            draw_summary_buttons 1 0
                        fi
                        ;;
                esac
            elif [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                if [ "$selected_button" -eq 1 ]; then
                    # Back to swap screen
                    swap_screen
                    return $?
                else
                    # Confirm - save configuration
                    cat > /tmp/jamstaller_system_config.$$ <<EOF
SYSTEM_HOSTNAME=$config_hostname
SYSTEM_TIMEZONE=$config_timezone
SYSTEM_SWAP=$config_swap
EOF
                    cleanup 1
                    return 1
                fi
            fi
        done
    }

    # Start with hostname screen
    hostname_screen
}

# Only run if executed directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ] || [ -z "${BASH_SOURCE[0]}" ]; then
    system_setup_tui
    exit $?
fi
