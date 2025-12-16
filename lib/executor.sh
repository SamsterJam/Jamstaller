#!/bin/bash
#
# Step execution engine for Jamstaller
#

# Parse metadata from step file
parse_metadata() {
    local file=$1
    local key=$2
    grep "^# ${key}=" "$file" 2>/dev/null | cut -d'=' -f2-
}

# Get description from step file (from metadata or filename)
get_step_description() {
    local step_file=$1

    # Try to get from DESCRIPTION metadata first
    local desc=$(parse_metadata "$step_file" "DESCRIPTION")

    # Fallback to filename if no metadata
    if [ -z "$desc" ]; then
        local filename=$(basename "$step_file" .sh)
        desc=$(echo "$filename" | sed 's/^[0-9]*_//' | tr '_' ' ')
    fi

    echo "$desc"
}

# Repeat a character N times
repeat_char() {
    local char=$1
    local count=$2
    for ((i=0; i<count; i++)); do
        printf '%s' "$char"
    done
}

# Draw a box at specified position
draw_box_at() {
    local row=$1
    local col=$2
    local width=$3
    local height=$4

    local inner_width=$((width - 2))
    local right_col=$((col + width - 1))

    # Top border
    printf '\033[%d;%dH┌' "$row" "$col"
    repeat_char '─' "$inner_width"
    printf '┐'

    # Middle rows
    for ((i=1; i<=height; i++)); do
        printf '\033[%d;%dH│' "$((row + i))" "$col"
        printf '\033[%d;%dH│' "$((row + i))" "$right_col"
    done

    # Bottom border
    printf '\033[%d;%dH└' "$((row + height + 1))" "$col"
    repeat_char '─' "$inner_width"
    printf '┘'
}

