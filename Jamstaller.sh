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
        # Account for state prefix "[*] " or "[] "
        opt_len=$((${#stage} + 4))
        [ "$opt_len" -gt "$max_opt_len" ] && max_opt_len=$opt_len
        i=$((i + 1))
    done

    # Check button lengths
    button_len=$((${#button_cancel} + ${#button_install} + 6))
    [ "$button_len" -gt "$max_opt_len" ] && max_opt_len=$button_len

    # Calculate box dimensions
    title_len=${#title}
    content_width=$max_opt_len
    [ "$title_len" -gt "$content_width" ] && content_width=$title_len
    box_inner_width=$((content_width + 4 + padding * 2))
    box_width=$((box_inner_width + border_width))
    box_inner_height=$((4 + stage_count + 2 + padding * 2))  # title + stages + spacer + buttons
    box_height=$((box_inner_height + border_width))

    # Calculate centering position
    start_row=$(((term_rows - box_height) / 2))
    start_col=$(((term_cols - box_width) / 2))
    [ "$start_row" -lt 1 ] && start_row=1
    [ "$start_col" -lt 1 ] && start_col=1

    # Draw border characters
    draw_box() {
        printf '\033[%d;%dH┌' "$start_row" "$start_col"
        i=1
        while [ "$i" -le "$box_inner_width" ]; do
            printf '─'
            i=$((i + 1))
        done
        printf '┐'

        i=1
        while [ "$i" -le "$box_inner_height" ]; do
            printf '\033[%d;%dH│' $((start_row + i)) "$start_col"
            printf '\033[%d;%dH│' $((start_row + i)) $((start_col + box_inner_width + 1))
            i=$((i + 1))
        done

        printf '\033[%d;%dH└' $((start_row + box_inner_height + 1)) "$start_col"
        i=1
        while [ "$i" -le "$box_inner_width" ]; do
            printf '─'
            i=$((i + 1))
        done
        printf '┘'
    }

    # Draw title
    draw_title() {
        title_row=$((start_row + padding + 1))
        title_start=$((start_col + (box_inner_width - title_len) / 2 + 1))
        printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_start" "$title"
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

        stage_row=$((start_row + padding + 3 + idx))
        stage_col=$((start_col + padding + 2))

        eval "stage=\$stage_$idx"
        eval "state=\$state_$idx"

        printf '\033[%d;%dH' "$stage_row" "$stage_col"

        if [ "$is_selected" = "1" ]; then
            # Highlight full row
            printf '\033[7m'
            printf '> '
            if [ "$state" -eq 1 ]; then
                printf '\033[27m\033[32m[*]\033[0m\033[7m'
            else
                printf '[]'
            fi
            printf ' %s' "$stage"
            # Pad to content_width
            text_len=$((4 + ${#stage}))
            j=$text_len
            while [ "$j" -lt "$content_width" ]; do
                printf ' '
                j=$((j + 1))
            done
            printf '\033[0m'
        else
            # Draw without highlight and pad to full width
            printf '  '
            if [ "$state" -eq 1 ]; then
                printf '\033[32m[*]\033[0m'
            else
                printf '[]'
            fi
            printf ' %s' "$stage"
            # Pad to content_width to clear any remaining highlight
            text_len=$((4 + ${#stage}))
            j=$text_len
            while [ "$j" -lt "$content_width" ]; do
                printf ' '
                j=$((j + 1))
            done
        fi
    }

    # Draw buttons
    draw_buttons() {
        is_cancel_selected="$1"
        is_install_selected="$2"

        # Spacer line
        spacer_row=$((start_row + padding + 4 + stage_count))

        # Button row
        button_row=$((spacer_row + 1))
        button_col=$((start_col + padding + 2))

        # Clear button area
        printf '\033[%d;%dH' "$button_row" "$button_col"
        spaces_needed=$((content_width + 4))
        j=0
        while [ "$j" -lt "$spaces_needed" ]; do
            printf ' '
            j=$((j + 1))
        done

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

    # Save cursor position and hide cursor
    printf '\033[?1049h\033[H\033[2J\033[?25l'

    # Cleanup on exit
    cleanup() {
        printf '\033[?25h\033[?1049l'
        stty echo
        return "${1:-0}"
    }
    trap 'cleanup 1' INT TERM

    # Initial render
    draw_box
    draw_title

    selected=1
    i=1
    while [ "$i" -le "$stage_count" ]; do
        draw_stage "$i" 0
        i=$((i + 1))
    done
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
                # Cancel button
                printf '\033[?25h\033[?1049l'
                stty echo
                return 1
            elif [ "$selected" -eq $((stage_count + 2)) ]; then
                # Install button
                printf '\033[?25h\033[?1049l'
                stty echo
                return 0
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
  "Install Location" \
  "System Setup" \
  "User Setup" \
  "Network Setup"

# Handle result
if [ $? -eq 0 ]; then
    echo "Installation started!"
else
    echo "Installation cancelled."
fi
