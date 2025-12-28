#!/bin/bash

# KWS System Requirements Checker for Arch Linux
# This script checks if your Arch Linux system meets the requirements for running KWS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "OK")
            echo -e "${GREEN}✓${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}⚠${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}✗${NC} $message"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ${NC} $message"
            ;;
    esac
}

# Function to check command existence
check_command() {
    local cmd=$1
    local package=$2
    if command -v "$cmd" &> /dev/null; then
        print_status "OK" "$cmd is installed"
        return 0
    else
        print_status "ERROR" "$cmd is not installed (install with: pacman -S $package)"
        return 1
    fi
}

# Function to check version
check_version() {
    local cmd=$1
    local min_version=$2
    local version_cmd=$3
    local package=$4

    if ! command -v "$cmd" &> /dev/null; then
        return 1
    fi

    local current_version
    current_version=$(eval "$version_cmd" 2>/dev/null | head -n1)

    if [[ -z "$current_version" ]]; then
        print_status "WARN" "Could not determine $cmd version"
        return 0
    fi

    # Simple version comparison (works for most cases)
    if [[ "$current_version" =~ ([0-9]+\.[0-9]+(\.[0-9]+)?) ]]; then
        local ver="${BASH_REMATCH[1]}"
        if [[ "$(printf '%s\n' "$min_version" "$ver" | sort -V | head -n1)" == "$min_version" ]]; then
            print_status "OK" "$cmd version $ver meets minimum $min_version"
        else
            print_status "WARN" "$cmd version $ver is below minimum $min_version"
        fi
    else
        print_status "INFO" "$cmd version: $current_version"
    fi
}

echo "========================================"
echo "KWS System Requirements Checker"
echo "========================================"
echo

# Check OS
echo "Checking Operating System..."
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ "$ID" == "arch" ]]; then
        print_status "OK" "Running Arch Linux ($PRETTY_NAME)"
    else
        print_status "ERROR" "This script is designed for Arch Linux, detected: $PRETTY_NAME"
        exit 1
    fi
else
    print_status "ERROR" "Cannot determine OS"
    exit 1
fi
echo

# Check system resources
echo "Checking System Resources..."

# RAM
total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
total_ram_gb=$((total_ram_kb / 1024 / 1024))

if (( total_ram_gb >= 4 )); then
    print_status "OK" "RAM: ${total_ram_gb}GB (minimum 4GB)"
else
    print_status "ERROR" "RAM: ${total_ram_gb}GB (minimum 4GB required)"
fi

# CPU cores
cpu_cores=$(nproc)
if (( cpu_cores >= 2 )); then
    print_status "OK" "CPU cores: $cpu_cores"
else
    print_status "WARN" "CPU cores: $cpu_cores (2+ recommended)"
fi

# Storage (check root filesystem free space)
root_free_gb=$(df / | tail -1 | awk '{print int($4/1024/1024)}')
if (( root_free_gb >= 20 )); then
    print_status "OK" "Free storage: ${root_free_gb}GB (minimum 20GB)"
else
    print_status "ERROR" "Free storage: ${root_free_gb}GB (minimum 20GB required)"
fi
echo

# Check privileges
echo "Checking User Privileges..."
if [[ $EUID -eq 0 ]]; then
    print_status "OK" "Running as root"
elif sudo -n true 2>/dev/null; then
    print_status "OK" "User has sudo access"
else
    print_status "WARN" "User may not have sudo access (test with: sudo -v)"
fi
echo

# Check required packages
echo "Checking Required Software..."

# Docker
if check_command "docker" "docker"; then
    check_version "docker" "20.10" "docker --version | cut -d' ' -f3 | cut -d',' -f1" "docker"
    # Check if Docker is running
    if docker info &>/dev/null; then
        print_status "OK" "Docker daemon is running"
    else
        print_status "ERROR" "Docker daemon is not running (start with: sudo systemctl start docker)"
    fi
fi

# Docker Compose (check both v1 and v2)
if check_command "docker-compose" "docker-compose"; then
    check_version "docker-compose" "2.0" "docker-compose --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'" "docker-compose"
elif docker compose version &>/dev/null 2>&1; then
    print_status "OK" "docker compose (v2) is available"
    check_version "docker" "2.0" "docker compose version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+'" "docker-compose"
else
    print_status "ERROR" "docker compose is not available (install docker-compose or use Docker v20.10+)"
fi

# LXD
if check_command "lxd" "lxd"; then
    # Check if LXD is initialized
    if sg lxd -c "lxc list" &>/dev/null; then
        print_status "OK" "LXD is initialized and accessible"
    else
        print_status "WARN" "LXD is installed but may not be initialized (run: sudo lxd init --auto)"
    fi
fi

# WireGuard
check_command "wg" "wireguard-tools"

# Go
if check_command "go" "go"; then
    check_version "go" "1.24" "go version | cut -d' ' -f3 | sed 's/go//'" "go"
fi

# uuidgen (part of util-linux)
check_command "uuidgen" "util-linux"

# curl (for downloading migrate)
check_command "curl" "curl"

# tar (for extracting migrate)
check_command "tar" "tar"

# Check for golang-migrate (optional, can be installed later)
if command -v "migrate" &> /dev/null; then
    print_status "OK" "golang-migrate is installed"
else
    print_status "INFO" "golang-migrate not found (will be installed during setup)"
fi

# Check for make
check_command "make" "make"

echo
echo "========================================"
echo "Network Configuration Check"
echo "========================================"

# Check network interfaces
echo "Available network interfaces:"
ip -br addr show | grep -v lo | while read -r line; do
    interface=$(echo "$line" | awk '{print $1}')
    state=$(echo "$line" | awk '{print $2}')
    ip=$(echo "$line" | awk '{print $3}')
    if [[ "$state" == "UP" ]]; then
        print_status "INFO" "Interface $interface: $ip"
    fi
done

echo
print_status "INFO" "For production deployment, ensure you have a static IP or domain name configured"
echo

echo "========================================"
echo "Summary"
echo "========================================"
echo "Review the checks above. If any requirements are not met,"
echo "install missing packages with: sudo pacman -S <package_name>"
echo
echo "For Docker group access, run: sudo usermod -aG docker \$USER"
echo "For LXD group access, run: sudo usermod -aG lxd \$USER"
echo "Then log out and back in for group changes to take effect."