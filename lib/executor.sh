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

# Execute all installation steps
execute_install_steps() {
    local steps_dir=$1
    local failed_steps=()
    local total_steps=0
    local current_step=0

    # Count total steps
    total_steps=$(ls -1 "$steps_dir"/*.sh 2>/dev/null | wc -l)

    if [ $total_steps -eq 0 ]; then
        log_error "No installation steps found in $steps_dir"
        return 1
    fi

    log_info "Found $total_steps installation steps"
    echo ""

    # Execute each step in order
    for step_file in $(ls "$steps_dir"/*.sh | sort -V); do
        current_step=$((current_step + 1))

        local step_name=$(get_step_description "$step_file")
        local is_critical=$(parse_metadata "$step_file" "CRITICAL")
        local on_fail=$(parse_metadata "$step_file" "ONFAIL")

        # Display progress
        echo ""
        echo -e "${BOLD_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD_BLUE}[$current_step/$total_steps] $step_name...${NC}"
        echo -e "${BOLD_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

        # Execute the step
        if bash "$step_file" 2>&1 | tee -a "$LOG_FILE"; then
            echo -e "${GREEN}✓${NC} $step_name - Complete"
        else
            echo -e "${RED}✗${NC} $step_name - Failed"

            # Show custom failure message if provided
            if [ -n "$on_fail" ]; then
                echo -e "${RED}   $on_fail${NC}"
            fi

            # Check if this is a critical step
            if [[ "$is_critical" == "yes" ]]; then
                echo ""
                echo -e "${RED}╔════════════════════════════════════════════╗${NC}"
                echo -e "${RED}║  CRITICAL STEP FAILED                      ║${NC}"
                echo -e "${RED}║  Installation cannot continue              ║${NC}"
                echo -e "${RED}╚════════════════════════════════════════════╝${NC}"
                echo ""
                echo -e "${YELLOW}Check the log file for details: $LOG_FILE${NC}"
                return 1
            else
                log_warning "Non-critical step failed, continuing..."
                failed_steps+=("$step_name")
            fi
        fi
    done

    echo ""
    echo -e "${BOLD_BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    # Summary
    if [ ${#failed_steps[@]} -eq 0 ]; then
        echo -e "${GREEN}All steps completed successfully!${NC}"
        return 0
    else
        echo -e "${YELLOW}Installation completed with ${#failed_steps[@]} non-critical failure(s):${NC}"
        for failed in "${failed_steps[@]}"; do
            echo -e "  ${RED}•${NC} $failed"
        done
        echo ""
        echo -e "${YELLOW}You may need to fix these manually after installation.${NC}"
        return 0
    fi
}
