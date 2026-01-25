#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check if command succeeded
check_command() {
    if [ $? -eq 0 ]; then
        print_success "$1"
    else
        print_error "$2"
        exit 1
    fi
}

print_status "Starting Nginx Full installation..."

# Update package list
print_status "Updating package list..."
sudo apt update
check_command "Package list updated successfully" "Failed to update package list"

# Install all packages
print_status "Installing net-tools, nginx, pkg-config, libssl-dev, build-essential, plocate, sshpass, neofetch, certbot, and python3-certbot-nginx..."
sudo apt install -y net-tools nginx pkg-config libssl-dev build-essential plocate sshpass neofetch certbot python3-certbot-nginx
check_command "All packages installed successfully" "Failed to install packages"

# Verify key installations
print_status "Verifying installations..."

if command -v nginx >/dev/null 2>&1; then
    print_success "Nginx installation verified - nginx command is available"
else
    print_warning "Nginx may not have installed correctly - nginx command not found"
fi

if command -v certbot >/dev/null 2>&1; then
    print_success "Certbot installation verified - certbot command is available"
else
    print_warning "Certbot may not have installed correctly - certbot command not found"
fi

if command -v neofetch >/dev/null 2>&1; then
    print_success "Neofetch installation verified - neofetch command is available"
else
    print_warning "Neofetch may not have installed correctly - neofetch command not found"
fi

print_success "Nginx Full installation completed successfully!"
print_status "You can now start Nginx with: sudo systemctl start nginx"
print_status "To enable Nginx to start on boot: sudo systemctl enable nginx"
print_status "To check Nginx status: sudo systemctl status nginx"
