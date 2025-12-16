#!/bin/bash
#
# Common functions and variables for Jamstaller
#

# Colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export BOLD_BLUE='\033[1;34m'
export NC='\033[0m'

# Global variables (will be set by TUI or config)
export HOSTNAME=""
export TIMEZONE=""
export USERNAME=""
export USER_PASSWORD=""
export DEVICE=""
export EFI_PARTITION=""
export ROOT_PARTITION=""
export SWAP_SIZE=0
export LOCALE="en_US.UTF-8"

# Paths
export MOUNT_POINT="/mnt"
export LOG_FILE="/var/log/jamstaller-install.log"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo ""
    echo -e "${BOLD_BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BOLD_BLUE}  $1${NC}"
    echo -e "${BOLD_BLUE}═══════════════════════════════════════${NC}"
    echo ""
}

# Validation functions
validate_hostname() {
    local hostname=$1
    local re='^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$'
    [[ $hostname =~ $re ]]
}

validate_username() {
    local username=$1
    local re='^[a-z_][a-z0-9_-]*[$]?$'
    [[ $username =~ $re ]] && [ ${#username} -le 32 ]
}

validate_timezone() {
    [ -f "/usr/share/zoneinfo/$1" ]
}

validate_device() {
    [ -b "/dev/$1" ]
}

# Utility functions
get_disk_size() {
    local device=$1
    lsblk -brndo SIZE "/dev/$device" | awk '{print int($1/1024/1024/1024)}'
}

detect_nvidia() {
    lspci | grep -E "VGA|3D" | grep -qi nvidia && echo "yes" || echo "no"
}

detect_intel() {
    lspci | grep -E "VGA|3D" | grep -qi intel && echo "yes" || echo "no"
}

detect_amd() {
    lspci | grep -E "VGA|3D" | grep -qi amd && echo "yes" || echo "no"
}

detect_intel_cpu() {
    grep -qi intel /proc/cpuinfo && echo "yes" || echo "no"
}

detect_amd_cpu() {
    grep -qi amd /proc/cpuinfo && echo "yes" || echo "no"
}

# Get number of CPU cores for parallel compilation
get_cpu_cores() {
    local total_cores=$(nproc)
    local used_cores=$(( (total_cores * 50 + 50) / 100 ))
    [ "$used_cores" -lt 1 ] && used_cores=1
    echo $used_cores
}

# Check if running in chroot
in_chroot() {
    [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]
}