# Execute all installation steps with TUI
execute_install_steps() {
    local steps_dir=$1
    local failed_steps=()
    local total_steps=0
    local current_step=0

    # Clear screen and hide cursor IMMEDIATELY to prevent flash
    printf '\033[H\033[2J\033[?25l'

    # Get terminal dimensions
    if command -v tput >/dev/null 2>&1; then
        term_rows=$(tput lines)
        term_cols=$(tput cols)
    else
        term_rows=24
        term_cols=80
    fi

    # Count total steps
    total_steps=$(ls -1 "$steps_dir"/*.sh 2>/dev/null | wc -l)

    if [ $total_steps -eq 0 ]; then
        printf '\033[?25h'  # Show cursor
        log_error "No installation steps found in $steps_dir"
        return 1
    fi

    # Collect step information
    declare -a step_files
    declare -a step_names
    declare -a step_critical
    declare -a step_onfail
    declare -a step_status  # 0=pending, 1=running, 2=complete, 3=failed

    for step_file in $(ls "$steps_dir"/*.sh | sort -V); do
        step_files+=("$step_file")
        step_names+=("$(get_step_description "$step_file")")
        step_critical+=("$(parse_metadata "$step_file" "CRITICAL")")
        step_onfail+=("$(parse_metadata "$step_file" "ONFAIL")")
        step_status+=(0)
    done

    # Calculate box dimensions
    local box_width=70
    local inner_width=$((box_width - 2))
    local box_height=$((total_steps + 6))
    local box_row=$(( (term_rows - box_height) / 2 ))
    local box_col=$(( (term_cols - box_width) / 2 ))

    # Ensure box fits on screen
    if [ $box_row -lt 1 ]; then box_row=1; fi
    if [ $box_col -lt 1 ]; then box_col=1; fi

    # Calculate right column position
    local right_col=$((box_col + box_width - 1))

    # Draw the main box
    draw_box_at "$box_row" "$box_col" "$box_width" "$box_height"

    # Draw title
    local title="Installing System"
    local title_row=$((box_row + 2))
    local title_col=$(( box_col + (box_width - ${#title}) / 2 ))
    printf '\033[%d;%dH\033[1m%s\033[0m' "$title_row" "$title_col" "$title"

    # Draw separator
    local sep_row=$((title_row + 1))
    printf '\033[%d;%dH├' "$sep_row" "$box_col"
    repeat_char '─' "$inner_width"
    printf '┤'

    # Force flush to ensure box is fully rendered
    sync 2>/dev/null || true

    # Step list starts here
    local step_list_row=$((sep_row + 2))
    local step_col=$((box_col + 3))

    # Spinner characters
    local spinner_chars='|/-\'

    # Function to update step display
    update_step_display() {
        local idx=$1
        local status=$2
        local spinner_char=$3
        local row=$((step_list_row + idx))
        local name="${step_names[$idx]}"

        # Recalculate right column position to ensure it's accessible
        local step_right_col=$((box_col + box_width - 1))

        # Calculate max width for step text (leave room for border and padding)
        local max_text_width=$((box_width - 8))  # 3 for left padding + 4 for [X] + 1 for right padding

        # Truncate name if too long
        if [ ${#name} -gt $max_text_width ]; then
            name="${name:0:$((max_text_width - 3))}..."
        fi

        # Move cursor to step row
        printf '\033[%d;%dH' "$row" "$step_col"

        # Print status and name
        local line=""
        case $status in
            0) # Pending
                line="[ ] $name"
                ;;
            1) # Running (with spinner)
                line="\033[33m[$spinner_char]\033[0m $name"
                ;;
            2) # Complete
                line="\033[32m[*]\033[0m $name"
                ;;
            3) # Failed
                line="\033[31m[✗]\033[0m $name"
                ;;
        esac

        printf '%b' "$line"

        # Calculate how much space we need to fill before the border
        # We're at step_col (box_col + 3), we printed [X] (4 chars with space) + name
        # We need to fill to just before the border at step_right_col
        local content_width=$((4 + ${#name}))  # [X] + space + name
        local available_width=$((step_right_col - step_col - 1))  # -1 to leave room for border
        local padding=$((available_width - content_width))

        if [ $padding -gt 0 ]; then
            repeat_char ' ' "$padding"
        fi

        # Redraw right border to ensure it's visible
        printf '\033[%d;%dH│' "$row" "$step_right_col"
    }

    # Initial display of all steps as pending
    for ((i=0; i<total_steps; i++)); do
        update_step_display $i 0 ""
    done

    # Redraw the entire right border to ensure it's visible
    for ((i=0; i<total_steps; i++)); do
        local border_row=$((step_list_row + i))
        printf '\033[%d;%dH│' "$border_row" "$right_col"
    done

    # Execute each step
    for ((current_step=0; current_step<total_steps; current_step++)); do
        local step_file="${step_files[$current_step]}"
        local step_name="${step_names[$current_step]}"
        local is_critical="${step_critical[$current_step]}"
        local on_fail="${step_onfail[$current_step]}"

        # Create a temp file for step output
        local step_output=$(mktemp)
        local step_pid_file=$(mktemp)

        # Run step in background
        (
            bash "$step_file" >> "$LOG_FILE" 2>&1
            echo $? > "$step_pid_file"
        ) &
        local step_pid=$!

        # Show spinner while step runs
        local spinner_idx=0
        step_status[$current_step]=1

        while kill -0 "$step_pid" 2>/dev/null; do
            local spinner_char="${spinner_chars:$spinner_idx:1}"
            update_step_display $current_step 1 "$spinner_char"
            spinner_idx=$(( (spinner_idx + 1) % 4 ))
            sleep 0.1
        done

        # Wait for process to fully complete
        wait "$step_pid" 2>/dev/null
        local exit_code=$(cat "$step_pid_file" 2>/dev/null || echo "1")

        # Update display based on result
        if [ "$exit_code" -eq 0 ]; then
            step_status[$current_step]=2
            update_step_display $current_step 2 ""
        else
            step_status[$current_step]=3
            update_step_display $current_step 3 ""

            # Check if this is a critical step
            if [[ "$is_critical" == "yes" ]]; then
                # Show error message at bottom of box
                local error_row=$((box_row + box_height - 1))
                printf '\033[%d;%dH\033[31m Critical step failed! Check log: %s\033[0m' \
                    "$error_row" "$((box_col + 2))" "$LOG_FILE"

                # Wait a moment for user to see the error
                sleep 3

                # Show cursor and exit
                printf '\033[?25h'
                rm -f "$step_output" "$step_pid_file"
                return 1
            else
                failed_steps+=("$step_name")
            fi
        fi

        # Clean up temp files
        rm -f "$step_output" "$step_pid_file"
    done

    # Show completion message
    local complete_row=$((box_row + box_height - 1))
    if [ ${#failed_steps[@]} -eq 0 ]; then
        printf '\033[%d;%dH\033[1;32m%s\033[0m' "$complete_row" \
            "$((box_col + (box_width - 29) / 2))" "Installation completed successfully!"
    else
        printf '\033[%d;%dH\033[1;33m%s\033[0m' "$complete_row" \
            "$((box_col + (box_width - 45) / 2))" "Installation completed with ${#failed_steps[@]} warning(s)"
    fi

    # Wait for user to press Enter
    local prompt_row=$((complete_row + 2))
    printf '\033[%d;%dH\033[2mPress Enter to continue...\033[0m' \
        "$prompt_row" "$((box_col + (box_width - 27) / 2))"

    # Show cursor
    printf '\033[?25h'

    # Wait for Enter
    stty -echo
    read -r
    stty echo

    # Clear screen
    printf '\033[H\033[2J'

    # Return appropriate code
    if [ ${#failed_steps[@]} -eq 0 ]; then
        return 0
    else
        return 0  # Non-critical failures still return success
    fi
}
