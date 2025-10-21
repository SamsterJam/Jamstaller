#!/bin/sh

# TUI Prompt Function
# Usage: prompt_tui "Title" "Option 1" "Option 2" "Option 3"
prompt_tui() {
    # Parse arguments
    [ "$#" -lt 2 ] && return 1
    title="$1"
    shift

    # Store options
    i=1
    for arg in "$@"; do
        eval "opt_$i=\"\$arg\""
        i=$((i + 1))
    done
    count=$((i - 1))
    [ "$count" -eq 0 ] && return 1

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
    while [ "$i" -le "$count" ]; do
        eval "opt=\$opt_$i"
        opt_len=${#opt}
        [ "$opt_len" -gt "$max_opt_len" ] && max_opt_len=$opt_len
        i=$((i + 1))
    done

    # Calculate box dimensions
    title_len=${#title}
    content_width=$max_opt_len
    [ "$title_len" -gt "$content_width" ] && content_width=$title_len
    box_inner_width=$((content_width + 4 + padding * 2))
    box_width=$((box_inner_width + border_width))
    box_inner_height=$((3 + count + padding * 2))
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

    # Draw option at index
    draw_option() {
        idx="$1"
        is_selected="$2"

        option_row=$((start_row + padding + 3 + idx))
        option_col=$((start_col + padding + 2))

        eval "opt=\$opt_$idx"

        printf '\033[%d;%dH' "$option_row" "$option_col"
        spaces_needed=$((content_width + 4))
        j=0
        while [ "$j" -lt "$spaces_needed" ]; do
            printf ' '
            j=$((j + 1))
        done

        printf '\033[%d;%dH' "$option_row" "$option_col"
        if [ "$is_selected" = "1" ]; then
            printf '\033[7m> %s\033[0m' "$opt"
        else
            printf '  %s' "$opt"
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
    while [ "$i" -le "$count" ]; do
        draw_option "$i" 0
        i=$((i + 1))
    done
    draw_option "$selected" 1

    # Update selection
    update() {
        old="$1"
        new="$2"
        draw_option "$old" 0
        draw_option "$new" 1
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
                    [ "$selected" -lt "$count" ] && {
                        old="$selected"
                        selected=$((selected + 1))
                        update "$old" "$selected"
                    }
                    ;;
            esac
        elif [ "$char" = "$(printf '\n')" ] || [ "$char" = "$(printf '\r')" ]; then
            eval "result=\$opt_$selected"
            printf '\033[?25h\033[?1049l'
            stty echo
            printf '%s\n' "$result"
            return 0
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

green="$(printf '\033[32m')"
gray="$(printf '\033[90m')"
reset="$(printf '\033[0m')"

prompt_tui "Jamstaller" \
  "${green}[*]${reset} Install Location" \
  "[] System Setup" \
  "[] User Setup" \
  "[] Network Setup"
