#!/bin/sh

# User Setup Module for Jamstaller
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
user_setup_tui() {
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
    config_username=""
    config_password=""
    config_is_admin=""

    # === SCREEN 1: Username Input ===
    username_screen() {
        box_inner_height=12
        box_height=$((box_inner_height + border_width))
        start_row=$(((term_rows - box_height) / 2))
        [ "$start_row" -lt 1 ] && start_row=1

        printf '\033[H\033[2J'
        draw_box_at "$start_row" "$start_col" "$box_inner_width" "$box_inner_height" 0

        title="User Setup"
        title_row=$((start_row + padding + 1))
        title_col=$((start_col + (box_inner_width - ${#title}) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

        subtitle_row=$((title_row + 2))
        subtitle="Enter username:"
        subtitle_col=$((start_col + padding + 2))
        printf '\033[%d;%dH%s' "$subtitle_row" "$subtitle_col" "$subtitle"

        info_row=$((subtitle_row + 1))
        info_text="\033[2m(Lowercase letters and numbers only)\033[0m"
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
        draw_username_buttons() {
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
        max_username_len=$((input_box_width - 2))

        # Start with empty input
        username_input=""
        cursor_pos=0

        # Draw current input
        draw_input() {
            printf '\033[%d;%dH%s' "$field_row" "$field_col" "$username_input"
            # Clear any remaining characters
            remaining=$((max_username_len - ${#username_input}))
            if [ "$remaining" -gt 0 ]; then
                repeat_char ' ' "$remaining"
            fi
        }

        selected_button=0  # 0 = input, 1 = cancel

        draw_input
        draw_username_buttons 0
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
                            draw_username_buttons 0
                            printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                        fi
                        ;;
                    B) # Down
                        if [ "$selected_button" -eq 0 ]; then
                            selected_button=1
                            printf '\033[?25l'
                            draw_username_buttons 1
                        fi
                        ;;
                    C) # Right
                        if [ "$selected_button" -eq 0 ]; then
                            if [ "$cursor_pos" -lt "${#username_input}" ]; then
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
                        if [ "$selected_button" -eq 0 ] && [ "$cursor_pos" -lt "${#username_input}" ]; then
                            if [ "$cursor_pos" -eq 0 ]; then
                                username_input="${username_input#?}"
                            else
                                before=$(echo "$username_input" | awk -v pos="$cursor_pos" '{print substr($0, 1, pos)}')
                                after=$(echo "$username_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+2)}')
                                username_input="${before}${after}"
                            fi
                            after_cursor=$(echo "$username_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+1)}')
                            printf '\033[%d;%dH%s ' "$field_row" $((field_col + cursor_pos)) "$after_cursor"
                            printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                        fi
                        ;;
                esac
            elif [ "$char" = "$(printf '\177')" ]; then
                # Backspace
                if [ "$selected_button" -eq 0 ] && [ "$cursor_pos" -gt 0 ]; then
                    before=$(echo "$username_input" | awk -v pos="$cursor_pos" '{print substr($0, 1, pos-1)}')
                    after=$(echo "$username_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+1)}')
                    username_input="${before}${after}"
                    cursor_pos=$((cursor_pos - 1))
                    after_cursor=$(echo "$username_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+1)}')
                    printf '\033[%d;%dH%s ' "$field_row" $((field_col + cursor_pos)) "$after_cursor"
                    printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                fi
            elif [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                if [ "$selected_button" -eq 1 ]; then
                    # Cancel
                    cleanup 0
                    return 0
                else
                    # Enter - validate username
                    if [ -z "$username_input" ]; then
                        # Show error if empty
                        error_row=$((input_row + 4))
                        error_msg="\033[31mUsername cannot be empty\033[0m"
                        error_col=$((start_col + padding + 2))
                        printf '\033[%d;%dH%b' "$error_row" "$error_col" "$error_msg"
                        sleep 1
                        printf '\033[%d;%dH' "$error_row" "$error_col"
                        repeat_char ' ' 30
                        if [ "$selected_button" -eq 0 ]; then
                            printf '\033[?25h'
                            printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                        fi
                    # Validate username format (lowercase letters, numbers, underscore, hyphen)
                    elif echo "$username_input" | grep -qE '^[a-z_][a-z0-9_-]{0,31}$'; then
                        config_username="$username_input"
                        printf '\033[?25l'
                        password_screen
                        return $?
                    else
                        # Invalid username
                        error_row=$((input_row + 4))
                        error_msg="\033[31mInvalid username format\033[0m"
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
                    # Only accept valid username characters (lowercase letters, numbers, underscore, hyphen)
                    if echo "$char" | grep -qE '^[a-z0-9_-]$'; then
                        if [ "${#username_input}" -lt "$max_username_len" ]; then
                            if [ "$cursor_pos" -eq 0 ]; then
                                username_input="${char}${username_input}"
                            elif [ "$cursor_pos" -eq "${#username_input}" ]; then
                                username_input="${username_input}${char}"
                            else
                                before=$(echo "$username_input" | awk -v pos="$cursor_pos" '{print substr($0, 1, pos)}')
                                after=$(echo "$username_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+1)}')
                                username_input="${before}${char}${after}"
                            fi
                            cursor_pos=$((cursor_pos + 1))
                            from_cursor=$(echo "$username_input" | awk -v pos="$cursor_pos" '{print substr($0, pos)}')
                            printf '\033[%d;%dH%s' "$field_row" $((field_col + cursor_pos - 1)) "$from_cursor"
                            printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                        fi
                    fi
                fi
            fi
        done
    }

    # === SCREEN 2: Password Input ===
    password_screen() {
        box_inner_height=12
        box_height=$((box_inner_height + border_width))
        start_row=$(((term_rows - box_height) / 2))
        [ "$start_row" -lt 1 ] && start_row=1

        printf '\033[H\033[2J'
        draw_box_at "$start_row" "$start_col" "$box_inner_width" "$box_inner_height" 0

        title="User Setup"
        title_row=$((start_row + padding + 1))
        title_col=$((start_col + (box_inner_width - ${#title}) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

        subtitle_row=$((title_row + 2))
        subtitle="Enter password for $config_username:"
        subtitle_col=$((start_col + padding + 2))
        printf '\033[%d;%dH%s' "$subtitle_row" "$subtitle_col" "$subtitle"

        info_row=$((subtitle_row + 1))
        strength_display_row="$info_row"
        strength_display_col=$((start_col + padding + 2))

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
        draw_password_buttons() {
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

        # Input field position
        field_row=$((input_row + 1))
        field_col=$((input_col + 2))
        max_password_len=$((input_box_width - 2))

        password_input=""
        cursor_pos=0

        # Draw password (as asterisks) - initial draw only
        draw_password() {
            printf '\033[%d;%dH%s' "$field_row" "$field_col" "$1"
            remaining=$((max_password_len - ${#1}))
            if [ "$remaining" -gt 0 ]; then
                repeat_char ' ' "$remaining"
            fi
        }

        # Update password strength display
        update_strength_display() {
            calculate_password_strength "$password_input"
            printf '\033[%d;%dH' "$strength_display_row" "$strength_display_col"
            printf 'Strength: %b%s\033[0m' "$strength_color" "$strength_text"
            repeat_char ' ' 30
        }

        selected_button=0  # 0 = input, 1 = back

        # Initial draw - empty field
        draw_password ""
        draw_password_buttons 0
        update_strength_display
        printf '\033[?25h'
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
                            draw_password_buttons 0
                            printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                        fi
                        ;;
                    B) # Down
                        if [ "$selected_button" -eq 0 ]; then
                            selected_button=1
                            printf '\033[?25l'
                            draw_password_buttons 1
                        fi
                        ;;
                    C) # Right
                        if [ "$selected_button" -eq 0 ]; then
                            if [ "$cursor_pos" -lt "${#password_input}" ]; then
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
                        if [ "$selected_button" -eq 0 ] && [ "$cursor_pos" -lt "${#password_input}" ]; then
                            if [ "$cursor_pos" -eq 0 ]; then
                                password_input="${password_input#?}"
                            else
                                before=$(echo "$password_input" | awk -v pos="$cursor_pos" '{print substr($0, 1, pos)}')
                                after=$(echo "$password_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+2)}')
                                password_input="${before}${after}"
                            fi
                            # Only redraw from cursor position to end
                            after_cursor=$(echo "$password_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+1)}')
                            printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                            i=0
                            while [ "$i" -lt "${#after_cursor}" ]; do
                                printf '*'
                                i=$((i + 1))
                            done
                            printf ' '
                            update_strength_display
                            printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                        fi
                        ;;
                esac
            elif [ "$char" = "$(printf '\177')" ]; then
                # Backspace
                if [ "$selected_button" -eq 0 ] && [ "$cursor_pos" -gt 0 ]; then
                    before=$(echo "$password_input" | awk -v pos="$cursor_pos" '{print substr($0, 1, pos-1)}')
                    after=$(echo "$password_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+1)}')
                    password_input="${before}${after}"
                    cursor_pos=$((cursor_pos - 1))
                    # Only redraw from new cursor position to end
                    after_cursor=$(echo "$password_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+1)}')
                    printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                    i=0
                    while [ "$i" -lt "${#after_cursor}" ]; do
                        printf '*'
                        i=$((i + 1))
                    done
                    printf ' '
                    update_strength_display
                    printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                fi
            elif [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                if [ "$selected_button" -eq 1 ]; then
                    # Back
                    printf '\033[?25l'
                    username_screen
                    return $?
                else
                    # Enter - validate password (allow any non-empty password)
                    if [ -z "$password_input" ]; then
                        error_row=$((input_row + 4))
                        error_msg="\033[31mPassword cannot be empty\033[0m"
                        error_col=$((start_col + padding + 2))
                        printf '\033[%d;%dH%b' "$error_row" "$error_col" "$error_msg"
                        sleep 1
                        printf '\033[%d;%dH' "$error_row" "$error_col"
                        repeat_char ' ' 50
                        if [ "$selected_button" -eq 0 ]; then
                            printf '\033[?25h'
                            printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                        fi
                    else
                        config_password="$password_input"
                        printf '\033[?25l'
                        password_confirm_screen
                        return $?
                    fi
                fi
            else
                # Regular character input
                if [ "$selected_button" -eq 0 ]; then
                    # Accept any printable character for password
                    if [ "${#password_input}" -lt "$max_password_len" ]; then
                        if [ "$cursor_pos" -eq 0 ]; then
                            password_input="${char}${password_input}"
                        elif [ "$cursor_pos" -eq "${#password_input}" ]; then
                            password_input="${password_input}${char}"
                        else
                            before=$(echo "$password_input" | awk -v pos="$cursor_pos" '{print substr($0, 1, pos)}')
                            after=$(echo "$password_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+1)}')
                            password_input="${before}${char}${after}"
                        fi
                        cursor_pos=$((cursor_pos + 1))
                        # Only redraw from previous cursor position to end
                        from_cursor=$(echo "$password_input" | awk -v pos="$cursor_pos" '{print substr($0, pos)}')
                        printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos - 1))
                        i=0
                        while [ "$i" -lt "${#from_cursor}" ]; do
                            printf '*'
                            i=$((i + 1))
                        done
                        update_strength_display
                        printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                    fi
                fi
            fi
        done
    }

    # === SCREEN 3: Password Confirmation ===
    password_confirm_screen() {
        box_inner_height=12
        box_height=$((box_inner_height + border_width))
        start_row=$(((term_rows - box_height) / 2))
        [ "$start_row" -lt 1 ] && start_row=1

        printf '\033[H\033[2J'
        draw_box_at "$start_row" "$start_col" "$box_inner_width" "$box_inner_height" 0

        title="User Setup"
        title_row=$((start_row + padding + 1))
        title_col=$((start_col + (box_inner_width - ${#title}) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

        subtitle_row=$((title_row + 2))
        subtitle="Confirm password:"
        subtitle_col=$((start_col + padding + 2))
        printf '\033[%d;%dH%s' "$subtitle_row" "$subtitle_col" "$subtitle"

        info_row=$((subtitle_row + 1))
        info_text="\033[2m(Re-enter your password)\033[0m"
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
        draw_confirm_buttons() {
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

        # Input field position
        field_row=$((input_row + 1))
        field_col=$((input_col + 2))
        max_password_len=$((input_box_width - 2))

        confirm_input=""
        cursor_pos=0

        # Draw password (as asterisks) - initial draw only
        draw_confirm() {
            printf '\033[%d;%dH%s' "$field_row" "$field_col" "$1"
            remaining=$((max_password_len - ${#1}))
            if [ "$remaining" -gt 0 ]; then
                repeat_char ' ' "$remaining"
            fi
        }

        selected_button=0  # 0 = input, 1 = back

        # Initial draw - empty field
        draw_confirm ""
        draw_confirm_buttons 0
        printf '\033[?25h'
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
                            draw_confirm_buttons 0
                            printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                        fi
                        ;;
                    B) # Down
                        if [ "$selected_button" -eq 0 ]; then
                            selected_button=1
                            printf '\033[?25l'
                            draw_confirm_buttons 1
                        fi
                        ;;
                    C) # Right
                        if [ "$selected_button" -eq 0 ]; then
                            if [ "$cursor_pos" -lt "${#confirm_input}" ]; then
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
                        if [ "$selected_button" -eq 0 ] && [ "$cursor_pos" -lt "${#confirm_input}" ]; then
                            if [ "$cursor_pos" -eq 0 ]; then
                                confirm_input="${confirm_input#?}"
                            else
                                before=$(echo "$confirm_input" | awk -v pos="$cursor_pos" '{print substr($0, 1, pos)}')
                                after=$(echo "$confirm_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+2)}')
                                confirm_input="${before}${after}"
                            fi
                            # Only redraw from cursor position to end
                            after_cursor=$(echo "$confirm_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+1)}')
                            printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                            i=0
                            while [ "$i" -lt "${#after_cursor}" ]; do
                                printf '*'
                                i=$((i + 1))
                            done
                            printf ' '
                            printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                        fi
                        ;;
                esac
            elif [ "$char" = "$(printf '\177')" ]; then
                # Backspace
                if [ "$selected_button" -eq 0 ] && [ "$cursor_pos" -gt 0 ]; then
                    before=$(echo "$confirm_input" | awk -v pos="$cursor_pos" '{print substr($0, 1, pos-1)}')
                    after=$(echo "$confirm_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+1)}')
                    confirm_input="${before}${after}"
                    cursor_pos=$((cursor_pos - 1))
                    # Only redraw from new cursor position to end
                    after_cursor=$(echo "$confirm_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+1)}')
                    printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                    i=0
                    while [ "$i" -lt "${#after_cursor}" ]; do
                        printf '*'
                        i=$((i + 1))
                    done
                    printf ' '
                    printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                fi
            elif [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                if [ "$selected_button" -eq 1 ]; then
                    # Back
                    printf '\033[?25l'
                    password_screen
                    return $?
                else
                    # Enter - check if passwords match
                    if [ "$confirm_input" != "$config_password" ]; then
                        error_row=$((input_row + 4))
                        error_msg="\033[31mPasswords do not match\033[0m"
                        error_col=$((start_col + padding + 2))
                        printf '\033[%d;%dH%b' "$error_row" "$error_col" "$error_msg"
                        sleep 1
                        printf '\033[%d;%dH' "$error_row" "$error_col"
                        repeat_char ' ' 30
                        if [ "$selected_button" -eq 0 ]; then
                            printf '\033[?25h'
                            printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                        fi
                    else
                        # Set as admin user by default
                        config_is_admin="yes"
                        printf '\033[?25l'
                        summary_screen
                        return $?
                    fi
                fi
            else
                # Regular character input
                if [ "$selected_button" -eq 0 ]; then
                    if [ "${#confirm_input}" -lt "$max_password_len" ]; then
                        if [ "$cursor_pos" -eq 0 ]; then
                            confirm_input="${char}${confirm_input}"
                        elif [ "$cursor_pos" -eq "${#confirm_input}" ]; then
                            confirm_input="${confirm_input}${char}"
                        else
                            before=$(echo "$confirm_input" | awk -v pos="$cursor_pos" '{print substr($0, 1, pos)}')
                            after=$(echo "$confirm_input" | awk -v pos="$cursor_pos" '{print substr($0, pos+1)}')
                            confirm_input="${before}${char}${after}"
                        fi
                        cursor_pos=$((cursor_pos + 1))
                        # Only redraw from previous cursor position to end
                        from_cursor=$(echo "$confirm_input" | awk -v pos="$cursor_pos" '{print substr($0, pos)}')
                        printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos - 1))
                        i=0
                        while [ "$i" -lt "${#from_cursor}" ]; do
                            printf '*'
                            i=$((i + 1))
                        done
                        printf '\033[%d;%dH' "$field_row" $((field_col + cursor_pos))
                    fi
                fi
            fi
        done
    }

    # === SCREEN 4: Administrator Privileges ===
    admin_screen() {
        box_inner_height=14
        box_height=$((box_inner_height + border_width))
        start_row=$(((term_rows - box_height) / 2))
        [ "$start_row" -lt 1 ] && start_row=1

        printf '\033[H\033[2J'
        draw_box_at "$start_row" "$start_col" "$box_inner_width" "$box_inner_height" 0

        title="User Setup"
        title_row=$((start_row + padding + 1))
        title_col=$((start_col + (box_inner_width - ${#title}) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

        subtitle_row=$((title_row + 2))
        subtitle="Administrator privileges"
        subtitle_col=$((start_col + padding + 2))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$subtitle_row" "$subtitle_col" "$subtitle"

        info_row=$((subtitle_row + 1))
        info_text="\033[2m(Grant $config_username administrator rights?)\033[0m"
        info_col=$((start_col + padding + 2))
        printf '\033[%d;%dH%b' "$info_row" "$info_col" "$info_text"

        # Options
        yes_row=$((info_row + 3))
        yes_text="Yes - Make administrator (sudo access)"
        no_row=$((yes_row + 2))
        no_text="No - Standard user"

        # Draw options
        draw_admin_options() {
            selected="$1"

            col=$((start_col + padding + 2))

            # Yes option
            printf '\033[%d;%dH' "$yes_row" "$col"
            if [ "$selected" -eq 1 ]; then
                printf '\033[7m> %s\033[0m' "$yes_text"
            else
                printf '  %s' "$yes_text"
            fi

            # No option
            printf '\033[%d;%dH' "$no_row" "$col"
            if [ "$selected" -eq 2 ]; then
                printf '\033[7m> %s\033[0m' "$no_text"
            else
                printf '  %s' "$no_text"
            fi
        }

        # Draw buttons
        draw_admin_buttons() {
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

        # Selection loop
        selected_option=1  # Default to Yes
        selected_item=0  # 0 = option, 1 = back

        draw_admin_options "$selected_option"
        draw_admin_buttons 0

        while true; do
            char=$(dd bs=1 count=1 2>/dev/null)

            if [ "$char" = "$(printf '\033')" ]; then
                dd bs=1 count=1 2>/dev/null | read -r _ 2>/dev/null
                char=$(dd bs=1 count=1 2>/dev/null)

                case "$char" in
                    A) # Up
                        if [ "$selected_item" -eq 0 ]; then
                            if [ "$selected_option" -gt 1 ]; then
                                selected_option=$((selected_option - 1))
                                draw_admin_options "$selected_option"
                            fi
                        elif [ "$selected_item" -eq 1 ]; then
                            selected_item=0
                            draw_admin_options "$selected_option"
                            draw_admin_buttons 0
                        fi
                        ;;
                    B) # Down
                        if [ "$selected_item" -eq 0 ]; then
                            if [ "$selected_option" -lt 2 ]; then
                                selected_option=$((selected_option + 1))
                                draw_admin_options "$selected_option"
                            else
                                selected_item=1
                                draw_admin_options "$selected_option"
                                draw_admin_buttons 1
                            fi
                        fi
                        ;;
                esac
            elif [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
                if [ "$selected_item" -eq 1 ]; then
                    # Back
                    password_confirm_screen
                    return $?
                else
                    # Select option
                    if [ "$selected_option" -eq 1 ]; then
                        config_is_admin="yes"
                    else
                        config_is_admin="no"
                    fi
                    summary_screen
                    return $?
                fi
            fi
        done
    }

    # === SCREEN 5: Summary and Confirmation ===
    summary_screen() {
        box_inner_height=18
        box_height=$((box_inner_height + border_width))
        start_row=$(((term_rows - box_height) / 2))
        [ "$start_row" -lt 1 ] && start_row=1

        printf '\033[H\033[2J'
        draw_box_at "$start_row" "$start_col" "$box_inner_width" "$box_inner_height" 0

        title="User Configuration Summary"
        title_row=$((start_row + padding + 1))
        title_col=$((start_col + (box_inner_width - ${#title}) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

        summary_row=$((title_row + 2))
        col=$((start_col + padding + 2))

        printf '\033[%d;%dH\033[1mUsername:\033[0m     %s' "$summary_row" "$col" "$config_username"
        printf '\033[%d;%dH\033[1mPassword:\033[0m     %s' $((summary_row + 2)) "$col" "********"
        printf '\033[%d;%dH\033[1mRole:\033[0m         Administrator (sudo access)' $((summary_row + 4)) "$col"

        # Note about root password
        note_row=$((summary_row + 7))
        note_text="\033[32mNote: This password will also be used for root access\033[0m"
        printf '\033[%d;%dH%b' "$note_row" "$col" "$note_text"

        confirm_row=$((summary_row + 9))
        confirm_msg="Confirm user configuration?"
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
                    # Back to password confirmation screen
                    password_confirm_screen
                    return $?
                else
                    # Confirm - save configuration
                    cat > /tmp/jamstaller_user_config.$$ <<EOF
USER_USERNAME=$config_username
USER_PASSWORD=$config_password
USER_IS_ADMIN=$config_is_admin
EOF
                    cleanup 1
                    return 1
                fi
            fi
        done
    }

    # Start with username screen
    # Calculate password strength
    # Returns: score 0-4 and sets strength_text and strength_color
    calculate_password_strength() {
        pass="$1"
        length="${#pass}"
        score=0

        # Empty password
        [ "$length" -eq 0 ] && {
            strength_text=""
            strength_color=""
            return 0
        }

        # Length scoring
        [ "$length" -ge 8 ] && score=$((score + 1))
        [ "$length" -ge 12 ] && score=$((score + 1))

        # Character variety
        echo "$pass" | grep -q '[a-z]' && score=$((score + 1))
        echo "$pass" | grep -q '[A-Z]' && score=$((score + 1))
        echo "$pass" | grep -q '[0-9]' && score=$((score + 1))
        echo "$pass" | grep -qE '[^a-zA-Z0-9]' && score=$((score + 1))

        # Cap score at 4
        [ "$score" -gt 4 ] && score=4

        # Set text and color based on score
        case "$score" in
            0) strength_text="Very Weak"; strength_color="\033[1;31m" ;;  # Bold red
            1) strength_text="Weak"; strength_color="\033[31m" ;;          # Red
            2) strength_text="Fair"; strength_color="\033[33m" ;;          # Yellow
            3) strength_text="Good"; strength_color="\033[32m" ;;          # Green
            4) strength_text="Strong"; strength_color="\033[1;32m" ;;      # Bold green
        esac

        return "$score"
    }

    username_screen
}

# Run user setup TUI
user_setup_tui
exit $?
