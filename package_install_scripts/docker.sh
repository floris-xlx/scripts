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

print_status "Starting Docker installation..."

# Update package list
print_status "Updating package list..."
sudo apt update
check_command "Package list updated successfully" "Failed to update package list"

# Install prerequisites
print_status "Installing prerequisites..."
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
check_command "Prerequisites installed successfully" "Failed to install prerequisites"

# Add Docker's official GPG key
print_status "Adding Docker's official GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
check_command "Docker GPG key added successfully" "Failed to add Docker GPG key"

# Add Docker repository
print_status "Adding Docker repository..."
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
check_command "Docker repository added successfully" "Failed to add Docker repository"

# Check Docker CE policy
print_status "Checking Docker CE policy..."
apt-cache policy docker-ce
check_command "Docker CE policy checked successfully" "Failed to check Docker CE policy"

# Install Docker CE
print_status "Installing Docker CE..."
sudo apt install -y docker-ce
check_command "Docker CE installed successfully" "Failed to install Docker CE"

# Check Docker status
print_status "Checking Docker service status..."
sudo systemctl status docker --no-pager

# Verify Docker installation
if command -v docker >/dev/null 2>&1; then
    print_success "Docker installation verified - docker command is available"
else
    print_warning "Docker may not have installed correctly - docker command not found"
fi

print_success "Docker installation completed successfully!"
print_status "You can now use Docker with: sudo docker --version"
print_status "To add your user to the docker group (optional): sudo usermod -aG docker \$USER"
print_status "To start Docker on boot: sudo systemctl enable docker"
