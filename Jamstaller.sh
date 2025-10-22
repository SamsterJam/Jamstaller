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

    # Save cursor position and hide cursor
    printf '\033[?1049h\033[H\033[2J\033[?25l'

    # Cleanup on exit
    cleanup() {
        printf '\033[?25h\033[?1049l'
        stty echo
        return "${1:-0}"
    }
    trap 'cleanup 1' INT TERM

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
                # Install button - show confirmation
                show_confirmation "install"
                confirm_result=$?

                # Redraw main UI
                redraw_main_ui
                draw_stage "$selected" 1
                draw_buttons 0 1

                # If confirmed (Yes selected = return 1), exit
                if [ "$confirm_result" -eq 1 ]; then
                    cleanup 0
                    return 0
                fi
            else
                # Toggle stage state on Enter (for testing)
                eval "current_state=\$state_$selected"
                new_state=$(((current_state + 1) % 2))
                eval "state_$selected=$new_state"
                draw_stage "$selected" 1
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
