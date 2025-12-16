#!/bin/bash
#
# Jamstaller Bootstrap
# Downloads and initializes the Jamstaller installation system
#

set -e

# Configuration
REPO_URL="https://raw.githubusercontent.com/SamsterJam/Jamstaller/main"
WORK_DIR="/tmp/jamstaller"
LOG_FILE="/var/log/jamstaller-bootstrap.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging
exec > >(tee "$LOG_FILE")
exec 2>&1

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}This script must be run as root. Please run with sudo or as the root user.${NC}"
    exit 1
fi

# Check for internet connectivity
echo -e "${BLUE}Checking internet connectivity...${NC}"
if ! ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
    echo -e "${RED}No internet connection detected. Please check your network and try again.${NC}"
    exit 1
fi

# Clean up any previous installations
if [ -d "$WORK_DIR" ]; then
    echo -e "${YELLOW}Removing previous Jamstaller workspace...${NC}"
    rm -rf "$WORK_DIR"
fi

# Create workspace
echo -e "${BLUE}Creating workspace at $WORK_DIR...${NC}"
mkdir -p "$WORK_DIR"/{lib,tui,steps}

# Download function with retry
download_file() {
    local url=$1
    local dest=$2
    local attempts=3
    local count=0

    while [ $count -lt $attempts ]; do
        if curl -fsSL "$url" -o "$dest" 2>/dev/null; then
            return 0
        fi
        count=$((count + 1))
        [ $count -lt $attempts ] && echo -e "${YELLOW}Download failed, retrying ($count/$attempts)...${NC}" && sleep 2
    done

    echo -e "${RED}Failed to download: $url${NC}"
    return 1
}

# Download manifest to know what files to fetch
echo -e "${BLUE}Downloading file manifest...${NC}"
if ! download_file "$REPO_URL/MANIFEST" "$WORK_DIR/MANIFEST"; then
    echo -e "${RED}Failed to download manifest. Installation cannot continue.${NC}"
    exit 1
fi

# Download all files listed in manifest
echo -e "${BLUE}Downloading Jamstaller components...${NC}"
total_files=$(wc -l < "$WORK_DIR/MANIFEST")
current=0

while IFS= read -r file; do
    current=$((current + 1))
    echo -e "${BLUE}[$current/$total_files] Downloading $file...${NC}"

    if ! download_file "$REPO_URL/$file" "$WORK_DIR/$file"; then
        echo -e "${RED}Failed to download required file: $file${NC}"
        exit 1
    fi

    # Make shell scripts executable
    if [[ "$file" == *.sh ]]; then
        chmod +x "$WORK_DIR/$file"
    fi
done < "$WORK_DIR/MANIFEST"

echo -e "${GREEN}All components downloaded successfully!${NC}"
echo ""

# Execute main installer
echo -e "${BLUE}Starting Jamstaller...${NC}"
cd "$WORK_DIR"
exec bash "$WORK_DIR/main.sh" "$@"
