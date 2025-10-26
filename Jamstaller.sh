#!/bin/sh

# TUI Installer Function
# Usage: installer_tui "Title" "Stage 1" "Stage 2" "Stage 3"
installer_tui() {
    # Parse arguments
    [ "$#" -lt 2 ] && return 1
    title="$1"
    shift

    # Store stages
    i=1
    for arg in "$@"; do
        eval "stage_$i=\"\$arg\""
        eval "state_$i=0"  # 0=incomplete, 1=complete
        i=$((i + 1))
    done
    stage_count=$((i - 1))
    [ "$stage_count" -eq 0 ] && return 1

    # Add buttons
    button_cancel="Cancel"
    button_install="Install"
    total_count=$((stage_count + 2))  # stages + 2 buttons

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

    # Calculate dimensions
    padding=2
    border_width=2
    max_opt_len=0
    i=1
    while [ "$i" -le "$stage_count" ]; do
        eval "stage=\$stage_$i"
        # Account for state prefix "> [*] " or "  [] " (6 chars total)
        opt_len=$((${#stage} + 6))
        [ "$opt_len" -gt "$max_opt_len" ] && max_opt_len=$opt_len
        i=$((i + 1))
    done

    # Check button lengths
    button_len=$((${#button_cancel} + ${#button_install} + 6))
    [ "$button_len" -gt "$max_opt_len" ] && max_opt_len=$button_len

    # Calculate box dimensions
    ascii_art_width=52  # Width of the ASCII art
    content_width=$max_opt_len
    [ "$ascii_art_width" -gt "$content_width" ] && content_width=$ascii_art_width
    box_inner_width=$((content_width + 4 + padding * 2))
    box_width=$((box_inner_width + border_width))
    box_inner_height=$((8 + stage_count + 2 + padding * 2))  # ASCII art (6 lines) + 1 spacer + 1 extra + stages + spacer + buttons
    box_height=$((box_inner_height + border_width))

    # Calculate centering position
    start_row=$(((term_rows - box_height) / 2))
    start_col=$(((term_cols - box_width) / 2))
    [ "$start_row" -lt 1 ] && start_row=1
    [ "$start_col" -lt 1 ] && start_col=1

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
        fill_inside="${5:-0}"  # Optional: fill inside with spaces

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

    # Draw main border
    draw_box() {
        draw_box_at "$start_row" "$start_col" "$box_inner_width" "$box_inner_height" 0
    }

    # Draw title
    draw_title() {
        # ASCII art logo - drawn line by line
        ascii_line1="   ___                     _        _ _           "
        ascii_line2="  |_  |                   | |      | | |          "
        ascii_line3="    | | __ _ _ __ ___  ___| |_ __ _| | | ___ _ __ "
        ascii_line4="    | |/ _\` | '_ \` _ \/ __| __/ _\` | | |/ _ \ '__|"
        ascii_line5="/\__/ / (_| | | | | | \__ \ || (_| | | |  __/ |   "
        ascii_line6="\____/ \__,_|_| |_| |_|___/\__\__,_|_|_|\___|_|   "

        # Draw each line centered
        ascii_row=$((start_row + padding + 1))
        ascii_start=$((start_col + (box_inner_width - ${#ascii_line1}) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$ascii_row" "$ascii_start" "$ascii_line1"

        ascii_row=$((ascii_row + 1))
        ascii_start=$((start_col + (box_inner_width - ${#ascii_line2}) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$ascii_row" "$ascii_start" "$ascii_line2"

        ascii_row=$((ascii_row + 1))
        ascii_start=$((start_col + (box_inner_width - ${#ascii_line3}) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$ascii_row" "$ascii_start" "$ascii_line3"

        ascii_row=$((ascii_row + 1))
        ascii_start=$((start_col + (box_inner_width - ${#ascii_line4}) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$ascii_row" "$ascii_start" "$ascii_line4"

        ascii_row=$((ascii_row + 1))
        ascii_start=$((start_col + (box_inner_width - ${#ascii_line5}) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$ascii_row" "$ascii_start" "$ascii_line5"

        ascii_row=$((ascii_row + 1))
        ascii_start=$((start_col + (box_inner_width - ${#ascii_line6}) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$ascii_row" "$ascii_start" "$ascii_line6"
    }

    # Get state indicator
    get_state_indicator() {
        state="$1"
        case "$state" in
            0) printf '[]' ;;      # incomplete
            1) printf '\033[32m[*]\033[0m' ;;     # complete (green)
        esac
    }

    # Draw stage at index
    draw_stage() {
        idx="$1"
        is_selected="$2"

        stage_row=$((start_row + padding + 8 + idx))  # ASCII art (6 lines) + 1 spacer + 1 extra
        stage_col=$((start_col + padding + 2))

        eval "stage=\$stage_$idx"
        eval "state=\$state_$idx"

        # Default to 0 if state is empty
        : "${state:=0}"

        # Move to position and ensure we start fresh
        printf '\033[%d;%dH' "$stage_row" "$stage_col"

        if [ "$is_selected" = "1" ]; then
            # Highlight full row
            printf '\033[7m> '
            if [ "$state" -eq 1 ]; then
                printf '\033[27m\033[32m[*]\033[0m\033[7m'
            else
                printf '[]'
            fi
            printf ' %s' "$stage"
            # Pad to content_width
            text_len=$((6 + ${#stage}))
            remaining=$((content_width - text_len))
            repeat_char ' ' "$remaining"
            printf '\033[0m'
        else
            # Draw without highlight - clear the entire line content with extra spaces
            printf '\033[0m  '
            if [ "$state" -eq 1 ]; then
                printf '\033[32m[*]\033[0m'
            else
                printf '[]'
            fi
            printf ' %s' "$stage"
            # Pad to content_width + extra to clear any remaining highlight
            text_len=$((6 + ${#stage}))
            remaining=$((content_width - text_len + 2))
            repeat_char ' ' "$remaining"
        fi
    }

    # Draw buttons
    draw_buttons() {
        is_cancel_selected="$1"
        is_install_selected="$2"

        # Spacer line
        spacer_row=$((start_row + padding + 9 + stage_count))  # ASCII art (6 lines) + 1 spacer + 1 extra + stages

        # Button row
        button_row=$((spacer_row + 1))
        button_col=$((start_col + padding + 2))

        # Clear button area
        printf '\033[%d;%dH' "$button_row" "$button_col"
        spaces_needed=$((content_width + 4))
        repeat_char ' ' "$spaces_needed"

        # Draw buttons centered with fixed width
        cancel_len=${#button_cancel}
        install_len=${#button_install}
        gap=3
        total_button_width=$((cancel_len + gap + install_len))
        button_start=$((button_col + (content_width + 4 - total_button_width) / 2))

        # Draw Cancel button
        printf '\033[%d;%dH' "$button_row" "$button_start"
        if [ "$is_cancel_selected" = "1" ]; then
            printf '\033[7m%s\033[0m' "$button_cancel"
        else
            printf '%s' "$button_cancel"
        fi

        # Draw gap
        printf '   '

        # Draw Install button
        if [ "$is_install_selected" = "1" ]; then
            printf '\033[7m%s\033[0m' "$button_install"
        else
            printf '%s' "$button_install"
        fi
    }

    # Show confirmation dialog
    show_confirmation() {
        action="$1"  # "cancel" or "install"

        if [ "$action" = "cancel" ]; then
            confirm_msg="Are you sure you want to cancel?"
        else
            confirm_msg="Are you sure you want to install?"
        fi

        # Calculate dialog dimensions
        msg_len=${#confirm_msg}
        button_yes="Yes"
        button_no="No"
        button_row_len=$((${#button_yes} + ${#button_no} + 6))
        dialog_content_width=$msg_len
        [ "$button_row_len" -gt "$dialog_content_width" ] && dialog_content_width=$button_row_len

        dialog_inner_width=$((dialog_content_width + 4 + padding * 2))
        dialog_width=$((dialog_inner_width + border_width))
        dialog_inner_height=$((3 + padding * 2))  # message + spacer + buttons
        dialog_height=$((dialog_inner_height + border_width))

        # Center dialog
        dialog_start_row=$(((term_rows - dialog_height) / 2))
        dialog_start_col=$(((term_cols - dialog_width) / 2))
        [ "$dialog_start_row" -lt 1 ] && dialog_start_row=1
        [ "$dialog_start_col" -lt 1 ] && dialog_start_col=1

        # Draw dialog box
        draw_box_at "$dialog_start_row" "$dialog_start_col" "$dialog_inner_width" "$dialog_inner_height" 1

        # Draw message
        msg_row=$((dialog_start_row + padding + 1))
        msg_col=$((dialog_start_col + (dialog_inner_width - msg_len) / 2 + 1))
        printf '\033[%d;%dH%s' "$msg_row" "$msg_col" "$confirm_msg"

        # Button positioning
        confirm_button_row=$((msg_row + 2))
        yes_len=${#button_yes}
        no_len=${#button_no}
        gap=3
        total_btn_width=$((yes_len + gap + no_len))
        btn_start=$((dialog_start_col + (dialog_inner_width - total_btn_width) / 2 + 1))

        # Helper: draw two buttons side-by-side
        draw_two_buttons() {
            row="$1"
            col="$2"
            btn1_text="$3"
            btn2_text="$4"
            btn1_selected="$5"
            total_width="$6"

            # Clear button area
            printf '\033[%d;%dH' "$row" "$col"
            repeat_char ' ' "$total_width"

            # Draw first button
            printf '\033[%d;%dH' "$row" "$col"
            if [ "$btn1_selected" = "1" ]; then
                printf '\033[7m%s\033[0m' "$btn1_text"
            else
                printf '%s' "$btn1_text"
            fi

            # Draw gap
            printf '   '

            # Draw second button
            if [ "$btn1_selected" = "0" ]; then
                printf '\033[7m%s\033[0m' "$btn2_text"
            else
                printf '%s' "$btn2_text"
            fi
        }

        # Draw confirmation buttons
        draw_confirm_buttons() {
            is_yes_selected="$1"
            draw_two_buttons "$confirm_button_row" "$btn_start" "$button_yes" "$button_no" "$is_yes_selected" "$total_btn_width"
        }

        # Initial state: No is selected (safer default)
        confirm_selected=0
        draw_confirm_buttons 0

        # Confirmation input loop
        stty -echo -icanon
        while true; do
            char=$(dd bs=1 count=1 2>/dev/null)

            if [ "$char" = "$(printf '\033')" ]; then
                dd bs=1 count=1 2>/dev/null | read -r _ 2>/dev/null
                char=$(dd bs=1 count=1 2>/dev/null)

                case "$char" in
                    C) # Right arrow
                        if [ "$confirm_selected" -eq 1 ]; then
                            confirm_selected=0
                            draw_confirm_buttons 0
                        fi
                        ;;
                    D) # Left arrow
                        if [ "$confirm_selected" -eq 0 ]; then
                            confirm_selected=1
                            draw_confirm_buttons 1
                        fi
                        ;;
                esac
            elif [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                # Return result: 1 for Yes, 0 for No
                if [ "$confirm_selected" -eq 1 ]; then
                    return 1
                else
                    return 0
                fi
            fi
        done
    }

    # Check network connectivity
    check_connectivity() {
        ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1
    }

    # Show error when not all stages are complete
    show_incomplete_error() {
        # Calculate dialog dimensions
        error_msg="Cannot proceed with installation"
        info_msg="Please complete all setup stages first"
        button_text="OK"

        msg_len=${#error_msg}
        info_len=${#info_msg}
        max_len=$msg_len
        [ "$info_len" -gt "$max_len" ] && max_len=$info_len

        dialog_content_width=$max_len
        dialog_inner_width=$((dialog_content_width + 4 + padding * 2))
        dialog_width=$((dialog_inner_width + border_width))
        dialog_inner_height=$((4 + padding * 2))
        dialog_height=$((dialog_inner_height + border_width))

        # Center dialog
        dialog_start_row=$(((term_rows - dialog_height) / 2))
        dialog_start_col=$(((term_cols - dialog_width) / 2))
        [ "$dialog_start_row" -lt 1 ] && dialog_start_row=1
        [ "$dialog_start_col" -lt 1 ] && dialog_start_col=1

        # Draw dialog box
        draw_box_at "$dialog_start_row" "$dialog_start_col" "$dialog_inner_width" "$dialog_inner_height" 1

        # Draw error message
        error_row=$((dialog_start_row + padding + 1))
        error_col=$((dialog_start_col + (dialog_inner_width - msg_len) / 2 + 1))
        printf '\033[%d;%dH\033[1;31m%s\033[0m' "$error_row" "$error_col" "$error_msg"

        # Draw info message
        info_row=$((error_row + 1))
        info_col=$((dialog_start_col + (dialog_inner_width - info_len) / 2 + 1))
        printf '\033[%d;%dH%s' "$info_row" "$info_col" "$info_msg"

        # Draw button
        button_row=$((info_row + 2))
        button_col=$((dialog_start_col + (dialog_inner_width - ${#button_text}) / 2 + 1))
        printf '\033[%d;%dH\033[7m%s\033[0m' "$button_row" "$button_col" "$button_text"

        # Wait for Enter
        stty -echo -icanon
        while true; do
            char=$(dd bs=1 count=1 2>/dev/null)
            if [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                return 0
            fi
        done
    }

    # Show detailed review screen
    show_review_screen() {
        # Load configuration files
        install_config=$(find /tmp -name "jamstaller_install_config.*" 2>/dev/null | head -1)
        system_config=$(find /tmp -name "jamstaller_system_config.*" 2>/dev/null | head -1)
        user_config=$(find /tmp -name "jamstaller_user_config.*" 2>/dev/null | head -1)

        # Source configs
        [ -f "$install_config" ] && . "$install_config"
        [ -f "$system_config" ] && . "$system_config"
        [ -f "$user_config" ] && . "$user_config"

        # Calculate box dimensions
        box_inner_width=70
        box_width=$((box_inner_width + border_width))
        box_inner_height=24
        box_height=$((box_inner_height + border_width))

        dialog_start_row=$(((term_rows - box_height) / 2))
        dialog_start_col=$(((term_cols - box_width) / 2))
        [ "$dialog_start_row" -lt 1 ] && dialog_start_row=1
        [ "$dialog_start_col" -lt 1 ] && dialog_start_col=1

        # Clear and draw box
        printf '\033[H\033[2J'
        draw_box_at "$dialog_start_row" "$dialog_start_col" "$box_inner_width" "$box_inner_height" 0

        # Draw title
        title="Installation Review"
        title_row=$((dialog_start_row + padding + 1))
        title_col=$((dialog_start_col + (box_inner_width - ${#title}) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

        # Draw subtitle
        subtitle_row=$((title_row + 1))
        subtitle="Review your configuration before proceeding"
        subtitle_col=$((dialog_start_col + (box_inner_width - ${#subtitle}) / 2 + 1))
        printf '\033[%d;%dH\033[2m%s\033[0m' "$subtitle_row" "$subtitle_col" "$subtitle"

        # Content area
        content_row=$((subtitle_row + 2))
        content_col=$((dialog_start_col + padding + 2))

        # Network section
        printf '\033[%d;%dH\033[1mNetwork:\033[0m' "$content_row" "$content_col"
        content_row=$((content_row + 1))
        if check_connectivity 2>/dev/null; then
            printf '\033[%d;%dH  \033[32m[*]\033[0m Connected' "$content_row" "$content_col"
        else
            printf '\033[%d;%dH  \033[33m[ ]\033[0m Not connected (will skip)' "$content_row" "$content_col"
        fi

        # Install Location section
        content_row=$((content_row + 2))
        printf '\033[%d;%dH\033[1mInstall Location:\033[0m' "$content_row" "$content_col"
        content_row=$((content_row + 1))
        printf '\033[%d;%dH  Device: %s' "$content_row" "$content_col" "${INSTALL_DEVICE:-Unknown}"
        content_row=$((content_row + 1))
        if [ "$INSTALL_MODE" = "full" ]; then
            printf '\033[%d;%dH  Mode: \033[1;31mFull disk (will erase all data)\033[0m' "$content_row" "$content_col"
        else
            printf '\033[%d;%dH  Mode: Alongside existing OS' "$content_row" "$content_col"
            content_row=$((content_row + 1))
            printf '\033[%d;%dH  Partition: %s' "$content_row" "$content_col" "${INSTALL_PARTITION:-Unknown}"
        fi

        # System Setup section
        content_row=$((content_row + 2))
        printf '\033[%d;%dH\033[1mSystem Configuration:\033[0m' "$content_row" "$content_col"
        content_row=$((content_row + 1))
        printf '\033[%d;%dH  Hostname: %s' "$content_row" "$content_col" "${SYSTEM_HOSTNAME:-Unknown}"
        content_row=$((content_row + 1))
        printf '\033[%d;%dH  Timezone: %s' "$content_row" "$content_col" "${SYSTEM_TIMEZONE:-Unknown}"
        content_row=$((content_row + 1))
        if [ "$SYSTEM_SWAP" = "true" ]; then
            printf '\033[%d;%dH  Swap: Enabled' "$content_row" "$content_col"
        else
            printf '\033[%d;%dH  Swap: Disabled' "$content_row" "$content_col"
        fi

        # User Setup section
        content_row=$((content_row + 2))
        printf '\033[%d;%dH\033[1mUser Account:\033[0m' "$content_row" "$content_col"
        content_row=$((content_row + 1))
        printf '\033[%d;%dH  Username: %s' "$content_row" "$content_col" "${USER_USERNAME:-Unknown}"

        # Buttons
        draw_review_buttons() {
            back_selected="$1"
            install_selected="$2"

            button_row=$((dialog_start_row + box_inner_height - padding))

            back_text="Back"
            install_text="Install"
            gap=3
            total_width=$((${#back_text} + gap + ${#install_text}))
            button_col=$((dialog_start_col + (box_inner_width - total_width) / 2 + 1))

            printf '\033[%d;%dH' "$button_row" "$button_col"

            if [ "$back_selected" -eq 1 ]; then
                printf '\033[7m%s\033[0m' "$back_text"
            else
                printf '%s' "$back_text"
            fi

            printf '   '

            if [ "$install_selected" -eq 1 ]; then
                printf '\033[7m%s\033[0m' "$install_text"
            else
                printf '%s' "$install_text"
            fi
        }

        # Input loop
        selected_button=1  # 1 = back, 2 = install
        draw_review_buttons 1 0

        stty -echo -icanon
        while true; do
            char=$(dd bs=1 count=1 2>/dev/null)

            if [ "$char" = "$(printf '\033')" ]; then
                dd bs=1 count=1 2>/dev/null | read -r _ 2>/dev/null
                char=$(dd bs=1 count=1 2>/dev/null)

                case "$char" in
                    C) # Right
                        if [ "$selected_button" -eq 1 ]; then
                            selected_button=2
                            draw_review_buttons 0 1
                        fi
                        ;;
                    D) # Left
                        if [ "$selected_button" -eq 2 ]; then
                            selected_button=1
                            draw_review_buttons 1 0
                        fi
                        ;;
                esac
            elif [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                if [ "$selected_button" -eq 1 ]; then
                    return 0  # Back
                else
                    return 1  # Install
                fi
            fi
        done
    }

    # Show final warning before installation
    show_final_warning() {
        # Load install config to get device
        install_config=$(find /tmp -name "jamstaller_install_config.*" 2>/dev/null | head -1)
        [ -f "$install_config" ] && . "$install_config"

        # Calculate dialog dimensions
        warning_line1="FINAL WARNING"
        warning_line2="This will erase data on ${INSTALL_DEVICE:-the selected device}"
        warning_line3="This action CANNOT be undone!"
        button_cancel="Cancel"
        button_confirm="Confirm & Install"

        max_len=${#warning_line2}
        [ ${#warning_line3} -gt "$max_len" ] && max_len=${#warning_line3}

        dialog_content_width=$max_len
        dialog_inner_width=$((dialog_content_width + 4 + padding * 2))
        dialog_width=$((dialog_inner_width + border_width))
        dialog_inner_height=$((7 + padding * 2))
        dialog_height=$((dialog_inner_height + border_width))

        # Center dialog
        dialog_start_row=$(((term_rows - dialog_height) / 2))
        dialog_start_col=$(((term_cols - dialog_width) / 2))
        [ "$dialog_start_row" -lt 1 ] && dialog_start_row=1
        [ "$dialog_start_col" -lt 1 ] && dialog_start_col=1

        # Draw dialog box
        draw_box_at "$dialog_start_row" "$dialog_start_col" "$dialog_inner_width" "$dialog_inner_height" 1

        # Draw warning messages
        warn_row=$((dialog_start_row + padding + 1))
        warn_col=$((dialog_start_col + (dialog_inner_width - ${#warning_line1}) / 2 + 1))
        printf '\033[%d;%dH\033[1;31m%s\033[0m' "$warn_row" "$warn_col" "$warning_line1"

        warn_row=$((warn_row + 2))
        warn_col=$((dialog_start_col + (dialog_inner_width - ${#warning_line2}) / 2 + 1))
        printf '\033[%d;%dH%s' "$warn_row" "$warn_col" "$warning_line2"

        warn_row=$((warn_row + 1))
        warn_col=$((dialog_start_col + (dialog_inner_width - ${#warning_line3}) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$warn_row" "$warn_col" "$warning_line3"

        # Draw buttons
        draw_final_buttons() {
            cancel_selected="$1"
            confirm_selected="$2"

            button_row=$((dialog_start_row + dialog_inner_height - padding))

            gap=3
            total_width=$((${#button_cancel} + gap + ${#button_confirm}))
            button_col=$((dialog_start_col + (dialog_inner_width - total_width) / 2 + 1))

            printf '\033[%d;%dH' "$button_row" "$button_col"

            if [ "$cancel_selected" -eq 1 ]; then
                printf '\033[7m%s\033[0m' "$button_cancel"
            else
                printf '%s' "$button_cancel"
            fi

            printf '   '

            if [ "$confirm_selected" -eq 1 ]; then
                printf '\033[7m%s\033[0m' "$button_confirm"
            else
                printf '%s' "$button_confirm"
            fi
        }

        # Input loop - default to Cancel for safety
        selected_button=1  # 1 = cancel, 2 = confirm
        draw_final_buttons 1 0

        stty -echo -icanon
        while true; do
            char=$(dd bs=1 count=1 2>/dev/null)

            if [ "$char" = "$(printf '\033')" ]; then
                dd bs=1 count=1 2>/dev/null | read -r _ 2>/dev/null
                char=$(dd bs=1 count=1 2>/dev/null)

                case "$char" in
                    C) # Right
                        if [ "$selected_button" -eq 1 ]; then
                            selected_button=2
                            draw_final_buttons 0 1
                        fi
                        ;;
                    D) # Left
                        if [ "$selected_button" -eq 2 ]; then
                            selected_button=1
                            draw_final_buttons 1 0
                        fi
                        ;;
                esac
            elif [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                if [ "$selected_button" -eq 1 ]; then
                    return 0  # Cancel
                else
                    return 1  # Confirm
                fi
            fi
        done
    }

    # Run installation (placeholder)
    run_installation() {
        # Calculate dialog dimensions
        dialog_inner_width=60
        dialog_width=$((dialog_inner_width + border_width))
        dialog_inner_height=10
        dialog_height=$((dialog_inner_height + border_width))

        dialog_start_row=$(((term_rows - dialog_height) / 2))
        dialog_start_col=$(((term_cols - dialog_width) / 2))
        [ "$dialog_start_row" -lt 1 ] && dialog_start_row=1
        [ "$dialog_start_col" -lt 1 ] && dialog_start_col=1

        # Draw dialog box
        printf '\033[H\033[2J'
        draw_box_at "$dialog_start_row" "$dialog_start_col" "$dialog_inner_width" "$dialog_inner_height" 0

        # Draw title
        title="Installing System"
        title_row=$((dialog_start_row + padding + 1))
        title_col=$((dialog_start_col + (dialog_inner_width - ${#title}) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

        # Installation steps
        step_row=$((title_row + 2))
        step_col=$((dialog_start_col + padding + 2))

        # Spinner chars (classic ASCII spinner for TTY compatibility)
        spinner_chars="\\|/-"

        # Simulate installation steps
        steps="Partitioning disk|Formatting filesystems|Installing base system|Configuring system|Installing bootloader|Finalizing installation"
        step_count=0

        printf '%s' "$steps" | tr '|' '\n' | while IFS= read -r step; do
            step_count=$((step_count + 1))
            current_row=$((step_row + step_count - 1))

            # Show spinner while "working"
            i=0
            while [ "$i" -lt 10 ]; do
                spinner_idx=$((i % 4))
                spinner_char=$(echo "$spinner_chars" | cut -c$((spinner_idx + 1)))
                printf '\033[%d;%dH%s %s...' "$current_row" "$step_col" "$spinner_char" "$step"
                sleep 0.1
                i=$((i + 1))
            done

            # Show complete
            printf '\033[%d;%dH\033[32m[*]\033[0m %s' "$current_row" "$step_col" "$step"
        done

        # Show completion message
        complete_row=$((step_row + 8))
        complete_msg="Installation complete!"
        complete_col=$((dialog_start_col + (dialog_inner_width - ${#complete_msg}) / 2 + 1))
        printf '\033[%d;%dH\033[1;32m%s\033[0m' "$complete_row" "$complete_col" "$complete_msg"

        # Exit button
        button_row=$((complete_row + 2))
        button_text="Exit"
        button_col=$((dialog_start_col + (dialog_inner_width - ${#button_text}) / 2 + 1))
        printf '\033[%d;%dH\033[7m%s\033[0m' "$button_row" "$button_col" "$button_text"

        # Wait for Enter
        stty -echo -icanon
        while true; do
            char=$(dd bs=1 count=1 2>/dev/null)
            if [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                return 0
            fi
        done
    }

    # Save cursor position and hide cursor
    printf '\033[?1049h\033[H\033[2J\033[?25l'

    # Cleanup on exit
    cleanup() {
        printf '\033[?25h\033[?1049l'
        stty echo
        clear
        return "${1:-0}"
    }

    # Ctrl+C handler
    ctrl_c_count=0
    handle_sigint() {
        ctrl_c_count=$((ctrl_c_count + 1))

        if [ "$ctrl_c_count" -eq 1 ]; then
            # First Ctrl+C - show confirmation
            show_confirmation "cancel"
            confirm_result=$?

            # Redraw main UI
            redraw_main_ui
            if [ "$selected" -le "$stage_count" ]; then
                draw_stage "$selected" 1
                draw_buttons 0 0
            elif [ "$selected" -eq $((stage_count + 1)) ]; then
                draw_buttons 1 0
            else
                draw_buttons 0 1
            fi

            # If confirmed (Yes selected = return 1), exit
            if [ "$confirm_result" -eq 1 ]; then
                cleanup 1
                exit 1
            fi

            # Reset counter if they chose No
            ctrl_c_count=0
        else
            # Second Ctrl+C - immediate exit
            cleanup 1
            exit 1
        fi
    }

    trap 'handle_sigint' INT
    trap 'cleanup 1' TERM

    # Helper: redraw entire main UI
    redraw_main_ui() {
        printf '\033[H\033[2J'
        draw_box
        draw_title
        i=1
        while [ "$i" -le "$stage_count" ]; do
            draw_stage "$i" 0
            i=$((i + 1))
        done
        # Force output flush
        printf ''
    }

    # Initial render
    selected=1
    redraw_main_ui
    draw_stage "$selected" 1
    draw_buttons 0 0

    # Update selection
    update() {
        old="$1"
        new="$2"

        # Determine if old/new are stages or buttons
        if [ "$old" -le "$stage_count" ]; then
            draw_stage "$old" 0
        elif [ "$old" -eq $((stage_count + 1)) ]; then
            draw_buttons 0 0
        elif [ "$old" -eq $((stage_count + 2)) ]; then
            draw_buttons 0 0
        fi

        if [ "$new" -le "$stage_count" ]; then
            draw_stage "$new" 1
        elif [ "$new" -eq $((stage_count + 1)) ]; then
            draw_buttons 1 0
        elif [ "$new" -eq $((stage_count + 2)) ]; then
            draw_buttons 0 1
        fi
    }

    # Input loop
    stty -echo -icanon
    while true; do
        char=$(dd bs=1 count=1 2>/dev/null)

        if [ "$char" = "$(printf '\033')" ]; then
            dd bs=1 count=1 2>/dev/null | read -r _ 2>/dev/null
            char=$(dd bs=1 count=1 2>/dev/null)

            case "$char" in
                A) # Up arrow
                    [ "$selected" -gt 1 ] && {
                        old="$selected"
                        selected=$((selected - 1))
                        update "$old" "$selected"
                    }
                    ;;
                B) # Down arrow
                    [ "$selected" -lt "$total_count" ] && {
                        old="$selected"
                        selected=$((selected + 1))
                        update "$old" "$selected"
                    }
                    ;;
                C) # Right arrow (navigate between buttons)
                    if [ "$selected" -eq $((stage_count + 1)) ]; then
                        old="$selected"
                        selected=$((stage_count + 2))
                        update "$old" "$selected"
                    fi
                    ;;
                D) # Left arrow (navigate between buttons)
                    if [ "$selected" -eq $((stage_count + 2)) ]; then
                        old="$selected"
                        selected=$((stage_count + 1))
                        update "$old" "$selected"
                    fi
                    ;;
            esac
        elif [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
            # Handle button press
            if [ "$selected" -eq $((stage_count + 1)) ]; then
                # Cancel button - show confirmation
                show_confirmation "cancel"
                confirm_result=$?

                # Redraw main UI
                redraw_main_ui
                draw_buttons 1 0

                # If confirmed (Yes selected = return 1), exit
                if [ "$confirm_result" -eq 1 ]; then
                    cleanup 1
                    return 1
                fi
            elif [ "$selected" -eq $((stage_count + 2)) ]; then
                # Install button - check if all stages are complete
                all_complete=1
                i=1
                while [ "$i" -le "$stage_count" ]; do
                    eval "state=\$state_$i"
                    if [ "$state" -ne 1 ]; then
                        all_complete=0
                        break
                    fi
                    i=$((i + 1))
                done

                if [ "$all_complete" -eq 0 ]; then
                    # Show error - not all stages complete
                    show_incomplete_error

                    # Redraw main UI
                    redraw_main_ui
                    draw_stage "$selected" 1
                    draw_buttons 0 1
                else
                    # All stages complete - show review screen
                    show_review_screen
                    review_result=$?

                    if [ "$review_result" -eq 0 ]; then
                        # User went back, redraw main UI
                        redraw_main_ui
                        draw_stage "$selected" 1
                        draw_buttons 0 1
                    elif [ "$review_result" -eq 1 ]; then
                        # User confirmed install - show final warning
                        show_final_warning
                        final_result=$?

                        if [ "$final_result" -eq 0 ]; then
                            # User cancelled, redraw main UI
                            redraw_main_ui
                            draw_stage "$selected" 1
                            draw_buttons 0 1
                        else
                            # User confirmed - run installation
                            run_installation
                            cleanup 0
                            return 0
                        fi
                    fi
                fi
            else
                # Launch stage module
                eval "stage_name=\$stage_$selected"

                case "$stage_name" in
                    "Network Setup")
                        # Temporarily disable main script's signal handler
                        trap - INT

                        # Run network setup module
                        ./network_setup.sh
                        network_result=$?

                        # Re-enable main script's signal handler and reset counter
                        trap 'handle_sigint' INT
                        ctrl_c_count=0

                        # Update state based on result
                        if [ "$network_result" -eq 1 ]; then
                            eval "state_$selected=1"
                        else
                            eval "state_$selected=0"
                        fi

                        # Restore terminal state and redraw main UI
                        printf '\033[?1049h\033[H\033[2J\033[?25l'
                        stty -echo -icanon
                        redraw_main_ui
                        draw_stage "$selected" 1
                        draw_buttons 0 0
                        ;;
                    "Install Location")
                        # Temporarily disable main script's signal handler
                        trap - INT

                        # Run install location module
                        ./install_location.sh
                        location_result=$?

                        # Re-enable main script's signal handler and reset counter
                        trap 'handle_sigint' INT
                        ctrl_c_count=0

                        # Update state based on result
                        if [ "$location_result" -eq 1 ]; then
                            eval "state_$selected=1"
                        else
                            eval "state_$selected=0"
                        fi

                        # Restore terminal state and redraw main UI
                        printf '\033[?1049h\033[H\033[2J\033[?25l'
                        stty -echo -icanon
                        redraw_main_ui
                        draw_stage "$selected" 1
                        draw_buttons 0 0
                        ;;
                    "System Setup")
                        # Temporarily disable main script's signal handler
                        trap - INT

                        # Run system setup module
                        ./system_setup.sh
                        system_result=$?

                        # Re-enable main script's signal handler and reset counter
                        trap 'handle_sigint' INT
                        ctrl_c_count=0

                        # Update state based on result
                        if [ "$system_result" -eq 1 ]; then
                            eval "state_$selected=1"
                        else
                            eval "state_$selected=0"
                        fi

                        # Restore terminal state and redraw main UI
                        printf '\033[?1049h\033[H\033[2J\033[?25l'
                        stty -echo -icanon
                        redraw_main_ui
                        draw_stage "$selected" 1
                        draw_buttons 0 0
                        ;;
                    "User Setup")
                        # Temporarily disable main script's signal handler
                        trap - INT

                        # Run user setup module
                        ./user_setup.sh
                        user_result=$?

                        # Re-enable main script's signal handler and reset counter
                        trap 'handle_sigint' INT
                        ctrl_c_count=0

                        # Update state based on result
                        if [ "$user_result" -eq 1 ]; then
                            eval "state_$selected=1"
                        else
                            eval "state_$selected=0"
                        fi

                        # Restore terminal state and redraw main UI
                        printf '\033[?1049h\033[H\033[2J\033[?25l'
                        stty -echo -icanon
                        redraw_main_ui
                        draw_stage "$selected" 1
                        draw_buttons 0 0
                        ;;
                    *)
                        # Toggle stage state on Enter (for other stages)
                        eval "current_state=\$state_$selected"
                        new_state=$(((current_state + 1) % 2))
                        eval "state_$selected=$new_state"
                        draw_stage "$selected" 1
                        ;;
                esac
            fi
        fi
    done
}

# Set color palette
echo -e "
\e]P0282c34
\e]P1e06c75
\e]P298c379
\e]P3e5c07b
\e]P461afef
\e]P5c678dd
\e]P656b6c2
\e]P7abb2bf
\e]P85c6370
\e]P9e06c75
\e]PA98c379
\e]PBe5c07b
\e]PC61afef
\e]PDc678dd
\e]PE56b6c2
\e]PFffffff
" && clear

installer_tui "Jamstaller" \
  "Network Setup" \
  "Install Location" \
  "System Setup" \
  "User Setup" 

# Handle result
if [ $? -eq 0 ]; then
    echo "Installation started!"
else
    echo "Installation cancelled."
fi
